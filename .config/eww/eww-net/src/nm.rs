//! Thin NetworkManager D-Bus helpers: property reads, the devices the control center shows,
//! and saved Wi-Fi profiles. Names and numbers come from NetworkManager's D-Bus API
//! (nm-dbus-interface.h).

use std::collections::HashMap;
use std::path::Path;

use serde::de::DeserializeOwned;
use serde::Serialize;
use zbus::blocking::Connection;
use zbus::zvariant::{DynamicType, OwnedObjectPath, OwnedValue, Type, Value};

pub const BUS: &str = "org.freedesktop.NetworkManager";
pub const ROOT: &str = "/org/freedesktop/NetworkManager";
pub const SETTINGS: &str = "/org/freedesktop/NetworkManager/Settings";
pub const IFACE_NM: &str = "org.freedesktop.NetworkManager";
pub const IFACE_DEVICE: &str = "org.freedesktop.NetworkManager.Device";
pub const IFACE_WIRELESS: &str = "org.freedesktop.NetworkManager.Device.Wireless";
pub const IFACE_AP: &str = "org.freedesktop.NetworkManager.AccessPoint";
pub const IFACE_ACTIVE: &str = "org.freedesktop.NetworkManager.Connection.Active";
pub const IFACE_SETTINGS_CONN: &str = "org.freedesktop.NetworkManager.Settings.Connection";
const IFACE_SETTINGS: &str = "org.freedesktop.NetworkManager.Settings";
const IFACE_PROPS: &str = "org.freedesktop.DBus.Properties";
const SYS_NET: &str = "/sys/class/net";

// NMDeviceType
const TYPE_ETHERNET: u32 = 1;
const TYPE_WIFI: u32 = 2;
// NMDeviceState
pub const STATE_UNMANAGED: u32 = 10;
pub const STATE_PREPARE: u32 = 40;
pub const STATE_SECONDARIES: u32 = 90;
pub const STATE_ACTIVATED: u32 = 100;
pub const STATE_FAILED: u32 = 120;
// NMActiveConnectionState
pub const AC_ACTIVATED: u32 = 2;
pub const AC_DEACTIVATED: u32 = 4;

pub type Props = HashMap<String, OwnedValue>;
pub type Result<T> = zbus::Result<T>;

pub struct Nm {
    pub conn: Connection,
}

/// The devices the control center shows.
pub struct Devices {
    pub wifi: Option<OwnedObjectPath>,
    /// Physical Ethernet devices, in NetworkManager's order.
    pub ethernet: Vec<OwnedObjectPath>,
}

/// A saved Wi-Fi profile.
pub struct Saved {
    pub path: OwnedObjectPath,
    /// Last successful activation (unix seconds), 0 if never.
    pub timestamp: u64,
}

impl Nm {
    pub fn connect() -> Result<Self> {
        Ok(Self {
            conn: Connection::system()?,
        })
    }

    pub fn call<B, R>(&self, path: &str, iface: &str, method: &str, body: &B) -> Result<R>
    where
        B: Serialize + DynamicType,
        R: DeserializeOwned + Type,
    {
        let reply = self
            .conn
            .call_method(Some(BUS), path, Some(iface), method, body)?;
        reply.body().deserialize()
    }

    /// A method call whose reply carries nothing we need.
    pub fn call_void<B>(&self, path: &str, iface: &str, method: &str, body: &B) -> Result<()>
    where
        B: Serialize + DynamicType,
    {
        self.conn
            .call_method(Some(BUS), path, Some(iface), method, body)?;
        Ok(())
    }

    pub fn props(&self, path: &str, iface: &str) -> Result<Props> {
        self.call(path, IFACE_PROPS, "GetAll", &(iface,))
    }

    pub fn set_prop(&self, path: &str, iface: &str, name: &str, value: Value<'_>) -> Result<()> {
        self.call_void(path, IFACE_PROPS, "Set", &(iface, name, value))
    }

    /// Finds the Wi-Fi device and the physical Ethernet devices.
    ///
    /// The kernel says which interfaces are real network hardware (a few file reads), and
    /// NetworkManager is asked only about those. Asking NetworkManager about each of its
    /// devices costs about 13 ms on this machine, which has dozens of Docker bridges and veths.
    pub fn devices(&self) -> Result<Devices> {
        let mut names: Vec<String> = std::fs::read_dir(SYS_NET)
            .map(|dir| {
                dir.flatten()
                    .map(|e| e.file_name().to_string_lossy().into_owned())
                    .collect()
            })
            .unwrap_or_default();
        names.sort();
        let mut devices = Devices {
            wifi: None,
            ethernet: Vec::new(),
        };
        for name in names {
            let dir = Path::new(SYS_NET).join(&name);
            // Only hardware has a `device` link: bridges, veths, tun and lo don't.
            if !dir.join("device").exists() {
                continue;
            }
            let wifi = dir.join("wireless").exists();
            if wifi && devices.wifi.is_some() {
                continue;
            }
            // Unknown to NetworkManager (e.g. marked unmanaged in its config): not ours to show.
            let Ok(path) = self.call::<_, OwnedObjectPath>(
                ROOT,
                IFACE_NM,
                "GetDeviceByIpIface",
                &(name.as_str(),),
            ) else {
                continue;
            };
            match self
                .props(path.as_str(), IFACE_DEVICE)
                .ok()
                .and_then(|p| u32_of(&p, "DeviceType"))
            {
                Some(TYPE_WIFI) => devices.wifi = Some(path),
                Some(TYPE_ETHERNET) => devices.ethernet.push(path),
                _ => {}
            }
        }
        Ok(devices)
    }

    /// The Ethernet device the "Wired" tile stands for (the first managed one) and its state.
    pub fn wired(&self, devices: &Devices) -> Option<(OwnedObjectPath, u32)> {
        devices.ethernet.iter().find_map(|path| {
            let state = u32_of(&self.props(path.as_str(), IFACE_DEVICE).ok()?, "State")?;
            (state != STATE_UNMANAGED).then(|| (path.clone(), state))
        })
    }

    /// Saved Wi-Fi client profiles by SSID, most recently used first.
    pub fn saved_wifi(&self) -> Result<HashMap<Vec<u8>, Vec<Saved>>> {
        let paths: Vec<OwnedObjectPath> =
            self.call(SETTINGS, IFACE_SETTINGS, "ListConnections", &())?;
        let mut saved: HashMap<Vec<u8>, Vec<Saved>> = HashMap::new();
        for path in paths {
            let Ok(s) = self.call::<_, HashMap<String, Props>>(
                path.as_str(),
                IFACE_SETTINGS_CONN,
                "GetSettings",
                &(),
            ) else {
                continue;
            };
            let (Some(conn), Some(wifi)) = (s.get("connection"), s.get("802-11-wireless")) else {
                continue;
            };
            // mode "ap" = a hotspot this machine hosts, not a network to join.
            if str_of(conn, "type") != Some("802-11-wireless") || str_of(wifi, "mode") == Some("ap")
            {
                continue;
            }
            let Some(ssid) = bytes_of(wifi, "ssid") else {
                continue;
            };
            let timestamp = u64_of(conn, "timestamp").unwrap_or(0);
            saved
                .entry(ssid)
                .or_default()
                .push(Saved { path, timestamp });
        }
        for profiles in saved.values_mut() {
            profiles.sort_by_key(|p| std::cmp::Reverse(p.timestamp));
        }
        Ok(saved)
    }
}

/// NetworkManager uses the path "/" for "none".
pub fn is_none(path: &OwnedObjectPath) -> bool {
    path.as_str() == "/"
}

fn get<'a>(p: &'a Props, key: &str) -> Option<&'a Value<'static>> {
    p.get(key).map(|v| &**v)
}

pub fn bool_of(p: &Props, key: &str) -> Option<bool> {
    match get(p, key)? {
        Value::Bool(v) => Some(*v),
        _ => None,
    }
}

pub fn u8_of(p: &Props, key: &str) -> Option<u8> {
    match get(p, key)? {
        Value::U8(v) => Some(*v),
        _ => None,
    }
}

pub fn u32_of(p: &Props, key: &str) -> Option<u32> {
    match get(p, key)? {
        Value::U32(v) => Some(*v),
        _ => None,
    }
}

pub fn u64_of(p: &Props, key: &str) -> Option<u64> {
    match get(p, key)? {
        Value::U64(v) => Some(*v),
        _ => None,
    }
}

pub fn str_of<'a>(p: &'a Props, key: &str) -> Option<&'a str> {
    match get(p, key)? {
        Value::Str(v) => Some(v.as_str()),
        _ => None,
    }
}

pub fn path_of(p: &Props, key: &str) -> Option<OwnedObjectPath> {
    match get(p, key)? {
        Value::ObjectPath(v) => Some(v.clone().into()),
        _ => None,
    }
}

pub fn paths_of(p: &Props, key: &str) -> Vec<OwnedObjectPath> {
    match get(p, key) {
        Some(Value::Array(items)) => items
            .iter()
            .filter_map(|v| match v {
                Value::ObjectPath(path) => Some(path.clone().into()),
                _ => None,
            })
            .collect(),
        _ => Vec::new(),
    }
}

pub fn bytes_of(p: &Props, key: &str) -> Option<Vec<u8>> {
    match get(p, key)? {
        Value::Array(items) => Some(
            items
                .iter()
                .filter_map(|v| match v {
                    Value::U8(b) => Some(*b),
                    _ => None,
                })
                .collect(),
        ),
        _ => None,
    }
}

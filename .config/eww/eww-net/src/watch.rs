//! `eww-net watch`: prints the network state as one JSON line, then a new line whenever it
//! changes, for eww's `deflisten`. It never polls. It wakes up on NetworkManager's D-Bus
//! signals, so a toggle or a finished connection reaches the panel within milliseconds.

use std::collections::HashMap;
use std::io::Write;
use std::sync::mpsc::{self, Receiver};
use std::time::{Duration, Instant};

use serde::Serialize;
use zbus::message::Type as MessageType;
use zbus::zvariant::OwnedObjectPath;
use zbus::{MatchRule, Message};

use crate::nm::{self, Nm, Saved};
use crate::{forward, hex, AnyResult};

/// Signals come in bursts (joining a network changes a dozen properties). Waiting this long
/// after the first one turns a burst into one update instead of a dozen.
const SETTLE: Duration = Duration::from_millis(40);

#[derive(Serialize)]
struct State {
    /// "on" when the Wi-Fi radio is enabled (both the software and the hardware switch).
    wifi: &'static str,
    /// Text under the Wi-Fi tile.
    label: String,
    /// "on" when the first managed Ethernet device is connected.
    wired: &'static str,
    networks: Vec<Network>,
}

#[derive(Serialize)]
struct Network {
    /// The SSID bytes as hex: always shell-safe, so yuck can paste it into a command.
    id: String,
    ssid: String,
    /// Rounded down to 0/25/50/75/100, the steps the signal icon has, so small strength
    /// changes don't redraw the list (a redraw clears a half-typed password).
    signal: u8,
    secured: bool,
    /// A saved profile exists, so connecting needs no password.
    known: bool,
    active: bool,
    connecting: bool,
}

pub fn run() -> AnyResult<()> {
    let nm = Nm::connect()?;
    // Subscribe before the first read, so no change can slip in between.
    let (tx, rx) = mpsc::channel();
    forward(
        &nm,
        MatchRule::builder()
            .msg_type(MessageType::Signal)
            .sender(nm::BUS)?
            .build(),
        tx.clone(),
    )?;
    // NetworkManager restarted: every object path changed.
    forward(
        &nm,
        MatchRule::builder()
            .msg_type(MessageType::Signal)
            .sender("org.freedesktop.DBus")?
            .member("NameOwnerChanged")?
            .arg(0, nm::BUS)?
            .build(),
        tx,
    )?;

    let mut saved = nm.saved_wifi().unwrap_or_default();
    let mut tracked = Vec::new();
    let mut last = String::new();
    let mut out = std::io::stdout().lock();
    loop {
        match read_state(&nm, &saved, &mut tracked) {
            Ok(state) => {
                let line = serde_json::to_string(&state)?;
                if line != last {
                    // The pipe is gone when eww stops the listener: nothing left to do.
                    if writeln!(out, "{line}").and_then(|()| out.flush()).is_err() {
                        return Ok(());
                    }
                    last = line;
                }
            }
            Err(e) => eprintln!("eww-net: reading NetworkManager state: {e}"),
        }
        if wait_for_change(&rx, &tracked)? {
            if let Ok(fresh) = nm.saved_wifi() {
                saved = fresh;
            }
        }
    }
}

enum Change {
    Ignored,
    State,
    /// Saved profiles changed (or NetworkManager restarted): re-read them as well.
    Saved,
}

/// Docker's bridges and veths, IP configs and DHCP leases also send signals: ignore those.
fn classify(msg: &Message, tracked: &[OwnedObjectPath]) -> Change {
    let header = msg.header();
    if header
        .member()
        .is_some_and(|m| m.as_str() == "NameOwnerChanged")
    {
        return Change::Saved;
    }
    let Some(path) = header.path().map(|p| p.as_str()) else {
        return Change::Ignored;
    };
    if path.starts_with(nm::SETTINGS) {
        Change::Saved
    } else if path == nm::ROOT
        || path.starts_with("/org/freedesktop/NetworkManager/AccessPoint/")
        || path.starts_with("/org/freedesktop/NetworkManager/ActiveConnection/")
        || tracked.iter().any(|t| t.as_str() == path)
    {
        Change::State
    } else {
        Change::Ignored
    }
}

/// Blocks until a relevant signal arrives, then swallows the rest of its burst.
/// Returns whether saved profiles need re-reading.
fn wait_for_change(rx: &Receiver<Message>, tracked: &[OwnedObjectPath]) -> AnyResult<bool> {
    let mut saved_changed = loop {
        match classify(&rx.recv()?, tracked) {
            Change::Ignored => continue,
            Change::State => break false,
            Change::Saved => break true,
        }
    };
    let deadline = Instant::now() + SETTLE;
    while let Ok(msg) = rx.recv_timeout(deadline.saturating_duration_since(Instant::now())) {
        saved_changed |= matches!(classify(&msg, tracked), Change::Saved);
    }
    Ok(saved_changed)
}

fn read_state(
    nm: &Nm,
    saved: &HashMap<Vec<u8>, Vec<Saved>>,
    tracked: &mut Vec<OwnedObjectPath>,
) -> nm::Result<State> {
    let root = nm.props(nm::ROOT, nm::IFACE_NM)?;
    let devices = nm.devices()?;
    tracked.clear();
    tracked.extend(devices.wifi.iter().cloned());
    tracked.extend(devices.ethernet.iter().cloned());

    let wired = match nm.wired(&devices) {
        Some((_, nm::STATE_ACTIVATED)) => "on",
        _ => "off",
    };
    let off = |label: &str| State {
        wifi: "off",
        label: label.into(),
        wired,
        networks: Vec::new(),
    };
    let Some(dev) = devices.wifi else {
        return Ok(off("No Wi-Fi"));
    };
    let enabled = nm::bool_of(&root, "WirelessEnabled").unwrap_or(false)
        && nm::bool_of(&root, "WirelessHardwareEnabled").unwrap_or(false);
    if !enabled {
        return Ok(off("Wifi Off"));
    }

    let device = nm.props(dev.as_str(), nm::IFACE_DEVICE)?;
    let wireless = nm.props(dev.as_str(), nm::IFACE_WIRELESS)?;
    let state = nm::u32_of(&device, "State").unwrap_or(0);
    let active = nm::path_of(&device, "ActiveConnection")
        .filter(|p| !nm::is_none(p))
        .and_then(|p| nm.props(p.as_str(), nm::IFACE_ACTIVE).ok());
    // While associating, ActiveAccessPoint can still be "/"; the activation already names the AP.
    let current_ap = nm::path_of(&wireless, "ActiveAccessPoint")
        .filter(|p| !nm::is_none(p))
        .or_else(|| {
            active
                .as_ref()
                .and_then(|a| nm::path_of(a, "SpecificObject"))
        })
        .filter(|p| !nm::is_none(p));

    let mut by_ssid: HashMap<Vec<u8>, Network> = HashMap::new();
    let mut current_ssid = None;
    for ap in nm::paths_of(&wireless, "AccessPoints") {
        // An AP can vanish between the list and this call.
        let Ok(p) = nm.props(ap.as_str(), nm::IFACE_AP) else {
            continue;
        };
        // Hidden networks have no SSID to show.
        let Some(ssid) = nm::bytes_of(&p, "Ssid").filter(|s| !s.is_empty()) else {
            continue;
        };
        if current_ap.as_ref() == Some(&ap) {
            current_ssid = Some(ssid.clone());
        }
        let signal = nm::u8_of(&p, "Strength").unwrap_or(0).min(100) / 25 * 25;
        let secured = nm::u32_of(&p, "Flags").unwrap_or(0) & 1 != 0 // NM_802_11_AP_FLAGS_PRIVACY
            || nm::u32_of(&p, "WpaFlags").unwrap_or(0) != 0
            || nm::u32_of(&p, "RsnFlags").unwrap_or(0) != 0;
        // One row per SSID (a network often has several APs): keep the strongest.
        let row = by_ssid.entry(ssid.clone()).or_insert_with(|| Network {
            id: hex::encode(&ssid),
            ssid: String::from_utf8_lossy(&ssid).into_owned(),
            signal,
            secured,
            known: saved.contains_key(&ssid),
            active: false,
            connecting: false,
        });
        row.signal = row.signal.max(signal);
    }

    let activated = state == nm::STATE_ACTIVATED;
    let connecting = (nm::STATE_PREPARE..=nm::STATE_SECONDARIES).contains(&state);
    if let Some(row) = current_ssid.as_ref().and_then(|s| by_ssid.get_mut(s)) {
        row.active = activated;
        row.connecting = connecting;
    }
    let label = if activated {
        // The profile name, like nmcli's GENERAL.CONNECTION (usually the SSID).
        active
            .as_ref()
            .and_then(|a| nm::str_of(a, "Id"))
            .map(str::to_owned)
            .or_else(|| {
                current_ssid
                    .as_ref()
                    .map(|s| String::from_utf8_lossy(s).into_owned())
            })
            .unwrap_or_else(|| "Connected".into())
    } else if connecting {
        "Connecting…".into()
    } else {
        "Disconnected".into()
    };

    let mut networks: Vec<Network> = by_ssid.into_values().collect();
    // Current network first, then by signal step, then by name: rows only move when a
    // network crosses a signal step, not on every small strength change.
    networks.sort_by(|a, b| {
        (b.active || b.connecting)
            .cmp(&(a.active || a.connecting))
            .then(b.signal.cmp(&a.signal))
            .then_with(|| a.ssid.to_lowercase().cmp(&b.ssid.to_lowercase()))
    });
    Ok(State {
        wifi: "on",
        label,
        wired,
        networks,
    })
}

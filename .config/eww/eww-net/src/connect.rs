//! `eww-net wifi connect ID [--password-stdin]`: starts the connection, waits for
//! NetworkManager's verdict and tells the control center what happened (close the password
//! row, or reopen it with an error). The list itself needs no help: `watch` shows
//! "Connecting…" and then the connected network as NetworkManager reports them.

use std::collections::HashMap;
use std::sync::mpsc::{self, Receiver};
use std::time::{Duration, Instant};

use zbus::message::Type as MessageType;
use zbus::zvariant::{ObjectPath, OwnedObjectPath, Value};
use zbus::{MatchRule, Message};

use crate::nm::{self, Nm};
use crate::{eww, forward, hex, AnyResult};

/// The eww button that runs this has `:timeout "60s"`; give up a little before eww kills us.
const WAIT: Duration = Duration::from_secs(50);

enum Outcome {
    Connected,
    /// NMDeviceStateReason of the failure, 0 if unknown.
    Failed(u32),
    TimedOut,
}

pub fn run(id: &str, password: Option<&str>) -> AnyResult<()> {
    let ssid = hex::decode(id).ok_or("network id is not hex")?;
    let name = String::from_utf8_lossy(&ssid).into_owned();
    if let Err(e) = connect(id, &ssid, &name, password) {
        eww::update(&[("cc_wifi_error", &format!("Could not connect to {name}"))]);
        return Err(e);
    }
    Ok(())
}

fn connect(id: &str, ssid: &[u8], name: &str, password: Option<&str>) -> AnyResult<()> {
    if password.is_some_and(|p| !(8..=64).contains(&p.len())) {
        eww::update(&[("cc_wifi_error", "Wi-Fi passwords are 8 to 63 characters")]);
        return Ok(());
    }
    let nm = Nm::connect()?;
    let dev = nm.devices()?.wifi.ok_or("no Wi-Fi device")?;
    let ap = strongest_ap(&nm, &dev, ssid);
    let saved = nm.saved_wifi()?.remove(ssid).unwrap_or_default();

    // Subscribe before activating: a wrong password can fail within milliseconds.
    let (tx, rx) = mpsc::channel();
    forward(
        &nm,
        MatchRule::builder()
            .msg_type(MessageType::Signal)
            .sender(nm::BUS)?
            .member("StateChanged")?
            .build(),
        tx,
    )?;

    // "/" lets NetworkManager pick the AP itself.
    let ap_path = ap.as_ref().map_or_else(
        || ObjectPath::from_static_str_unchecked("/"),
        |(p, _)| p.as_ref(),
    );
    let (created, active) = match (password, saved.first()) {
        (Some(psk), _) => {
            // A newly typed password replaces whatever was saved for this network. Only the
            // PSK is given, like nmcli does: NetworkManager fills in the security type (WPA2,
            // WPA3...) from the AP.
            for old in &saved {
                let _ = nm.call_void(old.path.as_str(), nm::IFACE_SETTINGS_CONN, "Delete", &());
            }
            let settings = HashMap::from([
                (
                    "802-11-wireless",
                    HashMap::from([("ssid", Value::from(ssid.to_vec()))]),
                ),
                (
                    "802-11-wireless-security",
                    HashMap::from([("psk", Value::from(psk))]),
                ),
            ]);
            add_and_activate(&nm, settings, &dev, ap_path)?
        }
        (None, Some(profile)) => {
            let active: OwnedObjectPath = nm.call(
                nm::ROOT,
                nm::IFACE_NM,
                "ActivateConnection",
                &(profile.path.as_ref(), dev.as_ref(), ap_path),
            )?;
            (None, active)
        }
        (None, None) => {
            let Some((_, secured)) = &ap else {
                return Err(format!("{name} is out of range").into());
            };
            if *secured {
                // Nothing saved for a secured network: ask for the password first.
                eww::update(&[("cc_pass_ssid", id), ("cc_pass", ""), ("cc_wifi_error", "")]);
                return Ok(());
            }
            add_and_activate(&nm, HashMap::new(), &dev, ap_path)?
        }
    };

    match wait(&rx, &dev, &active) {
        Outcome::Connected => {
            eww::update(&[("cc_pass_ssid", ""), ("cc_pass", ""), ("cc_wifi_error", "")])
        }
        Outcome::Failed(reason) => {
            // A profile that never worked would turn this network into a "known" one.
            if let Some(path) = &created {
                let _ = nm.call_void(path.as_str(), nm::IFACE_SETTINGS_CONN, "Delete", &());
            }
            // NO_SECRETS, SUPPLICANT_DISCONNECT/CONFIG_FAILED/FAILED/TIMEOUT: what a wrong or
            // missing password looks like.
            if (7..=11).contains(&reason) {
                let error = if password.is_some() {
                    "Wrong password, try again"
                } else {
                    "Password needed"
                };
                eww::update(&[
                    ("cc_pass_ssid", id),
                    ("cc_pass", ""),
                    ("cc_wifi_error", error),
                ]);
            } else {
                eww::update(&[("cc_wifi_error", &format!("Could not connect to {name}"))]);
            }
        }
        // NetworkManager is still trying; the list keeps showing what it does.
        Outcome::TimedOut => {}
    }
    Ok(())
}

type Settings<'a> = HashMap<&'a str, HashMap<&'a str, Value<'a>>>;

/// Returns (the new profile, the activation).
fn add_and_activate(
    nm: &Nm,
    settings: Settings<'_>,
    dev: &OwnedObjectPath,
    ap: ObjectPath<'_>,
) -> nm::Result<(Option<OwnedObjectPath>, OwnedObjectPath)> {
    let (profile, active): (OwnedObjectPath, OwnedObjectPath) = nm.call(
        nm::ROOT,
        nm::IFACE_NM,
        "AddAndActivateConnection",
        &(settings, dev.as_ref(), ap),
    )?;
    Ok((Some(profile), active))
}

/// The strongest visible AP of this network, and whether it is secured.
fn strongest_ap(nm: &Nm, dev: &OwnedObjectPath, ssid: &[u8]) -> Option<(OwnedObjectPath, bool)> {
    let wireless = nm.props(dev.as_str(), nm::IFACE_WIRELESS).ok()?;
    nm::paths_of(&wireless, "AccessPoints")
        .into_iter()
        .filter_map(|ap| {
            let p = nm.props(ap.as_str(), nm::IFACE_AP).ok()?;
            if nm::bytes_of(&p, "Ssid")? != ssid {
                return None;
            }
            let secured = nm::u32_of(&p, "Flags").unwrap_or(0) & 1 != 0
                || nm::u32_of(&p, "WpaFlags").unwrap_or(0) != 0
                || nm::u32_of(&p, "RsnFlags").unwrap_or(0) != 0;
            Some((nm::u8_of(&p, "Strength").unwrap_or(0), ap, secured))
        })
        .max_by_key(|(strength, ..)| *strength)
        .map(|(_, ap, secured)| (ap, secured))
}

fn wait(rx: &Receiver<Message>, dev: &OwnedObjectPath, active: &OwnedObjectPath) -> Outcome {
    let mut deadline = Instant::now() + WAIT;
    let mut deactivated = false;
    loop {
        let Ok(msg) = rx.recv_timeout(deadline.saturating_duration_since(Instant::now())) else {
            // The activation ended without the device saying why.
            return if deactivated {
                Outcome::Failed(0)
            } else {
                Outcome::TimedOut
            };
        };
        let header = msg.header();
        let (Some(path), Some(iface)) = (header.path(), header.interface()) else {
            continue;
        };
        if path.as_str() == dev.as_str() && iface.as_str() == nm::IFACE_DEVICE {
            if let Ok((new, _old, reason)) = msg.body().deserialize::<(u32, u32, u32)>() {
                match new {
                    nm::STATE_ACTIVATED => return Outcome::Connected,
                    nm::STATE_FAILED => return Outcome::Failed(reason),
                    _ => {}
                }
            }
        } else if path.as_str() == active.as_str() && iface.as_str() == nm::IFACE_ACTIVE {
            match msg.body().deserialize::<(u32, u32)>() {
                Ok((nm::AC_ACTIVATED, _)) => return Outcome::Connected,
                // The device's failure reason usually arrives right around this: give it a moment.
                Ok((nm::AC_DEACTIVATED, _)) => {
                    deactivated = true;
                    deadline = deadline.min(Instant::now() + Duration::from_millis(300));
                }
                _ => {}
            }
        }
    }
}

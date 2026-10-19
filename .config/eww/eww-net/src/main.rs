//! Wi-Fi and wired network state and actions for the eww control center.
//!
//! Talks to NetworkManager over D-Bus instead of running nmcli: about 1 ms per request
//! instead of about 35 ms, and state changes arrive as signals instead of being polled. See
//! `scripts/eww-net.sh` for how it is built and run.

mod connect;
mod nm;
mod watch;

use std::io::Read;
use std::process::ExitCode;
use std::sync::mpsc::Sender;

use zbus::blocking::MessageIterator;
use zbus::zvariant::{ObjectPath, Value};
use zbus::{MatchRule, Message};

use nm::Nm;

pub type AnyResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

const USAGE: &str = "usage: eww-net watch
       eww-net wifi toggle|rescan|disconnect
       eww-net wifi connect ID [--password-stdin]   (ID = SSID as hex, from `watch`)
       eww-net wired toggle";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let args: Vec<&str> = args.iter().map(String::as_str).collect();
    let result = match args.as_slice() {
        ["watch"] => watch::run(),
        ["wifi", "toggle"] => wifi_toggle(),
        ["wifi", "rescan"] => wifi_rescan(),
        ["wifi", "disconnect"] => wifi_disconnect(),
        ["wifi", "connect", id] => connect::run(id, None),
        ["wifi", "connect", id, "--password-stdin"] => {
            read_password().and_then(|p| connect::run(id, Some(&p)))
        }
        ["wired", "toggle"] => wired_toggle(),
        _ => {
            eprintln!("{USAGE}");
            return ExitCode::from(2);
        }
    };
    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("eww-net: {e}");
            ExitCode::FAILURE
        }
    }
}

/// The password comes on stdin (from `eww get cc_pass`), never on the command line where
/// `ps` would show it.
fn read_password() -> AnyResult<String> {
    let mut password = String::new();
    std::io::stdin().read_to_string(&mut password)?;
    // `eww get` ends the value with a newline.
    if password.ends_with('\n') {
        password.pop();
    }
    Ok(password)
}

fn wifi_toggle() -> AnyResult<()> {
    let nm = Nm::connect()?;
    let enabled =
        nm::bool_of(&nm.props(nm::ROOT, nm::IFACE_NM)?, "WirelessEnabled").unwrap_or(false);
    nm.set_prop(
        nm::ROOT,
        nm::IFACE_NM,
        "WirelessEnabled",
        Value::from(!enabled),
    )?;
    Ok(())
}

fn wifi_rescan() -> AnyResult<()> {
    let nm = Nm::connect()?;
    let dev = nm.devices()?.wifi.ok_or("no Wi-Fi device")?;
    // NetworkManager refuses a scan right after another one or while Wi-Fi is off. Either
    // way there is nothing to do: `watch` shows the results of whichever scan runs.
    let options: std::collections::HashMap<&str, Value> = Default::default();
    let _ = nm.call_void(dev.as_str(), nm::IFACE_WIRELESS, "RequestScan", &(options,));
    Ok(())
}

fn wifi_disconnect() -> AnyResult<()> {
    let nm = Nm::connect()?;
    let dev = nm.devices()?.wifi.ok_or("no Wi-Fi device")?;
    nm.call_void(dev.as_str(), nm::IFACE_DEVICE, "Disconnect", &())?;
    Ok(())
}

fn wired_toggle() -> AnyResult<()> {
    let nm = Nm::connect()?;
    let devices = nm.devices()?;
    let Some((dev, state)) = nm.wired(&devices) else {
        return Ok(());
    };
    if state == nm::STATE_ACTIVATED {
        nm.call_void(dev.as_str(), nm::IFACE_DEVICE, "Disconnect", &())?;
    } else {
        // Profile "/" = let NetworkManager pick the best one for the device (`nmcli device connect`).
        let any = ObjectPath::from_static_str_unchecked("/");
        nm.call_void(
            nm::ROOT,
            nm::IFACE_NM,
            "ActivateConnection",
            &(any.clone(), dev.as_ref(), any),
        )?;
    }
    Ok(())
}

/// Forwards every message matching `rule` to `tx`, from a background thread.
pub fn forward(nm: &Nm, rule: MatchRule<'static>, tx: Sender<Message>) -> zbus::Result<()> {
    let messages = MessageIterator::for_match_rule(rule, &nm.conn, Some(256))?;
    std::thread::spawn(move || {
        for msg in messages.flatten() {
            if tx.send(msg).is_err() {
                break;
            }
        }
    });
    Ok(())
}

/// Sets control center variables with `eww update`.
mod eww {
    use std::path::PathBuf;
    use std::process::{Command, Stdio};

    pub fn update(vars: &[(&str, &str)]) {
        let home = PathBuf::from(std::env::var_os("HOME").unwrap_or_default());
        // Same lookup as the shell scripts: $EWW_BIN, then ~/.local/bin/eww, then $PATH.
        let bin = std::env::var_os("EWW_BIN")
            .map(PathBuf::from)
            .unwrap_or_else(|| {
                let local = home.join(".local/bin/eww");
                if local.exists() {
                    local
                } else {
                    "eww".into()
                }
            });
        let config =
            std::env::var_os("EWW_CONFIG").map_or_else(|| home.join(".config/eww"), PathBuf::from);
        let status = Command::new(bin)
            .arg("--config")
            .arg(config)
            .arg("update")
            .args(vars.iter().map(|(k, v)| format!("{k}={v}")))
            .stdout(Stdio::null())
            .status();
        if let Err(e) = status {
            eprintln!("eww-net: running eww: {e}");
        }
    }
}

/// SSIDs are arbitrary bytes; as hex they are safe to paste into a shell command.
mod hex {
    pub fn encode(bytes: &[u8]) -> String {
        bytes.iter().map(|b| format!("{b:02x}")).collect()
    }

    pub fn decode(s: &str) -> Option<Vec<u8>> {
        if !s.len().is_multiple_of(2) {
            return None;
        }
        (0..s.len())
            .step_by(2)
            .map(|i| u8::from_str_radix(s.get(i..i + 2)?, 16).ok())
            .collect()
    }
}

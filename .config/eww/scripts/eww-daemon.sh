#!/usr/bin/env bash
# Keep exactly ONE healthy eww daemon running.
#
#   eww-daemon.sh ensure    start the daemon if it is missing; replace it if it stopped
#                           answering or if a second daemon exists (run before every popup)
#   eww-daemon.sh restart   kill every eww process and start a fresh daemon
#                           (runs on every sway reload, Mod+Shift+c)
#
# Why kill instead of just starting another daemon: when the daemon stops answering IPC
# (seen right after sway logged "connector HDMI-A-1: Atomic commit failed: Device or
# resource busy"), the next `eww open` silently starts a SECOND daemon and takes over the
# socket. The old daemon keeps its popup on screen, but every close command (clicking the
# clock, clicking outside) now reaches the new daemon, which answers "no such window was
# open" -> the popup is stuck for good. Killing every eww process removes those orphans.
set -u

EWW_BIN="${EWW_BIN:-$HOME/.local/bin/eww}"
[ -x "$EWW_BIN" ] || EWW_BIN="$(command -v eww)" || exit 1
CONFIG_DIR="$HOME/.config/eww"

healthy() {
    timeout 2 "$EWW_BIN" --config "$CONFIG_DIR" ping >/dev/null 2>&1
}

# Number of eww daemons listening on an IPC socket. More than 1 = split brain.
# (`ss -xl`, not `-xlp`: looking up the owning process costs ~35 ms per click.)
listeners() {
    ss -xl 2>/dev/null | grep -c 'eww-server_'
}

restart() {
    pkill -x eww
    for _ in {1..20}; do
        pgrep -x eww >/dev/null || break
        sleep 0.1
    done
    pkill -9 -x eww 2>/dev/null
    # No redirect: the daemon keeps our stdout/stderr, so its log lands in the journal
    "$EWW_BIN" --config "$CONFIG_DIR" daemon
    for _ in {1..30}; do
        healthy && return 0
        sleep 0.1
    done
    echo "eww-daemon.sh: daemon did not come up" >&2
    return 1
}

case "${1:-ensure}" in
    ensure)
        if healthy && [ "$(listeners)" -le 1 ]; then
            exit 0
        fi
        restart
        ;;
    restart)
        restart
        ;;
    *)
        echo "Usage: $0 [ensure|restart]" >&2
        exit 2
        ;;
esac

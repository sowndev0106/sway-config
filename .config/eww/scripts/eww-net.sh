#!/usr/bin/env bash
# Runs eww-net, the control center's Wi-Fi/wired helper (Rust, source in ../eww-net/).
#
#   eww-net.sh watch        live network state for `deflisten net` in eww.yuck
#   eww-net.sh build        (re)build the binary if it is missing or older than its source
#   eww-net.sh <args...>    an action, e.g. `wifi toggle` (run the binary with no args for the list)
#
# The binary lives in ~/.local/bin (next to eww), the build cache in ~/.cache/eww-net (outside the
# eww config dir, which eww watches for changes). `watch` rebuilds a stale binary first, so a
# `git pull` that changes the Rust source takes effect the next time the control center opens.
# Clicks never build: eww kills a click command after 200 ms by default.

set -euo pipefail

CONFIG_DIR="${EWW_CONFIG:-$HOME/.config/eww}"
SRC="$CONFIG_DIR/eww-net"
BIN="$HOME/.local/bin/eww-net"
TARGET_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/eww-net"

stale() {
    [ ! -x "$BIN" ] || [ -n "$(find -L "$SRC/Cargo.toml" "$SRC/Cargo.lock" "$SRC/src" -newer "$BIN" -print -quit)" ]
}

build() {
    # One build at a time (several eww windows can start `watch` together).
    exec 9>"${XDG_RUNTIME_DIR:-/tmp}/eww-net-build.lock"
    flock 9
    stale || return 0
    # The sway session's PATH does not always include rustup's cargo.
    PATH="$HOME/.cargo/bin:$PATH"
    # Build output goes to stderr: stdout of `watch` is what eww reads.
    if ! cargo build --release --locked --manifest-path "$SRC/Cargo.toml" --target-dir "$TARGET_DIR" >&2; then
        notify-send -u critical "eww-net" "Build failed: run ~/.config/eww/scripts/eww-net.sh build" 2>/dev/null || true
        return 1
    fi
    install -D -m 0755 "$TARGET_DIR/release/eww-net" "$BIN"
}

case "${1:-}" in
    build)
        build
        exit
        ;;
    watch)
        # A failed rebuild still runs the old binary if there is one.
        build || [ -x "$BIN" ]
        ;;
esac

if [ ! -x "$BIN" ]; then
    notify-send "eww-net" "Not built yet: run ~/.config/eww/scripts/eww-net.sh build" 2>/dev/null || true
    exit 1
fi
exec "$BIN" "$@"

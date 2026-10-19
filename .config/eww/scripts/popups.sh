#!/usr/bin/env bash
# Shared helpers for the header popups (calendar, control center, sensors).
#
#   popups.sh close-all           close every popup and every closer
#   popups.sh open-closers NAME   open the closer window NAME on EVERY monitor, so a click
#                                 anywhere outside the popup, on any screen, closes it
#
# A closer is a transparent full-screen window that sits under the popup; clicking it
# runs `close-all`. One closer per monitor, each with its own id: NAME-<output>.
set -u

EWW_BIN="${EWW_BIN:-$HOME/.local/bin/eww}"
[ -x "$EWW_BIN" ] || EWW_BIN="$(command -v eww)" || exit 1
CONFIG_DIR="$HOME/.config/eww"
eww() { "$EWW_BIN" --config "$CONFIG_DIR" "$@"; }

case "${1:-}" in
    close-all)
        # active-windows prints "<id>: <window name>"; every popup and closer id has "-popup"
        mapfile -t ids < <(eww active-windows | cut -d: -f1 | grep -- '-popup')
        [ "${#ids[@]}" -eq 0 ] || eww close "${ids[@]}"
        ;;
    open-closers)
        name="${2:?usage: popups.sh open-closers NAME}"
        windows=()
        args=()
        for out in $(swaymsg -t get_outputs | jq -r '.[] | select(.active).name'); do
            windows+=("$name:$name-$out")
            args+=(--arg "$name-$out:monitor=$out")
        done
        eww open-many "${windows[@]}" "${args[@]}"
        ;;
    *)
        echo "Usage: $0 close-all | open-closers NAME" >&2
        exit 2
        ;;
esac

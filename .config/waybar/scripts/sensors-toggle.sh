#!/usr/bin/env bash
# Manage on/off state for each sensor tile on waybar.
# Usage: sensors-toggle.sh get|toggle|enabled <key>
# key: temp | cpu | freq | power | ram
set -euo pipefail

STATE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/sensors.state"
KEYS=(temp cpu freq power ram)

_get() {
    local key="$1"
    if [ -f "$STATE_FILE" ]; then
        local val
        val=$(grep "^${key}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2 || true)
        echo "${val:-on}"
    else
        echo "on"
    fi
}

_set() {
    local key="$1" val="$2"
    mkdir -p "$(dirname "$STATE_FILE")"
    local tmp=""
    if [ -f "$STATE_FILE" ]; then
        tmp=$(grep -v "^${key}=" "$STATE_FILE" || true)
    fi
    printf '%s\n%s=%s\n' "$tmp" "$key" "$val" > "$STATE_FILE"
}

_count_on() {
    local count=0
    for k in "${KEYS[@]}"; do
        [ "$(_get "$k")" = "on" ] && count=$((count + 1))
    done
    echo "$count"
}

case "${1:-}" in
    get)
        [ -z "${2:-}" ] && { echo "Missing key" >&2; exit 1; }
        _get "$2"
        ;;
    toggle)
        [ -z "${2:-}" ] && { echo "Missing key" >&2; exit 1; }
        key="$2"
        cur=$(_get "$key")
        if [ "$cur" = "on" ]; then
            # Refuse to turn off the last enabled tile
            if [ "$(_count_on)" -le 1 ]; then
                exit 0
            fi
            _set "$key" "off"
        else
            _set "$key" "on"
        fi
        # Refresh waybar via RTMIN+8 signal (safe — does not kill waybar)
        pkill -RTMIN+8 -x waybar 2>/dev/null || true
        ;;
    enabled)
        [ -z "${2:-}" ] && { echo "Missing key" >&2; exit 1; }
        [ "$(_get "$2")" = "on" ]
        ;;
    *)
        echo "Usage: sensors-toggle.sh get|toggle|enabled <key>" >&2
        exit 1
        ;;
esac

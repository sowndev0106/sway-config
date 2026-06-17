#!/usr/bin/env bash
set -euo pipefail
TOGGLE="$HOME/.config/waybar/scripts/sensors-toggle.sh"

if ! "$TOGGLE" enabled ram 2>/dev/null; then
    printf '{"text":"","tooltip":"","class":""}\n'
    exit 0
fi

icon=$(printf '')

ram_total=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
ram_avail=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
ram_pct=$(( (ram_total - ram_avail) * 100 / ram_total ))

tooltip=$("$HOME/.config/waybar/scripts/sensors-readall.sh" 2>/dev/null || true)
printf '{"text":"%s %d%%","tooltip":"%s","class":""}\n' "$icon" "$ram_pct" "$tooltip"

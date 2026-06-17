#!/usr/bin/env bash
set -euo pipefail
TOGGLE="$HOME/.config/waybar/scripts/sensors-toggle.sh"

if ! "$TOGGLE" enabled temp 2>/dev/null; then
    printf '{"text":"","tooltip":"","class":""}\n'
    exit 0
fi

temp_raw=$(cat /sys/class/thermal/thermal_zone9/temp 2>/dev/null || echo 0)
temp_c=$((temp_raw / 1000))
cls=""

if [ "$temp_c" -ge 85 ]; then
    icon=$(printf '')
    cls="critical"
elif [ "$temp_c" -ge 60 ]; then
    icon=$(printf '')
else
    icon=$(printf '')
fi

tooltip=$("$HOME/.config/waybar/scripts/sensors-readall.sh" 2>/dev/null || true)
printf '{"text":"%s %d°C","tooltip":"%s","class":"%s"}\n' \
    "$icon" "$temp_c" "$tooltip" "$cls"

#!/usr/bin/env bash
set -euo pipefail
TOGGLE="$HOME/.config/waybar/scripts/sensors-toggle.sh"

if ! "$TOGGLE" enabled cpu 2>/dev/null; then
    printf '{"text":"","tooltip":"","class":""}\n'
    exit 0
fi

icon=$(printf '')

read_stat() { awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $2+$3+$4+$6+$7+$8}' /proc/stat; }
s1=$(read_stat); sleep 0.5; s2=$(read_stat)
total1=${s1%% *}; busy1=${s1##* }
total2=${s2%% *}; busy2=${s2##* }
dtotal=$((total2 - total1)); dbusy=$((busy2 - busy1))
[ "$dtotal" -eq 0 ] && pct=0 || pct=$(( (dbusy * 100) / dtotal ))

tooltip=$("$HOME/.config/waybar/scripts/sensors-readall.sh" 2>/dev/null || true)
printf '{"text":"%s %d%%","tooltip":"%s","class":""}\n' "$icon" "$pct" "$tooltip"

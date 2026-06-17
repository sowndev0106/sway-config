#!/usr/bin/env bash
set -euo pipefail
TOGGLE="$HOME/.config/waybar/scripts/sensors-toggle.sh"

if ! "$TOGGLE" enabled freq 2>/dev/null; then
    printf '{"text":"","tooltip":"","class":""}\n'
    exit 0
fi

freq_sum=0; freq_n=0
for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
    [ -r "$f" ] || continue
    freq_sum=$((freq_sum + $(cat "$f")))
    freq_n=$((freq_n + 1))
done
if [ "$freq_n" -gt 0 ]; then
    freq_ghz=$(awk "BEGIN{printf \"%.2f\", $freq_sum / $freq_n / 1000000}")
else
    freq_ghz="?.??"
fi

tooltip=$("$HOME/.config/waybar/scripts/sensors-readall.sh" 2>/dev/null || true)
printf '{"text":"%sGHz","tooltip":"%s","class":""}\n' "$freq_ghz" "$tooltip"

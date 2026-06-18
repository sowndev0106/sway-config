#!/usr/bin/env bash
set -euo pipefail
governor="${1:?Usage: set-cpu-governor.sh <governor>}"
for path in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -f "$path" ] && echo "$governor" > "$path"
done

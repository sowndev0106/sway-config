#!/usr/bin/env bash
set -euo pipefail

HELPER="$(dirname -- "${BASH_SOURCE[0]}")/set-cpu-governor.sh"
GOV_FILE="/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"

case "${1:-}" in
    get)
        gov=$(cat "$GOV_FILE" 2>/dev/null || echo "unknown")
        [ "$gov" = "performance" ] && echo "on" || echo "off"
        ;;
    toggle)
        gov=$(cat "$GOV_FILE" 2>/dev/null || echo "unknown")
        if [ "$gov" = "performance" ]; then
            sudo "$HELPER" schedutil
        else
            sudo "$HELPER" performance
        fi
        ;;
    *)
        echo "Usage: cpu-governor.sh get|toggle" >&2; exit 1 ;;
esac

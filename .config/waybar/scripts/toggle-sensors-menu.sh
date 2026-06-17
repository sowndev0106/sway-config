#!/usr/bin/env bash
set -euo pipefail

EWW_BIN="${EWW_BIN:-$HOME/.local/bin/eww}"
if [ ! -x "$EWW_BIN" ]; then
    command -v eww >/dev/null 2>&1 && EWW_BIN="$(command -v eww)" || exit 0
fi

CONFIG_DIR="$HOME/.config/eww"
TOGGLE="$HOME/.config/waybar/scripts/sensors-toggle.sh"
WINDOW="sensors-popup"
CLOSER="sensors-popup-closer"

MONITOR="$(swaymsg -t get_outputs 2>/dev/null | jq -r '.[] | select(.focused).name' | head -n1)"
MONITOR="${MONITOR:-0}"

# Start daemon if not running
if ! "$EWW_BIN" --config "$CONFIG_DIR" active-windows >/dev/null 2>&1; then
    "$EWW_BIN" --config "$CONFIG_DIR" daemon >/dev/null 2>&1 || true
    for i in {1..30}; do
        "$EWW_BIN" --config "$CONFIG_DIR" active-windows >/dev/null 2>&1 && break
        sleep 0.1
    done
fi

if "$EWW_BIN" --config "$CONFIG_DIR" active-windows | grep -q "^${WINDOW}"; then
    "$EWW_BIN" --config "$CONFIG_DIR" close "$WINDOW" || true
    "$EWW_BIN" --config "$CONFIG_DIR" close "$CLOSER" || true
else
    # Sync eww vars from state file before opening (instant, no poll lag)
    "$EWW_BIN" --config "$CONFIG_DIR" update \
        sensor_temp_on="$("$TOGGLE" get temp)" \
        sensor_cpu_on="$("$TOGGLE" get cpu)" \
        sensor_freq_on="$("$TOGGLE" get freq)" \
        sensor_power_on="$("$TOGGLE" get power)" \
        sensor_ram_on="$("$TOGGLE" get ram)" \
        2>/dev/null || true

    # Open popup BEFORE closer (closer must not steal click from buttons)
    "$EWW_BIN" --config "$CONFIG_DIR" open "$WINDOW" --arg monitor="$MONITOR"
    "$EWW_BIN" --config "$CONFIG_DIR" open "$CLOSER" --arg monitor="$MONITOR" || true
fi

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

# Make sure exactly one healthy daemon is running (a deaf or duplicate daemon is
# replaced, otherwise its popup stays stuck on screen; see eww-daemon.sh)
"$CONFIG_DIR/scripts/eww-daemon.sh" ensure

POPUPS="$CONFIG_DIR/scripts/popups.sh"

# Read active-windows ONCE: `eww active-windows | grep -q` under pipefail always fails
# while the window is open (grep quits early -> SIGPIPE), so clicks never closed it.
ACTIVE="$("$EWW_BIN" --config "$CONFIG_DIR" active-windows)"
if grep -q "^${WINDOW}:" <<<"$ACTIVE"; then
    "$POPUPS" close-all
else
    # Only one header popup at a time: close the calendar / control center if open
    if grep -q -- '-popup' <<<"$ACTIVE"; then
        "$POPUPS" close-all
    fi

    # Sync eww vars from state file before opening (instant, no poll lag)
    "$EWW_BIN" --config "$CONFIG_DIR" update \
        sensor_temp_on="$("$TOGGLE" get temp)" \
        sensor_cpu_on="$("$TOGGLE" get cpu)" \
        sensor_freq_on="$("$TOGGLE" get freq)" \
        sensor_power_on="$("$TOGGLE" get power)" \
        sensor_gpu_on="$("$TOGGLE" get gpu)" \
        sensor_gpupower_on="$("$TOGGLE" get gpupower)" \
        sensor_ram_on="$("$TOGGLE" get ram)" \
        2>/dev/null || true

    # Open popup BEFORE closers (closer must not steal click from buttons);
    # closers go on every monitor so a click on any other screen closes it too
    "$EWW_BIN" --config "$CONFIG_DIR" open "$WINDOW" --arg monitor="$MONITOR"
    "$POPUPS" open-closers "$CLOSER" || true
fi

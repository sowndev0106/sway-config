#!/bin/bash
# Ctrl+Shift+C acts as plain Copy everywhere (Chrome's DevTools inspect-element
# toggle, antigravity/VSCode's open-new-tab bind, etc. all get overridden).
# Exception: foot reserves Ctrl+C for SIGINT, so it already binds
# Ctrl+Shift+C to copy natively — just replay the original combo there.

BIND="Ctrl+Shift+c"
SCRIPT="$HOME/.config/sway/scripts/ctrl-shift-c.sh"

app_id=$(swaymsg -t get_tree | jq -r '.. | objects | select(.focused == true) | .app_id // .window_properties.class // empty' | head -n1)

if [ "$app_id" = "foot" ]; then
    # wtype's synthetic key press would otherwise be caught by this same
    # bindsym again, causing an infinite loop — drop the binding while
    # replaying the original combo, then restore it right after.
    swaymsg "unbindsym $BIND"
    wtype -M ctrl -M shift -k c -m shift -m ctrl
    swaymsg "bindsym $BIND exec $SCRIPT"
else
    wtype -M ctrl -k c -m ctrl
fi

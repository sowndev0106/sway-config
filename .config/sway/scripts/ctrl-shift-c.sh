#!/bin/bash
# Ctrl+Shift+C acts as plain Copy everywhere (overrides Chrome's DevTools
# inspect-element toggle, antigravity/VSCode's open-new-tab bind, etc).
# Exception: foot reserves Ctrl+C for SIGINT, so it already binds
# Ctrl+Shift+C to copy natively — just replay the original combo there.
#
# Known limitation: in Electron apps (antigravity/VSCode), this ends up a
# no-op instead of a real copy. Their clipboard write goes through Chromium's
# Clipboard API, which requires a "trusted" (real hardware) input event —
# wtype's synthetic key via the Wayland virtual-keyboard protocol doesn't
# qualify, so the copy command runs but silently fails to write anything.
# Confirmed this isn't fixable from here without a kernel-level input device
# (ydotool/uinput), which needs passwordless root — not worth the security
# trade-off for a keybinding. Plain (unmodified) Ctrl+C still works fine
# there, since it's real input.

BIND="Ctrl+Shift+c"
SCRIPT="$HOME/.config/sway/scripts/ctrl-shift-c.sh"

app_id=$(swaymsg -t get_tree | jq -r '.. | objects | select(.focused == true) | .app_id // .window_properties.class // empty' | head -n1)

# Match both the normal terminal (app_id=foot) and the floating one
# launched with --app-id=foot-float.
case "$app_id" in
foot|foot-*)
    # wtype's synthetic key press would otherwise be caught by this same
    # bindsym again, causing an infinite loop — drop the binding while
    # replaying the original combo, then restore it right after.
    swaymsg "unbindsym $BIND"
    wtype -M ctrl -M shift -k c -m shift -m ctrl
    swaymsg "bindsym $BIND exec $SCRIPT"
    ;;
*)
    wtype -M ctrl -k c -m ctrl
    ;;
esac

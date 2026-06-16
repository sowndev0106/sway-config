#!/usr/bin/env bash
# Tự động tìm màn hình đang focused và mở rofi trên màn hình đó.
# Cách này giải quyết vấn đề rofi (chạy qua XWayland) bị mở sai màn hình trên Sway.

focused_monitor=$(swaymsg -r -t get_outputs | jq -r '.[] | select(.focused) | .name' 2>/dev/null)

if [ -n "$focused_monitor" ]; then
    exec rofi -m "$focused_monitor" "$@"
else
    exec rofi "$@"
fi

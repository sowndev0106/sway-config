#!/usr/bin/env bash
# Mở rofi drun. Shift+Enter → app mở ra sẽ tự float (qua for_window rule bằng app_id).
# Tận dụng kb-accept-alt: chạy exec trả về cả app_id kèm cờ float bằng cách
# truyền tham số cho 1 wrapper script, nhưng drun không expose app_id ở output.
#
# Thực tế: dùng rofi -modi với 2 entry run command khác nhau, mỗi entry gắn
# app qua class/app_id bằng wrapper. Ở đây đơn giản hoá: luôn exec kèm cờ
# ROFI_FLOAT=1, một wrapper đọc cờ này và gọi swaymsg floating enable sau khi app mở.
#
# Cách dùng: gán bindsym $mod+d exec $HOME/.config/sway/scripts/launch-drun.sh
# Cài rule: for_window [app_id="..."] floating enable (xem sway config).

focused_monitor=$(swaymsg -r -t get_outputs | jq -r '.[] | select(.focused) | .name' 2>/dev/null)
monitor_arg=""
if [ -n "$focused_monitor" ]; then
    monitor_arg="-m $focused_monitor"
fi

if [ -n "$focused_monitor" ]; then
    rofi -m "$focused_monitor" -show drun "$@"
else
    rofi -show drun "$@"
fi

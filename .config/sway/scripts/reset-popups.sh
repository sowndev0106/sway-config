#!/bin/bash
# Phím panic: gỡ kẹt alt-tab / popup eww mà không cần logout.
# Giết grabber GTK (cửa sổ ẩn đang giữ độc quyền bàn phím), đóng switcher,
# xóa file trạng thái mồ côi để lần alt-tab sau khởi động sạch.

# Giết daemon/grabber alt-tab (trả lại bàn phím nếu đang bị giữ độc quyền)
pkill -f "alt_tab.py" 2>/dev/null

# Restart eww from scratch: closes the switcher and any stuck header popup
# (calendar, control center, sensors), even one left by a frozen daemon
"$HOME/.config/eww/scripts/eww-daemon.sh" restart

# Xóa file trạng thái mồ côi
rm -f /tmp/eww-switcher-daemon.pid /tmp/eww-switcher-state.json /tmp/alt-tab-grabbed

notify-send "Đã reset alt-tab / popup" "Bàn phím và switcher đã được giải phóng" 2>/dev/null

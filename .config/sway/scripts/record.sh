#!/bin/sh
# Bật/tắt quay màn hình (wf-recorder). Lần 1: chọn vùng rồi quay. Lần 2: dừng.
if pgrep -x wf-recorder >/dev/null; then
    pkill -INT -x wf-recorder
    notify-send "Quay màn hình" "Đã dừng — lưu vào ~/Videos"
else
    mkdir -p "$HOME/Videos"
    out="$HOME/Videos/rec-$(date +%Y%m%d-%H%M%S).mp4"
    notify-send "Quay màn hình" "Chọn vùng để bắt đầu..."
    wf-recorder -g "$(slurp)" -f "$out" &
fi

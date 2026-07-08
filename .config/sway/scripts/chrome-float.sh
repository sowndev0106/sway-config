#!/bin/bash
# Mở link bằng một profile Chrome RIÊNG (tách cookie/đăng nhập khỏi Chrome
# chính) trong cửa sổ MỚI. Bắt buộc dùng --user-data-dir riêng: Chrome chạy
# single-instance, nếu dùng chung profile với Chrome đang mở thì lệnh này chỉ
# forward qua tiến trình cũ (không tạo app_id mới) -> sway không nổi được.
#
# --class=chrome-float đặt app_id cho cửa sổ này, khớp rule floating trong
# ~/.config/sway/config: for_window [app_id="chrome-float"] floating enable
exec google-chrome-stable \
    --user-data-dir="$HOME/.config/google-chrome-float" \
    --class=chrome-float \
    --new-window \
    "$@"

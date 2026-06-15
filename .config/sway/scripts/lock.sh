#!/bin/sh
# Màn khóa đẹp: nền = ảnh chụp desktop đã LÀM MỜ (mỗi màn hình riêng), không dùng ảnh tĩnh.
# An toàn: nếu chụp/làm mờ thất bại -> khóa bằng nền tối từ config (không bao giờ màn trắng).

# Đã khóa rồi thì thôi (tránh khóa chồng)
pgrep -x swaylock >/dev/null 2>&1 && exit 0

dir=$(mktemp -d)
args=""
for out in $(swaymsg -t get_outputs -r 2>/dev/null | grep -oP '"name":\s*"\K[^"]+'); do
    f="$dir/$out.png"
    if grim -o "$out" "$f" 2>/dev/null; then
        # blur nhanh: thu nhỏ -> làm mờ -> phóng lại
        convert "$f" -scale 10% -blur 0x2.5 -scale 1000% "$f" 2>/dev/null
        args="$args -i $out:$f"
    fi
done

# chạy foreground (không -f) để giữ ảnh tạm tới khi mở khóa
if [ -n "$args" ]; then
    swaylock $args -s fill
else
    swaylock           # fallback: nền tối từ ~/.config/swaylock/config
fi

rm -rf "$dir"

#!/bin/sh
# Màn khóa đẹp: nền = desktop làm mờ (không ảnh tĩnh).
# Ưu tiên gtklock (có ô nhập mật khẩu thật + theme CSS); nếu chưa cài thì
# dùng swaylock (vòng tròn). An toàn: hỏng chụp/làm mờ vẫn khóa được, không màn trắng.

# Đã khóa rồi thì thôi
pgrep -x gtklock  >/dev/null 2>&1 && exit 0
pgrep -x swaylock >/dev/null 2>&1 && exit 0

dir=$(mktemp -d)

# Lấy danh sách tất cả các màn hình (outputs) đang hoạt động
outputs=$(swaymsg -t get_outputs 2>/dev/null | python3 -c "import sys,json;[print(x['name']) for x in json.load(sys.stdin)]" 2>/dev/null)

# Chụp màn hình và làm mờ song song cho từng monitor để tăng tốc
for out in $outputs; do
    (
        f="$dir/$out.png"
        if grim -o "$out" "$f" 2>/dev/null; then
            convert "$f" -scale 10% -blur 0x2.5 -scale 1000% "$f" 2>/dev/null
        fi
    ) &
done
wait

style="$HOME/.config/gtklock/style.css"

if command -v gtklock >/dev/null 2>&1; then
    style_temp="$dir/style.css"
    if [ -f "$style" ]; then
        cp "$style" "$style_temp"
    else
        touch "$style_temp"
    fi

    # Thêm cấu hình CSS nền blur cho từng màn hình
    for out in $outputs; do
        f="$dir/$out.png"
        if [ -f "$f" ]; then
            echo "window#$out { background-image: url('$f'); background-size: cover; background-repeat: no-repeat; background-position: center; }" >> "$style_temp"
        fi
    done

    gtklock -s "$style_temp"
else
    # Fallback: swaylock, nền blur từng màn hình
    args=""
    for out in $outputs; do
        f="$dir/$out.png"
        if [ -f "$f" ]; then
            args="$args -i $out:$f"
        fi
    done
    [ -n "$args" ] && swaylock $args -s fill || swaylock
fi

rm -rf "$dir"

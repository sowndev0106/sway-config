#!/bin/sh
# Màn khóa đẹp: nền = desktop làm mờ (không ảnh tĩnh).
# Ưu tiên gtklock (có ô nhập mật khẩu thật + theme CSS); nếu chưa cài thì
# dùng swaylock (vòng tròn). An toàn: hỏng chụp/làm mờ vẫn khóa được, không màn trắng.

# Đã khóa rồi thì thôi
pgrep -x gtklock  >/dev/null 2>&1 && exit 0
pgrep -x swaylock >/dev/null 2>&1 && exit 0

dir=$(mktemp -d)

# Chụp màn hình đang focus -> làm mờ -> dùng làm nền
focused=$(swaymsg -t get_outputs 2>/dev/null | python3 -c "import sys,json;o=[x for x in json.load(sys.stdin) if x.get('focused')];print(o[0]['name'] if o else '')" 2>/dev/null)
[ -z "$focused" ] && focused=$(swaymsg -t get_outputs 2>/dev/null | python3 -c "import sys,json;a=json.load(sys.stdin);print(a[0]['name'] if a else '')" 2>/dev/null)

bg=""
shot="$dir/bg.png"
if [ -n "$focused" ] && grim -o "$focused" "$shot" 2>/dev/null; then
    convert "$shot" -scale 10% -blur 0x2.5 -scale 1000% "$shot" 2>/dev/null && bg="$shot"
fi

style="$HOME/.config/gtklock/style.css"

if command -v gtklock >/dev/null 2>&1; then
    set --
    [ -f "$style" ] && set -- -s "$style"
    [ -n "$bg" ] && set -- "$@" -b "$bg"
    gtklock "$@"
else
    # Fallback: swaylock, nền blur từng màn hình
    args=""
    for out in $(swaymsg -t get_outputs 2>/dev/null | python3 -c "import sys,json;[print(x['name']) for x in json.load(sys.stdin)]" 2>/dev/null); do
        f="$dir/$out.png"
        if grim -o "$out" "$f" 2>/dev/null; then
            convert "$f" -scale 10% -blur 0x2.5 -scale 1000% "$f" 2>/dev/null
            args="$args -i $out:$f"
        fi
    done
    [ -n "$args" ] && swaylock $args -s fill || swaylock
fi

rm -rf "$dir"

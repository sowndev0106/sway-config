#!/usr/bin/env bash
# Đổi theme màu cho toàn bộ desktop (sway, waybar, eww, rofi, wofi, mako, foot,
# wlogout, gtklock, swaylock, nwg-dock) bằng MỘT lệnh.
#
# Cách hoạt động:
#   palettes/<tên>.conf   bảng màu: mỗi dòng `vai_trò=hex` (base, surface0, text, accent...)
#   templates/*           khuôn file màu cho từng chương trình, chỗ cần màu ghi {{vai_trò}}
#   build/<tên>/          file màu sinh ra = template + bảng màu (lệnh `build`)
#   current -> build/<tên>  symlink tới theme đang dùng; mọi config import từ current/
#
# Lệnh:
#   theme.sh list          liệt kê theme (dấu * = đang dùng)
#   theme.sh current       in tên theme đang dùng
#   theme.sh set <tên>     sinh lại file màu, chuyển sang theme đó, reload mọi thứ
#   theme.sh build [tên…]  chỉ sinh lại file màu (mặc định: mọi theme), không đổi theme
#   theme.sh menu          chọn theme bằng rofi (phím Mod+Shift+t)
#
# Thêm theme mới: copy palettes/black.conf thành palettes/<tên>.conf, đổi mã màu,
# rồi `theme.sh set <tên>`.
set -euo pipefail

THEME_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PALETTES="$THEME_DIR/palettes"
TEMPLATES="$THEME_DIR/templates"
BUILD="$THEME_DIR/build"
CURRENT="$THEME_DIR/current"

die() { echo "theme.sh: $*" >&2; exit 1; }

list_names() {
    local f
    for f in "$PALETTES"/*.conf; do
        [ -e "$f" ] && basename "$f" .conf
    done
}

current_name() {
    [ -L "$CURRENT" ] && basename "$(readlink "$CURRENT")"
}

# Sinh build/<tên>/ từ palettes/<tên>.conf + mọi file trong templates/.
build_one() {
    local name="$1" palette="$PALETTES/$1.conf" out="$BUILD/$1"
    local sed_args=() line key value tpl dst
    [ -f "$palette" ] || die "không có theme '$name' (thiếu $palette)"

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"                      # bỏ comment cuối dòng
        line="${line//[[:space:]]/}"
        [ -z "$line" ] && continue
        key="${line%%=*}"
        value="${line#*=}"
        [[ "$key" =~ ^[a-z0-9_]+$ ]] || die "$palette: tên vai trò không hợp lệ: '$key'"
        [[ "$value" =~ ^[0-9a-fA-F]{6}$ ]] || die "$palette: '$key' phải là 6 ký tự hex (không có #), đang là '$value'"
        sed_args+=(-e "s/{{$key}}/$value/g")
    done < "$palette"

    mkdir -p "$out"
    for tpl in "$TEMPLATES"/*; do
        dst="$out/$(basename "$tpl")"
        sed "${sed_args[@]}" "$tpl" > "$dst.tmp"
        # Còn {{...}} nghĩa là bảng màu thiếu vai trò mà template cần.
        if grep -q '{{[a-z0-9_]*}}' "$dst.tmp"; then
            local missing
            missing="$(grep -o '{{[a-z0-9_]*}}' "$dst.tmp" | sort -u | tr '\n' ' ')"
            rm -f "$dst.tmp"
            die "$palette thiếu vai trò $missing(template $(basename "$tpl") cần)"
        fi
        mv "$dst.tmp" "$dst"
    done
}

# Áp theme cho chương trình đang chạy. Cái nào chỉ đọc config lúc mở
# (rofi, wofi, wlogout, swaylock, gtklock, foot) thì tự ăn theme mới ở lần mở sau.
reload_running() {
    if [ -n "${SWAYSOCK:-}" ] && command -v swaymsg >/dev/null 2>&1; then
        # reload sway = màu viền/tiêu đề mới; exec_always trong sway/config
        # cũng khởi động lại waybar và eww nên chúng nạp CSS mới luôn.
        swaymsg reload >/dev/null
    fi
    if pgrep -x mako >/dev/null 2>&1; then
        makoctl reload || true
    fi
}

cmd_set() {
    local name="${1:-}"
    [ -n "$name" ] || die "cần tên theme. Có: $(list_names | tr '\n' ' ')"
    build_one "$name"
    ln -sfn "build/$name" "$CURRENT"
    reload_running
    echo "Đã chuyển sang theme '$name'. Terminal foot mở mới mới có màu mới (cửa sổ cũ giữ màu cũ)."
}

cmd_menu() {
    local cur pick
    cur="$(current_name || true)"
    # Mở rofi trên màn hình đang focus (rofi chạy qua XWayland hay mở nhầm màn).
    local mon=() out
    out="$(swaymsg -r -t get_outputs 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null || true)"
    [ -n "$out" ] && mon=(-m "$out")
    # Chọn sẵn dòng của theme đang dùng.
    local row
    row="$(list_names | grep -n -x -F "${cur:-}" | cut -d: -f1 || true)"
    pick="$(list_names | rofi "${mon[@]}" -dmenu -i -p "Theme" -selected-row "$(( ${row:-1} - 1 ))" \
        -theme-str 'window {width: 400px;} listview {lines: 6;}')" || exit 0
    [ -n "$pick" ] && cmd_set "$pick"
}

case "${1:-}" in
    list)
        cur="$(current_name || true)"
        while IFS= read -r n; do
            if [ "$n" = "$cur" ]; then echo "* $n"; else echo "  $n"; fi
        done < <(list_names)
        ;;
    current) current_name || die "chưa chọn theme (thiếu symlink $CURRENT)" ;;
    set)     cmd_set "${2:-}" ;;
    build)
        shift
        if [ $# -eq 0 ]; then set -- $(list_names); fi
        for n in "$@"; do build_one "$n"; echo "đã sinh build/$n"; done
        ;;
    menu)    cmd_menu ;;
    *)       sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed -e '$d' -e 's/^# \{0,1\}//'; exit 1 ;;
esac

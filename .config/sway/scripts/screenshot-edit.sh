#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

if ! command -v grim >/dev/null 2>&1; then
    notify-send "Screenshot" "Thiếu grim"
    exit 1
fi

if ! command -v slurp >/dev/null 2>&1; then
    notify-send "Screenshot" "Thiếu slurp"
    exit 1
fi

if ! command -v swappy >/dev/null 2>&1; then
    notify-send "Screenshot" "Thiếu swappy"
    exit 1
fi

swappy_bin="$(command -v swappy)"
freeze="$(dirname "$(readlink -f "$0")")/screenshot-freeze.sh"

tmp="$(mktemp --suffix=.png)"
trap 'rm -f "$tmp"' EXIT

# Chọn vùng + chụp khi màn hình ĐANG ĐÓNG BĂNG, nên ảnh là khung hình đúng lúc bấm phím
# (xem screenshot-freeze.sh). KHÔNG hiện thông báo ở bước này: thông báo hiện lên màn hình
# sẽ lọt vào chính bức ảnh. Mã 130 = bấm Esc huỷ chọn vùng.
rc=0
"$freeze" sh -c 'geometry=$(slurp) || exit 130; grim -g "$geometry" "$1"' _ "$tmp" || rc=$?
[ "$rc" -eq 130 ] && exit 0
if [ "$rc" -ne 0 ]; then
    notify-send "Screenshot" "Chụp màn hình lỗi"
    exit 1
fi
# Không có ảnh mà cũng không lỗi = bấm phím lần 2 khi lần 1 còn chạy (wrapper bỏ qua).
[ -s "$tmp" ] || exit 0

# Rã đông xong mới mở swappy: mở lúc còn đóng băng thì cửa sổ nằm dưới lớp đóng băng.
"$swappy_bin" -f "$tmp"

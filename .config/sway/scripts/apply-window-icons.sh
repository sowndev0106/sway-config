#!/usr/bin/env bash
# Áp các rule `title_format` trong window-icons.conf lên các cửa sổ ĐANG MỞ.
#
# Sway chỉ chạy `for_window` cho cửa sổ MỚI mở, không áp lại cho cửa sổ có sẵn lúc reload.
# Thiếu bước này thì sau mỗi lần sửa icon rồi reload (Mod+Shift+c), các cửa sổ đang mở vẫn
# giữ tiêu đề cũ cho tới khi đóng/mở lại app. Script đổi từng dòng
# `for_window [tiêu chí] title_format ...` thành lệnh chạy lúc runtime `[tiêu chí] title_format ...`
# rồi gửi MỘT lần cho sway, giữ nguyên thứ tự (rule riêng từng app đứng sau rule mặc định nên
# vẫn thắng). Chạy từ exec_always trong sway/config; chỉ động tới rule title_format.

set -euo pipefail

conf="${1:-$HOME/.config/sway/window-icons.conf}"
[ -r "$conf" ] || exit 0

cmds=""
while IFS= read -r line; do
    case "$line" in
        "for_window "*"title_format "*) cmds+="${line#for_window }; " ;;
    esac
done < "$conf"

[ -n "$cmds" ] || exit 0
swaymsg "${cmds%; }" >/dev/null

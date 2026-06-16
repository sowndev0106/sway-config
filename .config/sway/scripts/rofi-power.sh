#!/usr/bin/env bash
# Script modi cho rofi: power menu. Dùng lại đúng action của wlogout.
#
# Giao thức rofi script-mode (man rofi-script):
#   - Gọi lần đầu KHÔNG có $1  -> in danh sách mục (mỗi dòng có thể kèm icon).
#   - Người dùng chọn 1 mục    -> rofi gọi lại script với $1 = nguyên văn nhãn.
# Định dạng dòng: "<nhãn>\0icon\x1f<tên-icon-papirus>".
# Dòng "\0prompt\x1f..." đặt prompt, KHÔNG hiện thành mục.
#
# Hành động nguy hiểm (Đăng xuất/Khởi động lại/Tắt máy) phải qua một bước xác
# nhận: chọn mục gốc -> hiện "Có/Huỷ" -> chỉ "Có" mới thực thi.
set -u

# Glyph Nerd Font qua codepoint (ANSI-C quoting) để KHÔNG lưu ký tự PUA trong
# file — tránh việc trình soạn làm rớt glyph.
g_lock=$'\uf023'      # nf lock
g_logout=$'\uf08b'    # nf sign-out
g_suspend=$'\uf186'   # nf moon
g_reboot=$'\uf021'    # nf rotate
g_power=$'\uf011'     # nf power
g_check=$'\uf00c'     # nf check
g_cancel=$'\uf00d'    # nf times

emit()      { printf '%s\0icon\x1f%s\n' "$1" "$2"; }
show_menu() {
    emit "$g_lock Khoá màn"        "system-lock-screen"
    emit "$g_logout Đăng xuất"     "system-log-out"
    emit "$g_suspend Ngủ"          "system-suspend"
    emit "$g_reboot Khởi động lại" "system-reboot"
    emit "$g_power Tắt máy"        "system-shutdown"
}

printf '\0prompt\x1fPower\n'

case "${1:-}" in
    "")
        show_menu
        ;;

    # --- Bước xác nhận "Có" (đặt TRƯỚC để khớp specific trước) ---
    *"Có, đăng xuất"*)
        setsid -f swaymsg exit            >/dev/null 2>&1 ;;
    *"Có, khởi động lại"*)
        setsid -f systemctl reboot        >/dev/null 2>&1 ;;
    *"Có, tắt máy"*)
        setsid -f systemctl poweroff      >/dev/null 2>&1 ;;
    *"Huỷ"*)
        show_menu ;;

    # --- Hành động an toàn: chạy ngay ---
    *"Khoá màn"*)
        setsid -f "$HOME/.config/sway/scripts/lock.sh" >/dev/null 2>&1 ;;
    *"Ngủ"*)
        setsid -f systemctl suspend       >/dev/null 2>&1 ;;

    # --- Hành động nguy hiểm: hỏi xác nhận ---
    *"Đăng xuất"*)
        emit "$g_check Có, đăng xuất"      "system-log-out"
        emit "$g_cancel Huỷ"               "window-close" ;;
    *"Khởi động lại"*)
        emit "$g_check Có, khởi động lại"  "system-reboot"
        emit "$g_cancel Huỷ"               "window-close" ;;
    *"Tắt máy"*)
        emit "$g_check Có, tắt máy"        "system-shutdown"
        emit "$g_cancel Huỷ"               "window-close" ;;
esac

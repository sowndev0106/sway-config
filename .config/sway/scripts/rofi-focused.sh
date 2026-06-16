#!/usr/bin/env bash
# Tự động tìm màn hình đang focused và mở rofi trên màn hình đó.
# Cách này giải quyết vấn đề rofi (chạy qua XWayland) bị mở sai màn hình trên Sway.

focused_monitor=$(swaymsg -r -t get_outputs | jq -r '.[] | select(.focused) | .name' 2>/dev/null)

confirm_action() {
    local action_name="$1"
    local command_to_run="$2"
    local choice
    local monitor_arg=""
    if [ -n "$focused_monitor" ]; then
        monitor_arg="-m $focused_monitor"
    fi
    choice=$(echo -e "  Huỷ\n  Có, $action_name" | rofi $monitor_arg -dmenu -i -p "Xác nhận" -theme-str 'window {width: 400px;} listview {lines: 2;}')
    if [[ "$choice" == *"Có"* ]]; then
        eval "$command_to_run"
    fi
}

if [ -n "$focused_monitor" ]; then
    rofi -m "$focused_monitor" "$@"
else
    rofi "$@"
fi

exit_code=$?

case $exit_code in
    10) # Khoá màn (chạy luôn không cần xác nhận)
        setsid -f "$HOME/.config/sway/scripts/lock.sh" >/dev/null 2>&1
        ;;
    11) # Đăng xuất
        confirm_action "đăng xuất" "swaymsg exit"
        ;;
    12) # Khởi động lại
        confirm_action "khởi động lại" "systemctl reboot"
        ;;
    13) # Tắt máy
        confirm_action "tắt máy" "systemctl poweroff"
        ;;
esac

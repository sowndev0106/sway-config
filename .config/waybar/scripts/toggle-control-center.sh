#!/usr/bin/env bash
set -euo pipefail

# 1. Kiểm tra các phụ thuộc hệ thống
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: Yêu cầu cài đặt 'jq'." >&2
    exit 1
fi

if ! command -v swaymsg >/dev/null 2>&1; then
    echo "Error: Kịch bản yêu cầu môi trường Sway (không tìm thấy 'swaymsg')." >&2
    exit 1
fi

# 2. Xác định đường dẫn thực thi eww
EWW_BIN="${EWW_BIN:-$HOME/.local/bin/eww}"
if [ ! -x "$EWW_BIN" ]; then
    if command -v eww >/dev/null 2>&1; then
        EWW_BIN="$(command -v eww)"
    else
        echo "Error: Không tìm thấy eww binary. Vui lòng cài đặt eww." >&2
        exit 1
    fi
fi

CONFIG_DIR="$HOME/.config/eww"
WINDOW="control-center-popup"
CLOSER_WINDOW="control-center-popup-closer"
PAGE="${1:-home}"

case "$PAGE" in
    home|wifi|bluetooth|audio|mic|wired) ;;
    *)
        echo "Error: Unknown control center page '$PAGE'." >&2
        exit 1
        ;;
esac

# 3. Lấy tên màn hình đang được focus (fallback về 0 nếu trống)
MONITOR="$(swaymsg -t get_outputs | jq -r '.[] | select(.focused).name' | head -n1)"
MONITOR="${MONITOR:-0}"

# 4. Make sure exactly one healthy daemon is running (a deaf or duplicate daemon is
#    replaced, otherwise its popup stays stuck on screen; see eww-daemon.sh)
"$CONFIG_DIR/scripts/eww-daemon.sh" ensure

POPUPS="$CONFIG_DIR/scripts/popups.sh"

# 5. Toggle the control center. Read active-windows ONCE into a variable: piping it
#    straight into `grep -q` under `set -o pipefail` always fails while the window is
#    open (grep quits early, eww gets SIGPIPE), so a second click re-opened it.
ACTIVE="$("$EWW_BIN" --config "$CONFIG_DIR" active-windows)"
if grep -q "^$WINDOW:" <<<"$ACTIVE"; then
    if [ "$PAGE" = "home" ]; then
        "$POPUPS" close-all
    else
        "$HOME/.config/eww/scripts/control_center.sh" open-page "$PAGE" >/dev/null 2>&1 || true
    fi
else
    # Only one header popup at a time: close the calendar / sensors menu if open
    if grep -q -- '-popup' <<<"$ACTIVE"; then
        "$POPUPS" close-all
    fi

    # Reset trạng thái nhập mật khẩu trước khi mở; nếu có trang đích thì mở
    # thẳng trang đó để click icon Waybar đi đúng ngữ cảnh.
    "$EWW_BIN" --config "$CONFIG_DIR" update \
        cc_pass="" cc_pass_ssid="" cc_wifi_error="" 2>/dev/null || true
    if [ "$PAGE" = "home" ]; then
        "$EWW_BIN" --config "$CONFIG_DIR" update cc_view=home 2>/dev/null || true
    else
        "$HOME/.config/eww/scripts/control_center.sh" open-page "$PAGE" >/dev/null 2>&1 || true
    fi
    # Mở popup chính TRƯỚC, rồi mới mở closer.
    # Thứ tự này quan trọng: nếu mở closer trước, lớp closer toàn màn hình sẽ
    # chiếm sự kiện chuột và mọi cú click (kể cả lên nút) đều đóng popup —
    # khiến các nút bật/tắt vô hiệu. Mở popup trước thì nút bấm hoạt động,
    # closer mở sau vẫn bắt được click ở vùng ngoài popup để đóng.
    # Closers go on EVERY monitor, so clicking on any other screen also closes it.
    "$EWW_BIN" --config "$CONFIG_DIR" open "$WINDOW" --arg monitor="$MONITOR"
    "$POPUPS" open-closers "$CLOSER_WINDOW" || true
fi

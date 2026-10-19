#!/usr/bin/env bash
# Kịch bản bật/tắt cửa sổ lịch Eww.
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
WINDOW="calendar-popup"

# 3. Lấy tên màn hình đang được focus (fallback về 0 nếu trống)
MONITOR="$(swaymsg -t get_outputs | jq -r '.[] | select(.focused).name' | head -n1)"
MONITOR="${MONITOR:-0}"

# 4. Make sure exactly one healthy daemon is running (a deaf or duplicate daemon is
#    replaced, otherwise its popup stays stuck on screen; see eww-daemon.sh)
"$CONFIG_DIR/scripts/eww-daemon.sh" ensure

CLOSER_WINDOW="calendar-popup-closer"
POPUPS="$CONFIG_DIR/scripts/popups.sh"

# 5. Toggle the calendar. Read active-windows ONCE into a variable: piping it straight
#    into `grep -q` under `set -o pipefail` always fails while the window is open (grep
#    quits early, eww gets SIGPIPE), so a second click re-opened instead of closing.
ACTIVE="$("$EWW_BIN" --config "$CONFIG_DIR" active-windows)"
if grep -q "^$WINDOW:" <<<"$ACTIVE"; then
    "$POPUPS" close-all
else
    # Only one header popup at a time: close the control center / sensors menu if open
    if grep -q -- '-popup' <<<"$ACTIVE"; then
        "$POPUPS" close-all
    fi

    # Reset the shown month/year to today and load its data (one eww call)
    read -r current_year current_month < <(date "+%Y %m")
    DATA_SCRIPT="$CONFIG_DIR/scripts/calendar-data.sh"
    updates=(calendar_month="$((10#$current_month))" calendar_year="$((10#$current_year))")
    if [ -x "$DATA_SCRIPT" ]; then
        updates+=(calendar_json="$("$DATA_SCRIPT" "$current_month" "$current_year")")
    else
        echo "Warning: Không tìm thấy hoặc không có quyền chạy script dữ liệu lịch tại $DATA_SCRIPT" >&2
    fi
    "$EWW_BIN" --config "$CONFIG_DIR" update "${updates[@]}"

    # Open the popup FIRST, then the closers. If a closer opens first it grabs every
    # click (including clicks on the < > month/year buttons) and closes the popup.
    "$EWW_BIN" --config "$CONFIG_DIR" open "$WINDOW" --arg monitor="$MONITOR"
    "$POPUPS" open-closers "$CLOSER_WINDOW" || true
fi

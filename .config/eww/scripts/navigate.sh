#!/usr/bin/env bash
# Kịch bản điều hướng lịch Eww (thay đổi tháng/năm).
set -euo pipefail

EWW_BIN="${EWW_BIN:-$HOME/.local/bin/eww}"
if [ ! -x "$EWW_BIN" ]; then
    EWW_BIN="$(command -v eww)"
fi

CONFIG_DIR="$HOME/.config/eww"

# Nhận tham số: target (month/year) và action (prev/next)
TARGET="$1"
ACTION="$2"

# Lấy giá trị hiện tại từ Eww
month=$("$EWW_BIN" --config "$CONFIG_DIR" get calendar_month)
year=$("$EWW_BIN" --config "$CONFIG_DIR" get calendar_year)

# Ép kiểu số nguyên
month=$((10#$month))
year=$((10#$year))

if [ "$TARGET" = "month" ]; then
    if [ "$ACTION" = "prev" ]; then
        month=$((month - 1))
        if [ "$month" -eq 0 ]; then
            month=12
            year=$((year - 1))
        fi
    elif [ "$ACTION" = "next" ]; then
        month=$((month + 1))
        if [ "$month" -eq 13 ]; then
            month=1
            year=$((year + 1))
        fi
    fi
elif [ "$TARGET" = "year" ]; then
    if [ "$ACTION" = "prev" ]; then
        year=$((year - 1))
    elif [ "$ACTION" = "next" ]; then
        year=$((year + 1))
    fi
fi

# Cập nhật ngược lại các biến trong Eww
"$EWW_BIN" --config "$CONFIG_DIR" update calendar_month="$month"
"$EWW_BIN" --config "$CONFIG_DIR" update calendar_year="$year"

# Tải lại dữ liệu JSON mới cho lưới lịch hiển thị
NEW_DATA=$("$CONFIG_DIR/scripts/calendar-data.sh" "$month" "$year")
"$EWW_BIN" --config "$CONFIG_DIR" update calendar_json="$NEW_DATA"

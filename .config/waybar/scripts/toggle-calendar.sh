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

# 4. Khởi động daemon nếu chưa chạy và đợi kết nối sẵn sàng
if ! "$EWW_BIN" --config "$CONFIG_DIR" active-windows >/dev/null 2>&1; then
    "$EWW_BIN" --config "$CONFIG_DIR" daemon >/dev/null 2>&1 || true
    # Chờ tối đa 3 giây cho daemon sẵn sàng kết nối IPC
    for i in {1..30}; do
        if "$EWW_BIN" --config "$CONFIG_DIR" active-windows >/dev/null 2>&1; then
            break
        fi
        sleep 0.1
    done
fi

# 5. Thực hiện Bật/Tắt cửa sổ lịch
if "$EWW_BIN" --config "$CONFIG_DIR" active-windows | grep -q "^$WINDOW"; then
    # Nếu cửa sổ đang mở -> đóng lại
    "$EWW_BIN" --config "$CONFIG_DIR" close "$WINDOW"
else
    # Nếu cửa sổ đang đóng -> khởi tạo lại biến tháng/năm về thực tại, cập nhật dữ liệu và mở
    read -r current_year current_month < <(date "+%Y %m")
    
    # Cập nhật các biến trạng thái trong Eww về hiện tại
    "$EWW_BIN" --config "$CONFIG_DIR" update calendar_month="$((10#$current_month))"
    "$EWW_BIN" --config "$CONFIG_DIR" update calendar_year="$((10#$current_year))"
    
    DATA_SCRIPT="$CONFIG_DIR/scripts/calendar-data.sh"
    if [ -x "$DATA_SCRIPT" ]; then
        "$EWW_BIN" --config "$CONFIG_DIR" update calendar_json="$("$DATA_SCRIPT" "$current_month" "$current_year")"
    else
        echo "Warning: Không tìm thấy hoặc không có quyền chạy script dữ liệu lịch tại $DATA_SCRIPT" >&2
    fi
    "$EWW_BIN" --config "$CONFIG_DIR" open "$WINDOW" --arg monitor="$MONITOR"
fi

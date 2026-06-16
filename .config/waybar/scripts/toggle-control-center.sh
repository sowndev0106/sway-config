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

# 3. Lấy tên màn hình đang được focus (fallback về 0 nếu trống)
MONITOR="$(swaymsg -t get_outputs | jq -r '.[] | select(.focused).name' | head -n1)"
MONITOR="${MONITOR:-0}"

# 4. Khởi động daemon nếu chưa chạy và đợi kết nối sẵn sàng
if ! "$EWW_BIN" --config "$CONFIG_DIR" active-windows >/dev/null 2>&1; then
    "$EWW_BIN" --config "$CONFIG_DIR" daemon >/dev/null 2>&1 || true
    for i in {1..30}; do
        if "$EWW_BIN" --config "$CONFIG_DIR" active-windows >/dev/null 2>&1; then
            break
        fi
        sleep 0.1
    done
fi

# Đóng lịch (calendar-popup) nếu đang mở để tránh chồng chéo
if "$EWW_BIN" --config "$CONFIG_DIR" active-windows | grep -q "^calendar-popup"; then
    "$EWW_BIN" --config "$CONFIG_DIR" close "calendar-popup" || true
    "$EWW_BIN" --config "$CONFIG_DIR" close "calendar-popup-closer" || true
fi

# 5. Thực hiện Bật/Tắt cửa sổ control center
if "$EWW_BIN" --config "$CONFIG_DIR" active-windows | grep -q "^$WINDOW"; then
    "$EWW_BIN" --config "$CONFIG_DIR" close "$WINDOW" || true
    "$EWW_BIN" --config "$CONFIG_DIR" close "$CLOSER_WINDOW" || true
else
    # Mở closer trước (nếu được định nghĩa), sau đó mở popup chính
    "$EWW_BIN" --config "$CONFIG_DIR" open "$CLOSER_WINDOW" --arg monitor="$MONITOR" || true
    "$EWW_BIN" --config "$CONFIG_DIR" open "$WINDOW" --arg monitor="$MONITOR"
fi

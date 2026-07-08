#!/usr/bin/env bash
# Công suất tiêu thụ HIỆN TẠI của GPU (watt), đọc qua nvidia-smi power.draw.
#
# Cùng nguyên tắc tự dò như sensor-gpu.sh: máy chỉ-Intel không có nvidia-smi ->
# in rỗng để waybar tự ẩn ô (module custom non-json: output rỗng = ẩn).

TOGGLE="$HOME/.config/waybar/scripts/sensors-toggle.sh"
if [ -x "$TOGGLE" ] && ! "$TOGGLE" enabled gpupower 2>/dev/null; then
    echo ""
    exit 0
fi

command -v nvidia-smi >/dev/null 2>&1 || { echo ""; exit 0; }

watt=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null \
    | head -n1 | tr -dc '0-9.')
[ -z "$watt" ] && { echo ""; exit 0; }

awk "BEGIN { printf \"%.1f\", $watt }"

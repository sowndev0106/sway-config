#!/usr/bin/env bash
# Phần trăm sử dụng GPU.
#
# Tự dò GPU lúc chạy (config dùng chung 2 máy): máy có Nvidia rời thì đọc qua
# `nvidia-smi`; máy chỉ có iGPU Intel (không có nvidia-smi) thì in text rỗng để
# waybar TỰ ẨN ô này — không hardcode, không làm bar lỗi trên máy không có card.
set -euo pipefail
TOGGLE="$HOME/.config/waybar/scripts/sensors-toggle.sh"

if ! "$TOGGLE" enabled gpu 2>/dev/null; then
    printf '{"text":"","tooltip":"","class":""}\n'
    exit 0
fi

icon=$(printf '\U000F08AE')   # nf-md-expansion_card_variant (biểu tượng card đồ hoạ)

# Không có nvidia-smi -> máy chỉ-Intel -> ẩn ô.
if ! command -v nvidia-smi >/dev/null 2>&1; then
    printf '{"text":"","tooltip":"","class":""}\n'
    exit 0
fi

util=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null \
    | head -n1 | tr -dc '0-9')
[ -z "$util" ] && { printf '{"text":"","tooltip":"","class":""}\n'; exit 0; }

tooltip=$("$HOME/.config/waybar/scripts/sensors-readall.sh" 2>/dev/null || true)
printf '{"text":"%s %d%%","tooltip":"%s","class":""}\n' "$icon" "$util" "$tooltip"

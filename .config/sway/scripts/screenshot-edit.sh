#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

if ! command -v grim >/dev/null 2>&1; then
    notify-send "Screenshot" "Thiếu grim"
    exit 1
fi

if ! command -v slurp >/dev/null 2>&1; then
    notify-send "Screenshot" "Thiếu slurp"
    exit 1
fi

if ! command -v swappy >/dev/null 2>&1; then
    notify-send "Screenshot" "Thiếu swappy"
    exit 1
fi

swappy_bin="$(command -v swappy)"

notify-send "Screenshot" "Kéo chọn vùng để sửa bằng swappy..."
geometry="$(slurp)" || exit 0

grim -g "$geometry" - | "$swappy_bin" -f -

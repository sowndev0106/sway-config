#!/usr/bin/env bash
# Khởi động dock app dưới màn hình. Script tự tìm binary cài bằng cargo để
# vẫn chạy ổn trong session đăng nhập không nạp ~/.profile.
set -euo pipefail

dock_bin="${NWG_DOCK_BIN:-}"
if [ -z "$dock_bin" ]; then
    if command -v nwg-dock >/dev/null 2>&1; then
        dock_bin="$(command -v nwg-dock)"
    else
        dock_bin="$HOME/.cargo/bin/nwg-dock"
    fi
fi

if [ ! -x "$dock_bin" ]; then
    notify-send "nwg-dock chưa được cài" "Chạy ./install.sh trong repo sway-config để cài dock." 2>/dev/null \
        || echo "nwg-dock chưa được cài. Chạy ./install.sh trong repo sway-config để cài dock." >&2
    exit 0
fi

pkill -x nwg-dock 2>/dev/null || true
exec "$dock_bin" --wm sway -d -c "$HOME/.config/sway/scripts/rofi-focused.sh -show drun"

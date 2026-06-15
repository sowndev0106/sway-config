#!/bin/sh
# Chỉnh độ sáng + hiện OSD qua wob. Tham số: 5%+ | 5%-
brightnessctl set "$1" >/dev/null
pct=$(brightnessctl -m | cut -d, -f4 | tr -d '%')
[ -p "$XDG_RUNTIME_DIR/wob.sock" ] && echo "$pct" > "$XDG_RUNTIME_DIR/wob.sock"

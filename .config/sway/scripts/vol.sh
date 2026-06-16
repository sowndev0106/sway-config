#!/bin/sh
# Chỉnh âm lượng + hiện OSD qua wob. Tham số: 5%+ | 5%- | toggle
case "$1" in
    toggle) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    *)      wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ "$1" ;;
esac

vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
pct=$(echo "$vol" | awk '{printf "%.0f", $2*100}')
echo "$vol" | grep -q MUTED && pct=0
[ -p "$XDG_RUNTIME_DIR/wob.sock" ] && echo "$pct" > "$XDG_RUNTIME_DIR/wob.sock"

# Cập nhật ngay lập tức giao diện Eww nếu đang chạy
EWW="$HOME/.local/bin/eww"
[ -x "$EWW" ] || EWW="$(command -v eww)"
if [ -x "$EWW" ] && "$EWW" --config "$HOME/.config/eww" active-windows >/dev/null 2>&1; then
    muted="off"
    echo "$vol" | grep -q MUTED && muted="on"
    "$EWW" --config "$HOME/.config/eww" update vol_muted="$muted" vol_level="$pct" >/dev/null 2>&1 || true
fi


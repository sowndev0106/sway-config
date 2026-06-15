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

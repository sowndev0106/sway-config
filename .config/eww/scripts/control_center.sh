#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    wifi-ssid)
        if nmcli radio wifi | grep -q "disabled"; then
            echo "Wifi Off"
        else
            ssid=$(nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes' | cut -d: -f2 || true)
            echo "${ssid:-Disconnected}"
        fi
        ;;
    wifi-state)
        if nmcli radio wifi | grep -q "disabled"; then
            echo "off"
        else
            echo "on"
        fi
        ;;
    wifi-toggle)
        if nmcli radio wifi | grep -q "disabled"; then
            nmcli radio wifi on
        else
            nmcli radio wifi off
        fi
        ;;
    bt-state)
        if bluetoothctl show | grep -q 'Powered: yes'; then
            echo "on"
        else
            echo "off"
        fi
        ;;
    bt-toggle)
        if bluetoothctl show | grep -q 'Powered: yes'; then
            bluetoothctl power off
        else
            bluetoothctl power on
        fi
        ;;
    airplane-state)
        # Nếu có bất kỳ thiết bị nào bị khóa bởi rfkill (wifi/bt), coi như chế độ máy bay đang bật
        if rfkill list | grep -q 'Blocked: yes'; then
            echo "on"
        else
            echo "off"
        fi
        ;;
    airplane-toggle)
        if rfkill list | grep -q 'Blocked: yes'; then
            rfkill unblock all
        else
            rfkill block all
        fi
        ;;
    nightlight-state)
        if pgrep -x gammastep >/dev/null; then
            echo "on"
        else
            echo "off"
        fi
        ;;
    nightlight-toggle)
        if pgrep -x gammastep >/dev/null; then
            pkill -x gammastep
        else
            gammastep -O 4000 &
        fi
        ;;
    vol-level)
        wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%.0f\n", $2*100}'
        ;;
    vol-muted)
        if wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q 'MUTED'; then
            echo "on"
        else
            echo "off"
        fi
        ;;
    vol-toggle)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
    mic-muted)
        if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q 'MUTED'; then
            echo "on"
        else
            echo "off"
        fi
        ;;
    mic-toggle)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        ;;
    set-vol)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "${2}"%
        ;;
    bri-level)
        brightnessctl -m | cut -d, -f4 | tr -d '%'
        ;;
    set-bri)
        brightnessctl set "${2}"%
        ;;
    *)
        echo "Unknown command: ${1:-}" >&2
        exit 1
        ;;
esac

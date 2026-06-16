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
        # Chế độ máy bay = TẤT CẢ radio (wifi/bt) đều bị soft-block.
        # Còn ít nhất 1 cái "unblocked" => chưa phải máy bay.
        if rfkill -o SOFT -n | grep -qw unblocked; then
            echo "off"
        else
            echo "on"
        fi
        ;;
    airplane-toggle)
        if rfkill -o SOFT -n | grep -qw unblocked; then
            rfkill block all
        else
            rfkill unblock all
        fi
        ;;
    wired-state)
        # Tìm thiết bị ethernet vật lý (bỏ qua veth ảo của docker và thiết bị unmanaged)
        dev=$(nmcli -t -f DEVICE,TYPE,STATE device | awk -F: '$2=="ethernet" && $3!="unmanaged" && $1 !~ /^veth/ {print $1; exit}')
        if [ -n "$dev" ] && nmcli -t -f DEVICE,STATE device | grep -q "^${dev}:connected"; then
            echo "on"
        else
            echo "off"
        fi
        ;;
    wired-toggle)
        dev=$(nmcli -t -f DEVICE,TYPE,STATE device | awk -F: '$2=="ethernet" && $3!="unmanaged" && $1 !~ /^veth/ {print $1; exit}')
        if [ -z "$dev" ]; then
            exit 0
        fi
        if nmcli -t -f DEVICE,STATE device | grep -q "^${dev}:connected"; then
            nmcli device disconnect "$dev"
        else
            nmcli device connect "$dev"
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

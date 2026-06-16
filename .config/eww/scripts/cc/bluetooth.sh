#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    list)
        # JSON mảng thiết bị bluetooth đã biết/đang quét.
        # Trường: mac, name, connected (bool), paired (bool), battery (số hoặc -1)
        # Nếu không có thiết bị: pipe rỗng → paste → sed → "[]" — đúng, không cần check thêm.
        bluetoothctl devices 2>/dev/null \
            | awk '{mac=$2; $1=$2=""; name=substr($0,2)} mac!="" {print mac, name}' \
            | while IFS=' ' read -r mac name; do
                info=$(bluetoothctl info "$mac" 2>/dev/null || true)
                connected=$(echo "$info" | grep -c 'Connected: yes' || true)
                paired=$(echo "$info" | grep -c 'Paired: yes' || true)
                battery_line=$(echo "$info" | grep 'Battery Percentage' || true)
                battery="-1"
                if [ -n "$battery_line" ]; then
                    battery=$(echo "$battery_line" | grep -oP '\d+' | head -1 || echo "-1")
                fi
                name_esc="${name//\"/\\\"}"
                echo "{\"mac\":\"$mac\",\"name\":\"$name_esc\",\"connected\":$([ "$connected" -gt 0 ] && echo true || echo false),\"paired\":$([ "$paired" -gt 0 ] && echo true || echo false),\"battery\":$battery}"
              done \
            | paste -sd ',' - \
            | sed 's/^/[/;s/$/]/'
        ;;
    connect)
        bluetoothctl connect "${2}" >/dev/null 2>&1 || true
        ;;
    disconnect)
        bluetoothctl disconnect "${2}" >/dev/null 2>&1 || true
        ;;
    toggle)
        if bluetoothctl show | grep -q 'Powered: yes'; then
            bluetoothctl power off >/dev/null 2>&1
        else
            bluetoothctl power on >/dev/null 2>&1
        fi
        ;;
    scan-on)
        bluetoothctl scan on >/dev/null 2>&1 &
        ;;
    scan-off)
        bluetoothctl scan off >/dev/null 2>&1 || true
        ;;
    *)
        echo "Unknown: ${1:-}" >&2; exit 1 ;;
esac

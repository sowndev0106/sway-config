#!/usr/bin/env bash
set -euo pipefail

# Tìm thiết bị ethernet vật lý, bỏ qua veth/docker và unmanaged
_get_dev() {
    nmcli -t -f DEVICE,TYPE,STATE device \
        | awk -F: '$2=="ethernet" && $3!="unmanaged" && $1 !~ /^veth/ {print $1; exit}'
}

case "${1:-}" in
    info)
        # JSON object: state, device, ip, gateway, speed
        dev=$(_get_dev)
        if [ -z "$dev" ]; then
            echo '{"state":"unavailable","device":"","ip":"","gateway":"","speed":""}'
            exit 0
        fi
        state=$(nmcli -t -f DEVICE,STATE device | grep "^${dev}:" | cut -d: -f2)
        ip=$(ip -4 addr show "$dev" 2>/dev/null | grep -oP '(?<=inet )[^/]+' | head -1 || true)
        gw=$(ip route show dev "$dev" 2>/dev/null | grep 'default' | awk '{print $3}' | head -1 || true)
        speed=$(cat "/sys/class/net/${dev}/speed" 2>/dev/null || echo "")
        echo "{\"state\":\"${state:-disconnected}\",\"device\":\"${dev}\",\"ip\":\"${ip:-}\",\"gateway\":\"${gw:-}\",\"speed\":\"${speed:-}\"}"
        ;;
    toggle)
        dev=$(_get_dev)
        [ -z "$dev" ] && exit 0
        if nmcli -t -f DEVICE,STATE device | grep -q "^${dev}:connected"; then
            nmcli device disconnect "$dev" >/dev/null 2>&1
        else
            nmcli device connect "$dev" >/dev/null 2>&1
        fi
        ;;
    *)
        echo "Unknown: ${1:-}" >&2; exit 1 ;;
esac

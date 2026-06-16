#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    list)
        # In JSON mảng các mạng wifi đang quét được.
        # Trường: ssid, signal (0-100), secured (bool), active (bool)
        if nmcli radio wifi | grep -q "disabled"; then
            echo "[]"
            exit 0
        fi
        nmcli -t -f SSID,SIGNAL,SECURITY,ACTIVE dev wifi list 2>/dev/null \
            | awk -F: '
                $1 == "" { next }
                seen[$1]++ { next }
                {
                    ssid=$1; signal=$2; sec=$3; active=$4
                    gsub(/"/, "\\\"", ssid)
                    secured = (sec != "" && sec != "--") ? "true" : "false"
                    act = (active == "yes") ? "true" : "false"
                    printf "{\"ssid\":\"%s\",\"signal\":%s,\"secured\":%s,\"active\":%s}\n",
                        ssid, signal, secured, act
                }
            ' \
            | paste -sd ',' - \
            | sed 's/^/[/;s/$/]/'
        ;;
    connect)
        # Nối mạng đã biết (không cần mật khẩu)
        nmcli device wifi connect "${2}" >/dev/null 2>&1 || true
        ;;
    connect-pass)
        # Nối mạng mới với mật khẩu: connect-pass <ssid> <password>
        ssid="${2}"
        pass="${3}"
        # Xoá profile cũ hỏng nếu có (tránh lỗi "already exists")
        nmcli connection delete "${ssid}" >/dev/null 2>&1 || true
        if ! nmcli device wifi connect "${ssid}" password "${pass}" >/dev/null 2>&1; then
            # Xoá kết nối hỏng để người dùng thử lại
            nmcli connection delete "${ssid}" >/dev/null 2>&1 || true
            echo "error:wrong_password"
            exit 0
        fi
        ;;
    disconnect)
        dev=$(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2=="wifi"{print $1;exit}')
        [ -n "$dev" ] && nmcli device disconnect "$dev" >/dev/null 2>&1 || true
        ;;
    toggle)
        if nmcli radio wifi | grep -q "disabled"; then
            nmcli radio wifi on
        else
            nmcli radio wifi off
        fi
        ;;
    rescan)
        nmcli device wifi rescan >/dev/null 2>&1 || true
        ;;
    *)
        echo "Unknown: ${1:-}" >&2; exit 1 ;;
esac

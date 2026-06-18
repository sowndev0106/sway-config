#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${EWW_CONFIG:-$HOME/.config/eww}"

eww_bin() {
    local eww="${EWW_BIN:-$HOME/.local/bin/eww}"
    [ -x "$eww" ] || eww="$(command -v eww)"
    printf '%s\n' "$eww"
}

wifi_device() {
    nmcli -t -f DEVICE,TYPE dev | awk -F: '$2=="wifi"{print $1;exit}'
}

load_page_data() {
    local page="${1:-}" eww
    eww="$(eww_bin)"

    case "$page" in
        wifi)
            "$eww" --config "$CONFIG_DIR" update \
                wifi_list="$("$SCRIPT_DIR/cc/wifi.sh" list)"
            ;;
        bluetooth)
            "$eww" --config "$CONFIG_DIR" update \
                bt_list="$("$SCRIPT_DIR/cc/bluetooth.sh" list)"
            "$SCRIPT_DIR/cc/bluetooth.sh" scan-on
            ;;
        audio)
            "$eww" --config "$CONFIG_DIR" update \
                audio_sinks="$("$SCRIPT_DIR/cc/audio.sh" sinks)" \
                audio_apps="$("$SCRIPT_DIR/cc/audio.sh" apps)"
            ;;
        mic)
            "$eww" --config "$CONFIG_DIR" update \
                mic_sources="$("$SCRIPT_DIR/cc/mic.sh" sources)" \
                mic_level="$("$SCRIPT_DIR/cc/mic.sh" level)"
            ;;
        wired)
            "$eww" --config "$CONFIG_DIR" update \
                wired_info="$("$SCRIPT_DIR/cc/wired.sh" info)"
            ;;
    esac
}

case "${1:-}" in
    wifi-ssid)
        if nmcli radio wifi | grep -q "disabled"; then
            echo "Wifi Off"
        else
            dev="$(wifi_device)"
            ssid=""
            if [ -n "$dev" ]; then
                ssid="$(nmcli -t -f GENERAL.CONNECTION device show "$dev" 2>/dev/null \
                    | awk '$0 ~ /^GENERAL.CONNECTION:/ {sub(/^[^:]*:/, ""); print; exit}')"
            fi
            [ "$ssid" = "--" ] && ssid=""
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
        wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%.0f", $2*100}'
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
        vol_val=$(printf "%.0f" "${2}" 2>/dev/null || echo "${2}" | cut -d. -f1)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "${vol_val}"%
        EWW="$(eww_bin)"
        "$EWW" --config "$CONFIG_DIR" update vol_muted="off" vol_level="${vol_val}"
        ;;
    bri-level)
        brightnessctl -m | cut -d, -f4 | tr -d '%\n'
        ;;
    set-bri)
        bri_val=$(printf "%.0f" "${2}" 2>/dev/null || echo "${2}" | cut -d. -f1)
        brightnessctl set "${bri_val}"%
        EWW="$(eww_bin)"
        "$EWW" --config "$CONFIG_DIR" update bri_level="${bri_val}"
        ;;
    open-page)
        page="${2:-home}"
        EWW="$(eww_bin)"
        case "$page" in
            wifi)
                "$EWW" --config "$CONFIG_DIR" update \
                    cc_view=wifi cc_pass="" cc_pass_ssid="" cc_wifi_error=""
                ;;
            bluetooth|audio|mic|wired)
                "$EWW" --config "$CONFIG_DIR" update cc_view="$page"
                ;;
            home)
                "$SCRIPT_DIR/cc/bluetooth.sh" scan-off >/dev/null 2>&1 || true
                "$EWW" --config "$CONFIG_DIR" update \
                    cc_view=home cc_pass="" cc_pass_ssid="" cc_wifi_error=""
                exit 0
                ;;
            *)
                echo "Unknown page: $page" >&2
                exit 1
                ;;
        esac
        (load_page_data "$page") >/dev/null 2>&1 &
        ;;
    refresh)
        # Cập nhật ngay tất cả biến trạng thái vào eww để nút phản hồi tức thì,
        # không phải đợi nhịp defpoll (1-3s) => hết cảm giác bật/tắt bị chậm.
        EWW="$(eww_bin)"
        "$EWW" --config "$CONFIG_DIR" update \
            wifi_state="$("$0" wifi-state)" \
            wifi_ssid="$("$0" wifi-ssid)" \
            bt_state="$("$0" bt-state)" \
            wired_state="$("$0" wired-state)" \
            vol_muted="$("$0" vol-muted)" \
            vol_level="$("$0" vol-level)" \
            mic_muted="$("$0" mic-muted)" \
            cpu_perf_state="$(~/.config/eww/scripts/cc/cpu-governor.sh get)"
        ;;
    *)
        echo "Unknown command: ${1:-}" >&2
        exit 1
        ;;
esac

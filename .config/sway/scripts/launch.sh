#!/bin/sh
# Khởi chạy Sway trên máy GPU lai (Intel/AMD iGPU + Nvidia rời).
#
# Nguyên tắc: GPU nào đang ĐIỀU KHIỂN màn hình thì làm renderer CHÍNH (đứng đầu
# WLR_DRM_DEVICES) -> tránh copy khung hình chéo GPU (thứ gây nhiễu UI trên Nvidia).
# GPU còn lại đứng sau để màn hình nối qua nó vẫn dùng được.
#
# Dùng /dev/dri/cardN (KHÔNG dùng by-path vì tên chứa ':' trùng ký tự ngăn cách).

igpu=""; igpu_card=""; dgpu=""; dgpu_card=""
for d in /sys/class/drm/card[0-9]*; do
    card="$(basename "$d")"
    case "$card" in *-*) continue ;; esac          # bỏ connector (card1-eDP-1...)
    drv=$(basename "$(readlink -f "$d/device/driver" 2>/dev/null)" 2>/dev/null)
    node="/dev/dri/$card"
    case "$drv" in
        i915|xe|amdgpu|radeon) [ -z "$igpu" ] && { igpu="$node"; igpu_card="$card"; } ;;
        nvidia)                dgpu="$node"; dgpu_card="$card" ;;
    esac
done

# Card này có màn hình nào đang cắm (connected) không?
has_output() {
    for s in /sys/class/drm/"$1"-*/status; do
        [ "$(cat "$s" 2>/dev/null)" = "connected" ] && return 0
    done
    return 1
}

# Ưu tiên Nvidia làm chính NẾU màn hình cắm vào Nvidia; ngược lại dùng iGPU.
if [ -n "$dgpu" ] && has_output "$dgpu_card"; then
    primary="$dgpu";  secondary="$igpu"
elif [ -n "$igpu" ] && has_output "$igpu_card"; then
    primary="$igpu";  secondary="$dgpu"
else
    primary="$igpu";  secondary="$dgpu"
fi

devs="$primary"
[ -n "$secondary" ] && devs="${devs:+$devs:}$secondary"
[ -n "$devs" ] && export WLR_DRM_DEVICES="$devs"

# Nvidia không vẽ được con trỏ phần cứng -> ép con trỏ phần mềm
export WLR_NO_HARDWARE_CURSORS=1

exec sway --unsupported-gpu "$@"

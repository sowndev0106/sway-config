#!/bin/sh
# Khởi chạy Sway trên máy GPU lai (Intel/AMD iGPU + Nvidia rời).
# Dò card theo driver lúc chạy -> /dev/dri/cardN (KHÔNG dùng by-path vì tên
# chứa dấu ':' trùng với ký tự ngăn cách của WLR_DRM_DEVICES).
# iGPU làm renderer chính (đứng trước), Nvidia đứng sau để màn hình nối qua
# cổng Nvidia vẫn xuất hình.
igpu=""; dgpu=""
for d in /sys/class/drm/card[0-9]*; do
    case "$(basename "$d")" in *-*) continue ;; esac   # bỏ connector (card1-eDP-1...)
    drv=$(basename "$(readlink -f "$d/device/driver" 2>/dev/null)" 2>/dev/null)
    node="/dev/dri/$(basename "$d")"
    case "$drv" in
        i915|xe|amdgpu|radeon) [ -z "$igpu" ] && igpu="$node" ;;
        nvidia)                dgpu="$node" ;;
    esac
done
devs="$igpu"
[ -n "$dgpu" ] && devs="${devs:+$devs:}$dgpu"
[ -n "$devs" ] && export WLR_DRM_DEVICES="$devs"

exec sway --unsupported-gpu "$@"

#!/bin/sh
# Khởi chạy Sway trên máy GPU lai (Intel/AMD iGPU + Nvidia rời).
#
# Nguyên tắc: iGPU (Intel/AMD) LUÔN làm renderer CHÍNH (đứng đầu WLR_DRM_DEVICES)
# vì driver mesa của nó ổn định trên wlroots. Để Nvidia làm renderer chính trên
# Sway 1.9 (chưa có explicit-sync) là nguyên nhân kinh điển gây GIẬT/XÉ/NHIỄU hình.
# Nvidia đứng SAU: màn hình cắm vào Nvidia vẫn quét hình được (wlroots tự copy
# khung hình đã render từ iGPU sang Nvidia để xuất ra màn hình).
#
# Dùng /dev/dri/cardN (KHÔNG dùng by-path vì tên chứa ':' trùng ký tự ngăn cách).

igpu=""; dgpu=""
for d in /sys/class/drm/card[0-9]*; do
    card="$(basename "$d")"
    case "$card" in *-*) continue ;; esac          # bỏ connector (card1-eDP-1...)
    drv=$(basename "$(readlink -f "$d/device/driver" 2>/dev/null)" 2>/dev/null)
    node="/dev/dri/$card"
    case "$drv" in
        i915|xe|amdgpu|radeon) [ -z "$igpu" ] && igpu="$node" ;;
        nvidia)                dgpu="$node" ;;
    esac
done

# iGPU làm renderer chính nếu có; chỉ rơi về Nvidia khi máy KHÔNG có iGPU.
if [ -n "$igpu" ]; then
    primary="$igpu";  secondary="$dgpu"
else
    primary="$dgpu";  secondary="$igpu"
fi

devs="$primary"
[ -n "$secondary" ] && devs="${devs:+$devs:}$secondary"
[ -n "$devs" ] && export WLR_DRM_DEVICES="$devs"

# Nvidia không vẽ được con trỏ phần cứng dưới wlroots -> ép con trỏ phần mềm.
# Chỉ áp dụng khi CÓ Nvidia; máy chỉ-Intel để con trỏ phần cứng cho mượt.
[ -n "$dgpu" ] && export WLR_NO_HARDWARE_CURSORS=1

# Ưu tiên Sway 1.10+ build tay ở /opt/sway-stack (có explicit-sync -> hết giật
# Nvidia; xem build-sway.sh). Không có thì dùng Sway hệ thống (1.9).
sway_bin="/opt/sway-stack/bin/sway"
if [ -x "$sway_bin" ]; then
    # Đề phòng rpath không ăn: cho linker thấy lib trong /opt trước.
    export LD_LIBRARY_PATH="/opt/sway-stack/lib:${LD_LIBRARY_PATH:-}"
else
    sway_bin="sway"
fi

exec "$sway_bin" --unsupported-gpu "$@"

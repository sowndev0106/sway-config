#!/bin/sh
# Chạy app Electron (Discord, Postman...) trên ĐÚNG GPU mà Sway đang render.
#
# Bệnh: trên máy Nvidia-primary (màn hình cắm vào card rời, Sway render bằng
# Nvidia), Electron lại chọn render node MẶC ĐỊNH là iGPU Intel (renderD128).
# Hệ quả: app vẽ trên Intel, mỗi frame phải copy chéo GPU qua PCIe rồi Nvidia
# mới hiển thị được -> GIẬT khi cuộn/gõ phím (cùng cơ chế từng gây giật kéo
# cửa sổ, xem launch.sh). Chrome đời mới tự chọn đúng GPU qua dmabuf-feedback
# của compositor, nhưng Electron (137/138) thì chưa.
#
# Fix: truyền 2 flag cho Chromium bên trong Electron:
#   --render-node-override=<node Nvidia>  ép render đúng GPU đang xuất hình.
#   --use-angle=vulkan                    ANGLE chạy trên Vulkan. BẮT BUỘC đi
#       kèm: đường EGL/GLES mặc định của Electron không import được buffer GBM
#       trên node Nvidia (eglCreateImage lỗi EGL_BAD_MATCH 0x3009) -> GPU
#       process crash liên tục rồi Chromium TẮT luôn tăng tốc GPU (còn tệ
#       hơn). Vulkan import dmabuf ổn nên hết crash.
#
# Máy chỉ-Intel: không thấy driver nvidia -> chạy app y nguyên, không thêm gì
# (đúng quy tắc repo: tự dò GPU lúc chạy, không hardcode).
#
# Dùng: electron-gpu.sh <binary> [tham số...]
# (flag chèn NGAY SAU binary, trước tham số gốc như %U của desktop entry)

node=""
for d in /sys/class/drm/renderD*; do
    [ -e "$d" ] || continue
    drv=$(basename "$(readlink -f "$d/device/driver" 2>/dev/null)" 2>/dev/null)
    [ "$drv" = "nvidia" ] && node="/dev/dri/$(basename "$d")"
done

cmd="$1"
shift

if [ -n "$node" ]; then
    exec "$cmd" --render-node-override="$node" --use-angle=vulkan "$@"
fi
exec "$cmd" "$@"

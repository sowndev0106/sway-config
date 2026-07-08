#!/bin/sh
# Build Sway 1.12 từ source -> /opt/sway-stack (cho máy có Nvidia rời).
#
# VÌ SAO: driver Nvidia cần "explicit sync" (giao thức linux-drm-syncobj-v1)
# để đồng bộ khung hình trên Wayland. Thiếu nó -> mọi app Chromium/Electron
# (Chrome, Antigravity, Discord...) bị GIẬT/XÉ/NHIỄU. Lưu ý bài học cũ:
# wlroots 0.18 (Sway 1.10) mới chỉ CHỨA code protocol này chứ Sway chưa gọi —
# Sway chỉ thật sự bật explicit sync từ 1.11 (kiểm chứng: sway/server.c gọi
# wlr_linux_drm_syncobj_manager_v1_create). Ta build hẳn 1.12 (stable mới nhất,
# thêm một năm bugfix + chính thức hỗ trợ khởi động qua GDM).
#
# Sway 1.12 / wlroots 0.20 đòi vài thư viện mới hơn Ubuntu 24.04:
#   wayland >=1.24, libinput >=1.26, wayland-protocols >=1.41, pixman >=0.43,
#   libdrm >=2.4.129, xkbcommon >=1.8, libdisplay-info >=0.2
# Ta build đúng các thứ đó theo thứ tự phụ thuộc:
#   wayland -> wayland-protocols -> pixman -> libdrm -> xkbcommon
#   -> libinput -> libdisplay-info -> wlroots 0.20 -> sway 1.12
# rồi cài GỌN vào /opt/sway-stack, nhúng rpath để chỉ Sway/wlroots dùng các lib
# này — phần còn lại của hệ thống vẫn xài lib gốc, KHÔNG vỡ desktop.
#
# Chạy:  sudo ~/.config/sway/scripts/build-sway.sh   (cần mạng, ~15-25 phút)
# Chạy lại được nếu đứt giữa chừng (mục nào build xong sẽ tự bỏ qua).
# Gỡ bỏ: sudo rm -rf /opt/sway-stack   (rồi đăng nhập lại -> tự về Sway 1.9)
#
# Kiểm chứng sau khi đăng nhập lại: chạy
#   WAYLAND_DEBUG=1 grim -g "0,0 1x1" /tmp/x.png 2>&1 | grep syncobj
# phải thấy "wp_linux_drm_syncobj_manager_v1" -> explicit sync đã bật.

set -eu

PREFIX="${PREFIX:-/opt/sway-stack}"
WORK="${TMPDIR:-/tmp}/sway-stack-build"
JOBS="$(nproc 2>/dev/null || echo 2)"

# Tag CỐ ĐỊNH (pin) cho từng thành phần. KHÔNG dùng 'git ls-remote' để tự dò tag
# vì việc liệt kê toàn bộ ref ở gitlab.freedesktop.org rất chậm/treo; clone thẳng
# một tag thì nhanh. Muốn lên bản vá mới hơn -> sửa số ở đây.
# LƯU Ý meson của 24.04 là 1.3.2: xkbcommon >=1.9 và các bản pixman/wlroots mới
# hơn nữa có thể đòi meson >=1.4 -> trước khi nâng tag phải xem meson_version
# trong meson.build của tag đó.
WL_TAG=1.25.0            # wayland (24.04 chỉ có 1.22; cần >=1.24 vì wayland-scanner
                         #  phải hiểu attribute 'frozen' trong wayland-protocols mới)
WP_TAG=1.49              # wayland-protocols (24.04 chỉ có 1.34, cần >=1.41)
PIXMAN_TAG=pixman-0.46.4 # pixman (24.04 chỉ có 0.42, cần >=0.43)
DRM_TAG=libdrm-2.4.134   # libdrm (24.04 chỉ có 2.4.125, cần >=2.4.129)
XKB_TAG=xkbcommon-1.8.1  # xkbcommon (24.04 chỉ có 1.6, cần >=1.8; 1.9+ đòi meson 1.4)
LI_TAG=1.26.2            # libinput (24.04 chỉ có 1.25)
LDI_TAG=0.2.0            # libdisplay-info (24.04 chỉ có 0.1.1, wlroots cần >=0.2)
LO_TAG=v0.5.0            # libliftoff (24.04 chỉ có 0.4.1; wlroots dùng để xếp layer DRM)
WLR_TAG=0.20.1           # wlroots
SWAY_TAG=1.12            # sway (explicit sync có từ 1.11)

if [ "$(id -u)" -ne 0 ]; then
    echo "Cần quyền root (apt install + ghi vào $PREFIX). Chạy: sudo $0" >&2
    exit 1
fi

echo "==> [1/11] Cài gói build từ apt (apt update lỗi repo bên thứ ba bỏ qua)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update || true
apt-get install -y --no-install-recommends \
    git meson ninja-build gcc pkg-config bison \
    libffi-dev libexpat1-dev libxml2-dev \
    libevdev-dev libmtdev-dev libwacom-dev libudev-dev \
    libdrm-dev libxkbcommon-dev libpixman-1-dev libgbm-dev \
    libseat-dev hwdata wayland-protocols \
    libegl-dev libgles-dev libvulkan-dev \
    libsystemd-dev libjson-c-dev libpcre2-dev \
    libcairo2-dev libpango1.0-dev libgdk-pixbuf-2.0-dev scdoc \
    libxcb1-dev libxcb-composite0-dev libxcb-ewmh-dev libxcb-icccm4-dev \
    libxcb-render-util0-dev libxcb-res0-dev libxcb-xfixes0-dev \
    xwayland
    # (bison: xkbcommon cần để sinh parser. libxcb-errors-dev không có trên
    #  noble; wlroots tự bỏ qua xcb-errors.)

# Môi trường build: ưu tiên /opt (tìm lib vừa build), nhúng rpath.
# share/pkgconfig: wayland-protocols cài file .pc vào đó (gói chỉ có dữ liệu).
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig:${PKG_CONFIG_PATH:-}"
export PATH="$PREFIX/bin:$PATH"
RPATH="-Wl,-rpath,$PREFIX/lib"

mkdir -p "$WORK"
cd "$WORK"

# Clone shallow (HTTP/1.1 + thử lại; freedesktop hay lỗi HTTP/2 chập chờn).
git_clone() {  # $1=url  $2=tag  $3=đích
    n=0
    while [ "$n" -lt 3 ]; do
        rm -rf "$3"
        if git -c http.version=HTTP/1.1 clone --depth 1 -b "$2" "$1" "$3"; then
            return 0
        fi
        n=$((n + 1))
        echo "   (clone lỗi, thử lại $n/3 sau 3s...)" >&2
        sleep 3
    done
    echo "Clone thất bại sau 3 lần: $1 ($2)" >&2
    return 1
}

# Clone đúng tag rồi build bằng meson, cài vào $PREFIX.
# Bỏ qua nếu pkg-config đã thấy bản ĐỦ MỚI (cho phép chạy lại khi đứt giữa
# chừng, và tự build đè bản cũ trong /opt khi ta nâng tag — so sánh THEO
# VERSION chứ không phải "file .pc tồn tại", vì bản cũ cũng có file .pc).
clone_and_build() {  # $1=url  $2=dir  $3=tag  $4=tên.pc  $5=version tối thiểu  [meson args...]
    url=$1; dir=$2; tag=$3; pc=$4; minver=$5; shift 5
    # pkg-config nhận tên module KHÔNG có đuôi .pc -> cắt đuôi trước khi hỏi.
    if [ -n "$pc" ] && pkg-config --atleast-version="$minver" "${pc%.pc}" 2>/dev/null; then
        echo "   -> $dir đã có bản >= $minver, bỏ qua."
        return 0
    fi
    echo "   -> $dir tag $tag"
    git_clone "$url" "$tag" "$WORK/$dir"
    cd "$WORK/$dir"
    rm -rf build
    meson setup build --prefix="$PREFIX" --libdir=lib --buildtype=release \
        -Dc_link_args="$RPATH" "$@"
    ninja -C build -j "$JOBS"
    ninja -C build install
    cd "$WORK"
}

echo "==> [2/11] wayland $WL_TAG ..."
clone_and_build https://gitlab.freedesktop.org/wayland/wayland.git wayland "$WL_TAG" \
    wayland-server.pc "$WL_TAG" -Ddocumentation=false -Dtests=false

echo "==> [3/11] wayland-protocols $WP_TAG (chỉ file XML, rất nhanh)..."
clone_and_build https://gitlab.freedesktop.org/wayland/wayland-protocols.git wayland-protocols "$WP_TAG" \
    wayland-protocols.pc "$WP_TAG" -Dtests=false

echo "==> [4/11] pixman $PIXMAN_TAG ..."
clone_and_build https://gitlab.freedesktop.org/pixman/pixman.git pixman "$PIXMAN_TAG" \
    pixman-1.pc "${PIXMAN_TAG#pixman-}" -Dtests=disabled -Ddemos=disabled -Dgtk=disabled

echo "==> [5/11] libdrm $DRM_TAG (chỉ phần lõi, tắt driver phụ)..."
clone_and_build https://gitlab.freedesktop.org/mesa/drm.git drm "$DRM_TAG" \
    libdrm.pc "${DRM_TAG#libdrm-}" -Dauto_features=disabled -Dtests=false

echo "==> [6/11] xkbcommon $XKB_TAG ..."
clone_and_build https://github.com/xkbcommon/libxkbcommon.git libxkbcommon "$XKB_TAG" \
    xkbcommon.pc "${XKB_TAG#xkbcommon-}" -Denable-tools=false -Denable-x11=false -Denable-docs=false \
    -Denable-wayland=false -Denable-xkbregistry=false

echo "==> [7/11] libinput $LI_TAG ..."
clone_and_build https://gitlab.freedesktop.org/libinput/libinput.git libinput "$LI_TAG" \
    libinput.pc "$LI_TAG" -Ddocumentation=false -Dtests=false -Ddebug-gui=false

echo "==> [8/11] libdisplay-info $LDI_TAG (wlroots cần >=0.2 để đọc EDID)..."
clone_and_build https://gitlab.freedesktop.org/emersion/libdisplay-info.git libdisplay-info "$LDI_TAG" \
    libdisplay-info.pc "$LDI_TAG"

echo "==> [9/11] libliftoff $LO_TAG ..."
clone_and_build https://gitlab.freedesktop.org/emersion/libliftoff.git libliftoff "$LO_TAG" \
    libliftoff.pc "${LO_TAG#v}"

echo "==> [10/11] wlroots $WLR_TAG ..."
# LUÔN build lại wlroots (không skip) + CHỈ ĐỊNH RÕ backends/renderer/allocator.
# Bài học xương máu: để 'auto', meson thấy libdisplay-info của 24.04 quá cũ đã
# ÂM THẦM TẮT DRM backend -> build xong vẫn chạy --version ngon lành nhưng đến
# lúc login thì "Cannot create DRM backend: disabled at compile-time". Chỉ định
# rõ thì thiếu gì meson fail NGAY LÚC BUILD, không lừa mình được.
clone_and_build https://gitlab.freedesktop.org/wlroots/wlroots.git wlroots "$WLR_TAG" \
    "" "" -Dexamples=false -Dxwayland=enabled \
    -Dbackends=drm,libinput -Drenderers=gles2 -Dallocators=gbm \
    -Dsession=enabled -Dlibliftoff=enabled

echo "==> [11/11] sway $SWAY_TAG ..."
clone_and_build https://github.com/swaywm/sway.git sway "$SWAY_TAG" \
    "" "" -Dwerror=false

# Dọn lib wlroots cũ (0.18) nếu còn từ lần build trước, tránh lẫn lộn.
rm -f "$PREFIX"/lib/libwlroots-0.18.so* "$PREFIX"/lib/pkgconfig/wlroots-0.18.pc

ldconfig 2>/dev/null || true

echo "==> Hoàn tất. Kiểm tra:"
"$PREFIX/bin/sway" --version || { echo "Sway mới chạy thử lỗi!" >&2; exit 1; }
echo
echo "OK. Đăng xuất rồi đăng nhập lại, chọn session 'Sway (Hybrid GPU)'."
echo "Kiểm tra trong phiên mới: 'swaymsg -t get_version' phải ra $SWAY_TAG, và"
echo "  WAYLAND_DEBUG=1 grim -g \"0,0 1x1\" /tmp/x.png 2>&1 | grep -c syncobj"
echo "phải ra số > 0 (explicit sync đã bật)."

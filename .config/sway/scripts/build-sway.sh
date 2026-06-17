#!/bin/sh
# Build Sway 1.10 từ source -> /opt/sway-stack (cho máy có Nvidia rời).
#
# VÌ SAO: Ubuntu 24.04 chỉ có Sway 1.9 (wlroots 0.17) — bản này CHƯA có
# "explicit sync" (giao thức linux-drm-syncobj-v1), thứ mà driver Nvidia cần để
# đồng bộ khung hình. Thiếu nó -> màn hình cắm qua Nvidia bị GIẬT/XÉ/NHIỄU.
# Explicit sync xuất hiện từ wlroots 0.18 = Sway 1.10, nên ta build lên 1.10.
#
# Sway 1.10 đòi vài thư viện mới hơn 24.04: wayland >=1.23, libinput >=1.26
# (libdrm/pixman/xkbcommon của 24.04 thì ĐỦ -> KHÔNG đụng tới). Ta chỉ build:
#   wayland -> libinput -> wlroots 0.18 -> sway 1.10
# rồi cài GỌN vào /opt/sway-stack, nhúng rpath để chỉ Sway/wlroots dùng các lib
# này — phần còn lại của hệ thống vẫn xài lib gốc, KHÔNG vỡ desktop.
#
# Chạy:  sudo ~/.config/sway/scripts/build-sway.sh   (cần mạng, ~15-25 phút)
# Gỡ bỏ: sudo rm -rf /opt/sway-stack   (rồi đăng nhập lại -> tự về Sway 1.9)

set -eu

PREFIX=/opt/sway-stack
WORK="${TMPDIR:-/tmp}/sway-stack-build"
JOBS="$(nproc 2>/dev/null || echo 2)"

# Tag CỐ ĐỊNH (pin) cho từng thành phần. KHÔNG dùng 'git ls-remote' để tự dò tag
# vì việc liệt kê toàn bộ ref ở gitlab.freedesktop.org rất chậm/treo; clone thẳng
# một tag thì nhanh. Muốn lên bản vá mới hơn -> sửa số ở đây.
WL_TAG=1.23.1     # wayland (24.04 chỉ có 1.22)
LI_TAG=1.26.2     # libinput (24.04 chỉ có 1.25)
WLR_TAG=0.18.1    # wlroots (0.18 = bản đầu có explicit sync)
SWAY_TAG=1.10.1   # sway

if [ "$(id -u)" -ne 0 ]; then
    echo "Cần quyền root (apt install + ghi vào $PREFIX). Chạy: sudo $0" >&2
    exit 1
fi

echo "==> [1/6] Cài gói build từ apt (apt update lỗi repo bên thứ ba bỏ qua)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update || true
apt-get install -y --no-install-recommends \
    git meson ninja-build gcc pkg-config \
    libffi-dev libexpat1-dev libxml2-dev \
    libevdev-dev libmtdev-dev libwacom-dev libudev-dev \
    libdrm-dev libxkbcommon-dev libpixman-1-dev libgbm-dev \
    libseat-dev libdisplay-info-dev hwdata wayland-protocols \
    libegl-dev libgles-dev libvulkan-dev \
    libsystemd-dev libjson-c-dev libpcre2-dev \
    libcairo2-dev libpango1.0-dev libgdk-pixbuf-2.0-dev scdoc \
    libxcb1-dev libxcb-composite0-dev libxcb-ewmh-dev libxcb-icccm4-dev \
    libxcb-render-util0-dev libxcb-res0-dev libxcb-xfixes0-dev \
    xwayland
    # (libxcb-errors-dev không có trên noble; wlroots tự bỏ qua xcb-errors.)

# Môi trường build: ưu tiên /opt (tìm wayland/libinput vừa build), nhúng rpath.
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
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
# Bỏ qua nếu file .pc đã có sẵn (cho phép chạy lại mà không build lại từ đầu).
clone_and_build() {  # $1=url  $2=dir  $3=tag  $4=file.pc kiểm tra  [meson args...]
    url=$1; dir=$2; tag=$3; pc=$4; shift 4
    if [ -f "$PREFIX/lib/pkgconfig/$pc" ]; then
        echo "   -> $dir đã build sẵn ($pc), bỏ qua."
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

echo "==> [2/6] wayland $WL_TAG (libwayland, 24.04 chỉ có 1.22)..."
clone_and_build https://gitlab.freedesktop.org/wayland/wayland.git wayland "$WL_TAG" \
    wayland-server.pc -Ddocumentation=false -Dtests=false

echo "==> [3/6] libinput $LI_TAG (24.04 chỉ có 1.25)..."
clone_and_build https://gitlab.freedesktop.org/libinput/libinput.git libinput "$LI_TAG" \
    libinput.pc -Ddocumentation=false -Dtests=false -Ddebug-gui=false

echo "==> [4/6] wlroots $WLR_TAG (bản đầu có explicit sync)..."
# -Dc_std=c2x: wlroots 0.18 mặc định đòi c_std=c23 khi meson>=1.3, nhưng meson
# 1.3.2 (24.04) chỉ biết 'c2x' (cùng nghĩa C23) -> ghi đè cho khỏi lỗi.
clone_and_build https://gitlab.freedesktop.org/wlroots/wlroots.git wlroots "$WLR_TAG" \
    wlroots-0.18.pc -Dc_std=c2x -Dexamples=false -Dxwayland=enabled

echo "==> [5/6] sway $SWAY_TAG ..."
clone_and_build https://github.com/swaywm/sway.git sway "$SWAY_TAG" \
    _sway_never_skip.pc -Dc_std=c2x -Dwerror=false

ldconfig 2>/dev/null || true

echo "==> [6/6] Hoàn tất. Kiểm tra:"
"$PREFIX/bin/sway" --version || { echo "Sway mới chạy thử lỗi!" >&2; exit 1; }
echo
echo "OK. Đăng xuất rồi đăng nhập lại, chọn session 'Sway (Hybrid GPU)'."
echo "launch.sh sẽ tự ưu tiên $PREFIX/bin/sway. Kiểm tra: 'sway --version' trong"
echo "phiên mới phải ra $SWAY_TAG (không còn 1.9)."

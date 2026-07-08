#!/usr/bin/env bash
# Cài xremap (bộ remap phím theo ứng dụng) + cấp quyền để CHẠY KHÔNG CẦN ROOT.
#
# VÌ SAO: trình duyệt giữ riêng phím Ctrl+Shift+C để mở DevTools, không cho đổi;
# sway lại bind phím toàn cục. xremap đọc input ở tầng evdev, hỏi sway xem app nào
# đang focus, nên đổi được Ctrl+Shift+C -> Ctrl+C CHỈ trong trình duyệt (xem
# ~/.config/xremap/config.yml). Để chặn input cần quyền đọc /dev/input và ghi
# /dev/uinput — script này cấp qua group `input` + udev rule (không phải chạy root
# lúc dùng, an toàn hơn).
#
# xremap không có trong apt -> tải binary bản 'wlroots' từ GitHub release (sway là
# compositor wlroots; bản này nhận diện app qua wlr-foreign-toplevel). KHÔNG có bản
# tên 'sway' riêng.
# Chạy:  sudo ~/.config/sway/scripts/install-xremap.sh
# Gỡ:    sudo rm -f /usr/local/bin/xremap  (và xoá udev rule nếu muốn)
set -eu

DEST=/usr/local/bin/xremap
# Tài khoản gọi sudo (để thêm đúng user vào group input, không phải 'root').
REAL_USER="${SUDO_USER:-$(id -un)}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Cần quyền root (ghi /usr/local/bin + udev + group). Chạy: sudo $0" >&2
    exit 1
fi

echo "==> [1/4] Tải xremap (bản wlroots cho sway) từ GitHub release..."
# Lấy URL asset 'xremap-linux-x86_64-wlroots.zip' của bản mới nhất.
api="https://api.github.com/repos/xremap/xremap/releases/latest"
url="$(curl -fsSL "$api" \
    | grep -oE 'https://[^"]*xremap-linux-x86_64-wlroots\.zip' \
    | head -1)"
if [ -z "$url" ]; then
    echo "   lỗi: không tìm thấy asset wlroots trong release. Kiểm tra mạng/GitHub." >&2
    exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/xremap.zip" "$url"
unzip -oq "$tmp/xremap.zip" -d "$tmp"
install -m 0755 "$tmp/xremap" "$DEST"
echo "   -> đã cài $DEST ($("$DEST" --version 2>/dev/null || echo '?'))"

echo "==> [2/4] Thêm '$REAL_USER' vào group 'input' (đọc /dev/input)..."
if id -nG "$REAL_USER" | grep -qw input; then
    echo "   đã ở trong group 'input', bỏ qua."
else
    gpasswd -a "$REAL_USER" input
    echo "   ✓ đã thêm — CẦN ĐĂNG NHẬP LẠI để nhận group mới."
fi

echo "==> [3/4] Udev rule cho /dev/uinput (cho group input ghi)..."
tee /etc/udev/rules.d/99-uinput-xremap.rules >/dev/null <<'EOF'
# Cho phép xremap (chạy bằng user trong group input) tạo thiết bị ảo qua uinput.
KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
EOF
udevadm control --reload
udevadm trigger --subsystem-match=misc 2>/dev/null || true

echo "==> [4/4] Nạp module uinput (ngay + tự nạp lúc boot)..."
modprobe uinput || true
echo uinput > /etc/modules-load.d/uinput.conf

echo "==> Xong. ĐĂNG XUẤT/ĐĂNG NHẬP lại để nhận group 'input', rồi xremap tự chạy"
echo "    qua exec_always trong sway config. Kiểm tra: pgrep -a xremap"

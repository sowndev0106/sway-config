#!/usr/bin/env bash
# Cài Sway + tạo symlink config. Chạy: ./install.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PACKAGES=(
    sway swaybg swayidle swaylock
    waybar rofi wofi foot mako-notifier
    papirus-icon-theme
    grim slurp wl-clipboard
    brightnessctl playerctl
    wireplumber pavucontrol
    policykit-1-gnome
    fonts-font-awesome fonts-jetbrains-mono
    xwayland
    # Tiện ích desktop bổ sung
    xdg-desktop-portal-wlr   # chia sẻ màn hình / hộp thoại chọn file (Zoom, Meet, OBS)
    nautilus                 # file manager (GNOME Files)
    file-roller              # giải nén zip/rar (chuột phải trong Nautilus)
    firefox                  # trình duyệt
    imv                      # xem ảnh
    cliphist                 # quản lý lịch sử clipboard
    # Mạng / Bluetooth / Âm thanh (GUI + khay hệ thống)
    network-manager-gnome    # nm-applet (WiFi) + nm-connection-editor
    blueman bluez            # quản lý Bluetooth (GUI)
    # Bộ gõ tiếng Việt
    fcitx5 fcitx5-unikey fcitx5-configtool
    # Tiện ích thêm
    wob                      # OSD thanh volume/độ sáng
    zathura                  # đọc PDF
    wf-recorder              # quay màn hình
    libnotify-bin            # notify-send (thông báo từ script)
    xdg-desktop-portal-gtk   # backend hộp thoại chọn file
    yaru-theme-icon          # cursor/icon Yaru
    # Học từ Archcraft
    wlogout                  # menu nguồn (khóa/đăng xuất/tắt...)
    gtklock                  # màn khóa đẹp (ô nhập mật khẩu thật, theme CSS)
    grimshot                 # chụp màn hình tiện hơn (kèm thông báo)
    kanshi wdisplays         # đa màn hình: tự sắp xếp + GUI kéo thả
)

echo "==> Cài package (cần sudo)..."
sudo apt update
sudo apt install -y "${PACKAGES[@]}"

echo "==> Bật dịch vụ Bluetooth..."
sudo systemctl enable --now bluetooth

echo "==> Tạo symlink config..."
mkdir -p "$HOME/.config" "$HOME/Pictures" "$HOME/Videos"
for dir in "$REPO_DIR"/.config/*/; do
    name="$(basename "$dir")"
    target="$HOME/.config/$name"
    # Sao lưu config cũ nếu là thư mục thật (không phải symlink)
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "   backup $target -> $target.bak"
        mv "$target" "$target.bak"
    fi
    ln -sfn "$dir" "$target"
    echo "   linked ~/.config/$name -> $dir"
done

### GPU lai Nvidia: Sway từ chối khởi động với driver độc quyền -> cần --unsupported-gpu.
### Chạy đa GPU: render bằng iGPU (Intel/AMD) làm chính, nhưng vẫn dùng được màn hình
### nối qua card Nvidia rời (liệt kê Nvidia thứ hai trong WLR_DRM_DEVICES).
if lsmod 2>/dev/null | grep -q '^nvidia'; then
    echo "==> Phát hiện Nvidia: tạo session 'Sway (Hybrid GPU)'"
    # Dùng script launch.sh (tự dò card lúc chạy, dùng /dev/dri/cardN không có
    # dấu ':' để khỏi xung đột ký tự ngăn cách của WLR_DRM_DEVICES).
    sudo mkdir -p /usr/local/share/wayland-sessions
    sudo tee /usr/local/share/wayland-sessions/sway-gpu.desktop >/dev/null <<EOF
[Desktop Entry]
Name=Sway (Hybrid GPU)
Comment=Sway - render bang iGPU, ho tro ca man hinh noi qua Nvidia
Exec=$HOME/.config/sway/scripts/launch.sh
Type=Application
EOF
    echo "   -> Ở màn hình đăng nhập chọn 'Sway (Hybrid GPU)'."
fi

echo "==> Đặt Nautilus làm trình quản lý file mặc định..."
xdg-mime default org.gnome.Nautilus.desktop inode/directory 2>/dev/null || true

echo "==> Xong. Đăng xuất rồi chọn 'Sway (Hybrid GPU)' ở màn hình đăng nhập (máy Nvidia)."

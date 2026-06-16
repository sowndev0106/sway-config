#!/usr/bin/env bash
# Cài Sway + tạo symlink config. Chạy: ./install.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PACKAGES=(
    sway swaybg swayidle swaylock
    waybar rofi wofi foot mako-notifier
    papirus-icon-theme
    grim slurp wl-clipboard
    curl unzip            # tải + giải nén Nerd Font cho waybar
    brightnessctl playerctl
    wireplumber pavucontrol
    policykit-1-gnome
    fonts-font-awesome fonts-jetbrains-mono
    xwayland
    # Tiện ích desktop bổ sung
    xdg-desktop-portal-wlr   # chia sẻ màn hình / hộp thoại chọn file (Zoom, Meet, OBS)
    thunar                   # file manager (nhẹ, của XFCE)
    thunar-archive-plugin    # nén/giải nén zip/rar bằng chuột phải trong Thunar
    thunar-volman            # tự nhận USB/ổ cắm ngoài
    tumbler                  # tạo ảnh thu nhỏ (thumbnail) cho ảnh/PDF
    gvfs                     # gắn ổ đĩa, thùng rác, mạng cho Thunar
    file-roller              # backend giải nén cho thunar-archive-plugin
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
# Không để repo bên thứ ba bị lỗi (key hết hạn, thiếu Release...) làm dừng script.
sudo apt update || echo "   (cảnh báo: apt update có lỗi từ repo khác, bỏ qua)"
sudo apt install -y "${PACKAGES[@]}"

echo "==> Cài JetBrainsMono Nerd Font (icon waybar)..."
# apt không có sẵn Nerd Font -> tải bản release vào thư mục font của user (không cần sudo).
# Icon waybar (wifi/bluetooth/pin/nhiệt độ...) vẽ bằng font này; thiếu nó sẽ ra ô trống.
NERD_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd"
if [ -z "$(ls "$NERD_DIR"/*.ttf 2>/dev/null)" ]; then
    mkdir -p "$NERD_DIR"
    NERD_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    if curl -fsSL --max-time 180 -o /tmp/JetBrainsMono.zip "$NERD_URL"; then
        unzip -oq /tmp/JetBrainsMono.zip -x "*Windows*" "*.txt" "LICENSE" -d "$NERD_DIR"
        fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1
        echo "   đã cài Nerd Font vào $NERD_DIR"
    else
        echo "   (cảnh báo: tải Nerd Font lỗi - kiểm tra mạng rồi chạy lại)"
    fi
else
    echo "   Nerd Font đã có, bỏ qua."
fi

echo "==> Tắt blueman-applet tự khởi động (tránh icon bluetooth trùng với waybar)..."
# Có module bluetooth trên waybar rồi nên không cần applet tray. Ghi đè autostart
# hệ thống (/etc/xdg/autostart/blueman.desktop) bằng bản Hidden=true cho riêng user.
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/blueman.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Bluetooth Manager (disabled)
Comment=Tắt blueman-applet vì đã có module bluetooth trên waybar (tránh icon tray trùng)
Exec=blueman-applet
Hidden=true
X-GNOME-Autostart-enabled=false
EOF

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

echo "==> Đặt Thunar làm trình quản lý file mặc định..."
xdg-mime default thunar.desktop inode/directory 2>/dev/null || true

echo "==> Xong. Đăng xuất rồi chọn 'Sway (Hybrid GPU)' ở màn hình đăng nhập (máy Nvidia)."

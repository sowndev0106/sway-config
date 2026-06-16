#!/usr/bin/env bash
# Cài Sway + tạo symlink config. Chạy: ./install.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PACKAGES=(
    sway swaybg swayidle swaylock
    waybar rofi wofi foot mako-notifier gnome-calendar
    papirus-icon-theme
    grim slurp wl-clipboard
    curl unzip git ca-certificates
    build-essential pkg-config
    meson ninja-build libwayland-dev wayland-protocols libgtk-4-dev
    brightnessctl playerctl
    wireplumber pavucontrol
    policykit-1-gnome
    fonts-font-awesome fonts-jetbrains-mono
    xwayland
    # Tiện ích desktop bổ sung
    xdg-desktop-portal-wlr   # chia sẻ màn hình / hộp thoại chọn file (Zoom, Meet, OBS)
    nautilus                # file manager GNOME (giống Files/macOS, dark theme đẹp)
    file-roller             # nén/giải nén zip/rar
    gvfs                    # gắn ổ đĩa, thùng rác, mạng
    tumbler                 # thumbnail cho ảnh/PDF
    qt5ct                   # cấu hình theme Qt5 (Kvantum, dark)
    qt5-style-kvantum       # engine theme dark cho Qt5
    qt6ct                   # cấu hình theme Qt6
    adwaita-qt6             # theme Adwaita dark cho Qt6 (libadwaita fallback)
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
    # Phụ thuộc cho Eww (GTK3 layer shell, dbusmenu, cairo...)
    jq
    libgtk-3-dev
    libgtk-layer-shell-dev
    libdbusmenu-gtk3-dev
    libcairo2-dev
    libgdk-pixbuf-2.0-dev
    libpango1.0-dev
)

echo "==> Cài package (cần sudo)..."
# Không để repo bên thứ ba bị lỗi (key hết hạn, thiếu Release...) làm dừng script.
sudo apt update || echo "   (cảnh báo: apt update có lỗi từ repo khác, bỏ qua)"
sudo apt install -y "${PACKAGES[@]}"

echo "==> Cấp quyền chỉnh độ sáng (group 'video')..."
# /sys/class/backlight/*/brightness thuộc group `video` với quyền rw-rw-r--.
# Không có group này, brightnessctl fail "Permission denied" — phím Fn và
# slider eww đều vô hiệu. Sau khi thêm, cần LOGOUT/LOGIN để session mới
# nhận group mới (usermod chỉ thay đổi thông tin user, group đang áp dụng
# cho tiến trình hiện tại không đổi cho đến khi đăng nhập lại).
if id -nG "$USER" 2>/dev/null | grep -qw video; then
    echo "   $USER đã ở trong group 'video', bỏ qua."
else
    if sudo usermod -aG video "$USER"; then
        echo "   ✓ Đã thêm $USER vào group 'video'."
        echo "   ⚠  LOGOUT rồi LOGIN lại (hoặc reboot) để nhận group mới."
    else
        echo "   ✗ Không thể thêm vào group 'video' (cần sudo)."
    fi
fi

export PATH="$HOME/.cargo/bin:$PATH"

cargo_meets_min_version() {
    command -v cargo >/dev/null 2>&1 || return 1

    local current required oldest
    current="$(cargo --version | awk '{print $2}')"
    required="1.95.0"
    oldest="$(printf '%s\n%s\n' "$required" "$current" | sort -V | head -n1)"

    [ "$oldest" = "$required" ]
}

ensure_rust_toolchain() {
    if cargo_meets_min_version; then
        echo "==> Rust/Cargo đủ mới, bỏ qua."
        return
    fi

    echo "==> Cài/cập nhật Rust stable bằng rustup (nwg-dock cần Rust 1.95+)..."
    if command -v rustup >/dev/null 2>&1; then
        rustup update stable
        rustup default stable
    else
        curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal
    fi

    # Sway/GDM không phải lúc nào cũng nạp ~/.profile, nhưng install.sh cần cargo ngay.
    if [ -f "$HOME/.cargo/env" ]; then
        # shellcheck disable=SC1091
        . "$HOME/.cargo/env"
    fi
    export PATH="$HOME/.cargo/bin:$PATH"
}

ensure_eww() {
    local eww_bin tmpdir source_dir

    eww_bin="$(command -v eww 2>/dev/null || true)"
    if [ -z "$eww_bin" ] && [ -x "$HOME/.local/bin/eww" ]; then
        eww_bin="$HOME/.local/bin/eww"
    fi

    if [ -n "$eww_bin" ] && "$eww_bin" --help >/dev/null 2>&1; then
        echo "==> eww đã có ($eww_bin), bỏ qua."
        return
    fi

    # eww chưa được đóng gói sẵn trên Ubuntu Noble (24.04), nên cần tự build từ source.
    echo "==> Cài eww Wayland calendar popup..."
    tmpdir="$(mktemp -d)"
    (
        set -e
        trap 'rm -rf "$tmpdir"' EXIT
        source_dir="$tmpdir/eww"
        git clone --depth 1 https://github.com/elkowar/eww.git "$source_dir"
        cargo build --manifest-path "$source_dir/Cargo.toml" \
            --release \
            --no-default-features \
            --features=wayland

        mkdir -p "$HOME/.local/bin"
        install -m 0755 "$source_dir/target/release/eww" "$HOME/.local/bin/eww"
    )
}

ensure_gtk4_layer_shell() {
    local multiarch tmpdir source_dir build_dir

    if command -v gcc >/dev/null 2>&1; then
        multiarch="$(gcc -print-multiarch 2>/dev/null || true)"
        if [ -n "$multiarch" ]; then
            export PKG_CONFIG_PATH="/usr/local/lib/$multiarch/pkgconfig:${PKG_CONFIG_PATH:-}"
        fi
    fi
    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:${PKG_CONFIG_PATH:-}"

    if pkg-config --exists gtk4-layer-shell-0; then
        echo "==> gtk4-layer-shell đã có ($(pkg-config --modversion gtk4-layer-shell-0)), bỏ qua."
        return
    fi

    echo "==> Cài gtk4-layer-shell 1.3.0 từ source (Ubuntu noble chưa có package apt)..."
    tmpdir="$(mktemp -d)"
    source_dir="$tmpdir/gtk4-layer-shell"
    build_dir="$source_dir/build"

    git clone --depth 1 --branch v1.3.0 --single-branch \
        https://github.com/wmww/gtk4-layer-shell.git "$source_dir"
    meson setup "$build_dir" "$source_dir" \
        --prefix=/usr/local \
        -Dexamples=false \
        -Ddocs=false \
        -Dtests=false \
        -Dintrospection=false \
        -Dvapi=false
    ninja -C "$build_dir"
    sudo ninja -C "$build_dir" install
    sudo ldconfig
    rm -rf "$tmpdir"

    if ! pkg-config --exists gtk4-layer-shell-0; then
        echo "   lỗi: cài gtk4-layer-shell xong nhưng pkg-config chưa thấy gtk4-layer-shell-0"
        exit 1
    fi
}

install_nwg_dock() {
    local dock_bin

    dock_bin="$(command -v nwg-dock 2>/dev/null || true)"
    if [ -z "$dock_bin" ] && [ -x "$HOME/.cargo/bin/nwg-dock" ]; then
        dock_bin="$HOME/.cargo/bin/nwg-dock"
    fi

    if [ -n "$dock_bin" ] && [ "${UPDATE_NWG_DOCK:-0}" != "1" ]; then
        echo "==> nwg-dock đã có ($dock_bin), bỏ qua."
        return
    fi

    echo "==> Cài nwg-dock Rust/macOS-style..."
    cargo install nwg-dock
}

ensure_rust_toolchain
ensure_eww
ensure_gtk4_layer_shell
install_nwg_dock

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

echo "==> Đặt Nautilus làm trình quản lý file mặc định..."
xdg-mime default org.gnome.Nautilus.desktop inode/directory 2>/dev/null || true

echo "==> Xong. Đăng xuất rồi chọn 'Sway (Hybrid GPU)' ở màn hình đăng nhập (máy Nvidia)."

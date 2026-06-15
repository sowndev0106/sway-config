#!/usr/bin/env bash
# Cài Sway + tạo symlink config. Chạy: ./install.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PACKAGES=(
    sway swaybg swayidle swaylock
    waybar wofi foot mako-notifier
    grim slurp wl-clipboard
    brightnessctl playerctl
    wireplumber pavucontrol
    policykit-1-gnome
    fonts-font-awesome fonts-jetbrains-mono
    xwayland
)

echo "==> Cài package (cần sudo)..."
sudo apt update
sudo apt install -y "${PACKAGES[@]}"

echo "==> Tạo symlink config..."
mkdir -p "$HOME/.config" "$HOME/Pictures"
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

echo "==> Xong. Đăng xuất rồi chọn 'Sway' ở màn hình đăng nhập, hoặc gõ 'sway' từ TTY."

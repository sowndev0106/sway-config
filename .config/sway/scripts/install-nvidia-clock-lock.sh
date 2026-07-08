#!/bin/sh
# Cài + bật service khoá SÀN xung Nvidia (hết giật animation/Chromium trên
# Wayland). Chạy bằng sudo: sudo .../install-nvidia-clock-lock.sh
#
# Tách riêng (giống install-xremap.sh) để gọi được bằng MỘT dòng, khỏi dán
# heredoc nhiều dòng. install.sh gọi script này; cũng chạy tay được.
# Lý do/cách hoạt động: xem nvidia-clock-lock.sh.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Không có Nvidia thì thôi (máy chỉ-Intel).
[ -d /sys/module/nvidia ] || { echo "Không thấy module nvidia, bỏ qua."; exit 0; }

install -m 0755 "$SCRIPT_DIR/nvidia-clock-lock.sh" /usr/local/bin/nvidia-clock-lock

tee /etc/systemd/system/nvidia-clock-lock.service >/dev/null <<'EOF'
[Unit]
Description=Khoa san xung GPU Nvidia (het giat tren Wayland)
# After systemd-suspend.service + WantedBy=suspend.target: chay lai SAU resume
# (suspend lam mat khoa xung).
After=nvidia-persistenced.service systemd-suspend.service systemd-hibernate.service systemd-hybrid-sleep.service
Wants=nvidia-persistenced.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nvidia-clock-lock

[Install]
WantedBy=multi-user.target suspend.target hibernate.target hybrid-sleep.target
EOF

systemctl daemon-reload
systemctl enable --now nvidia-clock-lock.service
echo "✓ Đã bật nvidia-clock-lock.service"

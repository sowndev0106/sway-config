#!/usr/bin/env bash
# Cài Sway + tạo symlink config. Chạy: ./install.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PACKAGES=(
    sway swaybg swayidle swaylock
    waybar rofi wofi foot mako-notifier gnome-calendar
    papirus-icon-theme
    grim slurp wl-clipboard
    wtype                    # synthetic keypresses on Wayland (Ctrl+Shift+C remap)
    curl unzip git ca-certificates gpg
    build-essential pkg-config
    meson ninja-build libwayland-dev wayland-protocols libgtk-4-dev
    brightnessctl playerctl
    wireplumber pavucontrol
    policykit-1-gnome
    fonts-font-awesome fonts-jetbrains-mono
    xwayland
    # Tiện ích desktop bổ sung
    xdg-desktop-portal-wlr   # chia sẻ màn hình / hộp thoại chọn file (Zoom, Meet, OBS)
    nemo                    # file manager Cinnamon (GTK3, hỗ trợ chuột/kéo-thả tốt, nhẹ hơn Nautilus)
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
    gettext                  # msgfmt/xgettext cho build swappy nếu apt chưa có package
    pkg-config libxkbcommon-dev libwayland-dev   # build wayfreeze (đóng băng màn hình lúc chụp vùng)
    kanshi wdisplays         # đa màn hình: tự sắp xếp + GUI kéo thả
    # Phụ thuộc cho Eww (GTK3 layer shell, dbusmenu, cairo...)
    jq
    libgtk-3-dev
    libgtk-layer-shell-dev
    libdbusmenu-gtk3-dev
    libglib2.0-dev
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

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

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

install_wayfreeze() {
    local wf_bin

    wf_bin="$(command -v wayfreeze 2>/dev/null || true)"
    if [ -z "$wf_bin" ] && [ -x "$HOME/.cargo/bin/wayfreeze" ]; then
        wf_bin="$HOME/.cargo/bin/wayfreeze"
    fi

    if [ -n "$wf_bin" ] && [ "${UPDATE_WAYFREEZE:-0}" != "1" ]; then
        echo "==> wayfreeze đã có ($wf_bin), bỏ qua."
        return
    fi

    # Không có trên apt lẫn crates.io nên cài thẳng từ GitHub (ghim tag để build lặp lại được).
    # Thất bại (mất mạng...) thì KHÔNG dừng cả install.sh: phím chụp vùng vẫn chạy, chỉ là
    # màn hình không đóng băng lúc chọn vùng (screenshot-freeze.sh tự chạy tiếp không có nó).
    echo "==> Cài wayfreeze (đóng băng màn hình lúc chụp vùng)..."
    cargo install --git https://github.com/Jappie3/wayfreeze --tag 0.2.1 --locked \
        || echo "!! Không cài được wayfreeze: chụp vùng vẫn chạy nhưng màn hình không đóng băng."
}

ensure_wayscriber() {
    local wayscriber_bin configurator_bin
    local keyring="/usr/share/keyrings/wayscriber.gpg"
    local source_file="/etc/apt/sources.list.d/wayscriber.list"

    wayscriber_bin="$(command -v wayscriber 2>/dev/null || true)"
    configurator_bin="$(command -v wayscriber-configurator 2>/dev/null || true)"

    if dpkg-query -W -f='${Status}' wayscriber 2>/dev/null | grep -qx 'install ok installed' \
        && dpkg-query -W -f='${Status}' wayscriber-configurator 2>/dev/null | grep -qx 'install ok installed' \
        && [ "${UPDATE_WAYSCRIBER:-0}" != "1" ]; then
        echo "==> wayscriber apt package đã có, bỏ qua."
        if [ -n "$wayscriber_bin" ] && [[ "$wayscriber_bin" == "$HOME/.local/bin/"* ]]; then
            echo "   lưu ý: PATH đang ưu tiên bản user-local ($wayscriber_bin)."
        fi
        return
    fi

    echo "==> Cài wayscriber screen annotation..."
    sudo install -d -m 0755 /usr/share/keyrings
    curl -fsSL https://wayscriber.com/apt/WAYSCRIBER-GPG-KEY.asc \
        | gpg --dearmor \
        | sudo tee "$keyring" >/dev/null
    echo "deb [signed-by=$keyring] https://wayscriber.com/apt stable main" \
        | sudo tee "$source_file" >/dev/null
    sudo apt update
    sudo apt install -y wayscriber wayscriber-configurator

    wayscriber_bin="$(command -v wayscriber 2>/dev/null || true)"
    if [ -n "$wayscriber_bin" ] && [[ "$wayscriber_bin" == "$HOME/.local/bin/"* ]]; then
        echo "   lưu ý: PATH đang ưu tiên bản user-local ($wayscriber_bin) thay vì /usr/bin/wayscriber."
    fi
}

ensure_xremap() {
    # xremap: remap phím theo app (Ctrl+Shift+C = copy trong trình duyệt). Cần
    # quyền input nên cài bằng script riêng (sudo). Bỏ qua nếu đã có binary.
    if command -v xremap >/dev/null 2>&1 && [ "${UPDATE_XREMAP:-0}" != "1" ]; then
        echo "==> xremap đã có ($(command -v xremap)), bỏ qua."
        return
    fi
    echo "==> Cài xremap (remap phím theo app cho trình duyệt)..."
    sudo "$REPO_DIR/.config/sway/scripts/install-xremap.sh"
}

install_swappy() {
    local swappy_bin tmpdir source_dir build_dir

    swappy_bin="$(command -v swappy 2>/dev/null || true)"
    if [ -n "$swappy_bin" ] && [ "${UPDATE_SWAPPY:-0}" != "1" ]; then
        echo "==> swappy đã có ($swappy_bin), bỏ qua."
        return
    fi

    if apt-cache show swappy >/dev/null 2>&1; then
        echo "==> Cài swappy từ apt..."
        sudo apt install -y swappy
        return
    fi

    echo "==> Cài swappy screenshot editor từ source..."
    tmpdir="$(mktemp -d)"
    (
        set -e
        trap 'rm -rf "$tmpdir"' EXIT
        source_dir="$tmpdir/swappy"
        build_dir="$source_dir/build"

        git clone --depth 1 https://github.com/jtheoof/swappy.git "$source_dir"
        meson setup "$build_dir" "$source_dir" \
            --prefix="$HOME/.local" \
            -Dman-pages=disabled
        ninja -C "$build_dir"
        ninja -C "$build_dir" install
    )
}

ensure_wayscriber
install_swappy
ensure_xremap
ensure_rust_toolchain
ensure_eww
ensure_gtk4_layer_shell
install_nwg_dock
install_wayfreeze

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

echo "==> Ép Chrome chạy Wayland gốc (hết giật khi cuộn trang)..."
# Mặc định google-chrome chạy qua XWayland -> thêm một lớp copy/đồng bộ khung,
# gây GIẬT khi cuộn (rõ nhất trên máy Nvidia-primary). --ozone-platform-hint=auto
# cho Chrome tự chọn Wayland khi đang trong session Wayland. Ghi đè desktop file
# hệ thống bằng bản user cùng tên: copy nguyên bản gốc (giữ MimeType/Actions/icon)
# rồi chèn flag vào các dòng Exec -> bền qua mỗi lần Chrome update.
_chrome_desktop=/usr/share/applications/google-chrome.desktop
if [ -f "$_chrome_desktop" ]; then
    mkdir -p "$HOME/.local/share/applications"
    sed 's#^Exec=/usr/bin/google-chrome\S*#& --ozone-platform-hint=auto#' \
        "$_chrome_desktop" > "$HOME/.local/share/applications/google-chrome.desktop"
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

echo "==> Ép app Electron render đúng GPU (hết giật Discord/Postman... trên máy Nvidia)..."
# Electron chọn nhầm iGPU Intel làm render node trên máy Nvidia-primary -> mỗi
# frame copy chéo GPU qua PCIe -> GIẬT. Không có biến môi trường toàn cục nào
# truyền được flag Chromium cho Electron đóng gói sẵn, nên phải bọc từng app
# qua electron-gpu.sh (tự dò GPU lúc chạy, máy chỉ-Intel không bị ảnh hưởng —
# xem chú thích trong script). Cách làm giống Chrome ở trên: ghi đè desktop
# file bằng bản user cùng tên, chèn wrapper vào đầu dòng Exec -> bền qua mỗi
# lần app update. Chạy lại install.sh sau khi cài app Electron mới để bọc nó.
_electron_gpu="$REPO_DIR/.config/sway/scripts/electron-gpu.sh"

# Bọc 1 desktop file: copy sang bản user (nếu là file hệ thống) rồi chèn wrapper.
wrap_electron_desktop() {
    local src="$1" dst
    dst="$HOME/.local/share/applications/$(basename "$src")"
    if [ -f "$dst" ] && grep -q electron-gpu.sh "$dst"; then
        return    # đã bọc rồi
    fi
    mkdir -p "$HOME/.local/share/applications"
    if [ "$src" -ef "$dst" ]; then
        sed -i "s#^Exec=#Exec=$_electron_gpu #" "$dst"
    else
        sed "s#^Exec=#Exec=$_electron_gpu #" "$(readlink -f "$src")" > "$dst"
    fi
    echo "   bọc electron-gpu: $(basename "$src")"
}

# Tự quét mọi desktop entry: app nào có chrome_crashpad_handler / chrome-sandbox
# cạnh binary (hoặc thư mục cha) là app Electron/Chromium -> bọc. Bỏ qua:
# - google-chrome/chromium: đời mới tự chọn đúng GPU qua dmabuf-feedback rồi;
# - flatpak/snap: sandbox riêng, muốn thêm flag phải dùng cơ chế override của chúng.
for _f in /usr/share/applications/*.desktop "$HOME/.local/share/applications/"*.desktop; do
    [ -f "$_f" ] || continue
    case "$(basename "$_f")" in google-chrome*|chromium*|com.google.Chrome*) continue ;; esac
    _bin="$(awk -F= '/^Exec=/{print $2; exit}' "$_f" | awk '{print $1}')"
    case "$_bin" in ""|env|flatpak|snap|*electron-gpu.sh) continue ;; esac
    _real="$(readlink -f "$(command -v "$_bin" 2>/dev/null || echo "$_bin")" 2>/dev/null || true)"
    [ -n "$_real" ] && [ -e "$_real" ] || continue
    _dir="$(dirname "$_real")"
    if [ -e "$_dir/chrome_crashpad_handler" ] || [ -e "$_dir/chrome-sandbox" ] \
        || [ -e "$_dir/../chrome_crashpad_handler" ] || [ -e "$_dir/../chrome-sandbox" ]; then
        wrap_electron_desktop "$_f"
    fi
done
# Discord: /usr/bin/discord chỉ là script trỏ tới bản tự cập nhật trong
# ~/.config/discord nên heuristic trên không bắt được -> bọc thẳng.
[ -f /usr/share/applications/discord.desktop ] \
    && wrap_electron_desktop /usr/share/applications/discord.desktop
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo "==> Bật dịch vụ Bluetooth..."
sudo systemctl enable --now bluetooth

### Cho phép đọc công suất CPU (Intel RAPL) không cần root.
### File energy_uj mặc định chỉ root đọc (chặn tấn công kênh phụ PLATYPUS/CVE-2020-8694),
### nên module công suất của waybar (cpu-power.sh) không đọc được. Tạo udev rule
### nới quyền đọc, rồi reload + trigger để áp dụng NGAY (không phải đợi reboot).
### LƯU Ý: không đặt ACTION=="add" — udevadm trigger phát sự kiện "change", rule sẽ
### không chạy. Bỏ ACTION đi để rule khớp cả "change" (trigger) lẫn "add" (lúc boot).
if [ -d /sys/class/powercap/intel-rapl:0 ]; then
    echo "==> Mở quyền đọc công suất CPU (Intel RAPL) cho waybar..."
    sudo tee /etc/udev/rules.d/99-rapl.rules >/dev/null <<'EOF'
# Nới quyền đọc energy_uj của Intel RAPL để waybar hiển thị công suất CPU.
SUBSYSTEM=="powercap", RUN+="/bin/chmod o+r /sys%p/energy_uj"
EOF
    sudo udevadm control --reload
    sudo udevadm trigger --subsystem-match=powercap
fi

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
# Dò Nvidia qua /sys (KHÔNG dùng 'lsmod | grep -q': dưới 'set -o pipefail',
# grep -q khớp xong đóng pipe làm lsmod chết SIGPIPE -> pipeline báo lỗi dù đã
# khớp -> khối bị bỏ nhầm). Đọc /sys/module/nvidia là chắc chắn, không qua pipe.
if [ -d /sys/module/nvidia ]; then
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

    # Sway 1.9 của 24.04 thiếu explicit-sync -> màn hình qua Nvidia bị giật.
    # Build Sway 1.12 vào /opt/sway-stack nếu chưa có. LƯU Ý: explicit sync chỉ
    # có từ Sway 1.11 (1.10 mới chỉ chứa code trong wlroots, chưa bật) — vì vậy
    # bản 1.10/1.11 cũ trong /opt cũng phải build lại.
    # (Không dùng '... | grep -q' vì lý do pipefail/SIGPIPE nêu trên.)
    sway_built="$(/opt/sway-stack/bin/sway --version 2>/dev/null || true)"
    case "$sway_built" in
        *" 1.12"*)
            echo "   -> Đã có Sway 1.12 ở /opt/sway-stack, bỏ qua build." ;;
        *)
            echo "==> Build Sway 1.12 từ source để hết giật trên Nvidia (~15-25 phút)..."
            sudo "$REPO_DIR/.config/sway/scripts/build-sway.sh" ;;
    esac

    # Nvidia nằm lì ở pstate P8 trên Wayland -> animation/Chromium lâu lâu GIẬT.
    # Service khoá SÀN xung (vẫn boost được khi tải nặng) để hết giật. Chạy lúc
    # khởi động VÀ sau mỗi lần resume (suspend làm mất khoá xung). Script root
    # nên copy vào /usr/local/bin (không tham chiếu $HOME như session launch.sh).
    echo "==> Cài service khoá xung Nvidia (hết giật animation/Chromium trên Wayland)..."
    sudo "$REPO_DIR/.config/sway/scripts/install-nvidia-clock-lock.sh"
fi

echo "==> Đặt Nemo làm trình quản lý file mặc định..."
xdg-mime default nemo.desktop inode/directory 2>/dev/null || true

echo "==> Đăng ký Chrome profile riêng (float) cho link app khác mở ra..."
### Nhiều app (claude code, claude cli, VS Code, Slack...) mở link test/preview
### qua xdg-open -> mặc định Chrome sẽ nhồi vào tab của cửa sổ đang mở, xen vào
### layout tile hiện tại. Wrapper chrome-float.sh dùng --user-data-dir riêng để
### chạy một tiến trình Chrome ĐỘC LẬP (không dùng chung session với Chrome
### chính), --class=chrome-float đặt app_id để rule floating trong
### .config/sway/config bắt được và tự nổi giữa màn hình. Vì user-data-dir khác
### nhau, Chrome coi đây là phiên trình duyệt riêng (cookie/đăng nhập tách biệt
### khỏi Chrome chính) — các lần mở link sau sẽ vào tab mới của CHÍNH cửa sổ
### float này (Chrome tự nhận đã có tiến trình chạy trên profile đó), không
### bung thêm cửa sổ mới mỗi lần.
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/chrome-float.desktop" <<EOF
[Desktop Entry]
Name=Google Chrome (Float)
Comment=Chrome profile riêng, tự nổi giữa màn hình — dùng khi app khác (claude code, claude cli, VS Code...) mở link
Exec=$HOME/.config/sway/scripts/chrome-float.sh %U
Terminal=false
Type=Application
Icon=google-chrome
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
Categories=Network;WebBrowser;
NoDisplay=false
EOF
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
xdg-mime default chrome-float.desktop x-scheme-handler/http 2>/dev/null || true
xdg-mime default chrome-float.desktop x-scheme-handler/https 2>/dev/null || true


echo "==> Xong. Đăng xuất rồi chọn 'Sway (Hybrid GPU)' ở màn hình đăng nhập (máy Nvidia)."

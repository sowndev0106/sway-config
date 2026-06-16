# sway-config

Cấu hình **Sway** (trình quản lý cửa sổ tiling cho Wayland) của `sowndev0106`, quản lý bằng **git + symlink** để đồng bộ giữa nhiều máy.

Theme: **Catppuccin Mocha** · Phím `Mod` = **Super** (phím Windows ⊞).

---

## Mục lục

1. [Thành phần](#1-thành-phần)
2. [Cài đặt](#2-cài-đặt)
3. [Khởi động Sway](#3-khởi-động-sway)
4. [Toàn bộ phím tắt](#4-toàn-bộ-phím-tắt)
5. [Khái niệm cơ bản (tiling, workspace, layout...)](#5-khái-niệm-cơ-bản)
6. [Từng thành phần & cách dùng](#6-từng-thành-phần--cách-dùng)
7. [Tùy biến](#7-tùy-biến)
8. [Đồng bộ config với git](#8-đồng-bộ-config-với-git)
9. [Xử lý sự cố](#9-xử-lý-sự-cố)

---

## 1. Thành phần

| Công cụ | Vai trò | Phím / lệnh |
|---|---|---|
| **sway** | Quản lý cửa sổ tiling (Wayland) | — |
| **waybar** | Thanh trạng thái trên cùng | tự chạy |
| **nwg-dock** | Dock app dưới màn hình, tự ẩn | rê chuột xuống đáy màn hình |
| **rofi** | Trình khởi chạy ứng dụng & nút nguồn ghim trực tiếp (cải tiến) | `Mod+d` |
| **wofi** | Launcher dự phòng (native Wayland) | `Mod+Shift+d` |
| **foot** | Terminal | `Mod+Enter` |
| **mako** | Thông báo (notification) | tự chạy |
| **swaylock** | Khóa màn hình | `Mod+Shift+x` |
| **swayidle** | Tự khóa / tắt màn hình khi rảnh | tự chạy |
| **grim + slurp** | Chụp màn hình | `Print` |
| **wl-clipboard** | Copy/paste dòng lệnh (`wl-copy`/`wl-paste`) | — |
| **brightnessctl** | Chỉnh độ sáng | phím độ sáng |
| **playerctl** | Điều khiển nhạc/video | phím media |
| **pavucontrol** | Quản lý âm thanh (GUI) | từ launcher |
| **cliphist** | Lịch sử clipboard (copy nhiều lần) | `Mod+Shift+v` |
| **thunar** | Trình quản lý file (nhẹ, hỗ trợ USB/nén) | `Mod+E` |
| **firefox** | Trình duyệt | từ launcher |
| **imv** | Xem ảnh | `imv <ảnh>` |
| **nm-applet** | WiFi / mạng (GUI ở khay) | icon khay |
| **blueman** | Bluetooth (GUI ở khay) | icon khay |
| **wob** | Thanh OSD volume/độ sáng | tự hiện khi chỉnh |
| **wf-recorder** | Quay màn hình | `Mod+Shift+r` |
| **zathura** | Đọc PDF | `zathura <file>` |
| **wlogout** | Menu nguồn toàn màn hình (dự phòng) | `Mod+Shift+e` |
| **grimshot** | Chụp màn hình (kèm thông báo) | `Print` |
| **kanshi / wdisplays** | Đa màn hình (tự sắp xếp / GUI) | tự chạy / từ launcher |
| **fcitx5 + unikey** | Bộ gõ tiếng Việt | `Ctrl+Space` để bật/tắt |
| **xdg-desktop-portal-wlr** | Chia sẻ màn hình / hộp thoại chọn file | (nền) |

---

## 2. Cài đặt

### Trên máy mới

```bash
git clone git@github.com:sowndev0106/sway-config.git ~/sway-config
cd ~/sway-config
./install.sh
```

`install.sh` sẽ:
1. `apt install` toàn bộ package cần thiết.
2. Cài `nwg-dock` bằng Cargo; nếu Ubuntu chưa có `gtk4-layer-shell`, script tự build thư viện này từ source.
3. Tạo **symlink** từ `~/.config/<tên>` trỏ vào thư mục trong repo. Config cũ (nếu có) được đổi tên thành `<tên>.bak` để sao lưu.

> **Symlink là gì?** Là một "lối tắt": file thật nằm trong `~/sway-config`, còn `~/.config/sway` chỉ là con trỏ trỏ tới đó. Nhờ vậy bạn sửa file → `git commit` là xong, không phải copy qua lại. Một nguồn duy nhất.

### Cập nhật trên máy đã cài

```bash
cd ~/sway-config && git pull
```
Sau đó bấm `Mod+Shift+c` trong Sway để nạp lại config.

---

## 3. Khởi động Sway

- **Từ màn hình đăng nhập (GDM):** đăng xuất phiên hiện tại → ở góc dưới phải bấm biểu tượng bánh răng ⚙ → chọn **"Sway"** → đăng nhập.
- **Từ TTY:** chuyển sang một console (`Ctrl+Alt+F3`), đăng nhập rồi gõ:
  ```bash
  sway
  ```

Khi vào, bạn sẽ thấy nền màu trơn + thanh waybar trên cùng. Bấm `Mod+Enter` mở terminal đầu tiên.

---

## 4. Toàn bộ phím tắt

> `Mod` = **Super** (phím Windows). Tất cả định nghĩa trong `.config/sway/config`.

### Ứng dụng & hệ thống

| Phím | Hành động |
|---|---|
| `Mod+Enter` | Mở terminal (foot) |
| `Mod+d` | Trình khởi chạy ứng dụng (rofi) |
| `Mod+Shift+d` | Launcher dự phòng (wofi) |
| `Mod+q` | Đóng cửa sổ đang focus |
| `Mod+E` | Mở file manager (Thunar) |
| `Mod+Shift+c` | Nạp lại config (reload) |
| `Mod+Shift+e` | Menu nguồn toàn màn hình (wlogout) |
| `Mod+Shift+x` | Khóa màn hình ngay |
| `Mod+Shift+v` | Lịch sử clipboard (cliphist) |
| `Ctrl+Space` | Bật/tắt gõ tiếng Việt (fcitx5) |

### Di chuyển focus giữa các cửa sổ

| Phím | Hành động |
|---|---|
| `Mod+h` / `Mod+←` | Focus sang trái |
| `Mod+j` / `Mod+↓` | Focus xuống dưới |
| `Mod+k` / `Mod+↑` | Focus lên trên |
| `Mod+l` / `Mod+→` | Focus sang phải |

### Di chuyển (đổi vị trí) cửa sổ

| Phím | Hành động |
|---|---|
| `Mod+Shift+h` / `Mod+Shift+←` | Dời cửa sổ sang trái |
| `Mod+Shift+j` / `Mod+Shift+↓` | Dời cửa sổ xuống |
| `Mod+Shift+k` / `Mod+Shift+↑` | Dời cửa sổ lên |
| `Mod+Shift+l` / `Mod+Shift+→` | Dời cửa sổ sang phải |

### Workspace (không gian làm việc)

| Phím | Hành động |
|---|---|
| `Mod+1` … `Mod+0` | Chuyển sang workspace 1…10 |
| `Mod+Shift+1` … `Mod+Shift+0` | Dời cửa sổ sang workspace 1…10 |

### Bố cục (layout)

| Phím | Hành động |
|---|---|
| `Mod+b` | Chia ngang (cửa sổ mới nằm bên phải) |
| `Mod+v` | Chia dọc (cửa sổ mới nằm bên dưới) |
| `Mod+s` | Layout **stacking** (xếp chồng, xem tiêu đề) |
| `Mod+w` | Layout **tabbed** (dạng tab) |
| `Mod+f` | Bật/tắt **toàn màn hình** |
| `Mod+a` | Focus lên container cha |

### Cửa sổ nổi (floating) & scratchpad

| Phím | Hành động |
|---|---|
| `Mod+Shift+Space` | Bật/tắt chế độ nổi cho cửa sổ |
| `Mod+Space` | Chuyển focus giữa cửa sổ tiling ↔ floating |
| `Mod+Shift+-` | Cất cửa sổ vào **scratchpad** (ẩn) |
| `Mod+-` | Hiện cửa sổ trong scratchpad |

> **Scratchpad** = ngăn chứa ẩn. Cất một cửa sổ (vd terminal, máy tính) vào đó rồi gọi ra bất cứ workspace nào — tiện cho thứ dùng thoáng qua.

### Đổi kích thước (resize mode)

| Phím | Hành động |
|---|---|
| `Mod+r` | Vào **chế độ resize** |
| `h` / `j` / `k` / `l` | (trong resize) thu/giãn cửa sổ |
| `Enter` hoặc `Esc` | Thoát resize mode |

### Âm thanh / độ sáng / media (phím chức năng laptop)

| Phím | Hành động |
|---|---|
| `🔊+` / `🔊−` | Tăng / giảm âm lượng |
| `🔇` | Tắt/bật tiếng |
| Mic mute | Tắt/bật micro |
| `☀+` / `☀−` | Tăng / giảm độ sáng |
| ⏯ / ⏭ / ⏮ | Play-pause / bài kế / bài trước |

### Chụp màn hình

| Phím | Hành động |
|---|---|
| `Print` | Chụp **toàn màn hình** → lưu file (`~/Pictures`) |
| `Shift+Print` | Chọn **vùng** → copy vào clipboard |
| `Mod+Print` | Chọn **vùng** → lưu file |
| `Mod+Shift+s` | Chọn **vùng** → copy vào clipboard (kiểu snip) |
| `Mod+Shift+r` | Quay màn hình (bấm lần 2 để dừng) → lưu `~/Videos` |
| Vuốt 3 ngón (touchpad) | Đổi workspace trái/phải |

---

## 5. Khái niệm cơ bản

- **Tiling:** cửa sổ tự xếp kín màn hình, không chồng lên nhau. Mở cửa sổ mới → màn hình tự chia ô.
- **Workspace:** 10 không gian làm việc ảo (`Mod+1..0`). Mỗi workspace chứa bộ cửa sổ riêng — gom việc theo nhóm (vd 1=code, 2=trình duyệt, 3=chat).
- **Layout:** cách sắp xếp các cửa sổ trong một vùng — chia đôi (split), xếp chồng (stacking), hoặc dạng tab (tabbed).
- **Floating:** cửa sổ "nổi" tự do như trên desktop thường (hợp cho hộp thoại, máy tính bỏ túi). Bật bằng `Mod+Shift+Space`.
- **Focus:** cửa sổ đang nhận bàn phím (viền sáng màu xanh). Đổi bằng `Mod+h/j/k/l`.

---

## 6. Từng thành phần & cách dùng

### foot (terminal) — `Mod+Enter`
Terminal nhẹ, native Wayland. Cấu hình: `.config/foot/foot.ini` (font JetBrains Mono cỡ 11, theme Catppuccin, cuộn 10.000 dòng).

### rofi (launcher cải tiến) — `Mod+d`
Trình khởi chạy chính của hệ thống, được thiết kế lại theo phong cách kính mờ (glassmorphism) hiện đại:
* **Giao diện tab tinh gọn**: Có 3 tab điều hướng nằm dưới đáy cửa sổ:
  * **Apps (`󰀻  Apps`)**: Tìm và mở nhanh các ứng dụng đồ họa.
  * **Run (`  Run`)**: Chạy trực tiếp các lệnh hệ thống.
  * **Files (`󰉋  Files`)**: Duyệt và mở nhanh tệp tin trực tiếp (Enter vào thư mục để truy cập, Backspace để quay lại, Enter vào tệp tin để mở bằng phần mềm mặc định).
* **Shortcut Shift + Enter**: Trong tab **Run**, khi chọn một lệnh dòng lệnh (như `htop`, `btop`), bạn chỉ cần nhấn **`Shift+Enter`**, Rofi sẽ tự động mở terminal `foot` và chạy lệnh đó bên trong.
* **Cụm nút nguồn ghim trực tiếp (Bottom-Right Powerbar)**:
  * 4 nút nguồn: Khóa màn (``), Đăng xuất (``), Khởi động lại (``) và Tắt máy (``) luôn nằm cố định ở góc dưới bên phải cửa sổ Rofi.
  * **Xác nhận an toàn**: Nhấn Khóa màn sẽ khóa máy ngay lập tức. Nhấn các nút khác sẽ hiển thị một cửa sổ pop-up nhỏ hỏi lại *Có / Huỷ* để đảm bảo an toàn.

### waybar (thanh trạng thái)
Hiện workspace (trái), tên cửa sổ (giữa), và bên phải: âm lượng, mạng, CPU, RAM, pin, đồng hồ, khay hệ thống (tray). Cấu hình: `.config/waybar/config` (nội dung) và `style.css` (giao diện).

### nwg-dock (dock app tự ẩn)
Dock nằm dưới màn hình, mặc định ẩn để không chiếm diện tích. Rê chuột xuống đáy màn hình để dock trồi lên; rời chuột thì dock tự ẩn lại. Cấu hình: `.config/nwg-dock-hyprland/config.toml` và `style.css`. Script khởi động: `.config/sway/scripts/dock.sh`.

### mako (thông báo)
Tự chạy. Thông báo hiện góc trên-phải, theme Catppuccin. Cấu hình: `.config/mako/config`. Lệnh hữu ích: `makoctl dismiss` (đóng), `makoctl restore`.

### swaylock + swayidle (khóa màn hình)
- Khóa thủ công: `Mod+Shift+x` hoặc click nút khóa ở góc dưới phải Rofi.
- Tự động (cấu hình trong `sway/config`): **5 phút** không hoạt động → khóa; **10 phút** → tắt màn hình; khi mở nắp/đánh thức → bật lại. Khi máy ngủ (suspend) cũng tự khóa.

### Chụp màn hình (grim + slurp)
- `Print`: lưu file PNG vào `~/Pictures`.
- `Shift+Print`: kéo chọn vùng → vào clipboard, dán bằng `Ctrl+V`.

### Lịch sử clipboard (cliphist) — `Mod+Shift+v`
Mọi nội dung bạn copy được lưu lại. Bấm `Mod+Shift+v` → rofi hiện danh sách đã copy → chọn để dán lại. Tiến trình ghi chạy nền (`wl-paste --watch`).

### Bộ gõ tiếng Việt (fcitx5 + Unikey)
fcitx5 tự chạy nền khi vào Sway. Biến môi trường nằm ở `.config/environment.d/im.conf` — **cần đăng xuất rồi đăng nhập lại một lần** để có hiệu lực.

**Thiết lập lần đầu (chỉ làm một lần):**
1. Mở cấu hình: chạy `fcitx5-configtool` (từ launcher hoặc terminal).
2. Ở cột "Input Method", bấm `+`, bỏ chọn "Only Show Current Language", tìm **Unikey** → Add.
3. Đảm bảo danh sách có cả **Keyboard - English (US)** và **Unikey**.
4. Bấm Apply.

**Sử dụng:** bấm `Ctrl+Space` để chuyển qua lại Anh ↔ Việt (Unikey mặc định kiểu gõ Telex). Kiểu gõ (Telex/VNI) đổi trong `fcitx5-configtool` → Unikey.

> Nếu một app (thường là app XWayland) không gõ được tiếng Việt, kiểm tra đã đăng nhập lại sau khi cài chưa, và `pgrep fcitx5` có thấy tiến trình không.

---

## 7. Tùy biến

Mọi file nằm trong `~/sway-config/.config/` (đã symlink vào `~/.config`). Sửa xong bấm `Mod+Shift+c` để áp dụng (riêng waybar/mako cần khởi động lại tiến trình hoặc reload Sway).

| Muốn đổi | Sửa file |
|---|---|
| Phím tắt, layout, gaps, màu viền, autostart | `.config/sway/config` |
| Hình nền | dòng `output * bg ...` trong `sway/config` (đổi `#1e1e2e` thành `~/anh.png fill`) |
| Thời gian tự khóa màn hình | khối `exec swayidle ...` trong `sway/config` |
| Bố cục / module thanh trạng thái | `.config/waybar/config` |
| Màu sắc thanh trạng thái | `.config/waybar/style.css` |
| Dock app dưới màn hình | `.config/nwg-dock-hyprland/config.toml` |
| Màu sắc dock app | `.config/nwg-dock-hyprland/style.css` |
| Giao diện rofi | `.config/rofi/config.rasi` |
| Font / màu terminal | `.config/foot/foot.ini` |
| Kiểu thông báo | `.config/mako/config` |

**Đặt hình nền ảnh thật:** trong `sway/config` đổi dòng `output * bg #1e1e2e solid_color` thành:
```
output * bg ~/Pictures/wallpaper.jpg fill
```

**Xem tên màn hình / thiết bị nhập** (để cấu hình riêng):
```bash
swaymsg -t get_outputs   # màn hình
swaymsg -t get_inputs    # bàn phím, touchpad...
```

---

## 8. Đồng bộ config với git

Sau khi sửa bất kỳ file nào:

```bash
cd ~/sway-config
git add -A
git commit -m "Mô tả thay đổi"
git push
```

Lấy thay đổi từ máy khác về:
```bash
cd ~/sway-config && git pull
```
Rồi `Mod+Shift+c` để nạp lại.

> File `*.bak` (bản sao lưu config cũ) bị `.gitignore` bỏ qua, không lên git.

---

## 9. Xử lý sự cố

| Triệu chứng | Cách xử lý |
|---|---|
| Sway không khởi động | Chạy `sway` từ TTY để xem log lỗi; kiểm tra dòng `swaymsg -t get_outputs` |
| **Máy Nvidia: vào Sway bị văng về login** | Sway từ chối GPU Nvidia độc quyền nên thoát ngay. Chọn session **"Sway (Hybrid GPU)"** ở màn hình đăng nhập (install.sh tự tạo nếu có Nvidia — render bằng iGPU, vẫn dùng được màn hình nối qua Nvidia). Từ TTY: `WLR_DRM_DEVICES=<iGPU>:<Nvidia> sway --unsupported-gpu` |
| Phím tắt không ăn | `Mod+Shift+c` reload; xem log: `journalctl --user -b -u sway` hoặc chạy `swaymsg -t get_config` |
| Waybar không hiện | Chạy tay `waybar` trong terminal để đọc lỗi cú pháp JSON |
| Dock không hiện khi rê xuống đáy | Chạy `~/.config/sway/scripts/dock.sh` trong terminal để xem lỗi; nếu báo thiếu binary thì chạy `./install.sh` |
| Volume/độ sáng không đổi | Kiểm tra `wpctl status` (audio), `brightnessctl info` |
| Không share được màn hình (Zoom/Meet) | Cài thêm `xdg-desktop-portal-wlr` |
| App GUI không xin được quyền admin | Kiểm tra polkit agent đang chạy: `pgrep -f polkit-gnome` |
| Đổi config nhưng không thấy gì | Đảm bảo đang sửa file trong `~/sway-config` (symlink), rồi reload |

**Kiểm tra symlink còn đúng không:**
```bash
ls -l ~/.config | grep sway-config
```
Mỗi dòng phải trỏ về `~/sway-config/.config/...`.

---

## Cấu trúc repo

```
sway-config/
├── .config/
│   ├── sway/config            # cấu hình chính + toàn bộ phím tắt
│   ├── sway/scripts/          # vol.sh, bri.sh (OSD), record.sh (quay màn hình), rofi-focused.sh (điều khiển rofi)
│   ├── swaylock/config        # màn khóa (đồng hồ + theme)
│   ├── wlogout/{layout,style.css}  # menu nguồn
│   ├── kanshi/config          # bố cục đa màn hình
│   ├── xdg-desktop-portal/    # cấu hình portal (chia sẻ màn hình)
│   ├── waybar/config          # nội dung thanh trạng thái
│   ├── waybar/style.css       # giao diện thanh trạng thái
│   ├── nwg-dock-hyprland/     # dock app dưới màn hình (config + CSS)
│   ├── rofi/config.rasi       # launcher chính
│   ├── wofi/config            # launcher dự phòng
│   ├── wofi/style.css
│   ├── foot/foot.ini          # terminal
│   ├── mako/config            # thông báo
│   └── environment.d/im.conf  # biến môi trường bộ gõ tiếng Việt
├── install.sh                 # cài package + tạo symlink
├── .gitignore
└── README.md                  # file này
```

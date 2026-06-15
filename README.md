# sway-config

Cấu hình **Sway** (trình quản lý cửa sổ tiling cho Wayland) của `sowndev0106`,
quản lý bằng **git + symlink** để đồng bộ giữa nhiều máy.

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
| **rofi** | Trình khởi chạy ứng dụng (chính) | `Mod+d` |
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
2. Tạo **symlink** từ `~/.config/<tên>` trỏ vào thư mục trong repo.
   Config cũ (nếu có) được đổi tên thành `<tên>.bak` để sao lưu.

> **Symlink là gì?** Là một "lối tắt": file thật nằm trong `~/sway-config`,
> còn `~/.config/sway` chỉ là con trỏ trỏ tới đó. Nhờ vậy bạn sửa file →
> `git commit` là xong, không phải copy qua lại. Một nguồn duy nhất.

### Cập nhật trên máy đã cài

```bash
cd ~/sway-config && git pull
```
Sau đó bấm `Mod+Shift+c` trong Sway để nạp lại config.

---

## 3. Khởi động Sway

- **Từ màn hình đăng nhập (GDM):** đăng xuất phiên hiện tại → ở góc dưới phải
  bấm biểu tượng bánh răng ⚙ → chọn **"Sway"** → đăng nhập.
- **Từ TTY:** chuyển sang một console (`Ctrl+Alt+F3`), đăng nhập rồi gõ:
  ```bash
  sway
  ```

Khi vào, bạn sẽ thấy nền màu trơn + thanh waybar trên cùng. Bấm `Mod+Enter`
mở terminal đầu tiên.

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
| `Mod+Shift+c` | Nạp lại config (reload) |
| `Mod+Shift+e` | Thoát Sway (có hỏi xác nhận) |
| `Mod+Shift+x` | Khóa màn hình ngay |

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
| `Mod+e` | Đổi qua lại split ngang/dọc |
| `Mod+f` | Bật/tắt **toàn màn hình** |
| `Mod+a` | Focus lên container cha |

### Cửa sổ nổi (floating) & scratchpad

| Phím | Hành động |
|---|---|
| `Mod+Shift+Space` | Bật/tắt chế độ nổi cho cửa sổ |
| `Mod+Space` | Chuyển focus giữa cửa sổ tiling ↔ floating |
| `Mod+Shift+-` | Cất cửa sổ vào **scratchpad** (ẩn) |
| `Mod+-` | Hiện cửa sổ trong scratchpad |

> **Scratchpad** = ngăn chứa ẩn. Cất một cửa sổ (vd terminal, máy tính) vào đó
> rồi gọi ra bất cứ workspace nào — tiện cho thứ dùng thoáng qua.

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
| `Print` | Chụp **toàn màn hình** → lưu `~/Pictures/screenshot-<thời gian>.png` |
| `Shift+Print` | Chọn **vùng** bằng chuột → copy vào clipboard |

---

## 5. Khái niệm cơ bản

- **Tiling:** cửa sổ tự xếp kín màn hình, không chồng lên nhau. Mở cửa sổ mới
  → màn hình tự chia ô.
- **Workspace:** 10 không gian làm việc ảo (`Mod+1..0`). Mỗi workspace chứa
  bộ cửa sổ riêng — gom việc theo nhóm (vd 1=code, 2=trình duyệt, 3=chat).
- **Layout:** cách sắp xếp các cửa sổ trong một vùng — chia đôi (split),
  xếp chồng (stacking), hoặc dạng tab (tabbed).
- **Floating:** cửa sổ "nổi" tự do như trên desktop thường (hợp cho hộp thoại,
  máy tính bỏ túi). Bật bằng `Mod+Shift+Space`.
- **Focus:** cửa sổ đang nhận bàn phím (viền sáng màu xanh). Đổi bằng
  `Mod+h/j/k/l`.

---

## 6. Từng thành phần & cách dùng

### foot (terminal) — `Mod+Enter`
Terminal nhẹ, native Wayland. Cấu hình: `.config/foot/foot.ini`
(font JetBrains Mono cỡ 11, theme Catppuccin, cuộn 10.000 dòng).

### rofi / wofi (launcher)
- `Mod+d` mở **rofi** → gõ tên app → `Enter` để mở. Có icon, có chế độ
  chuyển cửa sổ. Cấu hình: `.config/rofi/config.rasi`.
- `Mod+Shift+d` mở **wofi** (dự phòng, native Wayland).

### waybar (thanh trạng thái)
Hiện workspace (trái), tên cửa sổ (giữa), và bên phải: âm lượng, mạng, CPU,
RAM, pin, đồng hồ, khay hệ thống (tray). Cấu hình:
`.config/waybar/config` (nội dung) và `style.css` (giao diện).

### mako (thông báo)
Tự chạy. Thông báo hiện góc trên-phải, theme Catppuccin. Cấu hình:
`.config/mako/config`. Lệnh hữu ích: `makoctl dismiss` (đóng), `makoctl restore`.

### swaylock + swayidle (khóa màn hình)
- Khóa thủ công: `Mod+Shift+x`.
- Tự động (cấu hình trong `sway/config`): **5 phút** không hoạt động → khóa;
  **10 phút** → tắt màn hình; khi mở nắp/đánh thức → bật lại. Khi máy ngủ
  (suspend) cũng tự khóa.

### Chụp màn hình (grim + slurp)
- `Print`: lưu file PNG vào `~/Pictures`.
- `Shift+Print`: kéo chọn vùng → vào clipboard, dán bằng `Ctrl+V`.

---

## 7. Tùy biến

Mọi file nằm trong `~/sway-config/.config/` (đã symlink vào `~/.config`).
Sửa xong bấm `Mod+Shift+c` để áp dụng (riêng waybar/mako cần khởi động lại
tiến trình hoặc reload Sway).

| Muốn đổi | Sửa file |
|---|---|
| Phím tắt, layout, gaps, màu viền, autostart | `.config/sway/config` |
| Hình nền | dòng `output * bg ...` trong `sway/config` (đổi `#1e1e2e` thành `~/anh.png fill`) |
| Thời gian tự khóa màn hình | khối `exec swayidle ...` trong `sway/config` |
| Bố cục / module thanh trạng thái | `.config/waybar/config` |
| Màu sắc thanh trạng thái | `.config/waybar/style.css` |
| Giao diện rofi | `.config/rofi/config.rasi` |
| Font / màu terminal | `.config/foot/foot.ini` |
| Kiểu thông báo | `.config/mako/config` |

**Đặt hình nền ảnh thật:** trong `sway/config` đổi dòng
`output * bg #1e1e2e solid_color` thành:
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
| Phím tắt không ăn | `Mod+Shift+c` reload; xem log: `journalctl --user -b -u sway` hoặc chạy `swaymsg -t get_config` |
| Waybar không hiện | Chạy tay `waybar` trong terminal để đọc lỗi cú pháp JSON |
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
│   ├── waybar/config          # nội dung thanh trạng thái
│   ├── waybar/style.css       # giao diện thanh trạng thái
│   ├── rofi/config.rasi       # launcher chính
│   ├── wofi/config            # launcher dự phòng
│   ├── wofi/style.css
│   ├── foot/foot.ini          # terminal
│   └── mako/config            # thông báo
├── install.sh                 # cài package + tạo symlink
├── .gitignore
└── README.md                  # file này
```

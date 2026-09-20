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
| **nwg-dock** | Dock app dưới màn hình (đang tắt autostart) | chạy tay `~/.config/sway/scripts/dock.sh` |
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
| **nemo** | Trình quản lý file (Cinnamon, GTK3, hỗ trợ chuột/kéo-thả tốt) | `Mod+e` |
| **firefox** | Trình duyệt | từ launcher |
| **imv** | Xem ảnh | `imv <ảnh>` |
| **nm-applet** | WiFi / mạng (GUI ở khay) | icon khay |
| **blueman** | Bluetooth (GUI ở khay) | icon khay |
| **wob** | Thanh OSD volume/độ sáng | tự hiện khi chỉnh |
| **wf-recorder** | Quay màn hình | `Mod+Shift+r` |
| **zathura** | Đọc PDF | `zathura <file>` |
| **wlogout** | Menu nguồn toàn màn hình (dự phòng) | từ rofi (góc dưới phải) |
| **grimshot** | Chụp màn hình (kèm thông báo) | `Print` |
| **wayfreeze** | Đóng băng màn hình đúng lúc bấm phím chụp vùng | (nền) `Shift+Print`, `Mod+Print`, `Mod+Shift+s` |
| **kanshi / wdisplays** | Đa màn hình (tự sắp xếp / GUI) | tự chạy / từ launcher |
| **fcitx5 + unikey** | Bộ gõ tiếng Việt | `Ctrl+Space` để bật/tắt |
| **xremap** | Remap phím theo app (trình duyệt: `Ctrl+Shift+C` = copy) | (nền) |
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
| `Mod+e` | Mở file manager (Nemo, nổi 70% màn hình, căn giữa) |
| `Mod+Shift+c` | Nạp lại config (reload) |
| `Mod+e` | Đổi layout (splith) |
| `Mod+Shift+x` | Khóa màn hình ngay |
| `Mod+Shift+b` | Ẩn/hiện header (waybar) của **màn hình đang focus** — cửa sổ giãn kín màn |
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
| `Shift+Print` | Chọn **vùng** → copy vào clipboard (màn hình đóng băng lúc bấm) |
| `Mod+Print` | Chọn **vùng** → lưu file (màn hình đóng băng lúc bấm) |
| `Mod+Shift+s` | Chọn **vùng** → mở swappy để vẽ/sửa (màn hình đóng băng lúc bấm) |
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

#### Ẩn/hiện header riêng từng màn hình — `Mod+Shift+b`
Bấm `Mod+Shift+b` để ẩn header trên **màn đang focus** (các màn khác giữ nguyên); cửa
sổ trên màn đó giãn ra chiếm luôn chỗ header. Bấm lại để hiện. Khác `Mod+f` (fullscreen
một cửa sổ), phím này giữ nguyên bố cục tiling, chỉ lấy thêm chỗ.

- Waybar chỉ có 1 tiến trình vẽ bar trên mọi màn, và tín hiệu ẩn/hiện có sẵn của nó
  (`SIGUSR1`) tác động lên **tất cả** bar. Nên script `waybar-outputs.sh` giữ danh sách
  "màn ẩn header", ghi thành 1 config tạm trong `$XDG_RUNTIME_DIR` (key `output` dạng
  `["!DP-5", "*"]` + `include` config thật), rồi **khởi động lại waybar** với config đó.
  Không nạp lại bằng `SIGUSR2` được: waybar 0.9.24 nạp lại nhưng giữ giá trị cũ của key
  đã có, nên `output` chỉ đổi được đúng 1 lần.
- Mỗi lần bấm, waybar khởi động lại nên header ở màn còn lại biến mất chừng 0,05 giây
  rồi hiện lại (đo bằng vùng dành riêng của bar); các ô cảm biến có thể trống tới khoảng
  1 giây cho đến khi script của chúng chạy xong. Icon tray của app tự đăng ký lại.
- Trạng thái nằm ở `$XDG_RUNTIME_DIR` nên **đăng nhập lại là header hiện đủ** ở mọi màn;
  reload sway (`Mod+Shift+c`) thì giữ nguyên màn đang ẩn.
- Phím có `--no-repeat` (giữ phím lâu vẫn chỉ tính 1 lần) và script tự xếp hàng các lần
  bấm liên tiếp, nên không bị nhân đôi waybar.
- Waybar khởi động bằng `exec_always` trong `.config/sway/config` qua script này, **không**
  dùng khối `bar { swaybar_command ... }` vì sway chỉ nhận đúng 1 tên chương trình trần
  ở đó (không tham số, không mở rộng `~`). `.config/waybar/config` giữ nguyên, chạy tay
  `waybar` để debug vẫn như cũ.
- Cần `jq` (đã có trong `install.sh`). Tắt/bật một màn cụ thể từ terminal:
  `~/.config/sway/scripts/waybar-outputs.sh toggle DP-5` (không đối số = màn đang focus).

### nwg-dock (dock app tự ẩn)
Dock nằm dưới màn hình, mặc định ẩn để không chiếm diện tích. Rê chuột xuống đáy màn hình để dock trồi lên; rời chuột thì dock tự ẩn lại. Cấu hình: `.config/nwg-dock-hyprland/config.toml` và `style.css`. Script khởi động: `.config/sway/scripts/dock.sh`.

**Hiện đang tắt autostart** (dock không tự chạy lúc vào Sway) để giải phóng đáy màn hình. Để bật lại:
- Sửa `.config/sway/config` dòng `exec_always ~/.config/sway/scripts/dock.sh` (bỏ comment) rồi `Mod+Shift+c`.
- Hoặc chạy thủ công: `~/.config/sway/scripts/dock.sh`.

### mako (thông báo)
Tự chạy. Thông báo hiện góc trên-phải, theme Catppuccin. Cấu hình: `.config/mako/config`. Lệnh hữu ích: `makoctl dismiss` (đóng), `makoctl restore`.

### swaylock + swayidle (khóa màn hình)
- Khóa thủ công: `Mod+Shift+x` hoặc click nút khóa ở góc dưới phải Rofi.
- Tự động (cấu hình trong `sway/config`): **5 phút** không hoạt động → khóa; **10 phút** → tắt màn hình; khi mở nắp/đánh thức → bật lại. Khi máy ngủ (suspend) cũng tự khóa.

### Chụp màn hình (grim + slurp + wayfreeze)
- `Print`: lưu file PNG vào `~/Pictures` (chụp tức thời).
- `Shift+Print`: kéo chọn vùng → vào clipboard, dán bằng `Ctrl+V`.
- `Mod+Print`: kéo chọn vùng → lưu file. `Mod+Shift+s`: kéo chọn vùng → mở swappy để vẽ/sửa.

**Đóng băng lúc bấm phím.** `slurp` chỉ vẽ khung chọn lên màn hình đang chạy thật, còn ảnh chỉ
được chụp sau khi thả chuột — nên ảnh là khung hình lúc thả chuột, video/animation/chữ đang
stream đã trôi đi mất. Ba phím chọn vùng vì vậy chạy qua `screenshot-freeze.sh`: `wayfreeze`
chụp mọi màn hình ngay lúc bấm rồi phủ khung hình đó lên trên, `slurp` và `grim` chạy sau đó
thấy màn hình đứng yên; chụp xong thì rã đông.

- Bấm `Esc` (hoặc chuột phải) để huỷ chọn: màn hình tự rã đông. Bấm phím lần 2 khi lần 1 còn
  chạy thì bị bỏ qua.
- Lớp đóng băng che cả waybar và dock trong lúc chọn (bình thường); con trỏ được ẩn khỏi
  khung hình đóng băng để ảnh không có "con trỏ ma".
- `screenshot-edit.sh` (`Mod+Shift+s`) không còn hiện thông báo "Kéo chọn vùng..." như trước:
  thông báo hiện lên màn hình sẽ lọt vào chính bức ảnh. Ảnh được chụp vào file tạm rồi mới mở
  swappy sau khi rã đông (mở lúc đang đóng băng thì cửa sổ nằm dưới lớp đóng băng).
- `wayfreeze` không có trên apt/crates.io; `install.sh` cài từ GitHub bằng
  `cargo install --git https://github.com/Jappie3/wayfreeze --tag 0.2.1`. Chưa cài thì chụp
  vùng vẫn chạy như cũ, chỉ là không đóng băng.

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

### Remap phím theo app (xremap) — trình duyệt: `Ctrl+Shift+C` = copy
Bình thường trong trình duyệt `Ctrl+Shift+C` mở DevTools/inspector. Cấu hình này
đổi nó thành **copy** (Ctrl+C) — *chỉ khi trình duyệt (Chrome/Firefox) đang focus*;
terminal và app khác giữ nguyên. Làm được nhờ **xremap** đọc input ở tầng evdev và
hỏi sway xem app nào đang focus (sway bind phím toàn cục nên không tự làm được).

- Cấu hình quy tắc: `.config/xremap/config.yml` (đổi app / phím tại đây).
- Tự chạy nền qua `exec_always` trong `.config/sway/config`.
- **Cài một lần** (cần quyền đọc input): `sudo ~/.config/sway/scripts/install-xremap.sh`
  rồi **đăng xuất/đăng nhập lại** (để nhận group `input`). `install.sh` cũng tự gọi.
- Kiểm tra đang chạy: `pgrep -a xremap`. Xem tên app để khớp: `swaymsg -t get_tree`.

### App mở ở màn nào hiện ở màn đó (launch-pin)
Sway đặt cửa sổ mới lên màn đang **focus vào lúc cửa sổ hiện ra**, không phải lúc bạn
bấm mở. App khởi động chậm (Chrome, Discord, Electron...) hiện ra sau vài giây; nếu lúc
đó bạn đã rê chuột sang màn khác thì app nhảy sang màn đó. Script `launch-pin.py` sửa
việc này:

- Nó nhớ "màn nào có focus vào lúc nào". Khi có cửa sổ mới, nó xem app **được khởi động
  lúc nào** (chính là lúc bạn bấm mở) rồi chuyển cửa sổ về màn lúc đó. Mỗi app tự tra
  theo tiến trình của chính nó, nên mở nhiều app ở nhiều màn cùng lúc vẫn về đúng màn
  của từng app, dù app nào hiện ra trước.
- Không cần móc vào launcher nào: rofi, dock, gõ lệnh trong terminal, phím tắt đều được.
- Chuyển xong focus của bạn vẫn ở chỗ đang làm, app không cướp focus.
- Chỉ áp dụng cho app **vừa khởi động (≤ 45 giây)**. App đã chạy sẵn mở thêm cửa sổ
  (Chrome, nemo...) giữ hành vi cũ; loại này hiện ngay nên ít bị lệch màn. Đổi lại: nếu
  bạn bấm Ctrl+N trong một Chrome mới bật chưa tới 45 giây, ở màn khác, cửa sổ đó cũng
  bị kéo về màn lúc bật Chrome.
- Cửa sổ có thể chớp ở màn sai khoảng 0,1 giây trước khi được chuyển.
- Tự chạy nền qua `exec_always` trong `.config/sway/config`; script tự tắt bản cũ nên
  reload không bị chạy nhân đôi.
- Kiểm tra đang chạy: `pgrep -af launch-pin.py`. Xem nó quyết định gì:
  `LAUNCH_PIN_DEBUG=1 ~/.config/sway/scripts/launch-pin.py` (chạy foreground, `Ctrl+C`
  để dừng, rồi `swaymsg reload` để nó chạy nền lại).

> App mở bằng `exec` của sway (phím tắt trong `config`) được sway gắn sẵn
> `XDG_ACTIVATION_TOKEN`, nên app biết dùng token như `foot` tự nằm đúng màn. App do
> rofi / dock / terminal spawn thì không có token, đó mới là chỗ cần script này.

### Thanh tiêu đề / tab cửa sổ có icon từng app
Thanh tiêu đề chỉ hiện khi cửa sổ nằm trong layout **tabbed** (`Mod+w`) hoặc **stacking**
(`Mod+s`); layout thường dùng viền pixel (`default_border pixel 3`) nên không có thanh.

Kiểu "thanh tối + icon màu" (Catppuccin Mocha), cao **25px** (chữ cỡ 9, đệm dọc 4; bản cũ 31px):
cửa sổ đang focus = thanh sáng hơn (`#313244`) + viền xanh; cửa sổ khác = thanh tối, chữ mờ; cửa
sổ đang chọn của màn/nhóm khác = nền `#1e1e2e` + viền xám. Phía trước tên có icon, màu riêng từng app.

- Màu và cỡ chữ: các dòng `font`, `titlebar_padding`, `client.*` trong `.config/sway/config`.
- Icon: `.config/sway/window-icons.conf` (`include` từ config). Sway không vẽ được ảnh trong
  thanh tiêu đề nên đây là ký tự của JetBrainsMono Nerd Font, **không phải logo thật** (Claude
  dùng tia sáng, Antigravity dùng tên lửa). App chưa có rule dùng icon mặc định màu xám.
- Thêm app: mở app đó, xem `swaymsg -t get_tree | grep -E 'app_id|class'`, sao 1 khối trong
  `window-icons.conf`, đổi regex + icon (bảng glyph: nerdfonts.com/cheat-sheet), rồi `Mod+Shift+c`.
  Mỗi app cần 2 rule (`app_id` cho app Wayland, `class` cho app XWayland).
- Sway chỉ chạy `for_window` cho cửa sổ **mới mở**, nên `scripts/apply-window-icons.sh` (chạy
  bằng `exec_always`) áp lại rule icon lên cửa sổ đang mở mỗi lần reload: sửa icon xong
  `Mod+Shift+c` là thấy ngay, khỏi đóng/mở lại app.
- Cửa sổ nổi dùng viền pixel (`default_floating_border`) nên không có thanh tiêu đề, không có icon.
- Font `Inter` khai trong config **chưa được cài** trên máy này, sway tự rơi về Noto Sans. Muốn
  đúng ý gốc thì `sudo apt install fonts-inter`.

### Dark theme cho toàn hệ thống
- **GTK3/GTK4** (Thunar cũ, file-roller, ...): cấu hình trong `.config/gtk-3.0/settings.ini` và `.config/gtk-4.0/settings.ini` (đang dùng `Yaru-dark`, `gtk-application-prefer-dark-theme=1`).
- **libadwaita** (Nautilus, app GNOME mới): biến `GTK_THEME=Yaru-dark:dark` trong `.config/environment.d/theme.conf` ép dark dù theme gốc là light.
- **Qt5/Qt6** (foot, wofi, app Qt khác): `QT_STYLE_OVERRIDE=kvantum` trong cùng file. Chạy `qt5ct` / `qt6ct` một lần để chọn theme Kvantum-dark hoặc Adwaita-dark.

Các biến trong `environment.d/` chỉ có hiệu lực với **session mới** (logout/login hoặc reboot). Để test ngay trong Sway hiện tại:
```bash
export GTK_THEME=Yaru-dark:dark
export QT_STYLE_OVERRIDE=kvantum
swaymsg reload
```

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
| Header (waybar) biến mất ở một màn hình | Có thể đã bấm `Mod+Shift+b` (ẩn header màn đó): bấm lại để hiện. Nếu mất ở mọi màn: `pgrep -a waybar` xem còn chạy không, không thì `swaymsg reload` |
| Dock không hiện khi rê xuống đáy | Dock hiện **đang tắt autostart**. Chạy tay `~/.config/sway/scripts/dock.sh` để mở; nếu muốn bật lại vĩnh viễn, bỏ comment dòng `exec_always ~/.config/sway/scripts/dock.sh` trong `sway/config`. Nếu báo thiếu binary thì chạy `./install.sh` |
| Volume/độ sáng không đổi | Audio: `wpctl status` + xem user có trong group `audio` không. Độ sáng: `/sys/class/backlight/intel_backlight/brightness` thuộc group `video` — nếu `brightnessctl set 5%+` báo "Permission denied" thì chạy `sudo usermod -aG video $USER` rồi **logout/login lại**. `install.sh` tự thêm bước này từ lần cài sau |
| **App Electron (Discord, Postman...) giật khi cuộn/gõ** (máy Nvidia) | Electron chọn nhầm iGPU Intel làm render node → mỗi frame copy chéo GPU qua PCIe. `install.sh` tự quét và bọc desktop entry qua `sway/scripts/electron-gpu.sh` (ép render node Nvidia + ANGLE Vulkan). Cài app Electron mới thì chạy lại `./install.sh`. Kiểm tra: app phải xuất hiện trong `nvidia-smi` khi đang mở |
| Mở app ở màn 1, rê chuột sang màn 2 thì app hiện ở màn 2 | Do `launch-pin.py` chưa chạy hoặc app không thuộc diện ghim. Kiểm tra `pgrep -af launch-pin.py` (không thấy thì `swaymsg reload`). Chỉ ghim app **vừa khởi động ≤ 45 giây**; app đã chạy sẵn mở thêm cửa sổ thì giữ hành vi cũ. Xem lý do từng cửa sổ: `LAUNCH_PIN_DEBUG=1 ~/.config/sway/scripts/launch-pin.py` (xem mục "App mở ở màn nào hiện ở màn đó") |
| Chụp vùng không đóng băng màn hình | `command -v wayfreeze || ls ~/.cargo/bin/wayfreeze`: chưa cài thì chạy `./install.sh` (hoặc `cargo install --git https://github.com/Jappie3/wayfreeze --tag 0.2.1`). Không có nó thì chụp vùng vẫn chạy nhưng màn hình không đứng yên |
| Màn hình kẹt ở trạng thái đóng băng | Bấm `Esc` hoặc click để thoát; nếu vẫn kẹt: `pkill -x wayfreeze; pkill -x slurp` |
| Cửa sổ hiện icon mặc định (xám) hoặc không có icon | App đó chưa có rule: thêm vào `.config/sway/window-icons.conf` (xem mục "Thanh tiêu đề / tab cửa sổ có icon từng app"), rồi `Mod+Shift+c` là áp luôn lên cửa sổ đang mở |
| Không share được màn hình (Zoom/Meet) | Cài thêm `xdg-desktop-portal-wlr` |
| App GUI không xin được quyền admin | Kiểm tra polkit agent đang chạy: `pgrep -f polkit-gnome` |
| Nautilus (hoặc app libadwaita) vẫn sáng dù đã set dark | Biến `environment.d` chỉ nạp ở session mới — **đăng xuất rồi đăng nhập lại**. Hoặc test ngay: `export GTK_THEME=Yaru-dark:dark && swaymsg reload` |
| App Qt (foot, wofi, ...) không theo theme tối | Cài `qt5ct qt5-style-kvantum qt6ct adwaita-qt6`, chạy `qt5ct` một lần chọn theme Kvantum-dark hoặc Adwaita-dark, logout/login lại |
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
│   ├── sway/window-icons.conf # icon từng app trên thanh tiêu đề/tab (include từ sway/config)
│   ├── sway/scripts/          # vol.sh, bri.sh (OSD), record.sh (quay màn hình), rofi-focused.sh (điều khiển rofi), launch-pin.py (app mở ở màn nào hiện ở màn đó), waybar-outputs.sh (chạy waybar + ẩn/hiện header từng màn), screenshot-freeze.sh (đóng băng màn hình lúc chụp vùng), apply-window-icons.sh (áp icon tiêu đề lên cửa sổ đang mở)
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
│   ├── eww/                   # widget calendar/popup (CSS, yuck, scripts)
│   ├── environment.d/
│   │   ├── im.conf            # biến môi trường bộ gõ tiếng Việt
│   │   ├── cursor.conf        # theme con trỏ chuột
│   │   └── theme.conf         # dark theme libadwaita + Qt
│   └── gtk-{3,4}.0/settings.ini  # theme/icon/cursor GTK
├── install.sh                 # cài package + tạo symlink
├── .gitignore
└── README.md                  # file này
```

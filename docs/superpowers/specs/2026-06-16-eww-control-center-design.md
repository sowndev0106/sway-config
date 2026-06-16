# Thiết kế Eww Control Center cho Sway

Tài liệu thiết kế chi tiết (Design Specification) cho widget Bảng điều khiển nhanh (Control Center) được xây dựng bằng Eww (Elkowar's Wacky Widgets), tích hợp cùng Waybar và Sway WM.

---

## 1. Yêu cầu giao diện (UI/UX)
Giao diện được thiết kế mô phỏng chính xác ảnh tham khảo do người dùng cung cấp:
- **Tông màu:** Catppuccin Mocha đồng bộ với theme hiện tại.
- **Bố cục chính:** Dạng cửa sổ chữ nhật đứng bo góc (`16px`), nền tối mờ.
- **Cấu trúc:**
  - **Header:** Giờ số lớn, ngăn cách bằng dấu `|` (Ví dụ: `11|51`), bên dưới là thứ ngày tháng. Góc trên bên phải là icon mặt trăng (Do Not Disturb/Night Light status).
  - **Grid Toggles (3x2):** Các nút hình viên thuốc (capsule) được chia đôi bằng đường kẻ dọc mờ:
    - Bên trái: Icon trạng thái.
    - Bên phải: Dấu mũi tên `>`.
    - Phía dưới mỗi nút: Nhãn tên (Wi-Fi SSID, Bluetooth, Airplane, Night Light, Volume, Micro).
  - **Thanh trượt (Sliders):** Hai thanh trượt ngang có icon bên trái:
    - Thanh chỉnh âm lượng (Volume) màu xanh dương nhạt.
    - Thanh chỉnh độ sáng (Brightness) màu cam/đào nhạt.
  - **Footer:** 3 nút nguồn hình tròn ở góc dưới bên phải: Tắt máy (Power), Khởi động lại (Restart), Đăng xuất (Logout).

---

## 2. Vị trí và thông số cửa sổ (Geometry)
- **Tên cửa sổ:** `control-center-popup`
- **Neo màn hình (Anchor):** `top right`
- **Tọa độ:**
  - `x`: `16px` (cách lề phải)
  - `y`: `48px` (cách lề trên, ngay dưới thanh Waybar)
- **Kích thước:**
  - `width`: `360px`
  - `height`: `450px`
- **Thuộc tính:**
  - `stacking`: `overlay` (nổi lên trên các ứng dụng)
  - `focusable`: `true` (cho phép click và kéo slider)
  - `exclusive`: `false` (không đẩy cửa sổ khác)

---

## 3. Trạng thái và logic điều khiển (Toggles & Sliders Logic)

Dưới đây là các câu lệnh shell được sử dụng để lấy thông tin trạng thái (Poll/Script) và thực hiện hành động (onclick/onchange):

### A. Toggles

| Toggle | Icon | Câu lệnh lấy trạng thái (State) | Hành động khi Click nút chính (Toggle) | Hành động khi Click mũi tên `>` |
|---|---|---|---|---|
| **Wi-Fi** | `` | `nmcli -t -f ACTIVE,SSID dev wifi \| grep '^yes' \| cut -d: -f2` (Nếu trống hiển thị "Disconnected") | Bật/tắt card mạng Wi-Fi: `nmcli radio wifi` (on/off) | Mở cửa sổ cấu hình mạng: `nm-connection-editor &` |
| **Bluetooth** | `` | `bluetoothctl show \| grep -q 'Powered: yes'` | Bật/tắt nguồn Bluetooth bằng `bluetoothctl` | Mở cửa sổ quản lý Bluetooth: `blueman-manager &` |
| **Airplane** | `` | `rfkill list \| grep -q 'Blocked: yes'` | Bật/tắt chế độ máy bay: `rfkill block all` hoặc `rfkill unblock all` | Không có (hoặc mở rfkill GUI nếu cần) |
| **Night Light** | `` | `pgrep -x gammastep >/dev/null` | Bật/tắt `gammastep -O 4000 &` hoặc `pkill -x gammastep` | Không có |
| **Volume Mute** | `` | `wpctl get-volume @DEFAULT_AUDIO_SINK@ \| grep -q 'MUTED'` | Bật/tắt tắt âm loa: `wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle` | Mở ứng dụng trộn âm: `pavucontrol &` |
| **Micro Mute** | `` | `wpctl get-volume @DEFAULT_AUDIO_SOURCE@ \| grep -q 'MUTED'` | Bật/tắt tắt âm mic: `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle` | Mở ứng dụng trộn âm: `pavucontrol &` |

### B. Sliders

- **Âm lượng (Volume Slider):**
  - **Lấy giá trị:** `wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%.0f", $2*100}'` (Cập nhật liên tục 1 giây/lần hoặc dùng script theo dõi).
  - **Thay đổi giá trị:** `wpctl set-volume @DEFAULT_AUDIO_SINK@ {}%`
- **Độ sáng (Brightness Slider):**
  - **Lấy giá trị:** `brightnessctl -m | cut -d, -f4 | tr -d '%'`
  - **Thay đổi giá trị:** `brightnessctl set {}%`

### C. Cụm nút nguồn (Footer Power Actions)

- **Power Off:** `systemctl poweroff`
- **Reboot:** `systemctl reboot`
- **Logout:** `swaymsg exit`

---

## 4. Tích hợp Waybar
Khi người dùng click chuột trái vào mô-đun Mạng (`network`) hoặc Bluetooth (`bluetooth`) trên Waybar, thay vì mở trực tiếp các app cấu hình cũ, Waybar sẽ gọi script toggle:
```bash
~/.config/waybar/scripts/toggle-control-center.sh
```
Script này sẽ chịu trách nhiệm bật/tắt cửa sổ `control-center-popup` của Eww tương tự cách làm với Lịch (`calendar-popup`).

---

## 5. Kế hoạch triển khai (Implementation Plan)
1. **Bước 1:** Viết các script hỗ trợ lấy trạng thái và điều khiển Wi-Fi, Bluetooth, Airplane, Night Light, Volume, Brightness trong thư mục `~/.config/eww/scripts/`.
2. **Bước 2:** Cập nhật file `~/.config/eww/eww.yuck` để định nghĩa window `control-center-popup` and widget `control-center-card` với đầy đủ biến động (variables, defpoll) và layout lưới.
3. **Bước 3:** Thêm style SCSS cho Control Center vào `~/.config/eww/eww.scss` (sử dụng màu từ bảng màu Catppuccin Mocha có sẵn).
4. **Bước 4:** Tạo script toggler `~/.config/waybar/scripts/toggle-control-center.sh` để quản lý việc ẩn hiện Control Center.
5. **Bước 5:** Sửa file cấu hình `~/.config/waybar/config` để gán sự kiện click cho icon mạng và bluetooth.
6. **Bước 6:** Chạy thử nghiệm, kiểm tra giao diện và tinh chỉnh CSS để đảm bảo khớp 100% với ảnh gốc.

# Thiết kế: Control Center — Panel chi tiết tự dựng (thay app built-in)

**Ngày:** 2026-06-16
**Trạng thái:** Đã chốt, chờ lập plan

## Mục tiêu

Hiện tại các mũi tên `›` trong control center (eww popup) mở app GTK built-in
(`nm-connection-editor`, `blueman-manager`, `pavucontrol`) — xấu, lệch tông với
giao diện Catppuccin Mocha. Thay toàn bộ bằng **panel chi tiết tự dựng trong
eww**, đẹp và đồng bộ, các app ngoài chỉ còn là lối thoát "nâng cao" cho ca hiếm.

## Phạm vi

### Trong phạm vi
- Cơ chế "router view" trong 1 popup: home ⇄ các trang chi tiết, có nút Back.
- 5 panel chi tiết: **Wi-Fi, Bluetooth, Âm thanh (output + per-app), Micro,
  Mạng dây**.
- Bỏ mũi tên `›` ở ô **Airplane** (không có chi tiết ý nghĩa).
- Nút "Cài đặt nâng cao…" ở mỗi panel mở app ngoài tương ứng.
- Tách script theo module, nạp danh sách theo yêu cầu (không poll liên tục).
- Style Catppuccin Mocha đồng bộ card hiện có.

### Ngoài phạm vi (mở rộng tương lai)
- **Media player** (playerctl): play/pause/next, tên bài, artwork. Để v2.
- Cấu hình VPN / IP tĩnh / kênh BT nâng cao → vẫn dùng app ngoài qua "nâng cao".
- Quản lý profile âm thanh (HDMI/analog) → pavucontrol.

## Kiến trúc

### Router view trong popup
- Thêm biến trạng thái:
  - `(defvar cc_view "home")` — giá trị: `home` | `wifi` | `bluetooth` |
    `audio` | `mic` | `wired`.
  - `(defvar cc_pass "")` — đệm mật khẩu Wi-Fi đang nhập.
  - `(defvar cc_pass_ssid "")` — SSID đang chờ nhập mật khẩu (mở ô input cho đúng hàng).
- `control-center-card` chọn nội dung theo `cc_view` (dùng biểu thức điều kiện
  hoặc widget bao). Home = layout hiện tại; mỗi view khác = `(<panel>-page)`.
- Mũi tên `›` đổi từ mở app → `eww update cc_view=<tên>` (+ nạp danh sách lần đầu).
- Nút `‹ Back` mỗi panel: `eww update cc_view=home`.
- **Reset khi mở popup:** `toggle-control-center.sh` chạy `eww update cc_view=home
  cc_pass="" cc_pass_ssid=""` TRƯỚC khi `open` popup, để luôn mở ở trang home.

### Cửa sổ & geometry
- Popup giữ `:stacking "overlay" :focusable false`; closer giữ `:stacking
  "foreground"`; thứ tự mở popup-trước-closer **giữ nguyên** (xem
  `[[eww-popup-closer-order]]`).
- **Chiều cao động:** trang chi tiết (danh sách) cao hơn home. Bỏ `:height` cố
  định "450px" của popup, để eww tự co theo nội dung (hoặc đặt chiều cao đủ lớn
  cố định ~520px và panel dùng `scroll` khi danh sách dài). Quyết định: dùng
  widget `(scroll :vscroll true)` bọc danh sách, chiều cao popup cố định để bố
  cục ổn định, danh sách dài thì cuộn.

### Tách script (mỗi file một việc)
Thư mục mới `.config/eww/scripts/cc/`:
- `wifi.sh`     — `list` (in JSON mạng), `connect <ssid>`, `connect-pass <ssid>
  <pass>`, `disconnect`, `toggle`, `rescan`.
- `bluetooth.sh`— `list` (JSON thiết bị), `connect <mac>`, `disconnect <mac>`,
  `toggle`, `scan-on`, `scan-off`.
- `audio.sh`    — `sinks` (JSON thiết bị ra), `set-sink <id>`, `apps` (JSON
  per-app volume), `set-app-vol <id> <pct>`.
- `mic.sh`      — `sources` (JSON thiết bị thu), `set-source <id>`,
  `level`/`set-level`.
- `wired.sh`    — `info` (JSON: state, ip, gateway, speed), `toggle`.
- `control_center.sh` hiện tại: giữ nguyên phần home (toggle nhanh, slider,
  refresh). Các lệnh `wifi-toggle`/`bt-toggle`/… ở home gọi sang module mới để
  không trùng logic (hoặc giữ nguyên, module mới chỉ lo danh sách — chọn: module
  mới là nguồn chân lý, `control_center.sh` gọi lại).

### Dữ liệu: nạp theo yêu cầu, KHÔNG poll liên tục
Lệnh quét Wi-Fi/Bluetooth nặng và chậm; poll nền khi popup đóng là lãng phí
(bài học từ fix "chậm" trước). Quy tắc:
- Danh sách lưu trong defvar (`wifi_list`, `bt_list`, `audio_sinks`,
  `audio_apps`, `mic_sources`, `wired_info`), KHÔNG phải defpoll.
- Cập nhật danh sách khi: (a) bấm `›` vào panel, (b) bấm nút ⟳ rescan, (c) sau
  một thao tác (connect/disconnect) để phản ánh ngay — qua `eww update`.
- Trạng thái bật/tắt nhanh ở home vẫn dùng defpoll như hiện tại (nhẹ).
- Wi-Fi/BT scan: bật scan khi vào panel, hiện spinner trong lúc quét, rồi đổ
  danh sách. Có thể auto-refresh mỗi ~5s **chỉ khi** đang ở panel đó (gắn poll
  có điều kiện qua `:interval` + kiểm tra `cc_view`, hoặc một vòng lặp script
  ngắn). Quyết định: đơn giản trước — nạp khi vào + nút ⟳ thủ công; auto-refresh
  để sau nếu thấy cần.

## Chi tiết từng panel

Bố cục chung mỗi panel: hàng header (`‹ Back` | tiêu đề | ⟳ nếu có), nội dung
(scroll), chân "Cài đặt nâng cao…".

### Wi-Fi (`cc_view = wifi`)
- Header: Back, "Wi-Fi", ⟳ rescan.
- Hàng công tắc Wi-Fi on/off (tái dùng `wifi_state`).
- Danh sách mạng từ `wifi.sh list` → JSON mảng `{ssid, signal, secured,
  active}`. Mỗi hàng: icon sóng theo `signal` (4 mức), tên, ổ khóa nếu
  `secured`, dấu ● nếu `active`.
  - Bấm mạng **đã biết / đang nối** → connect/disconnect ngay.
  - Bấm mạng **mới + secured** → mở ô `input` mật khẩu ngay dưới hàng đó
    (`cc_pass_ssid` = ssid), `input :onchange "eww update cc_pass={}"`, nút
    "Nối" chạy `wifi.sh connect-pass <ssid> <pass>` rồi nạp lại danh sách.
  - Bấm mạng **mới + mở** → `wifi.sh connect <ssid>`.
- Chân: "Cài đặt nâng cao…" → `nm-connection-editor`.

### Bluetooth (`cc_view = bluetooth`)
- Header: Back, "Bluetooth", ⟳ scan.
- Công tắc BT on/off (tái dùng `bt_state`).
- Vào panel: `bluetooth.sh scan-on`; rời panel/Back: `scan-off` (tiết kiệm pin).
- Danh sách từ `bluetooth.sh list` → JSON `{mac, name, icon, connected,
  paired, battery?}`. Hàng: icon loại thiết bị, tên, pin% nếu có, trạng thái.
  - Bấm → connected thì `disconnect <mac>`, chưa thì `connect <mac>` (tự pair
    nếu chưa paired).
- Chân: "Nâng cao…" → `blueman-manager`.

### Âm thanh (`cc_view = audio`, mở từ `›` ô Volume)
- Header: Back, "Âm thanh".
- **Thiết bị ra:** danh sách sink từ `audio.sh sinks` → `{id, name, default}`.
  Bấm → `audio.sh set-sink <id>` (đổi sink mặc định), đánh dấu ● cái đang dùng.
- **Âm lượng tổng:** thanh trượt (tái dùng `vol_level` + `set-vol`).
- **Âm lượng từng app:** `audio.sh apps` → `{id, name, icon, volume}` (từ
  `pactl list sink-inputs`). Mỗi app: icon/tên + slider →
  `audio.sh set-app-vol <id> {}`.
- Chân: "Nâng cao…" → `pavucontrol`.

### Micro (`cc_view = mic`, mở từ `›` ô Mic)
- Header: Back, "Micro".
- **Thiết bị thu:** danh sách source từ `mic.sh sources` → bấm để đổi mặc định.
- **Mức micro:** slider `mic.sh level` / `set-level`; nút mute (tái dùng
  `mic_muted`/`mic-toggle`).
- Chân: "Nâng cao…" → `pavucontrol`.

### Mạng dây (`cc_view = wired`, mở từ `›` ô Mạng dây)
- Header: Back, "Mạng dây".
- `wired.sh info` → `{state, device, ip, gateway, speed}`. Hiển thị card thông
  tin gọn (trạng thái, thiết bị `enp1s0`, IP, gateway, tốc độ).
- Nút Connect/Disconnect (tái dùng `wired-toggle`).
- Chân: "Nâng cao…" → `nm-connection-editor`.

## Định dạng dữ liệu (hợp đồng giữa script và yuck)

Mọi lệnh `list`/`sinks`/`apps`/… in **một dòng JSON** (eww `defvar` + `for`
lặp). Ví dụ `wifi.sh list`:
```json
[{"ssid":"MyHome","signal":78,"secured":true,"active":true},
 {"ssid":"Cafe","signal":40,"secured":true,"active":false}]
```
Script tự lọc dòng rác: SSID rỗng với Wi-Fi; với mạng dây bỏ `veth*`/`docker0`/
bridge (tái dùng quy tắc lọc ethernet đã có trong lệnh `wired-state` của
`control_center.sh`). Lỗi/không có dữ liệu → in `[]`.

## Style (CSS)

- Thêm các class panel vào `eww.css` (CSS thuần, **không SCSS** — GTK CSS không
  hỗ trợ nesting/biến; xem lịch sử repo). Bảng màu Catppuccin Mocha hardcode hex
  như phần hiện có.
- Thành phần: `.cc-page`, `.cc-page-header`, `.cc-back-btn`, `.cc-rescan-btn`,
  `.cc-list`, `.cc-list-row` (bo góc 12px, hover `#313244`, hàng active viền/nền
  xanh `#89b4fa`), `.cc-signal`, `.cc-lock`, `.cc-battery`, `.cc-pass-input`,
  `.cc-advanced-btn`, `.app-vol-row`.
- Hiệu ứng: hover mượt; (transition GTK nếu hỗ trợ).

## Xử lý lỗi & ca biên

- Thiết bị/dịch vụ vắng (không có card BT, không sink) → panel hiện thông báo
  "Không tìm thấy…" thay vì lỗi; script in `[]`.
- Wi-Fi đang tắt → panel chỉ hiện công tắc + gợi ý bật, không quét.
- Nhập sai mật khẩu Wi-Fi → `nmcli` báo lỗi; bắt mã trả về, hiện "Sai mật khẩu",
  xoá kết nối hỏng (`nmcli connection delete`), cho nhập lại.
- Thao tác chậm (connect): hiện trạng thái "Đang nối…" tạm thời.
- Mọi script `set -euo pipefail`, lệnh có thể fail bọc `|| true` đúng chỗ.

## Kiểm thử (thủ công — dotfiles, không có suite)

- `eww reload` parse sạch; mở popup không lỗi.
- Mô phỏng chuột (`swaymsg "seat - cursor set X Y"` + press/release) để bấm `›`,
  chụp `grim` xác minh từng panel render; bấm Back về home.
- Từng lệnh script chạy tay trả JSON hợp lệ (`| jq .`).
- Test thật: đổi sink, đổi mạng Wi-Fi đã lưu, connect/disconnect BT.
- Lưu ý mô phỏng chuột chập chờn (cần `cursor set` rồi mới press) — xem
  `[[eww-popup-closer-order]]`.

## Quyết định đã chốt

1. Kiểu mở rộng: **trang chi tiết đẩy-trang** (không accordion / side-drawer).
2. Panel: Wi-Fi, Bluetooth, Âm thanh (output + per-app), Micro, Mạng dây.
3. App ngoài: **giữ link "Nâng cao…"** ở mỗi panel.
4. Media player: **ngoài v1**.
5. Nạp danh sách **theo yêu cầu**, không poll nền.

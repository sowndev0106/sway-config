# Thiết kế: Menu eww bật/tắt cảm biến waybar

Ngày: 2026-06-17

## Mục tiêu

Cho phép người dùng **bật/tắt từng mục** trong cụm cảm biến trên waybar (Nhiệt
độ, CPU %, Xung nhịp, Công suất, RAM) thông qua một **popup eww có toggle
switch**, mở ra khi bấm vào bất kỳ ô nào đang hiện trong cụm. Trạng thái được
lưu bền qua reload/reboot.

## Bối cảnh

- Cụm cảm biến hiện ở `modules-left`: `temperature`, `cpu` (đã gộp CPU % +
  `{avg_frequency}GHz`), `custom/cpu-power`, `memory` — nối liền thành 1 pill
  (bo góc 2 đầu trong `style.css`).
- Repo đã có hệ eww đầy đủ: `eww.yuck`, `eww.css`, các popup
  `control-center-popup` + `control-center-popup-closer`, dò monitor focus qua
  `swaymsg -t get_outputs`. Sẽ tái dùng đúng pattern này.
- Tín hiệu refresh waybar: dùng signal real-time `pkill -RTMIN+8 -x waybar`
  (KHÔNG dùng `pkill -f waybar` — sẽ tự giết shell; dùng `-x` khớp đúng tên).

## Ràng buộc kỹ thuật quyết định kiến trúc

waybar **không ẩn/hiện module gốc lúc đang chạy**. Vì vậy 3 module gốc
(`temperature`, `cpu`, `memory`) phải được **viết lại thành module custom**.
Một module custom **tự ẩn khi script in ra chuỗi rỗng** — đây là cơ chế ẩn/hiện.

## Quyết định đã chốt

- 5 mục toggle độc lập: `temp`, `cpu`, `freq`, `power`, `ram`.
- Menu = eww popup với toggle switch, khớp thẩm mỹ control-center (Catppuccin Mocha).
- Bấm vào **bất kỳ ô đang hiện** trong cụm → mở popup.
- **Không cho ẩn hết** — luôn giữ tối thiểu 1 mục bật (nếu không sẽ không còn ô
  nào để bấm mở lại menu).
- Trạng thái lưu bền; mặc định lần đầu: **bật hết 5 mục**.
- Bọc cả cụm trong waybar **`group`** và bo góc cho container `group`, để góc
  pill luôn đúng dù ẩn ô đầu/cuối.
- **Hover xem nhanh:** rê chuột vào ô bất kỳ → tooltip waybar gốc hiện một popup
  nhỏ liệt kê **đủ cả 5 giá trị** (kể cả mục đang ẩn khỏi bar).

## Kiến trúc

### 1. File trạng thái
`~/.config/waybar/sensors.state` — dạng `key=on|off`, 5 khoá `temp cpu freq
power ram`. Nếu thiếu file/khoá → mặc định `on`.

### 2. Helper `~/.config/waybar/scripts/sensors-toggle.sh`
- `get <key>` → in `on`/`off` (đọc file, mặc định `on`).
- `toggle <key>` → lật trạng thái; **từ chối tắt nếu đó là mục `on` cuối cùng**
  (giữ ≥1); ghi file; `pkill -RTMIN+8 -x waybar` để bar cập nhật tức thì.
- `enabled <key>` → exit 0 nếu `on`, exit 1 nếu `off` (tiện cho script hiển thị).

### 3. Năm script hiển thị (mỗi module custom 1 script)
Mỗi script: nếu mục `off` → in chuỗi rỗng cho `text` (ẩn ô); nếu `on` → in nội
dung. **Mọi script đều dùng `return-type: json`** để mang trường `tooltip`.

**Tooltip "xem nhanh tất cả":** một helper chung `sensors-readall.sh` in đủ 5
dòng (nhiệt độ, CPU %, xung nhịp, công suất, RAM) dạng Pango markup. Mỗi script
hiển thị nhét kết quả này vào trường `tooltip` của JSON — nên hover vào BẤT KỲ ô
nào (kể cả khi các mục khác đang ẩn) đều thấy đủ 5 giá trị. Ô đang ẩn (`text`
rỗng) không bắt được hover, nhưng chỉ cần ≥1 ô hiện là có chỗ hover.
- `sensor-temp.sh` — đọc `thermal_zone9` (x86_pkg_temp), in JSON `{text,class,tooltip}`
  với `class="critical"` khi ≥85°C (giữ behavior module gốc), icon theo ngưỡng.
- `sensor-cpu.sh` — CPU % (đọc `/proc/stat` lấy delta, hoặc `top -bn1`/`mpstat`).
- `sensor-freq.sh` — xung nhịp trung bình các nhân từ
  `/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq`, in `<x.xx>GHz`.
- `cpu-power.sh` — đã tồn tại; thêm phần gate `enabled power` ở đầu.
- `sensor-ram.sh` — % RAM dùng (từ `/proc/meminfo`: `(Total-Available)/Total`).

Mỗi script là module custom có `"return-type"` phù hợp (`json` cho temp,
mặc định cho phần còn lại), `"signal": 8`, `"interval"` hợp lý (2–5s),
`"on-click"` mở popup.

### 4. Module waybar (`.config/waybar/config`)
- Thay `temperature`, `cpu`, `memory` (gốc) bằng `custom/sensor-temp`,
  `custom/sensor-cpu`, `custom/sensor-freq`, `custom/sensor-ram`; giữ
  `custom/cpu-power`.
- Bọc tất cả trong một `group/sensors` (module `group`) đặt trong `modules-left`
  thay cho danh sách phẳng hiện tại.
- `on-click` của mỗi sensor module: `~/.config/waybar/scripts/toggle-sensors-menu.sh`.

### 5. Popup eww
- `defwindow sensors-popup [monitor]` + `defwindow sensors-popup-closer [monitor]`
  (theo đúng pattern control-center; **mở popup TRƯỚC rồi mới closer** để closer
  không nuốt click — theo lưu ý đã biết của repo).
- `defwidget sensors-card`: 5 hàng, mỗi hàng = nhãn + mô tả ngắn + toggle
  switch. Switch gọi `sensors-toggle.sh toggle <key>` rồi đóng popup hoặc cập
  nhật biến poll.
- Trạng thái phản ánh qua `defpoll` đọc `sensors-toggle.sh get <key>` (interval
  ngắn) hoặc `defvar` cập nhật khi mở.
- Script mở/đóng: `~/.config/waybar/scripts/toggle-sensors-menu.sh` (sao theo
  `toggle-control-center.sh`: dò `EWW_BIN`, monitor focus, đóng nếu đang mở).

### 6. CSS
- `.config/waybar/style.css`: chuyển bo góc/màu nền từ từng ô sang container
  `#sensors` (hoặc selector group), bỏ bo góc 2 đầu trên các ô con. Giữ màu chữ
  riêng từng ô (peach/yellow/green/mauve…).
- `.config/eww/eww.css`: style cho `sensors-card` và toggle switch, đồng bộ
  control-center.

## Luồng dữ liệu

```
Bấm ô cảm biến → toggle-sensors-menu.sh → mở sensors-popup
   → người dùng bật/tắt switch → sensors-toggle.sh toggle <key>
      → ghi sensors.state → pkill -RTMIN+8 -x waybar
         → script hiển thị đọc lại state → in nội dung hoặc rỗng → ô ẩn/hiện
```

## Xử lý lỗi / biên

- Thiếu file state → coi như tất cả `on`.
- Cố tắt mục `on` cuối cùng → bỏ qua, không đổi state (UI có thể chặn switch
  cuối hoặc đơn giản là không phản hồi).
- `energy_uj` chưa cấp quyền → `cpu-power.sh` vẫn in `N/A` như hiện tại.
- eww chưa chạy/không có binary → script thoát êm như `toggle-control-center.sh`.

## Kiểm thử (thủ công — đây là dotfiles)

1. Bật/tắt từng mục → ô tương ứng ẩn/hiện ngay, pill vẫn bo góc đúng.
2. Tắt dần đến mục cuối → switch cuối không tắt được, luôn còn ≥1 ô.
3. `swaymsg reload` và reboot → trạng thái giữ nguyên.
4. Nhiệt độ ≥85°C → ô temp đổi sang class `critical` (màu đỏ) như trước.
5. Bấm ô bất kỳ đang hiện → popup mở; bấm ra ngoài (closer) → đóng.
6. Hover vào ô bất kỳ → tooltip hiện đủ 5 giá trị, kể cả mục đang ẩn.

## Ngoài phạm vi (YAGNI)

- Không thêm phím tắt Sway mở menu (đã chọn bấm-vào-ô).
- Không thêm cảm biến mới (GPU, mạng…).
- Không cấu hình interval/màu qua menu — chỉ ẩn/hiện.

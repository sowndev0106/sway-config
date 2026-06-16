# Eww Calendar Popup Implementation Plan (Mockup Design)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triển khai một popup lịch Eww cao cấp khớp chính xác với hình ảnh thiết kế người dùng cung cấp (bao gồm đồng hồ số lớn ở đầu, dòng điều hướng tháng/năm, lưới lịch bắt đầu bằng Chủ Nhật và hiển thị các ngày đệm dạng số từ tháng trước/sau).

**Architecture:** Popup lịch Eww sẽ được tải động và hiển thị ở giữa phía trên màn hình đang hoạt động. Nó gồm 3 phần: Phần đồng hồ lớn ở đầu cập nhật mỗi giây, phần chọn tháng/năm có các nút điều hướng gọi script điều hướng, và lưới lịch 6x7 bắt đầu bằng Chủ Nhật sinh bởi script bash.

**Tech Stack:** Sway, Waybar, Eww, Bash, `date`, `swaymsg`, `jq`, GTK SCSS, Catppuccin Mocha theme.

---

## File Structure

- Modify: `.config/eww/scripts/calendar-data.sh`
  - Đổi thuật toán sang Chủ Nhật làm đầu tuần. Sinh ngày đệm là số thật của tháng cũ/mới (thay vì chuỗi rỗng). Nhận đối số `month` và `year`.
- Create: `.config/eww/scripts/navigate.sh`
  - Script thực hiện cộng/trừ tháng hoặc năm hiện tại trên Eww và tải lại dữ liệu lịch tương ứng.
- Modify: `.config/eww/eww.yuck`
  - Định nghĩa các biến `calendar_month`, `calendar_year`, `calendar_json` và các poll lấy giờ phút ngày tháng. Dựng widget `calendar-card` với các nút điều hướng.
- Modify: `.config/eww/eww.scss`
  - Thiết kế CSS hoàn chỉnh khớp với mockup (đồng hồ lớn, nút điều hướng, màu sắc Catppuccin, font chữ, hover).
- Modify: `.config/waybar/scripts/toggle-calendar.sh`
  - Reset trạng thái hiển thị của Eww về tháng/năm hiện tại mỗi khi mở popup.

---

### Task 1: Update Calendar Data Generator

**Files:**
- Modify: `.config/eww/scripts/calendar-data.sh`

- [ ] **Step 1: Thay đổi script dữ liệu lịch**
Chuyển đổi logic sang Chủ Nhật làm đầu tuần và hiển thị số của ngày đệm tháng trước/sau.
Sử dụng mã nguồn sau:

```bash
#!/usr/bin/env bash
# Script sinh dữ liệu lịch dạng JSON (bắt đầu bằng Chủ Nhật, hiển thị ngày đệm).
set -euo pipefail

# Lấy thời gian thực tại của hệ thống
read -r real_year real_month real_day < <(date "+%Y %m %d")
real_day=$((10#$real_day))

# Nhận đối số hoặc mặc định là tháng/năm hiện tại
month="${1:-$real_month}"
year="${2:-$real_year}"

# Bỏ số 0 ở đầu để tránh lỗi bát phân (octal error)
month=$((10#$month))
year=$((10#$year))

# Lấy tên tháng (tiếng Anh) dưới dạng LC_TIME=C (ví dụ: "August")
month_name=$(LC_TIME=C date -d "$year-$month-01" +"%B")

# Thứ của ngày đầu tiên trong tháng (0 = Chủ Nhật, 1 = Thứ Hai, ..., 6 = Thứ Bảy)
first_day_weekday=$(date -d "$year-$month-01" +%w)

# Số ngày trong tháng hiển thị
days_in_month=$(date -d "$year-$month-01 +1 month -1 day" +%d)
days_in_month=$((10#$days_in_month))

# Số ngày đệm đầu tháng (padding_start) từ tháng trước
padding_start=$first_day_weekday

# Tính tháng trước và năm trước tương ứng để lấy số ngày
prev_month=$((month - 1))
prev_year=$year
if [ "$prev_month" -eq 0 ]; then
    prev_month=12
    prev_year=$((year - 1))
fi
days_in_prev_month=$(date -d "$prev_year-$prev_month-01 +1 month -1 day" +%d)
days_in_prev_month=$((10#$days_in_prev_month))

# Khởi tạo chuỗi JSON danh sách ngày
days_json="["

# Thêm các ngày đệm từ cuối tháng trước (được đánh dấu muted: true)
start_pad_day=$((days_in_prev_month - padding_start + 1))
for ((i=0; i<padding_start; i++)); do
    d_val=$((start_pad_day + i))
    days_json+="{\"label\": \"$d_val\", \"today\": false, \"muted\": true},"
done

# Thêm các ngày trong tháng hiện tại
for ((d=1; d<=days_in_month; d++)); do
    is_today="false"
    if [ "$year" -eq "$real_year" ] && [ "$month" -eq "$real_month" ] && [ "$d" -eq "$real_day" ]; then
        is_today="true"
    fi
    days_json+="{\"label\": \"$d\", \"today\": $is_today, \"muted\": false},"
done

# Tính số ngày đệm cuối tháng để tạo lưới 6 tuần = 42 ô
padding_end=$((42 - padding_start - days_in_month))

# Thêm các ngày đệm từ đầu tháng sau (được đánh dấu muted: true)
for ((i=1; i<=padding_end; i++)); do
    days_json+="{\"label\": \"$i\", \"today\": false, \"muted\": true},"
done

# Bỏ dấu phẩy thừa ở cuối và đóng mảng
days_json="${days_json%,}]"

# Mảng các thứ trong tuần (Bắt đầu bằng Chủ Nhật)
weekdays_json='["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]'

# Tạo JSON cấu trúc hoàn chỉnh bằng jq
jq -n \
  --arg month_name "$month_name" \
  --argjson weekdays "$weekdays_json" \
  --argjson days "$days_json" \
  '{
    month_name: $month_name,
    weekdays: $weekdays,
    weeks: [range(0; ($days | length); 7) as $i | $days[$i:$i+7]]
  }'
```

- [ ] **Step 2: Đảm bảo quyền thực thi**
Chạy:
```bash
chmod +x .config/eww/scripts/calendar-data.sh
```

- [ ] **Step 3: Chạy thử và xác thực JSON**
Chạy:
```bash
.config/eww/scripts/calendar-data.sh | jq empty
.config/eww/scripts/calendar-data.sh 8 2022 | jq .month_name
```
Expected: Lệnh đầu tiên trả về exit code `0`. Lệnh thứ hai trả về `"August"`.

---

### Task 2: Create Navigation Script

**Files:**
- Create: `.config/eww/scripts/navigate.sh`

- [ ] **Step 1: Tạo script điều hướng**
Script này thay đổi tháng/năm trên Eww và nạp lại lịch mới.
Sử dụng mã nguồn sau:

```bash
#!/usr/bin/env bash
# Kịch bản điều hướng lịch Eww (thay đổi tháng/năm).
set -euo pipefail

EWW_BIN="${EWW_BIN:-$HOME/.local/bin/eww}"
if [ ! -x "$EWW_BIN" ]; then
    EWW_BIN="$(command -v eww)"
fi

CONFIG_DIR="$HOME/.config/eww"

# Nhận tham số: target (month/year) và action (prev/next)
TARGET="$1"
ACTION="$2"

# Lấy giá trị hiện tại từ Eww
month=$("$EWW_BIN" --config "$CONFIG_DIR" get calendar_month)
year=$("$EWW_BIN" --config "$CONFIG_DIR" get calendar_year)

# Ép kiểu số nguyên
month=$((10#$month))
year=$((10#$year))

if [ "$TARGET" = "month" ]; then
    if [ "$ACTION" = "prev" ]; then
        month=$((month - 1))
        if [ "$month" -eq 0 ]; then
            month=12
            year=$((year - 1))
        fi
    elif [ "$ACTION" = "next" ]; then
        month=$((month + 1))
        if [ "$month" -eq 13 ]; then
            month=1
            year=$((year + 1))
        fi
    fi
elif [ "$TARGET" = "year" ]; then
    if [ "$ACTION" = "prev" ]; then
        year=$((year - 1))
    elif [ "$ACTION" = "next" ]; then
        year=$((year + 1))
    fi
fi

# Cập nhật ngược lại các biến trong Eww
"$EWW_BIN" --config "$CONFIG_DIR" update calendar_month="$month"
"$EWW_BIN" --config "$CONFIG_DIR" update calendar_year="$year"

# Tải lại dữ liệu JSON mới cho lưới lịch hiển thị
NEW_DATA=$("$CONFIG_DIR/scripts/calendar-data.sh" "$month" "$year")
"$EWW_BIN" --config "$CONFIG_DIR" update calendar_json="$NEW_DATA"
```

- [ ] **Step 2: Phân quyền thực thi**
Chạy:
```bash
chmod +x .config/eww/scripts/navigate.sh
```

- [ ] **Step 3: Kiểm tra cú pháp script**
Chạy:
```bash
bash -n .config/eww/scripts/navigate.sh
```
Expected: exit code `0`.

---

### Task 3: Update Eww Layout Config

**Files:**
- Modify: `.config/eww/eww.yuck`

- [ ] **Step 1: Định nghĩa cấu trúc eww.yuck mới**
Thay thế nội dung `.config/eww/eww.yuck` bằng giao diện đầy đủ có đồng hồ lớn và thanh điều hướng:

```scheme
;; Biến lưu trữ dữ liệu JSON lịch
(defvar calendar_json "{}")

;; Biến trạng thái năm và tháng hiển thị trên UI
(defvar calendar_month "")
(defvar calendar_year "")

;; Poll lấy giờ, phút và ngày tháng hiện tại cho phần Header
(defpoll time_hour :interval "1s" "date +%H")
(defpoll time_min  :interval "1s" "date +%M")
(defpoll time_date :interval "10s" "LC_TIME=C date '+%A, %d %B'")

;; Cửa sổ Calendar Popup hiển thị trên màn hình hiện tại
(defwindow calendar-popup [monitor]
  :monitor monitor
  :geometry (geometry
    :x "0px"
    :y "45px"
    :width "360px"
    :height "480px"
    :anchor "top center")
  :stacking "overlay"
  :exclusive false
  :focusable "none"
  :namespace "eww-calendar-popup"
  (calendar-card))

;; Widget chính của lịch
(defwidget calendar-card []
  (box :class "calendar-card" :orientation "vertical" :space-evenly false
    ;; ── Phần 1: Header hiển thị Đồng hồ số lớn & Ngày tháng ──
    (box :class "header-box" :orientation "vertical" :space-evenly false
      (box :class "clock-box" :orientation "horizontal" :space-evenly false :halign "center"
        (label :class "clock-time" :text time_hour)
        (label :class "clock-separator" :text "|")
        (label :class "clock-time" :text time_min))
      (label :class "clock-date" :text time_date))

    ;; ── Phần 2: Điều hướng Tháng và Năm ──
    (box :class "nav-box" :orientation "horizontal" :space-evenly true
      ;; Chọn tháng
      (box :class "selector-box" :orientation "horizontal" :space-evenly false :halign "center"
        (button :class "nav-btn" :onclick "~/.config/eww/scripts/navigate.sh month prev" "‹")
        (label :class "nav-label month" :text {calendar_json.month_name ?: ""})
        (button :class "nav-btn" :onclick "~/.config/eww/scripts/navigate.sh month next" "›"))
      ;; Chọn năm
      (box :class "selector-box" :orientation "horizontal" :space-evenly false :halign "center"
        (button :class "nav-btn" :onclick "~/.config/eww/scripts/navigate.sh year prev" "‹")
        (label :class "nav-label year" :text {calendar_year})
        (button :class "nav-btn" :onclick "~/.config/eww/scripts/navigate.sh year next" "›")))

    ;; ── Phần 3: Lưới Lịch hiển thị ──
    ;; Dòng thứ trong tuần
    (box :class "weekday-row" :orientation "horizontal" :space-evenly true
      (for day in {calendar_json.weekdays ?: "[]"}
        (label :class "weekday" :text day)))
    ;; Lưới ngày
    (box :class "day-grid" :orientation "vertical" :space-evenly false
      (for week in {calendar_json.weeks ?: "[]"}
        (box :class "week-row" :orientation "horizontal" :space-evenly true
          (for day in week
            (label
              :class {day.today ? "day today" : day.muted ? "day muted" : "day"}
              :text {day.label})))))))
```

- [ ] **Step 2: Kiểm tra cấu trúc tĩnh**
Kiểm tra cấu trúc tập tin bằng công cụ tĩnh (kiểm tra dấu ngoặc đơn lồng nhau mở đóng đầy đủ).

---

### Task 4: Design Eww SCSS Theme

**Files:**
- Modify: `.config/eww/eww.scss`

- [ ] **Step 1: Áp dụng CSS/SCSS nâng cấp**
Thay thế nội dung file `.config/eww/eww.scss` để tạo giao diện tuyệt đẹp như mockup:

```scss
// Bảng màu Catppuccin Mocha đồng bộ với Waybar
$base: #1e1e2e;
$surface0: #313244;
$surface1: #45475a;
$text: #cdd6f4;
$subtext0: #a6adc8;
$blue: #89b4fa;
$lavender: #b4befe;
$red: #f38ba8;
$green: #a6e3a1;

* {
  all: unset;
  font-family: "JetBrainsMono Nerd Font", "JetBrains Mono", "DejaVu Sans Mono", monospace;
}

// Thẻ bọc ngoài cùng
.calendar-card {
  background: $base;
  border: 2px solid $surface0;
  border-radius: 16px;
  padding: 20px;
  color: $text;
}

// ── 1. Phần Header (Đồng hồ & Ngày) ──
.header-box {
  margin-bottom: 20px;
}

.clock-box {
  margin-bottom: 5px;
}

.clock-time {
  font-size: 44px;
  font-weight: 800;
  color: $text;
}

.clock-separator {
  font-size: 40px;
  font-weight: 300;
  color: $lavender;
  margin: 0 12px;
}

.clock-date {
  font-size: 13px;
  font-weight: 500;
  color: $subtext0;
  text-align: center;
}

// ── 2. Phần Điều hướng Lịch ──
.nav-box {
  background: $surface0;
  border-radius: 12px;
  padding: 8px 12px;
  margin-bottom: 20px;
}

.selector-box {
  min-width: 130px;
  justify-content: space-between;
}

.nav-btn {
  font-size: 20px;
  font-weight: bold;
  color: $blue;
  padding: 0 8px;
  border-radius: 6px;
}

.nav-btn:hover {
  background: $surface1;
}

.nav-label {
  font-size: 13px;
  font-weight: bold;
  color: $text;
  text-align: center;
}

// ── 3. Phần Lưới Lịch ──
.weekday-row {
  margin-bottom: 10px;
}

.weekday {
  font-size: 12px;
  font-weight: bold;
  color: $green;
  width: 40px;
  min-width: 40px;
  height: 25px;
  min-height: 25px;
  text-align: center;
}

.day-grid {
  // Container các dòng tuần
}

.week-row {
  margin-bottom: 6px;
}

.day {
  font-size: 13px;
  font-weight: 500;
  width: 40px;
  height: 40px;
  min-width: 40px;
  min-height: 40px;
  text-align: center;
  margin: 0 2px;
  border-radius: 20px;
  color: $text;
}

.day.today {
  background: $blue;
  color: $base;
  font-weight: 700;
}

.day.muted {
  color: $surface1;
}

.day:hover:not(.today):not(.muted) {
  background: $surface0;
  font-weight: bold;
}
```

---

### Task 5: Refactor Waybar Toggle Script

**Files:**
- Modify: `.config/waybar/scripts/toggle-calendar.sh`

- [ ] **Step 1: Cập nhật script toggle**
Sửa đổi phần mở của script `.config/waybar/scripts/toggle-calendar.sh` để reset các biến `calendar_month` và `calendar_year` về thời gian hiện tại của hệ thống.
Thay đổi khối xử lý ở cuối:

```bash
# 5. Thực hiện Bật/Tắt cửa sổ lịch
if "$EWW_BIN" --config "$CONFIG_DIR" active-windows | grep -q "^$WINDOW"; then
    # Nếu cửa sổ đang mở -> đóng lại
    "$EWW_BIN" --config "$CONFIG_DIR" close "$WINDOW"
else
    # Nếu cửa sổ đang đóng -> khởi tạo lại biến tháng/năm về thực tại, cập nhật dữ liệu và mở
    read -r current_year current_month < <(date "+%Y %m")
    
    # Cập nhật các biến trạng thái trong Eww về hiện tại
    "$EWW_BIN" --config "$CONFIG_DIR" update calendar_month="$((10#$current_month))"
    "$EWW_BIN" --config "$CONFIG_DIR" update calendar_year="$((10#$current_year))"
    
    DATA_SCRIPT="$CONFIG_DIR/scripts/calendar-data.sh"
    if [ -x "$DATA_SCRIPT" ]; then
        "$EWW_BIN" --config "$CONFIG_DIR" update calendar_json="$("$DATA_SCRIPT" "$current_month" "$current_year")"
    else
        echo "Warning: Không tìm thấy hoặc không có quyền chạy script dữ liệu lịch tại $DATA_SCRIPT" >&2
    fi
    "$EWW_BIN" --config "$CONFIG_DIR" open "$WINDOW" --arg monitor="$MONITOR"
fi
```

- [ ] **Step 2: Đảm bảo cú pháp**
Chạy:
```bash
bash -n .config/waybar/scripts/toggle-calendar.sh
```
Expected: exit code `0`.

---

### Task 6: Runtime Verification

**Files:**
- Runtime only

- [ ] **Step 1: Reload Sway/Waybar**
Chạy:
```bash
swaymsg reload
```

- [ ] **Step 2: Chạy thử thủ công bằng script toggle**
Chạy:
```bash
~/.config/waybar/scripts/toggle-calendar.sh
```
Expected: Cửa sổ popup lịch Eww mở lên ngay lập tức, hiển thị giao diện tuyệt đẹp với giờ hệ thống thực tế và lưới lịch chuẩn xác.

- [ ] **Step 3: Thử bấm nút điều hướng**
Click vào các nút `‹` và `›` ở phần tháng và năm trên popup.
Expected: Grid lịch thay đổi và cập nhật hiển thị đúng ngày của tháng/năm được chọn. Ngày hôm nay thực tế chỉ được highlight nếu quay lại đúng tháng/năm hiện tại.

- [ ] **Step 4: Đóng popup**
Chạy lại script toggle hoặc click vào clock để đóng popup.
Expected: Cửa sổ lịch đóng lại trơn tru.

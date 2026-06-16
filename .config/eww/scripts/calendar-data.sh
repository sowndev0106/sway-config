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

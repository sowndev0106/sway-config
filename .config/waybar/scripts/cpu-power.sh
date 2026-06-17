#!/usr/bin/env bash
# Đo công suất tiêu thụ HIỆN TẠI của gói CPU qua Intel RAPL.
#
# Nguyên lý: file energy_uj là bộ đếm NĂNG LƯỢNG tích luỹ (đơn vị micro-joule),
# luôn tăng dần. Lấy hiệu hai lần đọc cách nhau 1 giây rồi chia cho 1.000.000
# sẽ ra công suất tính bằng watt (vì J/s = W).
#
# energy_uj mặc định chỉ root đọc được; install.sh tạo udev rule + chmod để mọi
# user đọc được. Nếu chưa chạy install.sh thì trả "N/A" thay vì làm waybar treo.

TOGGLE="$HOME/.config/waybar/scripts/sensors-toggle.sh"
if [ -x "$TOGGLE" ] && ! "$TOGGLE" enabled power 2>/dev/null; then
    echo ""
    exit 0
fi

RAPL="/sys/class/powercap/intel-rapl:0"   # package-0 = toàn bộ gói CPU
E="$RAPL/energy_uj"

[ -r "$E" ] || { echo "N/A"; exit 0; }

e1=$(< "$E")
sleep 1
e2=$(< "$E")

# Bộ đếm tràn (wrap) khi chạm max_energy_range_uj -> cộng bù một vòng.
if [ "$e2" -lt "$e1" ]; then
    max=$(< "$RAPL/max_energy_range_uj")
    delta=$(( max - e1 + e2 ))
else
    delta=$(( e2 - e1 ))
fi

awk "BEGIN { printf \"%.1f\", $delta / 1000000 }"

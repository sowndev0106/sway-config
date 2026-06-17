#!/usr/bin/env bash
# Doc du 5 gia tri cam bien, in Pango markup de dung lam tooltip waybar.
set -euo pipefail

# Nhiet do (thermal_zone9 = x86_pkg_temp tren may nay)
temp_raw=$(cat /sys/class/thermal/thermal_zone9/temp 2>/dev/null || echo 0)
temp_c=$((temp_raw / 1000))
if [ "$temp_c" -ge 85 ]; then
    temp_str="<span foreground='#f38ba8'> ${temp_c}C</span>"
elif [ "$temp_c" -ge 70 ]; then
    temp_str="<span foreground='#f9e2af'> ${temp_c}C</span>"
else
    temp_str="<span foreground='#fab387'> ${temp_c}C</span>"
fi

# CPU % (doc /proc/stat 2 lan cach nhau 0.5s)
read_stat() { awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $2+$3+$4+$6+$7+$8}' /proc/stat; }
s1=$(read_stat); sleep 0.5; s2=$(read_stat)
total1=${s1%% *}; busy1=${s1##* }
total2=${s2%% *}; busy2=${s2##* }
dtotal=$((total2 - total1)); dbusy=$((busy2 - busy1))
[ "$dtotal" -eq 0 ] && cpu_pct=0 || cpu_pct=$(( (dbusy * 100) / dtotal ))
cpu_str="<span foreground='#f9e2af'> ${cpu_pct}%</span>"

# Xung nhip trung binh cac nhan
freq_sum=0; freq_n=0
for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
    [ -r "$f" ] || continue
    freq_sum=$((freq_sum + $(cat "$f")))
    freq_n=$((freq_n + 1))
done
if [ "$freq_n" -gt 0 ]; then
    freq_ghz=$(awk "BEGIN{printf \"%.2f\", $freq_sum / $freq_n / 1000000}")
else
    freq_ghz="?.??"
fi
freq_str="<span foreground='#f9e2af'> ${freq_ghz}GHz</span>"

# Cong suat RAPL (do nhanh trong 0.3s)
E="/sys/class/powercap/intel-rapl:0/energy_uj"
if [ -r "$E" ]; then
    e1=$(< "$E"); sleep 0.3; e2=$(< "$E")
    if [ "$e2" -lt "$e1" ]; then
        max=$(< /sys/class/powercap/intel-rapl:0/max_energy_range_uj)
        delta=$(( max - e1 + e2 ))
    else
        delta=$(( e2 - e1 ))
    fi
    power_w=$(awk "BEGIN{printf \"%.1f\", $delta / 300000}")
    power_str="<span foreground='#a6e3a1'>${power_w}W</span>"
else
    power_str="<span foreground='#6c7086'>N/A W</span>"
fi

# RAM %
ram_total=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
ram_avail=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
ram_pct=$(( (ram_total - ram_avail) * 100 / ram_total ))
ram_str="<span foreground='#cba6f7'> ${ram_pct}%</span>"

printf '%s  %s  %s  %s  %s' \
    "$temp_str" "$cpu_str" "$freq_str" "$power_str" "$ram_str"

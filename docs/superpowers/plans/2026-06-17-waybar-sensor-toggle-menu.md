# Waybar Sensor Toggle Menu — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cho phép bật/tắt từng ô cảm biến (nhiệt độ, CPU %, xung nhịp, công suất, RAM) trên waybar qua popup eww có toggle switch, bấm vào bất kỳ ô nào đang hiện để mở; hover để xem tất cả giá trị.

**Architecture:** 5 module custom thay thế 3 module gốc (temperature/cpu/memory) + giữ cpu-power; mỗi module chạy script tự ẩn khi mục tắt (in chuỗi rỗng). State lưu trong `~/.config/waybar/sensors.state`. Bọc cả cụm trong waybar `group` để bo góc pill luôn đúng. Popup eww theo pattern control-center hiện có.

**Tech Stack:** bash, waybar custom module (return-type json, signal 8), eww (yuck/css), Catppuccin Mocha, JetBrainsMono Nerd Font.

## Global Constraints

- Ngôn ngữ comment/commit: tiếng Việt.
- Màu sắc: Catppuccin Mocha (`base #1e1e2e · surface0 #313244 · text #cdd6f4 · blue #89b4fa · green #a6e3a1 · red #f38ba8 · yellow #f9e2af · peach #fab387 · mauve #cba6f7`).
- Signal waybar: `pkill -RTMIN+8 -x waybar` (KHÔNG `-f`, KHÔNG kill trực tiếp).
- eww binary: `${EWW_BIN:-$HOME/.local/bin/eww}`.
- Mở popup TRƯỚC rồi mới closer (pattern đã được ghi chú trong repo).
- `thermal_zone9` = x86_pkg_temp trên máy này (i7-1355U).
- RAPL path: `/sys/class/powercap/intel-rapl:0/energy_uj` (đã có quyền o+r).
- Không commit trừ khi người dùng yêu cầu — kiểm thử thủ công sau mỗi task.

---

## File Map

| Trạng thái | Đường dẫn | Vai trò |
|---|---|---|
| **Tạo mới** | `.config/waybar/scripts/sensors-toggle.sh` | Helper state: get/toggle/enabled |
| **Tạo mới** | `.config/waybar/scripts/sensors-readall.sh` | Đọc đủ 5 giá trị cho tooltip |
| **Tạo mới** | `.config/waybar/scripts/sensor-temp.sh` | Module nhiệt độ (JSON + tooltip) |
| **Tạo mới** | `.config/waybar/scripts/sensor-cpu.sh` | Module CPU % (JSON + tooltip) |
| **Tạo mới** | `.config/waybar/scripts/sensor-freq.sh` | Module xung nhịp (JSON + tooltip) |
| **Sửa** | `.config/waybar/scripts/cpu-power.sh` | Thêm gate enabled power |
| **Tạo mới** | `.config/waybar/scripts/sensor-ram.sh` | Module RAM (JSON + tooltip) |
| **Tạo mới** | `.config/waybar/scripts/toggle-sensors-menu.sh` | Mở/đóng popup eww |
| **Sửa** | `.config/waybar/config` | Đổi modules, thêm group + 5 custom module |
| **Sửa** | `.config/waybar/style.css` | Bo góc group, màu các ô con |
| **Sửa** | `.config/eww/eww.yuck` | Thêm defpoll, defwindow, defwidget sensors |
| **Sửa** | `.config/eww/eww.css` | Style sensors-card, toggle switch |

---

## Task 1: sensors-toggle.sh — Helper quản lý state

**Files:**
- Tạo: `.config/waybar/scripts/sensors-toggle.sh`

**Interfaces:**
- Produces:
  - `sensors-toggle.sh get <key>` → in `on` hoặc `off` (stdout)
  - `sensors-toggle.sh toggle <key>` → lật state, từ chối nếu là mục on cuối, refresh waybar
  - `sensors-toggle.sh enabled <key>` → exit 0 nếu on, exit 1 nếu off
  - State file: `~/.config/waybar/sensors.state` (dạng `key=on|off`, 5 khoá: `temp cpu freq power ram`)

- [ ] **Bước 1: Tạo file**

```bash
cat > ~/.config/sway-config-repo/.config/waybar/scripts/sensors-toggle.sh << 'SCRIPT'
#!/usr/bin/env bash
# Quản lý trạng thái bật/tắt từng ô cảm biến trên waybar.
# Sử dụng: sensors-toggle.sh get|toggle|enabled <key>
# key: temp | cpu | freq | power | ram
set -euo pipefail

STATE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/sensors.state"
KEYS=(temp cpu freq power ram)

_get() {
    local key="$1"
    if [ -f "$STATE_FILE" ]; then
        local val
        val=$(grep "^${key}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2 || true)
        echo "${val:-on}"
    else
        echo "on"
    fi
}

_set() {
    local key="$1" val="$2"
    mkdir -p "$(dirname "$STATE_FILE")"
    if [ -f "$STATE_FILE" ]; then
        # Xoá dòng cũ rồi thêm dòng mới
        local tmp
        tmp=$(grep -v "^${key}=" "$STATE_FILE" || true)
        printf '%s\n%s=%s\n' "$tmp" "$key" "$val" > "$STATE_FILE"
    else
        printf '%s=%s\n' "$key" "$val" > "$STATE_FILE"
    fi
}

_count_on() {
    local count=0
    for k in "${KEYS[@]}"; do
        [ "$(_get "$k")" = "on" ] && count=$((count + 1))
    done
    echo "$count"
}

case "${1:-}" in
    get)
        [ -z "${2:-}" ] && { echo "Thiếu key" >&2; exit 1; }
        _get "$2"
        ;;
    toggle)
        [ -z "${2:-}" ] && { echo "Thiếu key" >&2; exit 1; }
        key="$2"
        cur=$(_get "$key")
        if [ "$cur" = "on" ]; then
            # Từ chối tắt nếu đây là mục on cuối cùng
            if [ "$(_count_on)" -le 1 ]; then
                exit 0
            fi
            _set "$key" "off"
        else
            _set "$key" "on"
        fi
        # Refresh waybar qua signal RTMIN+8 (an toàn, không kill waybar)
        pkill -RTMIN+8 -x waybar 2>/dev/null || true
        ;;
    enabled)
        [ -z "${2:-}" ] && { echo "Thiếu key" >&2; exit 1; }
        [ "$(_get "$2")" = "on" ]
        ;;
    *)
        echo "Dùng: sensors-toggle.sh get|toggle|enabled <key>" >&2
        exit 1
        ;;
esac
SCRIPT
chmod +x ~/.config/waybar/scripts/sensors-toggle.sh
```

> **Chú ý đường dẫn:** file này nằm trong repo symlink tới `~/.config/waybar/scripts/`. Sửa trong repo (`/home/sown/workplace/sway-config/.config/waybar/scripts/`) và chmod thêm ở đó, hoặc symlink đã tự trỏ.

- [ ] **Bước 2: Kiểm thử thủ công**

```bash
# Lần đầu — file chưa tồn tại, mặc định on
~/.config/waybar/scripts/sensors-toggle.sh get temp        # in: on
~/.config/waybar/scripts/sensors-toggle.sh get ram         # in: on

# Toggle tắt temp
~/.config/waybar/scripts/sensors-toggle.sh toggle temp
~/.config/waybar/scripts/sensors-toggle.sh get temp        # in: off
cat ~/.config/waybar/sensors.state                         # có dòng temp=off

# Toggle on lại
~/.config/waybar/scripts/sensors-toggle.sh toggle temp
~/.config/waybar/scripts/sensors-toggle.sh get temp        # in: on

# Không cho tắt hết: tắt 4 mục rồi thử tắt mục cuối
for k in temp cpu freq power; do
    ~/.config/waybar/scripts/sensors-toggle.sh toggle "$k"
done
~/.config/waybar/scripts/sensors-toggle.sh toggle ram      # phải không đổi
~/.config/waybar/scripts/sensors-toggle.sh get ram         # in: on

# Reset về bật hết
for k in temp cpu freq power; do
    ~/.config/waybar/scripts/sensors-toggle.sh toggle "$k"
done

# enabled
~/.config/waybar/scripts/sensors-toggle.sh enabled temp && echo "ok" || echo "off"  # ok
```

---

## Task 2: sensors-readall.sh — Tooltip đọc đủ 5 giá trị

**Files:**
- Tạo: `.config/waybar/scripts/sensors-readall.sh`

**Interfaces:**
- Consumes: `/sys/class/thermal/thermal_zone9/temp`, `/proc/stat`, `/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq`, `/sys/class/powercap/intel-rapl:0/energy_uj`, `/proc/meminfo`
- Produces: `sensors-readall.sh` → in Pango markup nhiều dòng (dùng làm `tooltip` trong JSON)

- [ ] **Bước 1: Tạo file**

```bash
cat > /home/sown/workplace/sway-config/.config/waybar/scripts/sensors-readall.sh << 'SCRIPT'
#!/usr/bin/env bash
# Đọc đủ 5 giá trị cảm biến và in dạng Pango markup cho waybar tooltip.
set -euo pipefail

# Nhiệt độ
temp_raw=$(cat /sys/class/thermal/thermal_zone9/temp 2>/dev/null || echo 0)
temp_c=$((temp_raw / 1000))
if [ "$temp_c" -ge 85 ]; then
    temp_str="<span foreground='#f38ba8'> ${temp_c}°C</span>"
elif [ "$temp_c" -ge 70 ]; then
    temp_str="<span foreground='#f9e2af'> ${temp_c}°C</span>"
else
    temp_str="<span foreground='#fab387'> ${temp_c}°C</span>"
fi

# CPU % (đọc /proc/stat 2 lần cách nhau 0.5s)
read_stat() { awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $2+$3+$4+$6+$7+$8}' /proc/stat; }
s1=$(read_stat); sleep 0.5; s2=$(read_stat)
total1=${s1%% *}; busy1=${s1##* }
total2=${s2%% *}; busy2=${s2##* }
dtotal=$((total2 - total1)); dbusy=$((busy2 - busy1))
[ "$dtotal" -eq 0 ] && cpu_pct=0 || cpu_pct=$(( (dbusy * 100) / dtotal ))
cpu_str="<span foreground='#f9e2af'> ${cpu_pct}%</span>"

# Xung nhịp trung bình
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

# Công suất RAPL
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
SCRIPT
chmod +x /home/sown/workplace/sway-config/.config/waybar/scripts/sensors-readall.sh
```

- [ ] **Bước 2: Kiểm thử**

```bash
~/.config/waybar/scripts/sensors-readall.sh
# Phải in 1 dòng Pango markup có 5 phần, không lỗi, không trống
```

---

## Task 3: 5 script hiển thị module cảm biến

**Files:**
- Tạo: `.config/waybar/scripts/sensor-temp.sh`
- Tạo: `.config/waybar/scripts/sensor-cpu.sh`
- Tạo: `.config/waybar/scripts/sensor-freq.sh`
- Sửa: `.config/waybar/scripts/cpu-power.sh` (thêm gate `enabled power`)
- Tạo: `.config/waybar/scripts/sensor-ram.sh`

**Interfaces:**
- Consumes: `sensors-toggle.sh enabled <key>`, `sensors-readall.sh`
- Produces: mỗi script in JSON `{"text":"...","tooltip":"...","class":"..."}` ra stdout — waybar đọc mỗi `interval` giây. `text` rỗng → ô tự ẩn.

- [ ] **Bước 1: sensor-temp.sh**

```bash
cat > /home/sown/workplace/sway-config/.config/waybar/scripts/sensor-temp.sh << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
TOGGLE="$HOME/.config/waybar/scripts/sensors-toggle.sh"

if ! "$TOGGLE" enabled temp 2>/dev/null; then
    echo '{"text":"","tooltip":"","class":""}'
    exit 0
fi

temp_raw=$(cat /sys/class/thermal/thermal_zone9/temp 2>/dev/null || echo 0)
temp_c=$((temp_raw / 1000))

if [ "$temp_c" -ge 85 ]; then
    icon=""
    cls="critical"
elif [ "$temp_c" -ge 60 ]; then
    icon=""
else
    icon=""
fi

tooltip=$("$HOME/.config/waybar/scripts/sensors-readall.sh" 2>/dev/null || echo "")
printf '{"text":"%s %d°C","tooltip":"%s","class":"%s"}\n' \
    "$icon" "$temp_c" "$tooltip" "$cls"
SCRIPT
chmod +x /home/sown/workplace/sway-config/.config/waybar/scripts/sensor-temp.sh
```

- [ ] **Bước 2: sensor-cpu.sh**

```bash
cat > /home/sown/workplace/sway-config/.config/waybar/scripts/sensor-cpu.sh << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
TOGGLE="$HOME/.config/waybar/scripts/sensors-toggle.sh"

if ! "$TOGGLE" enabled cpu 2>/dev/null; then
    echo '{"text":"","tooltip":"","class":""}'
    exit 0
fi

read_stat() { awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $2+$3+$4+$6+$7+$8}' /proc/stat; }
s1=$(read_stat); sleep 0.5; s2=$(read_stat)
total1=${s1%% *}; busy1=${s1##* }
total2=${s2%% *}; busy2=${s2##* }
dtotal=$((total2 - total1)); dbusy=$((busy2 - busy1))
[ "$dtotal" -eq 0 ] && pct=0 || pct=$(( (dbusy * 100) / dtotal ))

tooltip=$("$HOME/.config/waybar/scripts/sensors-readall.sh" 2>/dev/null || echo "")
printf '{"text":" %d%%","tooltip":"%s","class":""}\n' "$pct" "$tooltip"
SCRIPT
chmod +x /home/sown/workplace/sway-config/.config/waybar/scripts/sensor-cpu.sh
```

- [ ] **Bước 3: sensor-freq.sh**

```bash
cat > /home/sown/workplace/sway-config/.config/waybar/scripts/sensor-freq.sh << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
TOGGLE="$HOME/.config/waybar/scripts/sensors-toggle.sh"

if ! "$TOGGLE" enabled freq 2>/dev/null; then
    echo '{"text":"","tooltip":"","class":""}'
    exit 0
fi

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

tooltip=$("$HOME/.config/waybar/scripts/sensors-readall.sh" 2>/dev/null || echo "")
printf '{"text":"%sGHz","tooltip":"%s","class":""}\n' "$freq_ghz" "$tooltip"
SCRIPT
chmod +x /home/sown/workplace/sway-config/.config/waybar/scripts/sensor-freq.sh
```

- [ ] **Bước 4: Sửa cpu-power.sh — thêm gate enabled power**

Thêm 6 dòng gate vào đầu script (sau `set -euo pipefail`):

```bash
# Thêm vào đầu cpu-power.sh (sau dòng RAPL="/sys/..." ):
TOGGLE="$HOME/.config/waybar/scripts/sensors-toggle.sh"
if command -v "$TOGGLE" >/dev/null 2>&1 || [ -x "$TOGGLE" ]; then
    if ! "$TOGGLE" enabled power 2>/dev/null; then
        echo ""
        exit 0
    fi
fi
```

Nội dung đầy đủ cpu-power.sh sau khi sửa:

```bash
cat > /home/sown/workplace/sway-config/.config/waybar/scripts/cpu-power.sh << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

TOGGLE="$HOME/.config/waybar/scripts/sensors-toggle.sh"
if [ -x "$TOGGLE" ] && ! "$TOGGLE" enabled power 2>/dev/null; then
    echo ""
    exit 0
fi

RAPL="/sys/class/powercap/intel-rapl:0"
E="$RAPL/energy_uj"

[ -r "$E" ] || { echo "N/A"; exit 0; }

e1=$(< "$E")
sleep 1
e2=$(< "$E")

if [ "$e2" -lt "$e1" ]; then
    max=$(< "$RAPL/max_energy_range_uj")
    delta=$(( max - e1 + e2 ))
else
    delta=$(( e2 - e1 ))
fi

awk "BEGIN { printf \"%.1f\", $delta / 1000000 }"
SCRIPT
chmod +x /home/sown/workplace/sway-config/.config/waybar/scripts/cpu-power.sh
```

- [ ] **Bước 5: sensor-ram.sh**

```bash
cat > /home/sown/workplace/sway-config/.config/waybar/scripts/sensor-ram.sh << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
TOGGLE="$HOME/.config/waybar/scripts/sensors-toggle.sh"

if ! "$TOGGLE" enabled ram 2>/dev/null; then
    echo '{"text":"","tooltip":"","class":""}'
    exit 0
fi

ram_total=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
ram_avail=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
ram_pct=$(( (ram_total - ram_avail) * 100 / ram_total ))

tooltip=$("$HOME/.config/waybar/scripts/sensors-readall.sh" 2>/dev/null || echo "")
printf '{"text":" %d%%","tooltip":"%s","class":""}\n' "$ram_pct" "$tooltip"
SCRIPT
chmod +x /home/sown/workplace/sway-config/.config/waybar/scripts/sensor-ram.sh
```

- [ ] **Bước 6: Kiểm thử từng script**

```bash
# Chạy thử — phải ra JSON hợp lệ
~/.config/waybar/scripts/sensor-temp.sh
~/.config/waybar/scripts/sensor-cpu.sh
~/.config/waybar/scripts/sensor-freq.sh
~/.config/waybar/scripts/cpu-power.sh    # ra số W (không phải JSON vì module này format {}W)
~/.config/waybar/scripts/sensor-ram.sh

# Kiểm thử gate: tắt một mục rồi chạy script tương ứng → phải ra {"text":"","tooltip":"","class":""}
~/.config/waybar/scripts/sensors-toggle.sh toggle temp
~/.config/waybar/scripts/sensor-temp.sh  # → {"text":"","tooltip":"","class":""}
~/.config/waybar/scripts/sensors-toggle.sh toggle temp  # bật lại
```

---

## Task 4: toggle-sensors-menu.sh — Script mở/đóng popup eww

**Files:**
- Tạo: `.config/waybar/scripts/toggle-sensors-menu.sh`

**Interfaces:**
- Consumes: eww binary, `control-center-popup-closer` pattern (đóng nếu đang mở)
- Produces: mở/đóng `sensors-popup` + `sensors-popup-closer` trên monitor hiện tại

- [ ] **Bước 1: Tạo file**

```bash
cat > /home/sown/workplace/sway-config/.config/waybar/scripts/toggle-sensors-menu.sh << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

EWW_BIN="${EWW_BIN:-$HOME/.local/bin/eww}"
if [ ! -x "$EWW_BIN" ]; then
    command -v eww >/dev/null 2>&1 && EWW_BIN="$(command -v eww)" || exit 0
fi

CONFIG_DIR="$HOME/.config/eww"
WINDOW="sensors-popup"
CLOSER="sensors-popup-closer"

MONITOR="$(swaymsg -t get_outputs 2>/dev/null | jq -r '.[] | select(.focused).name' | head -n1)"
MONITOR="${MONITOR:-0}"

# Khởi động daemon nếu chưa chạy
if ! "$EWW_BIN" --config "$CONFIG_DIR" active-windows >/dev/null 2>&1; then
    "$EWW_BIN" --config "$CONFIG_DIR" daemon >/dev/null 2>&1 || true
    for i in {1..30}; do
        "$EWW_BIN" --config "$CONFIG_DIR" active-windows >/dev/null 2>&1 && break
        sleep 0.1
    done
fi

if "$EWW_BIN" --config "$CONFIG_DIR" active-windows | grep -q "^${WINDOW}"; then
    "$EWW_BIN" --config "$CONFIG_DIR" close "$WINDOW" || true
    "$EWW_BIN" --config "$CONFIG_DIR" close "$CLOSER" || true
else
    # Mở popup TRƯỚC, closer SAU (xem lưu ý trong toggle-control-center.sh)
    "$EWW_BIN" --config "$CONFIG_DIR" open "$WINDOW" --arg monitor="$MONITOR"
    "$EWW_BIN" --config "$CONFIG_DIR" open "$CLOSER" --arg monitor="$MONITOR" || true
fi
SCRIPT
chmod +x /home/sown/workplace/sway-config/.config/waybar/scripts/toggle-sensors-menu.sh
```

- [ ] **Bước 2: Kiểm thử (sau khi task 6 xong eww.yuck)**

```bash
~/.config/waybar/scripts/toggle-sensors-menu.sh  # mở popup
~/.config/waybar/scripts/toggle-sensors-menu.sh  # đóng popup
```

---

## Task 5: waybar config — group + 5 module custom

**Files:**
- Sửa: `.config/waybar/config`

**Interfaces:**
- Consumes: 5 script sensor từ Task 3, `toggle-sensors-menu.sh` từ Task 4
- Produces: waybar group `group/sensors` thay thế `temperature`, `cpu`, `custom/cpu-power`, `memory`

- [ ] **Bước 1: Sửa modules-left và thêm module definitions**

Thay toàn bộ nội dung `.config/waybar/config`:

```json
{
    "layer": "top",
    "position": "top",
    "height": 32,
    "spacing": 0,

    "modules-left": ["custom/power", "sway/workspaces", "sway/mode", "group/sensors"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "bluetooth", "custom/control-center", "battery", "tray"],

    "custom/power": {
        "format": "",
        "tooltip": false,
        "on-click": "wlogout"
    },

    "sway/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{name}"
    },
    "sway/mode": {
        "format": "{}"
    },

    "group/sensors": {
        "orientation": "horizontal",
        "modules": [
            "custom/sensor-temp",
            "custom/sensor-cpu",
            "custom/sensor-freq",
            "custom/cpu-power",
            "custom/sensor-ram"
        ]
    },

    "custom/sensor-temp": {
        "exec": "~/.config/waybar/scripts/sensor-temp.sh",
        "return-type": "json",
        "interval": 3,
        "signal": 8,
        "on-click": "~/.config/waybar/scripts/toggle-sensors-menu.sh"
    },
    "custom/sensor-cpu": {
        "exec": "~/.config/waybar/scripts/sensor-cpu.sh",
        "return-type": "json",
        "interval": 2,
        "signal": 8,
        "on-click": "~/.config/waybar/scripts/toggle-sensors-menu.sh"
    },
    "custom/sensor-freq": {
        "exec": "~/.config/waybar/scripts/sensor-freq.sh",
        "return-type": "json",
        "interval": 2,
        "signal": 8,
        "on-click": "~/.config/waybar/scripts/toggle-sensors-menu.sh"
    },
    "custom/cpu-power": {
        "format": "{}W",
        "exec": "~/.config/waybar/scripts/cpu-power.sh",
        "interval": 3,
        "signal": 8,
        "on-click": "~/.config/waybar/scripts/toggle-sensors-menu.sh"
    },
    "custom/sensor-ram": {
        "exec": "~/.config/waybar/scripts/sensor-ram.sh",
        "return-type": "json",
        "interval": 5,
        "signal": 8,
        "on-click": "~/.config/waybar/scripts/toggle-sensors-menu.sh"
    },

    "clock": {
        "format": " {:%a %d-%m  %H:%M}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
        "on-click": "~/.config/waybar/scripts/toggle-calendar.sh"
    },

    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "",
        "format-icons": { "default": ["", "", "", "", ""] },
        "tooltip-format": "{volume}%",
        "tooltip-format-muted": "Muted",
        "on-click": "~/.config/waybar/scripts/toggle-control-center.sh audio"
    },
    "bluetooth": {
        "format": "",
        "format-disabled": "",
        "format-off": "",
        "format-connected": "󰄱",
        "tooltip-format": "{controller_alias}\t{status}",
        "tooltip-format-connected": "{controller_alias}\t{status}\n\n{device_enumerate}",
        "tooltip-format-enumerate-connected": "{device_alias}",
        "on-click": "~/.config/waybar/scripts/toggle-control-center.sh bluetooth"
    },
    "battery": {
        "states": { "warning": 30, "critical": 15, "full": 95 },
        "format": "{icon}",
        "format-charging": "",
        "format-plugged": "",
        "tooltip-format": "{capacity}% ({time})",
        "tooltip-format-charging": "Charging: {capacity}% ({time})",
        "tooltip-format-plugged": "Plugged: {capacity}%",
        "format-icons": ["", "", "", "", ""],
        "interval": 2
    },
    "custom/control-center": {
        "format": "󰅮",
        "tooltip": false,
        "on-click": "~/.config/waybar/scripts/toggle-control-center.sh home"
    },

    "tray": {
        "icon-size": 16,
        "spacing": 8
    }
}
```

> **Ghi chú glyph:** File config dùng escape `\uXXXX` thay vì paste glyph trực tiếp vì Write tool có thể làm rớt PUA glyph. Waybar đọc JSON hỗ trợ `\uXXXX`.

- [ ] **Bước 2: Reload waybar kiểm thử**

```bash
swaymsg reload
sleep 2
pgrep -x waybar >/dev/null && echo "waybar OK" || echo "LỖII — xem journalctl -u waybar"
# Kiểm thử: 5 ô cảm biến hiện trên bar, bấm bất kỳ ô → toggle-sensors-menu.sh chạy
```

---

## Task 6: eww.yuck — defpoll, sensors-card, popup windows

**Files:**
- Sửa: `.config/eww/eww.yuck`

**Interfaces:**
- Consumes: `sensors-toggle.sh get <key>`, `sensors-toggle.sh toggle <key>`
- Produces: `sensors-popup` window + `sensors-popup-closer` window

- [ ] **Bước 1: Thêm defpoll 5 khoá vào eww.yuck**

Thêm đoạn sau (sau phần `defvar mic_level` cuối phần biến control-center, khoảng dòng 129):

```scheme
;; ── Cảm biến: poll trạng thái bật/tắt ──
(defpoll sensor_temp_on  :interval "2s" "~/.config/waybar/scripts/sensors-toggle.sh get temp")
(defpoll sensor_cpu_on   :interval "2s" "~/.config/waybar/scripts/sensors-toggle.sh get cpu")
(defpoll sensor_freq_on  :interval "2s" "~/.config/waybar/scripts/sensors-toggle.sh get freq")
(defpoll sensor_power_on :interval "2s" "~/.config/waybar/scripts/sensors-toggle.sh get power")
(defpoll sensor_ram_on   :interval "2s" "~/.config/waybar/scripts/sensors-toggle.sh get ram")
```

- [ ] **Bước 2: Thêm defwidget sensors-card và 2 defwindow vào cuối eww.yuck**

```scheme
;; ── Popup cảm biến: bật/tắt từng ô trên waybar ──
(defwidget sensor-row [label icon key poll-val]
  (box :class "sensor-row" :orientation "horizontal" :space-evenly false
    (label :class "sensor-row-icon" :text icon)
    (label :class "sensor-row-label" :text label :hexpand true)
    (button
      :class {poll-val == "on" ? "sensor-toggle active" : "sensor-toggle"}
      :onclick "~/.config/waybar/scripts/sensors-toggle.sh toggle ${key}"
      (label :text {poll-val == "on" ? "" : ""}))))

(defwidget sensors-card []
  (box :class "sensors-card" :orientation "vertical" :space-evenly false
    (label :class "sensors-title" :text "Cảm biến")
    (sensor-row :label "Nhiệt độ"  :icon "" :key "temp"  :poll-val sensor_temp_on)
    (sensor-row :label "CPU %"     :icon "" :key "cpu"   :poll-val sensor_cpu_on)
    (sensor-row :label "Xung nhịp" :icon "" :key "freq"  :poll-val sensor_freq_on)
    (sensor-row :label "Công suất" :icon "" :key "power" :poll-val sensor_power_on)
    (sensor-row :label "RAM"       :icon "" :key "ram"   :poll-val sensor_ram_on)))

(defwindow sensors-popup [monitor]
  :monitor monitor
  :geometry (geometry
    :x "15px"
    :y "45px"
    :width "240px"
    :anchor "top left")
  :stacking "overlay"
  :exclusive false
  :focusable false
  :namespace "eww-sensors"
  (sensors-card))

(defwindow sensors-popup-closer [monitor]
  :monitor monitor
  :geometry (geometry
    :x "0px"
    :y "0px"
    :width "100%"
    :height "100%"
    :anchor "top left")
  :stacking "foreground"
  :focusable false
  (closer :window "sensors-popup"))
```

- [ ] **Bước 3: Kiểm thử eww daemon**

```bash
eww --config ~/.config/eww reload 2>/dev/null || eww --config ~/.config/eww daemon &
sleep 1
# Mở thủ công để kiểm tra widget không lỗi cú pháp
MONITOR=$(swaymsg -t get_outputs | jq -r '.[]|select(.focused).name' | head -1)
eww --config ~/.config/eww open sensors-popup --arg monitor="$MONITOR"
# Phải thấy popup sensors-card xuất hiện (chưa có style đẹp, OK)
eww --config ~/.config/eww close sensors-popup
```

---

## Task 7: waybar style.css — group pill + màu ô con

**Files:**
- Sửa: `.config/waybar/style.css`

**Interfaces:**
- Produces: `#sensors` bo góc pill, 5 ô con có màu riêng, không bo góc riêng lẻ

- [ ] **Bước 1: Sửa style.css — thay khối cảm biến cũ**

Xoá khối cảm biến cũ (temperature/cpu/memory) và thay bằng:

```css
/* ── Cụm cảm biến — container group bo góc pill ── */
#sensors {
    background-color: #313244;
    border-radius: 16px;
    margin: 4px 6px;
    padding: 0 4px;
}

/* Các ô con: không bo góc riêng, dùng màu riêng từng loại */
#custom-sensor-temp,
#custom-sensor-cpu,
#custom-sensor-freq,
#custom-cpu-power,
#custom-sensor-ram {
    padding: 0 8px;
    background-color: transparent;
}

#custom-sensor-temp  { color: #fab387; }
#custom-sensor-cpu   { color: #f9e2af; }
#custom-sensor-freq  { color: #f9e2af; }
#custom-cpu-power    { color: #a6e3a1; }
#custom-sensor-ram   { color: #cba6f7; }
#custom-sensor-temp.critical { color: #f38ba8; }
```

- [ ] **Bước 2: Reload và kiểm tra trực quan**

```bash
swaymsg reload
sleep 1
# Pill cảm biến phải bo góc đều, màu từng ô đúng như Catppuccin
# Thử tắt 1-2 mục qua sensors-toggle.sh và quan sát pill vẫn bo góc đúng
~/.config/waybar/scripts/sensors-toggle.sh toggle temp
sleep 4  # đợi signal RTMIN+8 refresh
# Ô nhiệt độ biến mất, pill vẫn đẹp
~/.config/waybar/scripts/sensors-toggle.sh toggle temp  # bật lại
```

---

## Task 8: eww.css — style sensors-card

**Files:**
- Sửa: `.config/eww/eww.css`

**Interfaces:**
- Produces: `.sensors-card`, `.sensor-row`, `.sensor-toggle`, `.sensor-toggle.active` khớp Catppuccin

- [ ] **Bước 1: Thêm vào cuối eww.css**

```css
/* ── Sensors popup ── */
.sensors-card {
  background: #1e1e2e;
  border: 2px solid #313244;
  border-radius: 16px;
  padding: 16px;
  color: #cdd6f4;
  min-width: 220px;
}

.sensors-title {
  font-size: 13px;
  font-weight: 700;
  color: #89b4fa;
  margin-bottom: 10px;
}

.sensor-row {
  margin: 4px 0;
  padding: 4px 0;
}

.sensor-row-icon {
  font-size: 14px;
  margin-right: 8px;
  min-width: 20px;
}

.sensor-row-label {
  font-size: 13px;
  color: #cdd6f4;
}

.sensor-toggle {
  background: #313244;
  border-radius: 12px;
  padding: 2px 10px;
  font-size: 12px;
  color: #6c7086;
  min-width: 32px;
}

.sensor-toggle.active {
  background: #89b4fa;
  color: #1e1e2e;
}
```

- [ ] **Bước 2: Kiểm thử popup đầy đủ**

```bash
~/.config/waybar/scripts/toggle-sensors-menu.sh
# Popup hiện với 5 hàng sensor, mỗi hàng có icon + label + toggle switch
# Toggle bật = nền xanh, tắt = xám
# Bấm toggle → ô tương ứng ẩn/hiện trên waybar sau ~signal delay
# Bấm ra ngoài popup → đóng
# Hover vào ô trên waybar → tooltip hiện đủ 5 giá trị
```

---

## Task 9: Kiểm thử tổng hợp và dọn dẹp

**Files:** Không thêm file mới.

- [ ] **Bước 1: Kiểm thử bật/tắt từng mục**

```bash
for key in temp cpu freq power ram; do
    echo "=== Toggle $key ==="
    ~/.config/waybar/scripts/sensors-toggle.sh toggle "$key"
    sleep 3
    ~/.config/waybar/scripts/sensors-toggle.sh toggle "$key"
    sleep 2
done
# Mỗi lần toggle: ô biến mất rồi xuất hiện lại, pill vẫn bo góc đúng
```

- [ ] **Bước 2: Kiểm thử không cho ẩn hết**

```bash
for key in temp cpu freq power; do
    ~/.config/waybar/scripts/sensors-toggle.sh toggle "$key"
done
# 4 mục tắt, chỉ còn ram
~/.config/waybar/scripts/sensors-toggle.sh toggle ram
~/.config/waybar/scripts/sensors-toggle.sh get ram  # phải vẫn là "on"
# Bật lại hết
for key in temp cpu freq power; do
    ~/.config/waybar/scripts/sensors-toggle.sh toggle "$key"
done
```

- [ ] **Bước 3: Kiểm thử bền vững**

```bash
swaymsg reload
sleep 3
# State phải giữ nguyên sau reload
cat ~/.config/waybar/sensors.state
```

- [ ] **Bước 4: Hover tooltip**

Rê chuột vào bất kỳ ô cảm biến nào → tooltip hiện 5 giá trị (nhiệt độ, CPU %, GHz, W, RAM %).

- [ ] **Bước 5: Commit khi mọi thứ ổn**

```bash
git add \
  .config/waybar/config \
  .config/waybar/style.css \
  .config/waybar/scripts/sensors-toggle.sh \
  .config/waybar/scripts/sensors-readall.sh \
  .config/waybar/scripts/sensor-temp.sh \
  .config/waybar/scripts/sensor-cpu.sh \
  .config/waybar/scripts/sensor-freq.sh \
  .config/waybar/scripts/cpu-power.sh \
  .config/waybar/scripts/sensor-ram.sh \
  .config/waybar/scripts/toggle-sensors-menu.sh \
  .config/eww/eww.yuck \
  .config/eww/eww.css \
  docs/superpowers/specs/2026-06-17-waybar-sensor-toggle-menu-design.md \
  docs/superpowers/plans/2026-06-17-waybar-sensor-toggle-menu.md
git commit -m "feat(waybar): thêm menu eww bật/tắt từng ô cảm biến (nhiệt độ, CPU, GHz, W, RAM)"
```

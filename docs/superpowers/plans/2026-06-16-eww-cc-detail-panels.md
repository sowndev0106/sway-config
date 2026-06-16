# Eww Control Center — Detail Panels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `›` arrow buttons in the control center (which currently open external GTK apps) with self-contained detail panels inside the same eww popup, using a router-view pattern driven by `cc_view` defvar.

**Architecture:** A single `(defvar cc_view "home")` controls which page renders inside `control-center-card`. Five panel widgets (wifi-page, bluetooth-page, audio-page, mic-page, wired-page) are added to `eww.yuck`; the `›` buttons set `cc_view` and load data on demand. Five script modules under `.config/eww/scripts/cc/` each output single-line JSON for eww `for` loops. Data is loaded on demand (not polled) via `eww update <list_var>=...`.

**Tech Stack:** eww (yuck DSL), bash scripts, nmcli, bluetoothctl, wpctl/pactl, brightnessctl, GTK CSS (plain, no SCSS).

---

## File Map

| File | Action | Mô tả |
|---|---|---|
| `.config/eww/scripts/cc/wifi.sh` | Create | list, connect, connect-pass, disconnect, toggle, rescan |
| `.config/eww/scripts/cc/bluetooth.sh` | Create | list, connect, disconnect, toggle, scan-on, scan-off |
| `.config/eww/scripts/cc/audio.sh` | Create | sinks, set-sink, apps, set-app-vol |
| `.config/eww/scripts/cc/mic.sh` | Create | sources, set-source, level, set-level |
| `.config/eww/scripts/cc/wired.sh` | Create | info, toggle |
| `.config/eww/eww.yuck` | Modify | thêm defvar cc_view/cc_pass/cc_pass_ssid và 5 list vars; router-view trong control-center-card; 5 widget panel |
| `.config/waybar/scripts/toggle-control-center.sh` | Modify | reset cc_view=home khi mở popup |
| `.config/eww/eww.css` | Modify | thêm CSS cho panel pages |

---

### Task 1: Tạo wifi.sh

**Files:**
- Create: `.config/eww/scripts/cc/wifi.sh`

- [ ] **Step 1: Tạo thư mục và file wifi.sh**

```bash
mkdir -p ~/.config/eww/scripts/cc
```

Tạo file `.config/eww/scripts/cc/wifi.sh` (trong repo, không phải ~/.config vì là symlink):

```bash
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    list)
        # In JSON mảng các mạng wifi đang quét được.
        # Trường: ssid, signal (0-100), secured (bool), active (bool)
        if nmcli radio wifi | grep -q "disabled"; then
            echo "[]"
            exit 0
        fi
        nmcli -t -f SSID,SIGNAL,SECURITY,ACTIVE dev wifi list 2>/dev/null \
            | awk -F: '
                $1 == "" { next }
                seen[$1]++ { next }
                {
                    ssid=$1; signal=$2; sec=$3; active=$4
                    gsub(/"/, "\\\"", ssid)
                    secured = (sec != "" && sec != "--") ? "true" : "false"
                    act = (active == "yes") ? "true" : "false"
                    printf "{\"ssid\":\"%s\",\"signal\":%s,\"secured\":%s,\"active\":%s}\n",
                        ssid, signal, secured, act
                }
            ' \
            | paste -sd ',' - \
            | sed 's/^/[/;s/$/]/'
        ;;
    connect)
        # Nối mạng đã biết (không cần mật khẩu)
        nmcli device wifi connect "${2}" >/dev/null 2>&1 || true
        ;;
    connect-pass)
        # Nối mạng mới với mật khẩu: connect-pass <ssid> <password>
        ssid="${2}"
        pass="${3}"
        # Xoá profile cũ hỏng nếu có (tránh lỗi "already exists")
        nmcli connection delete "${ssid}" >/dev/null 2>&1 || true
        if ! nmcli device wifi connect "${ssid}" password "${pass}" >/dev/null 2>&1; then
            # Xoá kết nối hỏng để người dùng thử lại
            nmcli connection delete "${ssid}" >/dev/null 2>&1 || true
            echo "error:wrong_password"
            exit 0
        fi
        ;;
    disconnect)
        dev=$(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2=="wifi"{print $1;exit}')
        [ -n "$dev" ] && nmcli device disconnect "$dev" >/dev/null 2>&1 || true
        ;;
    toggle)
        if nmcli radio wifi | grep -q "disabled"; then
            nmcli radio wifi on
        else
            nmcli radio wifi off
        fi
        ;;
    rescan)
        nmcli device wifi rescan >/dev/null 2>&1 || true
        ;;
    *)
        echo "Unknown: ${1:-}" >&2; exit 1 ;;
esac
```

- [ ] **Step 2: Cấp quyền thực thi và kiểm tra**

```bash
chmod +x .config/eww/scripts/cc/wifi.sh
.config/eww/scripts/cc/wifi.sh list | python3 -m json.tool
```

Kết quả mong đợi: JSON hợp lệ, ví dụ `[{"ssid":"MyHome","signal":72,...}]`

- [ ] **Step 3: Commit**

```bash
git add .config/eww/scripts/cc/wifi.sh
git commit -m "feat: thêm script wifi.sh cho panel Wi-Fi chi tiết"
```

---

### Task 2: Tạo bluetooth.sh

**Files:**
- Create: `.config/eww/scripts/cc/bluetooth.sh`

- [ ] **Step 1: Tạo file bluetooth.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    list)
        # JSON mảng thiết bị bluetooth đã biết/đang quét.
        # Trường: mac, name, connected (bool), paired (bool), battery (số hoặc -1)
        # Nếu không có thiết bị: pipe rỗng → paste → sed → "[]" — đúng, không cần check thêm.
        bluetoothctl devices 2>/dev/null \
            | awk '{mac=$2; $1=$2=""; name=substr($0,2)} mac!="" {print mac, name}' \
            | while IFS=' ' read -r mac name; do
                info=$(bluetoothctl info "$mac" 2>/dev/null)
                connected=$(echo "$info" | grep -c 'Connected: yes' || true)
                paired=$(echo "$info" | grep -c 'Paired: yes' || true)
                battery=$(echo "$info" | grep 'Battery Percentage' | grep -oP '\d+' | head -1)
                battery="${battery:--1}"
                name_esc="${name//\"/\\\"}"
                echo "{\"mac\":\"$mac\",\"name\":\"$name_esc\",\"connected\":$([ "$connected" -gt 0 ] && echo true || echo false),\"paired\":$([ "$paired" -gt 0 ] && echo true || echo false),\"battery\":$battery}"
              done \
            | paste -sd ',' - \
            | sed 's/^/[/;s/$/]/'
        ;;
    connect)
        bluetoothctl connect "${2}" >/dev/null 2>&1 || true
        ;;
    disconnect)
        bluetoothctl disconnect "${2}" >/dev/null 2>&1 || true
        ;;
    toggle)
        if bluetoothctl show | grep -q 'Powered: yes'; then
            bluetoothctl power off >/dev/null 2>&1
        else
            bluetoothctl power on >/dev/null 2>&1
        fi
        ;;
    scan-on)
        bluetoothctl scan on >/dev/null 2>&1 &
        ;;
    scan-off)
        bluetoothctl scan off >/dev/null 2>&1 || true
        ;;
    *)
        echo "Unknown: ${1:-}" >&2; exit 1 ;;
esac
```

- [ ] **Step 2: Cấp quyền và kiểm tra**

```bash
chmod +x .config/eww/scripts/cc/bluetooth.sh
.config/eww/scripts/cc/bluetooth.sh list | python3 -m json.tool
```

Kết quả: JSON hợp lệ (có thể `[]` nếu chưa pair thiết bị nào).

- [ ] **Step 3: Commit**

```bash
git add .config/eww/scripts/cc/bluetooth.sh
git commit -m "feat: thêm script bluetooth.sh cho panel Bluetooth chi tiết"
```

---

### Task 3: Tạo audio.sh

**Files:**
- Create: `.config/eww/scripts/cc/audio.sh`

- [ ] **Step 1: Tạo file audio.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    sinks)
        # JSON mảng thiết bị âm thanh ra (sink).
        # Trường: id (số), name (chuỗi), default (bool)
        default_sink=$(pactl get-default-sink 2>/dev/null || true)
        pactl list sinks 2>/dev/null \
            | awk -v default_sink="$default_sink" '
                /^Sink #/ { id=substr($2,2); name=""; desc="" }
                /^\tName:/ { name=$2 }
                /^\tDescription:/ { $1=""; desc=substr($0,2) }
                /^\tState:/ && name!="" {
                    gsub(/"/, "\\\"", desc)
                    is_default = (name == default_sink) ? "true" : "false"
                    printf "{\"id\":%s,\"name\":\"%s\",\"default\":%s}\n",
                        id, desc, is_default
                }
            ' \
            | paste -sd ',' - \
            | sed 's/^/[/;s/$/]/'
        ;;
    set-sink)
        pactl set-default-sink "${2}" >/dev/null 2>&1
        # Di chuyển tất cả sink-input sang sink mới
        pactl list sink-inputs 2>/dev/null \
            | grep 'Sink Input #' \
            | grep -oP '\d+' \
            | while read -r input_id; do
                pactl move-sink-input "$input_id" "${2}" >/dev/null 2>&1 || true
              done
        ;;
    apps)
        # JSON mảng ứng dụng đang phát âm thanh (sink-inputs).
        # Trường: id (số), name (chuỗi), volume (0-100)
        pactl list sink-inputs 2>/dev/null \
            | awk '
                /^Sink Input #/ { id=substr($3,2); name=""; vol=0 }
                /application\.name =/ {
                    match($0, /"([^"]+)"/, arr); name=arr[1]
                }
                /Volume:/ && /front-left/ {
                    match($0, /([0-9]+)%/, arr); vol=arr[1]
                }
                /Corked:/ && name!="" {
                    gsub(/"/, "\\\"", name)
                    printf "{\"id\":%s,\"name\":\"%s\",\"volume\":%s}\n",
                        id, name, vol
                    name=""
                }
            ' \
            | paste -sd ',' - \
            | sed 's/^/[/;s/$/]/'
        ;;
    set-app-vol)
        # set-app-vol <sink-input-id> <volume-percent>
        pactl set-sink-input-volume "${2}" "${3}%" >/dev/null 2>&1
        ;;
    *)
        echo "Unknown: ${1:-}" >&2; exit 1 ;;
esac
```

- [ ] **Step 2: Cấp quyền và kiểm tra**

```bash
chmod +x .config/eww/scripts/cc/audio.sh
.config/eww/scripts/cc/audio.sh sinks | python3 -m json.tool
.config/eww/scripts/cc/audio.sh apps | python3 -m json.tool
```

Kết quả: JSON hợp lệ. `sinks` phải có ít nhất 1 sink; `apps` có thể `[]`.

- [ ] **Step 3: Commit**

```bash
git add .config/eww/scripts/cc/audio.sh
git commit -m "feat: thêm script audio.sh cho panel Âm thanh chi tiết"
```

---

### Task 4: Tạo mic.sh

**Files:**
- Create: `.config/eww/scripts/cc/mic.sh`

- [ ] **Step 1: Tạo file mic.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    sources)
        # JSON mảng thiết bị thu âm (source), bỏ qua monitor.
        # Trường: id (số), name (chuỗi), default (bool)
        default_src=$(pactl get-default-source 2>/dev/null || true)
        pactl list sources 2>/dev/null \
            | awk -v default_src="$default_src" '
                /^Source #/ { id=substr($2,2); name=""; desc=""; is_monitor=0 }
                /^\tName:/ { name=$2; if (name ~ /\.monitor$/) is_monitor=1 }
                /^\tDescription:/ { $1=""; desc=substr($0,2) }
                /^\tState:/ && name!="" && !is_monitor {
                    gsub(/"/, "\\\"", desc)
                    is_default = (name == default_src) ? "true" : "false"
                    printf "{\"id\":%s,\"name\":\"%s\",\"default\":%s}\n",
                        id, desc, is_default
                }
            ' \
            | paste -sd ',' - \
            | sed 's/^/[/;s/$/]/'
        ;;
    set-source)
        pactl set-default-source "${2}" >/dev/null 2>&1
        ;;
    level)
        wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | awk '{printf "%.0f\n", $2*100}'
        ;;
    set-level)
        wpctl set-volume @DEFAULT_AUDIO_SOURCE@ "${2}%"
        ;;
    *)
        echo "Unknown: ${1:-}" >&2; exit 1 ;;
esac
```

- [ ] **Step 2: Cấp quyền và kiểm tra**

```bash
chmod +x .config/eww/scripts/cc/mic.sh
.config/eww/scripts/cc/mic.sh sources | python3 -m json.tool
.config/eww/scripts/cc/mic.sh level
```

Kết quả: JSON hợp lệ và số 0-100.

- [ ] **Step 3: Commit**

```bash
git add .config/eww/scripts/cc/mic.sh
git commit -m "feat: thêm script mic.sh cho panel Micro chi tiết"
```

---

### Task 5: Tạo wired.sh

**Files:**
- Create: `.config/eww/scripts/cc/wired.sh`

- [ ] **Step 1: Tạo file wired.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Tìm thiết bị ethernet vật lý, bỏ qua veth/docker và unmanaged
_get_dev() {
    nmcli -t -f DEVICE,TYPE,STATE device \
        | awk -F: '$2=="ethernet" && $3!="unmanaged" && $1 !~ /^veth/ {print $1; exit}'
}

case "${1:-}" in
    info)
        # JSON object: state, device, ip, gateway, speed
        dev=$(_get_dev)
        if [ -z "$dev" ]; then
            echo '{"state":"unavailable","device":"","ip":"","gateway":"","speed":""}'
            exit 0
        fi
        state=$(nmcli -t -f DEVICE,STATE device | grep "^${dev}:" | cut -d: -f2)
        ip=$(ip -4 addr show "$dev" 2>/dev/null | grep -oP '(?<=inet )[^/]+' | head -1 || true)
        gw=$(ip route show dev "$dev" 2>/dev/null | grep 'default' | awk '{print $3}' | head -1 || true)
        speed=$(cat "/sys/class/net/${dev}/speed" 2>/dev/null || echo "")
        echo "{\"state\":\"${state:-disconnected}\",\"device\":\"${dev}\",\"ip\":\"${ip:-}\",\"gateway\":\"${gw:-}\",\"speed\":\"${speed:-}\"}"
        ;;
    toggle)
        dev=$(_get_dev)
        [ -z "$dev" ] && exit 0
        if nmcli -t -f DEVICE,STATE device | grep -q "^${dev}:connected"; then
            nmcli device disconnect "$dev" >/dev/null 2>&1
        else
            nmcli device connect "$dev" >/dev/null 2>&1
        fi
        ;;
    *)
        echo "Unknown: ${1:-}" >&2; exit 1 ;;
esac
```

- [ ] **Step 2: Cấp quyền và kiểm tra**

```bash
chmod +x .config/eww/scripts/cc/wired.sh
.config/eww/scripts/cc/wired.sh info | python3 -m json.tool
```

Kết quả: JSON hợp lệ với trường state là "connected" hoặc "disconnected".

- [ ] **Step 3: Commit**

```bash
git add .config/eww/scripts/cc/wired.sh
git commit -m "feat: thêm script wired.sh cho panel Mạng dây chi tiết"
```

---

### Task 6: Thêm defvar và defpoll vào eww.yuck

**Files:**
- Modify: `.config/eww/eww.yuck` — thêm biến router-view và list vars sau dòng `(defpoll bri_level ...)`

- [ ] **Step 1: Thêm defvar vào eww.yuck**

Thêm đoạn sau vào cuối phần biến (sau `(defpoll bri_level ...)`, trước `(defwindow control-center-popup ...)`):

```yuck
;; ── Router-view: trang đang hiển thị trong control center ──
(defvar cc_view "home")
;; Đệm mật khẩu Wi-Fi (chỉ dùng khi cc_pass_ssid != "")
(defvar cc_pass "")
;; SSID đang chờ nhập mật khẩu; "" = không hiện ô nhập
(defvar cc_pass_ssid "")
;; Thông báo lỗi tạm (ví dụ "Sai mật khẩu")
(defvar cc_wifi_error "")

;; Danh sách dữ liệu các panel — nạp theo yêu cầu (không poll)
(defvar wifi_list "[]")
(defvar bt_list "[]")
(defvar audio_sinks "[]")
(defvar audio_apps "[]")
(defvar mic_sources "[]")
(defvar wired_info "{\"state\":\"unknown\",\"device\":\"\",\"ip\":\"\",\"gateway\":\"\",\"speed\":\"\"}")
;; Mức micro hiện tại (0-100) — nạp khi vào panel mic
(defvar mic_level "50")
```

- [ ] **Step 2: Reload và kiểm tra không lỗi parse**

```bash
~/.local/bin/eww --config ~/.config/eww reload 2>&1 | head -20
```

Không có dòng `ERROR` hoặc `parse error`.

- [ ] **Step 3: Commit**

```bash
git add .config/eww/eww.yuck
git commit -m "feat: thêm defvar router-view và list vars vào eww.yuck"
```

---

### Task 7: Thêm 5 widget panel vào eww.yuck

**Files:**
- Modify: `.config/eww/eww.yuck` — thêm 5 widget trước widget `control-center-card`

- [ ] **Step 1: Thêm widget wifi-page**

Thêm đoạn sau (trước `(defwidget control-center-card [])`):

```yuck
;; ── Panel: Wi-Fi ──
(defwidget wifi-page []
  (box :class "cc-page" :orientation "vertical" :space-evenly false
    ;; Header
    (box :class "cc-page-header" :orientation "horizontal" :space-evenly false
      (button :class "cc-back-btn"
              :onclick "eww --config ~/.config/eww update cc_view=home cc_pass='' cc_pass_ssid='' cc_wifi_error=''"
              "‹ Quay lại")
      (label :class "cc-page-title" :hexpand true :halign "center" :text "Wi-Fi")
      (button :class "cc-rescan-btn"
              :onclick "~/.config/eww/scripts/cc/wifi.sh rescan & sleep 1 && eww --config ~/.config/eww update wifi_list=\"$(~/.config/eww/scripts/cc/wifi.sh list)\""
              "⟳"))
    ;; Công tắc Wi-Fi on/off
    (box :class "cc-section-row" :orientation "horizontal" :space-evenly false
      (label :class "cc-section-label" :hexpand true :text "Wi-Fi")
      (button :class {wifi_state == "on" ? "cc-switch on" : "cc-switch off"}
              :onclick "~/.config/eww/scripts/cc/wifi.sh toggle && ~/.config/eww/scripts/control_center.sh refresh"
              {wifi_state == "on" ? "Bật" : "Tắt"}))
    ;; Thông báo lỗi (nếu có)
    (revealer :reveal {cc_wifi_error != ""} :transition "slidedown"
      (label :class "cc-error-label" :text cc_wifi_error))
    ;; Danh sách mạng (scroll)
    (scroll :vscroll true :class "cc-list"
      (box :orientation "vertical" :space-evenly false
        (for net in wifi_list
          (box :orientation "vertical" :space-evenly false
            ;; Hàng mạng
            (button :class {net.active ? "cc-list-row active" : "cc-list-row"}
                    :onclick {net.active
                        ? "~/.config/eww/scripts/cc/wifi.sh disconnect && sleep 0.5 && eww --config ~/.config/eww update wifi_list=\"$(~/.config/eww/scripts/cc/wifi.sh list)\" && ~/.config/eww/scripts/control_center.sh refresh"
                        : net.secured
                            ? "eww --config ~/.config/eww update cc_pass_ssid='${net.ssid}' cc_pass='' cc_wifi_error=''"
                            : "~/.config/eww/scripts/cc/wifi.sh connect '${net.ssid}' & sleep 1 && eww --config ~/.config/eww update wifi_list=\"$(~/.config/eww/scripts/cc/wifi.sh list)\" && ~/.config/eww/scripts/control_center.sh refresh"}
              (box :orientation "horizontal" :space-evenly false
                (label :class "cc-signal"
                       :text {net.signal >= 75 ? "󰤨" : net.signal >= 50 ? "󰤥" : net.signal >= 25 ? "󰤢" : "󰤟"})
                (label :class "cc-net-name" :hexpand true :halign "start" :limit-width 20 :text {net.ssid})
                (label :class "cc-lock" :visible {net.secured} :text "")
                (label :class "cc-active-dot" :visible {net.active} :text "●")))
            ;; Ô nhập mật khẩu (chỉ hiện khi bấm vào mạng này)
            (revealer :reveal {cc_pass_ssid == net.ssid} :transition "slidedown"
              (box :class "cc-pass-row" :orientation "horizontal" :space-evenly false
                (input :class "cc-pass-input" :hexpand true
                       :placeholder "Mật khẩu Wi-Fi"
                       :onchange "eww --config ~/.config/eww update cc_pass={}")
                (button :class "cc-connect-btn"
                        :onclick "result=$(~/.config/eww/scripts/cc/wifi.sh connect-pass '${net.ssid}' \"$cc_pass\"); if [ \"$result\" = 'error:wrong_password' ]; then eww --config ~/.config/eww update cc_wifi_error='Sai mật khẩu, thử lại'; else eww --config ~/.config/eww update cc_pass_ssid='' cc_pass='' cc_wifi_error=''; sleep 1; eww --config ~/.config/eww update wifi_list=\"$(~/.config/eww/scripts/cc/wifi.sh list)\"; ~/.config/eww/scripts/control_center.sh refresh; fi"
                        "Nối")))))))
    ;; Nâng cao
    (button :class "cc-advanced-btn" :onclick "nm-connection-editor &" "Cài đặt nâng cao…")))
```

- [ ] **Step 2: Thêm widget bluetooth-page**

Thêm tiếp (sau wifi-page):

```yuck
;; ── Panel: Bluetooth ──
(defwidget bluetooth-page []
  (box :class "cc-page" :orientation "vertical" :space-evenly false
    (box :class "cc-page-header" :orientation "horizontal" :space-evenly false
      (button :class "cc-back-btn"
              :onclick "~/.config/eww/scripts/cc/bluetooth.sh scan-off; eww --config ~/.config/eww update cc_view=home"
              "‹ Quay lại")
      (label :class "cc-page-title" :hexpand true :halign "center" :text "Bluetooth")
      (button :class "cc-rescan-btn"
              :onclick "eww --config ~/.config/eww update bt_list=\"$(~/.config/eww/scripts/cc/bluetooth.sh list)\""
              "⟳"))
    (box :class "cc-section-row" :orientation "horizontal" :space-evenly false
      (label :class "cc-section-label" :hexpand true :text "Bluetooth")
      (button :class {bt_state == "on" ? "cc-switch on" : "cc-switch off"}
              :onclick "~/.config/eww/scripts/cc/bluetooth.sh toggle && ~/.config/eww/scripts/control_center.sh refresh"
              {bt_state == "on" ? "Bật" : "Tắt"}))
    (scroll :vscroll true :class "cc-list"
      (box :orientation "vertical" :space-evenly false
        (for dev in bt_list
          (button :class {dev.connected ? "cc-list-row active" : "cc-list-row"}
                  :onclick {dev.connected
                      ? "~/.config/eww/scripts/cc/bluetooth.sh disconnect '${dev.mac}' && sleep 0.5 && eww --config ~/.config/eww update bt_list=\"$(~/.config/eww/scripts/cc/bluetooth.sh list)\""
                      : "~/.config/eww/scripts/cc/bluetooth.sh connect '${dev.mac}' && sleep 1 && eww --config ~/.config/eww update bt_list=\"$(~/.config/eww/scripts/cc/bluetooth.sh list)\""}
            (box :orientation "horizontal" :space-evenly false
              (label :class "cc-bt-icon" :text "")
              (label :class "cc-net-name" :hexpand true :halign "start" :limit-width 22 :text {dev.name})
              (label :class "cc-battery" :visible {dev.battery >= 0} :text {"🔋" + dev.battery + "%"})
              (label :class "cc-active-dot" :visible {dev.connected} :text "●"))))))
    (button :class "cc-advanced-btn" :onclick "blueman-manager &" "Nâng cao…")))
```

- [ ] **Step 3: Thêm widget audio-page**

```yuck
;; ── Panel: Âm thanh ──
(defwidget audio-page []
  (box :class "cc-page" :orientation "vertical" :space-evenly false
    (box :class "cc-page-header" :orientation "horizontal" :space-evenly false
      (button :class "cc-back-btn"
              :onclick "eww --config ~/.config/eww update cc_view=home"
              "‹ Quay lại")
      (label :class "cc-page-title" :hexpand true :halign "center" :text "Âm thanh"))
    ;; Thiết bị ra (sinks)
    (label :class "cc-subsection-label" :halign "start" :text "Thiết bị ra")
    (scroll :vscroll true :class "cc-list cc-list-short"
      (box :orientation "vertical" :space-evenly false
        (for sink in audio_sinks
          (button :class {sink.default ? "cc-list-row active" : "cc-list-row"}
                  :onclick "~/.config/eww/scripts/cc/audio.sh set-sink '${sink.id}' && sleep 0.2 && eww --config ~/.config/eww update audio_sinks=\"$(~/.config/eww/scripts/cc/audio.sh sinks)\""
            (box :orientation "horizontal" :space-evenly false
              (label :class "cc-net-name" :hexpand true :halign "start" :limit-width 25 :text {sink.name})
              (label :class "cc-active-dot" :visible {sink.default} :text "●"))))))
    ;; Âm lượng tổng
    (label :class "cc-subsection-label" :halign "start" :text "Âm lượng")
    (box :class "slider-row" :orientation "horizontal" :space-evenly false
      (label :class "slider-icon vol" :text {vol_muted == "on" ? "󰝟" : ""})
      (scale :class "slider vol" :value {vol_muted == "on" ? 0 : vol_level}
             :min 0 :max 100
             :onchange "~/.config/eww/scripts/control_center.sh set-vol {}"))
    ;; Âm lượng từng app
    (label :class "cc-subsection-label" :halign "start" :text "Ứng dụng")
    (scroll :vscroll true :class "cc-list cc-list-short"
      (box :orientation "vertical" :space-evenly false
        (for app in audio_apps
          (box :class "app-vol-row" :orientation "horizontal" :space-evenly false
            (label :class "cc-net-name" :hexpand true :halign "start" :limit-width 18 :text {app.name})
            (scale :class "slider app-vol" :value {app.volume}
                   :min 0 :max 100
                   :onchange "~/.config/eww/scripts/cc/audio.sh set-app-vol '${app.id}' {}")))))
    (button :class "cc-advanced-btn" :onclick "pavucontrol &" "Nâng cao…")))
```

- [ ] **Step 4: Thêm widget mic-page**

```yuck
;; ── Panel: Micro ──
(defwidget mic-page []
  (box :class "cc-page" :orientation "vertical" :space-evenly false
    (box :class "cc-page-header" :orientation "horizontal" :space-evenly false
      (button :class "cc-back-btn"
              :onclick "eww --config ~/.config/eww update cc_view=home"
              "‹ Quay lại")
      (label :class "cc-page-title" :hexpand true :halign "center" :text "Micro"))
    ;; Thiết bị thu (sources)
    (label :class "cc-subsection-label" :halign "start" :text "Thiết bị thu")
    (scroll :vscroll true :class "cc-list cc-list-short"
      (box :orientation "vertical" :space-evenly false
        (for src in mic_sources
          (button :class {src.default ? "cc-list-row active" : "cc-list-row"}
                  :onclick "~/.config/eww/scripts/cc/mic.sh set-source '${src.id}' && sleep 0.2 && eww --config ~/.config/eww update mic_sources=\"$(~/.config/eww/scripts/cc/mic.sh sources)\""
            (box :orientation "horizontal" :space-evenly false
              (label :class "cc-net-name" :hexpand true :halign "start" :limit-width 25 :text {src.name})
              (label :class "cc-active-dot" :visible {src.default} :text "●"))))))
    ;; Mức micro + mute
    (label :class "cc-subsection-label" :halign "start" :text "Mức micro")
    (box :class "slider-row" :orientation "horizontal" :space-evenly false
      (button :class "cc-mute-btn"
              :onclick "~/.config/eww/scripts/control_center.sh mic-toggle && ~/.config/eww/scripts/control_center.sh refresh"
              {mic_muted == "on" ? "" : ""})
      (scale :class "slider mic-vol" :value {mic_muted == "on" ? 0 : mic_level}
             :min 0 :max 100
             :onchange "~/.config/eww/scripts/cc/mic.sh set-level {}"))
    (button :class "cc-advanced-btn" :onclick "pavucontrol &" "Nâng cao…")))
```

- [ ] **Step 5: Thêm widget wired-page**

```yuck
;; ── Panel: Mạng dây ──
(defwidget wired-page []
  (box :class "cc-page" :orientation "vertical" :space-evenly false
    (box :class "cc-page-header" :orientation "horizontal" :space-evenly false
      (button :class "cc-back-btn"
              :onclick "eww --config ~/.config/eww update cc_view=home"
              "‹ Quay lại")
      (label :class "cc-page-title" :hexpand true :halign "center" :text "Mạng dây"))
    ;; Thông tin thiết bị
    (box :class "cc-info-card" :orientation "vertical" :space-evenly false
      (box :class "cc-info-row" :orientation "horizontal"
        (label :class "cc-info-key" :text "Trạng thái")
        (label :class "cc-info-val" :hexpand true :halign "end" :text {wired_info.state}))
      (box :class "cc-info-row" :orientation "horizontal"
        (label :class "cc-info-key" :text "Thiết bị")
        (label :class "cc-info-val" :hexpand true :halign "end" :text {wired_info.device}))
      (box :class "cc-info-row" :orientation "horizontal"
        (label :class "cc-info-key" :text "IP")
        (label :class "cc-info-val" :hexpand true :halign "end" :text {wired_info.ip ?: "—"}))
      (box :class "cc-info-row" :orientation "horizontal"
        (label :class "cc-info-key" :text "Gateway")
        (label :class "cc-info-val" :hexpand true :halign "end" :text {wired_info.gateway ?: "—"}))
      (box :class "cc-info-row" :orientation "horizontal"
        (label :class "cc-info-key" :text "Tốc độ")
        (label :class "cc-info-val" :hexpand true :halign "end"
               :text {wired_info.speed != "" ? wired_info.speed + " Mbps" : "—"})))
    ;; Nút connect/disconnect
    (button :class {wired_state == "on" ? "cc-wired-btn disconnect" : "cc-wired-btn connect"}
            :onclick "~/.config/eww/scripts/cc/wired.sh toggle && sleep 0.5 && eww --config ~/.config/eww update wired_info=\"$(~/.config/eww/scripts/cc/wired.sh info)\" && ~/.config/eww/scripts/control_center.sh refresh"
            {wired_state == "on" ? "Ngắt kết nối" : "Kết nối"})
    (button :class "cc-advanced-btn" :onclick "nm-connection-editor &" "Cài đặt nâng cao…")))
```

- [ ] **Step 6: Reload và kiểm tra parse**

```bash
~/.local/bin/eww --config ~/.config/eww reload 2>&1 | head -20
```

Không có `ERROR`.

- [ ] **Step 7: Commit**

```bash
git add .config/eww/eww.yuck
git commit -m "feat: thêm 5 widget panel chi tiết vào eww.yuck"
```

---

### Task 8: Cập nhật control-center-card — router-view

**Files:**
- Modify: `.config/eww/eww.yuck` — thay body của `control-center-card` bằng router-view

- [ ] **Step 1: Wrap nội dung home trong stack-like reveal**

Tìm widget `(defwidget control-center-card []` và thay toàn bộ body:

```yuck
(defwidget control-center-card []
  (box :class "control-center-card" :orientation "vertical" :space-evenly false
    ;; Router: chọn trang theo cc_view
    (revealer :reveal {cc_view == "home"} :transition "none" :duration 0
      (box :orientation "vertical" :space-evenly false
        ;; Phần đầu (Header): Đồng hồ lớn & Ngày tháng & Icon trạng thái mạng dây ở bên phải
        (box :class "cc-header" :orientation "horizontal" :space-evenly true
          (box :class "cc-header-left" :orientation "vertical" :space-evenly false :halign "start"
            (box :class "cc-clock" :orientation "horizontal" :space-evenly false
              (label :class "cc-time" :text time_hour)
              (label :class "cc-sep" :text "|")
              (label :class "cc-time" :text time_min))
            (label :class "cc-date" :text time_date))
          (box :class "cc-header-right" :halign "end" :valign "start"
            (label :class {wired_state == "on" ? "cc-moon active" : "cc-moon"} :text "\u{F0AC}")))

        ;; Lưới nút bật/tắt nhanh (3 cột x 2 hàng)
        (box :class "cc-grid" :orientation "vertical" :space-evenly true
          (box :orientation "horizontal" :space-evenly true
            ;; Nút bật/tắt Wifi
            (box :class "toggle-container" :orientation "vertical" :space-evenly false
              (box :class {wifi_state == "on" ? "toggle-btn active" : "toggle-btn"} :orientation "horizontal" :space-evenly false
                (button :class "toggle-main" :onclick "~/.config/eww/scripts/control_center.sh wifi-toggle && ~/.config/eww/scripts/control_center.sh refresh"
                  (label :text {wifi_state == "on" ? "\u{F1EB}" : "\u{F092A}"}))
                (box :class "toggle-divider")
                (button :class "toggle-arrow"
                        :onclick "eww --config ~/.config/eww update cc_view=wifi wifi_list=\"$(~/.config/eww/scripts/cc/wifi.sh list)\""
                        "›"))
              (label :class "toggle-label" :limit-width 12 :text wifi_ssid))

            ;; Nút bật/tắt Bluetooth
            (box :class "toggle-container" :orientation "vertical" :space-evenly false
              (box :class {bt_state == "on" ? "toggle-btn active" : "toggle-btn"} :orientation "horizontal" :space-evenly false
                (button :class "toggle-main" :onclick "~/.config/eww/scripts/control_center.sh bt-toggle && ~/.config/eww/scripts/control_center.sh refresh"
                  (label :text "\u{F0294}"))
                (box :class "toggle-divider")
                (button :class "toggle-arrow"
                        :onclick "eww --config ~/.config/eww update cc_view=bluetooth bt_list=\"$(~/.config/eww/scripts/cc/bluetooth.sh list)\"; ~/.config/eww/scripts/cc/bluetooth.sh scan-on"
                        "›"))
              (label :class "toggle-label" :text "Bluetooth"))

            ;; Nút bật/tắt Chế độ máy bay (không có panel chi tiết)
            (box :class "toggle-container" :orientation "vertical" :space-evenly false
              (box :class {airplane_state == "on" ? "toggle-btn active" : "toggle-btn"} :orientation "horizontal" :space-evenly false
                (button :class "toggle-main" :onclick "~/.config/eww/scripts/control_center.sh airplane-toggle && ~/.config/eww/scripts/control_center.sh refresh"
                  (label :text "\u{F072}"))
                (box :class "toggle-divider")
                (button :class "toggle-arrow" :onclick "" "›"))
              (label :class "toggle-label" :text "Airplane")))

          (box :orientation "horizontal" :space-evenly true
            ;; Nút bật/tắt Mạng dây (Ethernet)
            (box :class "toggle-container" :orientation "vertical" :space-evenly false
              (box :class {wired_state == "on" ? "toggle-btn active" : "toggle-btn"} :orientation "horizontal" :space-evenly false
                (button :class "toggle-main" :onclick "~/.config/eww/scripts/control_center.sh wired-toggle && ~/.config/eww/scripts/control_center.sh refresh"
                  (label :text "\u{F0AC}"))
                (box :class "toggle-divider")
                (button :class "toggle-arrow"
                        :onclick "eww --config ~/.config/eww update cc_view=wired wired_info=\"$(~/.config/eww/scripts/cc/wired.sh info)\""
                        "›"))
              (label :class "toggle-label" :text "Mạng dây"))

            ;; Nút bật/tắt Âm lượng (Volume)
            (box :class "toggle-container" :orientation "vertical" :space-evenly false
              (box :class {vol_muted == "off" ? "toggle-btn active" : "toggle-btn"} :orientation "horizontal" :space-evenly false
                (button :class "toggle-main" :onclick "~/.config/eww/scripts/control_center.sh vol-toggle && ~/.config/eww/scripts/control_center.sh refresh"
                  (label :text {vol_muted == "on" ? "\u{F075F}" : "\u{F028}"}))
                (box :class "toggle-divider")
                (button :class "toggle-arrow"
                        :onclick "eww --config ~/.config/eww update cc_view=audio audio_sinks=\"$(~/.config/eww/scripts/cc/audio.sh sinks)\" audio_apps=\"$(~/.config/eww/scripts/cc/audio.sh apps)\""
                        "›"))
              (label :class "toggle-label" :text "Volume"))

            ;; Nút bật/tắt Micro
            (box :class "toggle-container" :orientation "vertical" :space-evenly false
              (box :class {mic_muted == "off" ? "toggle-btn active" : "toggle-btn"} :orientation "horizontal" :space-evenly false
                (button :class "toggle-main" :onclick "~/.config/eww/scripts/control_center.sh mic-toggle && ~/.config/eww/scripts/control_center.sh refresh"
                  (label :text {mic_muted == "on" ? "\u{F0E23}" : "\u{F0E22}"}))
                (box :class "toggle-divider")
                (button :class "toggle-arrow"
                        :onclick "eww --config ~/.config/eww update cc_view=mic mic_sources=\"$(~/.config/eww/scripts/cc/mic.sh sources)\" mic_level=\"$(~/.config/eww/scripts/cc/mic.sh level)\""
                        "›"))
              (label :class "toggle-label" :text "Micro"))))

        ;; Thanh trượt (Sliders) cho Âm lượng và Độ sáng
        (box :class "cc-sliders" :orientation "vertical" :space-evenly false
          (box :class "slider-row" :orientation "horizontal" :space-evenly false
            (label :class "slider-icon vol" :text {vol_muted == "on" ? "\u{F075F}" : "\u{F028}"})
            (scale :class "slider vol" :value {vol_muted == "on" ? 0 : vol_level} :min 0 :max 100 :onchange "~/.config/eww/scripts/control_center.sh set-vol {}"))
          (box :class "slider-row" :orientation "horizontal" :space-evenly false
            (label :class "slider-icon bri" :text "\u{F00DE}")
            (scale :class "slider bri" :value bri_level :min 10 :max 100 :onchange "~/.config/eww/scripts/control_center.sh set-bri {}")))

        ;; Phần chân trang (Footer)
        (box :class "cc-footer" :orientation "horizontal" :space-evenly true
          (box :halign "start")
          (box :class "power-box" :orientation "horizontal" :space-evenly false :halign "end"
            (button :class "power-btn shutdown" :onclick "systemctl poweroff" "\u{F0425}")
            (button :class "power-btn reboot" :onclick "systemctl reboot" "\u{F0453}")
            (button :class "power-btn logout" :onclick "swaymsg exit" "\u{F0343}")))))

    ;; Pages chi tiết
    (revealer :reveal {cc_view == "wifi"} :transition "none" :duration 0
      (wifi-page))
    (revealer :reveal {cc_view == "bluetooth"} :transition "none" :duration 0
      (bluetooth-page))
    (revealer :reveal {cc_view == "audio"} :transition "none" :duration 0
      (audio-page))
    (revealer :reveal {cc_view == "mic"} :transition "none" :duration 0
      (mic-page))
    (revealer :reveal {cc_view == "wired"} :transition "none" :duration 0
      (wired-page))))
```

**Lưu ý:** Tất cả glyph phải dùng cú pháp `\u{XXXX}` trong yuck string. Kiểm tra bảng codepoint sau:
- Wi-Fi on: `\u{F1EB}` (󰇫), off: `\u{F092A}` (󰤪)
- Bluetooth: `\u{F0294}` (󰊔)
- Airplane: `\u{F072}` (✈)
- Ethernet/wired: `\u{F0AC}` (󰂬)
- Volume on: `\u{F028}` (🔊), muted: `\u{F075F}` (󰝟)
- Mic on: `\u{F0E22}` (󰸢), off: `\u{F0E23}` (󰸣)
- Brightness: `\u{F00DE}` (󰃞)
- Shutdown: `\u{F0425}` (󰐥), Reboot: `\u{F0453}` (󰑓), Logout: `\u{F0343}` (󰍃)

**Quan trọng:** Trong eww yuck, chuỗi unicode literal `\u{XXXX}` chỉ được hỗ trợ trong `(label :text "...")`. Nếu eww version không hỗ trợ, dùng perl để inject glyph sau khi tạo file:
```bash
# Ví dụ inject F1EB (wifi on):
perl -CSD -i -pe 's/\\u\{F1EB\}/\x{F1EB}/g' .config/eww/eww.yuck
```
Hoặc giữ nguyên glyph từ widget cũ (copy từ dòng `:text ""` hiện có trong file).

- [ ] **Step 2: Reload và kiểm tra**

```bash
~/.local/bin/eww --config ~/.config/eww reload 2>&1 | head -20
```

- [ ] **Step 3: Mở popup và xác nhận home còn đúng**

```bash
~/.config/waybar/scripts/toggle-control-center.sh
```

Kiểm tra popup mở bình thường, home layout OK.

- [ ] **Step 4: Commit**

```bash
git add .config/eww/eww.yuck
git commit -m "feat: router-view trong control-center-card, mũi tên mở panel chi tiết"
```

---

### Task 9: Reset cc_view=home khi mở popup

**Files:**
- Modify: `.config/waybar/scripts/toggle-control-center.sh`

- [ ] **Step 1: Thêm reset trước lệnh open**

Tìm đoạn `else` trong toggle script, thêm `eww update` TRƯỚC lệnh `open`:

```bash
else
    # Reset về trang home và xoá trạng thái nhập mật khẩu trước khi mở
    "$EWW_BIN" --config "$CONFIG_DIR" update \
        cc_view=home cc_pass="" cc_pass_ssid="" cc_wifi_error="" 2>/dev/null || true
    # Mở popup chính TRƯỚC, rồi mới mở closer.
    "$EWW_BIN" --config "$CONFIG_DIR" open "$WINDOW" --arg monitor="$MONITOR"
    "$EWW_BIN" --config "$CONFIG_DIR" open "$CLOSER_WINDOW" --arg monitor="$MONITOR" || true
fi
```

- [ ] **Step 2: Kiểm tra: mở từ panel, đóng, mở lại → về home**

```bash
# Mở CC
~/.config/waybar/scripts/toggle-control-center.sh
# Chuyển sang wifi panel
~/.local/bin/eww --config ~/.config/eww update cc_view=wifi
# Đóng CC
~/.config/waybar/scripts/toggle-control-center.sh
# Mở lại → phải hiện home
~/.config/waybar/scripts/toggle-control-center.sh
~/.local/bin/eww --config ~/.config/eww get cc_view
```

Output: `home`

- [ ] **Step 3: Commit**

```bash
git add .config/waybar/scripts/toggle-control-center.sh
git commit -m "feat: reset cc_view về home khi mở lại control center"
```

---

### Task 10: Thêm CSS cho các panel

**Files:**
- Modify: `.config/eww/eww.css`

- [ ] **Step 1: Append CSS cho panel pages vào eww.css**

Thêm đoạn sau vào cuối file `.config/eww/eww.css`:

```css
/* ── Panel chi tiết (router-view pages) ── */

.cc-page {
  padding: 4px 0;
}

.cc-page-header {
  padding: 8px 4px 16px 4px;
  border-bottom: 1px solid #313244;
  margin-bottom: 12px;
}

.cc-back-btn {
  font-size: 13px;
  color: #89b4fa;
  padding: 4px 10px;
  border-radius: 8px;
  min-width: 80px;
}

.cc-back-btn:hover {
  background: #313244;
}

.cc-page-title {
  font-size: 16px;
  font-weight: 700;
  color: #cdd6f4;
}

.cc-rescan-btn {
  font-size: 16px;
  color: #a6adc8;
  padding: 4px 8px;
  border-radius: 8px;
  min-width: 32px;
}

.cc-rescan-btn:hover {
  background: #313244;
  color: #89b4fa;
}

/* Hàng công tắc on/off trong panel */
.cc-section-row {
  padding: 8px 4px;
  margin-bottom: 8px;
}

.cc-section-label {
  font-size: 14px;
  font-weight: 600;
  color: #cdd6f4;
}

.cc-subsection-label {
  font-size: 12px;
  font-weight: 600;
  color: #a6adc8;
  padding: 8px 4px 4px 4px;
}

/* Nút switch on/off nhỏ */
.cc-switch {
  font-size: 12px;
  font-weight: 600;
  padding: 4px 12px;
  border-radius: 12px;
}

.cc-switch.on {
  background: #89b4fa;
  color: #1e1e2e;
}

.cc-switch.off {
  background: #313244;
  color: #a6adc8;
}

/* Danh sách cuộn */
.cc-list {
  min-height: 160px;
  max-height: 200px;
  margin-bottom: 8px;
}

.cc-list-short {
  min-height: 80px;
  max-height: 120px;
}

/* Từng hàng trong danh sách */
.cc-list-row {
  padding: 10px 12px;
  border-radius: 12px;
  margin-bottom: 4px;
}

.cc-list-row:hover {
  background: #313244;
}

.cc-list-row.active {
  background: rgba(137, 180, 250, 0.15);
  border: 1px solid #89b4fa;
}

/* Icon sóng wifi */
.cc-signal {
  font-size: 16px;
  color: #a6adc8;
  margin-right: 10px;
  min-width: 20px;
}

.cc-list-row.active .cc-signal {
  color: #89b4fa;
}

/* Tên mạng / thiết bị */
.cc-net-name {
  font-size: 13px;
  color: #cdd6f4;
}

/* Icon khóa */
.cc-lock {
  font-size: 12px;
  color: #a6adc8;
  margin-left: 6px;
}

/* Dấu chấm active */
.cc-active-dot {
  font-size: 10px;
  color: #a6e3a1;
  margin-left: 6px;
}

/* Pin bluetooth */
.cc-battery {
  font-size: 11px;
  color: #a6adc8;
  margin-left: 6px;
}

/* Bluetooth icon */
.cc-bt-icon {
  font-size: 16px;
  color: #89b4fa;
  margin-right: 10px;
  min-width: 20px;
}

/* Ô nhập mật khẩu */
.cc-pass-row {
  padding: 8px 12px;
  background: #181825;
  border-radius: 10px;
  margin-bottom: 4px;
}

.cc-pass-input {
  font-size: 13px;
  color: #cdd6f4;
  background: transparent;
  border-bottom: 1px solid #45475a;
  padding: 4px;
  min-width: 160px;
}

.cc-connect-btn {
  font-size: 12px;
  font-weight: 600;
  color: #1e1e2e;
  background: #89b4fa;
  border-radius: 8px;
  padding: 4px 12px;
  margin-left: 8px;
}

.cc-connect-btn:hover {
  background: #b4befe;
}

/* Nhãn lỗi */
.cc-error-label {
  font-size: 12px;
  color: #f38ba8;
  padding: 4px 12px;
}

/* Card thông tin mạng dây */
.cc-info-card {
  background: #181825;
  border-radius: 12px;
  padding: 12px;
  margin-bottom: 12px;
}

.cc-info-row {
  padding: 6px 0;
  border-bottom: 1px solid #313244;
}

.cc-info-key {
  font-size: 12px;
  color: #a6adc8;
  min-width: 80px;
}

.cc-info-val {
  font-size: 13px;
  color: #cdd6f4;
  font-weight: 600;
}

/* Nút connect/disconnect mạng dây */
.cc-wired-btn {
  font-size: 13px;
  font-weight: 600;
  padding: 8px 16px;
  border-radius: 10px;
  margin-bottom: 8px;
}

.cc-wired-btn.connect {
  background: #89b4fa;
  color: #1e1e2e;
}

.cc-wired-btn.disconnect {
  background: #f38ba8;
  color: #1e1e2e;
}

.cc-wired-btn:hover {
  opacity: 0.85;
}

/* Nút nâng cao ở chân panel */
.cc-advanced-btn {
  font-size: 12px;
  color: #6c7086;
  padding: 6px 12px;
  border-radius: 8px;
  margin-top: 8px;
}

.cc-advanced-btn:hover {
  background: #313244;
  color: #a6adc8;
}

/* Slider âm lượng từng app */
.app-vol-row {
  padding: 6px 4px;
  border-radius: 8px;
  margin-bottom: 4px;
}

.app-vol-row:hover {
  background: #313244;
}

.slider.app-vol {
  min-width: 120px;
}

.slider.app-vol scale trough highlight {
  background: #a6e3a1;
}

/* Mic volume slider */
.slider.mic-vol scale trough highlight {
  background: #cba6f7;
}

/* Nút mute mic nhỏ */
.cc-mute-btn {
  font-size: 18px;
  color: #cdd6f4;
  min-width: 28px;
  margin-right: 12px;
}
```

- [ ] **Step 2: Reload eww**

```bash
~/.local/bin/eww --config ~/.config/eww reload 2>&1 | head -5
```

- [ ] **Step 3: Commit**

```bash
git add .config/eww/eww.css
git commit -m "feat: thêm CSS cho 5 panel chi tiết control center"
```

---

### Task 11: Kiểm tra tổng thể (manual smoke test)

Không có test suite — kiểm tra thủ công từng luồng.

- [ ] **Step 1: Kiểm tra parse eww sạch**

```bash
~/.local/bin/eww --config ~/.config/eww reload 2>&1
```

Không có dòng `error` (case-insensitive).

- [ ] **Step 2: Mở popup → home hiển thị đúng**

```bash
~/.config/waybar/scripts/toggle-control-center.sh
~/.local/bin/eww --config ~/.config/eww get cc_view
```

Output: `home`

- [ ] **Step 3: Kiểm tra mũi tên Wi-Fi → panel wifi load**

```bash
# Giả lập bấm › Wi-Fi
~/.local/bin/eww --config ~/.config/eww update \
    cc_view=wifi \
    wifi_list="$(~/.config/eww/scripts/cc/wifi.sh list)"
~/.local/bin/eww --config ~/.config/eww get wifi_list | python3 -m json.tool | head -10
```

Panel wifi phải xuất hiện với danh sách mạng.

- [ ] **Step 4: Kiểm tra Back → home**

```bash
~/.local/bin/eww --config ~/.config/eww update cc_view=home
```

Layout home phải trở lại.

- [ ] **Step 5: Kiểm tra mũi tên Bluetooth → panel bluetooth**

```bash
~/.local/bin/eww --config ~/.config/eww update \
    cc_view=bluetooth \
    bt_list="$(~/.config/eww/scripts/cc/bluetooth.sh list)"
```

Panel bluetooth hiển thị.

- [ ] **Step 6: Kiểm tra panel Âm thanh**

```bash
~/.local/bin/eww --config ~/.config/eww update \
    cc_view=audio \
    audio_sinks="$(~/.config/eww/scripts/cc/audio.sh sinks)" \
    audio_apps="$(~/.config/eww/scripts/cc/audio.sh apps)"
```

Danh sách sink hiển thị, sink default có dấu ●.

- [ ] **Step 7: Kiểm tra panel Micro**

```bash
~/.local/bin/eww --config ~/.config/eww update \
    cc_view=mic \
    mic_sources="$(~/.config/eww/scripts/cc/mic.sh sources)"
```

- [ ] **Step 8: Kiểm tra panel Mạng dây**

```bash
~/.local/bin/eww --config ~/.config/eww update \
    cc_view=wired \
    wired_info="$(~/.config/eww/scripts/cc/wired.sh info)"
~/.local/bin/eww --config ~/.config/eww get wired_info
```

JSON hiện IP, gateway, trạng thái thiết bị enp1s0.

- [ ] **Step 9: Đóng popup, mở lại → về home**

```bash
~/.config/waybar/scripts/toggle-control-center.sh
~/.config/waybar/scripts/toggle-control-center.sh
~/.local/bin/eww --config ~/.config/eww get cc_view
```

Output: `home`

- [ ] **Step 10: Commit cuối nếu có fix nhỏ**

```bash
git add -p
git commit -m "fix: điều chỉnh nhỏ sau smoke test"
```

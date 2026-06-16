# Eww Control Center Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a beautiful, Catppuccin Mocha-themed Control Center popup using Eww on Sway, matching the visual toggles (WiFi, Bluetooth, Airplane, Night Light, Volume, Mic), sliders (Volume, Brightness), and power buttons, and trigger it via Waybar network/bluetooth modules.

**Architecture:** Use a background shell script to query system states and trigger actions. Use Eww (`yuck`) for layout and structure, and `scss` for matching the reference styling. Trigger the window via `waybar` clicking.

**Tech Stack:** Eww, Sway WM, Waybar, bash, `nmcli`, `bluetoothctl`, `brightnessctl`, `wpctl`, `gammastep`.

---

### Task 1: Create control_center.sh script

**Files:**
- Create: `/home/sown/workplace/sway-config/.config/eww/scripts/control_center.sh`

- [ ] **Step 1: Write control_center.sh helper script**
Write the following content to `/home/sown/workplace/sway-config/.config/eww/scripts/control_center.sh` to query and toggle states:
```bash
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    wifi-ssid)
        if nmcli radio wifi | grep -q "disabled"; then
            echo "Wifi Off"
        else
            ssid=$(nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes' | cut -d: -f2)
            echo "${ssid:-Disconnected}"
        fi
        ;;
    wifi-state)
        if nmcli radio wifi | grep -q "disabled"; then
            echo "off"
        else
            echo "on"
        fi
        ;;
    wifi-toggle)
        if nmcli radio wifi | grep -q "disabled"; then
            nmcli radio wifi on
        else
            nmcli radio wifi off
        fi
        ;;
    bt-state)
        if bluetoothctl show | grep -q 'Powered: yes'; then
            echo "on"
        else
            echo "off"
        fi
        ;;
    bt-toggle)
        if bluetoothctl show | grep -q 'Powered: yes'; then
            bluetoothctl power off
        else
            bluetoothctl power on
        fi
        ;;
    airplane-state)
        # If any rfkill block exists for wifi/bt, consider it enabled
        if rfkill list | grep -q 'Blocked: yes'; then
            echo "on"
        else
            echo "off"
        fi
        ;;
    airplane-toggle)
        if rfkill list | grep -q 'Blocked: yes'; then
            rfkill unblock all
        else
            rfkill block all
        fi
        ;;
    nightlight-state)
        if pgrep -x gammastep >/dev/null; then
            echo "on"
        else
            echo "off"
        fi
        ;;
    nightlight-toggle)
        if pgrep -x gammastep >/dev/null; then
            pkill -x gammastep
        else
            gammastep -O 4000 &
        fi
        ;;
    vol-level)
        wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%.0f\n", $2*100}'
        ;;
    vol-muted)
        if wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q 'MUTED'; then
            echo "on"
        else
            echo "off"
        fi
        ;;
    vol-toggle)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
    mic-muted)
        if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q 'MUTED'; then
            echo "on"
        else
            echo "off"
        fi
        ;;
    mic-toggle)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        ;;
    set-vol)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "${2}"%
        ;;
    bri-level)
        brightnessctl -m | cut -d, -f4 | tr -d '%'
        ;;
    set-bri)
        brightnessctl set "${2}"%
        ;;
    *)
        echo "Unknown command: ${1:-}" >&2
        exit 1
        ;;
esac
```

- [ ] **Step 2: Make the script executable**
Run: `chmod +x /home/sown/workplace/sway-config/.config/eww/scripts/control_center.sh`
Expected: Return 0, no error output.

- [ ] **Step 3: Test the script**
Run: `/home/sown/workplace/sway-config/.config/eww/scripts/control_center.sh wifi-state`
Expected: Output `on` or `off`.

- [ ] **Step 4: Commit changes**
```bash
git add .config/eww/scripts/control_center.sh
git commit -m "feat: add control_center.sh script to query and toggle system states"
```

---

### Task 2: Create Waybar toggle script

**Files:**
- Create: `/home/sown/workplace/sway-config/.config/waybar/scripts/toggle-control-center.sh`
- Modify: `/home/sown/workplace/sway-config/.config/waybar/scripts/toggle-calendar.sh`

- [ ] **Step 1: Write toggle-control-center.sh**
Write the following contents to `/home/sown/workplace/sway-config/.config/waybar/scripts/toggle-control-center.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

EWW_BIN="$(command -v eww)"
CONFIG_DIR="$HOME/.config/eww"
WINDOW="control-center-popup"

# Get current monitor
MONITOR="$(swaymsg -t get_outputs | jq -r '.[] | select(.focused).name' | head -n1)"
MONITOR="${MONITOR:-0}"

# Start daemon if not running
if ! "$EWW_BIN" --config "$CONFIG_DIR" active-windows >/dev/null 2>&1; then
    "$EWW_BIN" --config "$CONFIG_DIR" daemon >/dev/null 2>&1 || true
    for i in {1..30}; do
        if "$EWW_BIN" --config "$CONFIG_DIR" active-windows >/dev/null 2>&1; then
            break
        fi
        sleep 0.1
    done
fi

# Close calendar if open
if "$EWW_BIN" --config "$CONFIG_DIR" active-windows | grep -q "^calendar-popup"; then
    "$EWW_BIN" --config "$CONFIG_DIR" close "calendar-popup"
fi

# Toggle Control Center
if "$EWW_BIN" --config "$CONFIG_DIR" active-windows | grep -q "^$WINDOW"; then
    "$EWW_BIN" --config "$CONFIG_DIR" close "$WINDOW"
else
    "$EWW_BIN" --config "$CONFIG_DIR" open "$WINDOW" --arg monitor="$MONITOR"
fi
```

- [ ] **Step 2: Make toggle script executable**
Run: `chmod +x /home/sown/workplace/sway-config/.config/waybar/scripts/toggle-control-center.sh`
Expected: Return 0, no error output.

- [ ] **Step 3: Modify toggle-calendar.sh to close control center**
Modify `/home/sown/workplace/sway-config/.config/waybar/scripts/toggle-calendar.sh` to add a check to close `control-center-popup` if open.
TargetContent (near line 46):
```bash
# 5. Thực hiện Bật/Tắt cửa sổ lịch
if "$EWW_BIN" --config "$CONFIG_DIR" active-windows | grep -q "^$WINDOW"; then
    # Nếu cửa sổ đang mở -> đóng lại
    "$EWW_BIN" --config "$CONFIG_DIR" close "$WINDOW"
else
```
ReplacementContent:
```bash
# Close control center if open
if "$EWW_BIN" --config "$CONFIG_DIR" active-windows | grep -q "^control-center-popup"; then
    "$EWW_BIN" --config "$CONFIG_DIR" close "control-center-popup"
fi

# 5. Thực hiện Bật/Tắt cửa sổ lịch
if "$EWW_BIN" --config "$CONFIG_DIR" active-windows | grep -q "^$WINDOW"; then
    # Nếu cửa sổ đang mở -> đóng lại
    "$EWW_BIN" --config "$CONFIG_DIR" close "$WINDOW"
else
```

- [ ] **Step 4: Commit changes**
```bash
git add .config/waybar/scripts/toggle-control-center.sh .config/waybar/scripts/toggle-calendar.sh
git commit -m "feat: add waybar toggle scripts for control center and sync with calendar"
```

---

### Task 3: Modify eww.yuck to define Control Center UI

**Files:**
- Modify: `/home/sown/workplace/sway-config/.config/eww/eww.yuck`

- [ ] **Step 1: Edit eww.yuck to add variables and window definition**
Append the variables, polls, window, and widgets definitions for `control-center-popup` to `/home/sown/workplace/sway-config/.config/eww/eww.yuck`.
TargetContent (at the end of the file, after line 64):
```yuck
              :text {day.label})))))))
```
ReplacementContent:
```yuck
              :text {day.label})))))))

;; ── Control Center Polls & Variables ──
(defpoll wifi_ssid :interval "3s" "~/.config/eww/scripts/control_center.sh wifi-ssid")
(defpoll wifi_state :interval "3s" "~/.config/eww/scripts/control_center.sh wifi-state")
(defpoll bt_state :interval "3s" "~/.config/eww/scripts/control_center.sh bt-state")
(defpoll airplane_state :interval "3s" "~/.config/eww/scripts/control_center.sh airplane-state")
(defpoll nightlight_state :interval "3s" "~/.config/eww/scripts/control_center.sh nightlight-state")
(defpoll vol_level :interval "1s" "~/.config/eww/scripts/control_center.sh vol-level")
(defpoll vol_muted :interval "1s" "~/.config/eww/scripts/control_center.sh vol-muted")
(defpoll mic_muted :interval "1s" "~/.config/eww/scripts/control_center.sh mic-muted")
(defpoll bri_level :interval "2s" "~/.config/eww/scripts/control_center.sh bri-level")

;; ── Control Center Window ──
(defwindow control-center-popup [monitor]
  :monitor monitor
  :geometry (geometry
    :x "15px"
    :y "45px"
    :width "360px"
    :height "450px"
    :anchor "top right")
  :stacking "overlay"
  :exclusive false
  :focusable true
  :namespace "eww-control-center"
  (control-center-card))

;; ── Control Center Widget Card ──
(defwidget control-center-card []
  (box :class "control-center-card" :orientation "vertical" :space-evenly false
    ;; Header (Clock & DND/Night light state icon)
    (box :class "cc-header" :orientation "horizontal" :space-evenly true
      (box :class "cc-header-left" :orientation "vertical" :space-evenly false :halign "start"
        (box :class "cc-clock" :orientation "horizontal" :space-evenly false
          (label :class "cc-time" :text time_hour)
          (label :class "cc-sep" :text "|")
          (label :class "cc-time" :text time_min))
        (label :class "cc-date" :text time_date))
      (box :class "cc-header-right" :halign "end" :valign "start"
        (label :class {nightlight_state == "on" ? "cc-moon active" : "cc-moon"} :text "")))

    ;; Quick Settings Grid (3 columns, 2 rows)
    (box :class "cc-grid" :orientation "vertical" :space-evenly true
      (box :orientation "horizontal" :space-evenly true
        ;; Wifi Toggle
        (box :class "toggle-container" :orientation "vertical" :space-evenly false
          (box :class {wifi_state == "on" ? "toggle-btn active" : "toggle-btn"} :orientation "horizontal" :space-evenly false
            (button :class "toggle-main" :onclick "~/.config/eww/scripts/control_center.sh wifi-toggle"
              (label :text {wifi_state == "on" ? "" : "󰖪"}))
            (box :class "toggle-divider")
            (button :class "toggle-arrow" :onclick "nm-connection-editor &" "›"))
          (label :class "toggle-label" :limit-width 12 :text wifi_ssid))

        ;; Bluetooth Toggle
        (box :class "toggle-container" :orientation "vertical" :space-evenly false
          (box :class {bt_state == "on" ? "toggle-btn active" : "toggle-btn"} :orientation "horizontal" :space-evenly false
            (button :class "toggle-main" :onclick "~/.config/eww/scripts/control_center.sh bt-toggle"
              (label :text ""))
            (box :class "toggle-divider")
            (button :class "toggle-arrow" :onclick "blueman-manager &" "›"))
          (label :class "toggle-label" :text "Bluetooth"))

        ;; Airplane Toggle
        (box :class "toggle-container" :orientation "vertical" :space-evenly false
          (box :class {airplane_state == "on" ? "toggle-btn active" : "toggle-btn"} :orientation "horizontal" :space-evenly false
            (button :class "toggle-main" :onclick "~/.config/eww/scripts/control_center.sh airplane-toggle"
              (label :text ""))
            (box :class "toggle-divider")
            (button :class "toggle-arrow" :onclick "" "›"))
          (label :class "toggle-label" :text "Airplane")))

      (box :orientation "horizontal" :space-evenly true
        ;; Night Light Toggle
        (box :class "toggle-container" :orientation "vertical" :space-evenly false
          (box :class {nightlight_state == "on" ? "toggle-btn active" : "toggle-btn"} :orientation "horizontal" :space-evenly false
            (button :class "toggle-main" :onclick "~/.config/eww/scripts/control_center.sh nightlight-toggle"
              (label :text ""))
            (box :class "toggle-divider")
            (button :class "toggle-arrow" :onclick "" "›"))
          (label :class "toggle-label" :text "Night Light"))

        ;; Volume Mute Toggle
        (box :class "toggle-container" :orientation "vertical" :space-evenly false
          (box :class {vol_muted == "off" ? "toggle-btn active" : "toggle-btn"} :orientation "horizontal" :space-evenly false
            (button :class "toggle-main" :onclick "~/.config/eww/scripts/control_center.sh vol-toggle"
              (label :text {vol_muted == "on" ? "󰝟" : ""}))
            (box :class "toggle-divider")
            (button :class "toggle-arrow" :onclick "pavucontrol &" "›"))
          (label :class "toggle-label" :text "Volume"))

        ;; Micro Mute Toggle
        (box :class "toggle-container" :orientation "vertical" :space-evenly false
          (box :class {mic_muted == "off" ? "toggle-btn active" : "toggle-btn"} :orientation "horizontal" :space-evenly false
            (button :class "toggle-main" :onclick "~/.config/eww/scripts/control_center.sh mic-toggle"
              (label :text {mic_muted == "on" ? "" : ""}))
            (box :class "toggle-divider")
            (button :class "toggle-arrow" :onclick "pavucontrol &" "›"))
          (label :class "toggle-label" :text "Micro"))))

    ;; Sliders Section
    (box :class "cc-sliders" :orientation "vertical" :space-evenly false
      ;; Volume Slider
      (box :class "slider-row" :orientation "horizontal" :space-evenly false
        (label :class "slider-icon vol" :text {vol_muted == "on" ? "󰝟" : ""})
        (scale :class "slider vol" :value {vol_muted == "on" ? 0 : vol_level} :min 0 :max 100 :onchange "~/.config/eww/scripts/control_center.sh set-vol {}"))
      ;; Brightness Slider
      (box :class "slider-row" :orientation "horizontal" :space-evenly false
        (label :class "slider-icon bri" :text "")
        (scale :class "slider bri" :value bri_level :min 10 :max 100 :onchange "~/.config/eww/scripts/control_center.sh set-bri {}")))

    ;; Footer (Power actions)
    (box :class "cc-footer" :orientation "horizontal" :space-evenly true
      (box :halign "start")
      (box :class "power-box" :orientation "horizontal" :space-evenly false :halign "end"
        (button :class "power-btn shutdown" :onclick "systemctl poweroff" "")
        (button :class "power-btn reboot" :onclick "systemctl reboot" "")
        (button :class "power-btn logout" :onclick "swaymsg exit" "󰍃")))))
```

- [ ] **Step 2: Commit changes**
```bash
git add .config/eww/eww.yuck
git commit -m "feat: add control-center-popup and widgets to eww.yuck"
```

---

### Task 4: Modify eww.scss to style the Control Center

**Files:**
- Modify: `/home/sown/workplace/sway-config/.config/eww/eww.scss`

- [ ] **Step 1: Append styling rules to eww.scss**
Append styling for the control center to `/home/sown/workplace/sway-config/.config/eww/eww.scss`.
TargetContent (at the end of the file, after line 89):
```scss
.day:hover:not(.today):not(.muted) {
  background: $surface1;
}
```
ReplacementContent:
```scss
.day:hover:not(.today):not(.muted) {
  background: $surface1;
}

// ── Control Center Styling ──
.control-center-card {
  background: rgba(30, 30, 46, 0.95); // Semi-transparent base
  border: 2px solid $surface0;
  border-radius: 20px;
  padding: 24px;
  color: $text;
}

.cc-header {
  margin-bottom: 24px;
}

.cc-clock {
  margin-bottom: 4px;
}

.cc-time {
  font-size: 32px;
  font-weight: 800;
  color: $text;
}

.cc-sep {
  font-size: 30px;
  font-weight: 300;
  color: $surface1;
  margin: 0 10px;
}

.cc-date {
  font-size: 14px;
  color: $subtext0;
}

.cc-moon {
  font-size: 24px;
  color: $surface1;
  padding: 8px;
  border-radius: 50%;
  
  &.active {
    color: $blue;
  }
}

.cc-grid {
  margin-bottom: 24px;
}

.toggle-container {
  margin: 8px;
  min-width: 90px;
}

.toggle-btn {
  background: $surface0;
  border-radius: 24px;
  padding: 10px 8px;
  margin-bottom: 8px;
  border: 1px solid transparent;
  transition: all 200ms ease;

  &.active {
    background: $blue;
    color: $base;
    
    .toggle-divider {
      background: rgba(30, 30, 46, 0.2);
    }
    .toggle-main, .toggle-arrow {
      color: $base;
    }
  }
}

.toggle-main {
  font-size: 18px;
  color: $text;
  margin-right: 6px;
  min-width: 28px;
  text-align: center;
}

.toggle-divider {
  width: 1px;
  background: rgba(205, 214, 244, 0.15);
  margin: 0 4px;
}

.toggle-arrow {
  font-size: 16px;
  color: $subtext0;
  margin-left: 6px;
  min-width: 18px;
  text-align: center;
}

.toggle-label {
  font-size: 12px;
  color: $subtext0;
  text-align: center;
}

.cc-sliders {
  margin-bottom: 24px;
  padding: 0 8px;
}

.slider-row {
  margin-bottom: 16px;
  background: $surface0;
  border-radius: 16px;
  padding: 10px 16px;
  align-items: center;
}

.slider-icon {
  font-size: 18px;
  margin-right: 12px;
  min-width: 24px;
  
  &.vol {
    color: $blue;
  }
  &.bri {
    color: #f9e2af; // catppuccin peach/yellow
  }
}

.slider {
  min-width: 230px;
  
  scale trough {
    background: $surface1;
    border-radius: 6px;
    min-height: 8px;
    
    highlight {
      border-radius: 6px;
    }
  }

  &.vol scale trough highlight {
    background: $blue;
  }

  &.bri scale trough highlight {
    background: #f9e2af;
  }
}

.cc-footer {
  padding-top: 12px;
  border-top: 1px solid $surface0;
}

.power-box {
  // align to right
}

.power-btn {
  font-size: 16px;
  width: 38px;
  height: 38px;
  border-radius: 50%;
  background: $surface0;
  color: $text;
  margin-left: 12px;
  text-align: center;
  transition: all 200ms ease;

  &:hover {
    background: $surface1;
  }

  &.shutdown:hover {
    background: $red;
    color: $base;
  }

  &.reboot:hover {
    background: $lavender;
    color: $base;
  }

  &.logout:hover {
    background: $blue;
    color: $base;
  }
}
```

- [ ] **Step 2: Commit changes**
```bash
git add .config/eww/eww.scss
git commit -m "feat: add SCSS styles for eww control center popup"
```

---

### Task 5: Modify Waybar config to trigger Control Center

**Files:**
- Modify: `/home/sown/workplace/sway-config/.config/waybar/config`

- [ ] **Step 1: Update network and bluetooth click events in Waybar config**
Modify `/home/sown/workplace/sway-config/.config/waybar/config` to change `"on-click"` in both modules to point to the toggle-control-center.sh script.
TargetContent (near line 74):
```json
        "tooltip-format-disconnected": "Disconnected",
        "on-click": "nm-connection-editor"
    },
    "bluetooth": {
        "format": "",
        "format-disabled": "",
        "format-off": "",
        "format-connected": " {device_alias}",
        "tooltip-format": "{controller_alias}\t{status}",
        "tooltip-format-connected": "{controller_alias}\t{status}\n\n{device_enumerate}",
        "tooltip-format-enumerate-connected": "{device_alias}",
        "on-click": "blueman-manager"
    },
```
ReplacementContent:
```json
        "tooltip-format-disconnected": "Disconnected",
        "on-click": "~/.config/waybar/scripts/toggle-control-center.sh"
    },
    "bluetooth": {
        "format": "",
        "format-disabled": "",
        "format-off": "",
        "format-connected": " {device_alias}",
        "tooltip-format": "{controller_alias}\t{status}",
        "tooltip-format-connected": "{controller_alias}\t{status}\n\n{device_enumerate}",
        "tooltip-format-enumerate-connected": "{device_alias}",
        "on-click": "~/.config/waybar/scripts/toggle-control-center.sh"
    },
```

- [ ] **Step 2: Commit changes**
```bash
git add .config/waybar/config
git commit -m "feat: hook up waybar network and bluetooth on-click to toggle control center"
```

---

### Task 6: Reload configuration and verify

- [ ] **Step 1: Reload Sway configuration**
Run: `swaymsg reload`
Expected: Sway reloads configs successfully.

- [ ] **Step 2: Restart Waybar**
Run: `pkill waybar && waybar &` in the background (or it restarts automatically via sway config).
Expected: Waybar starts up with the updated network and bluetooth module configs.

- [ ] **Step 3: Click on Waybar Wifi icon to open Control Center**
Click on the network icon.
Expected: The control center popup opens at the top right, matching the reference design. Clicking again closes it.

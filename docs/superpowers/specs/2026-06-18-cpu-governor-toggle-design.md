# CPU Governor Toggle — Design Spec

**Date:** 2026-06-18
**Status:** Approved

## Tóm tắt

Thêm nút toggle "Performance" vào lưới quick-toggles của eww Control Center popup.
Nút này chuyển đổi CPU governor giữa `performance` (hiệu suất tối đa) và `schedutil`
(tiết kiệm pin, mặc định). Khi bật → active (highlight), khi tắt → default — giống
hệt các nút Airplane mode, Bluetooth, v.v.

---

## UI

**Vị trí:** Hàng thứ 3 trong `cc-grid`, chứa 1 nút căn giữa.

```
┌─────────────┬─────────────┬─────────────┐
│   Wi-Fi  ›  │ Bluetooth › │  Airplane › │
├─────────────┼─────────────┼─────────────┤
│   Wired  ›  │  Volume  ›  │   Mic     › │
├─────────────┴─────────────┴─────────────┤
│           Performance                   │
└─────────────────────────────────────────┘
```

**Widget:** dùng `toggle-container` / `toggle-btn` / `toggle-main` giống các nút hiện
có. Không có mũi tên `›` (không có trang con). Icon `` (Nerd Font lightning,
codepoint U+F0E7). Label "Performance".

**State:** `cpu_perf_state` poll 3s, giá trị `"on"` hoặc `"off"`.
- `on` → class `toggle-btn active`, icon highlight
- `off` → class `toggle-btn`, icon mờ

---

## Scripts

### `~/.config/eww/scripts/cc/cpu-governor.sh`

Script mới, xử lý 2 subcommand:

| Subcommand | Mô tả |
|---|---|
| `get` | Đọc `/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`; in `on` nếu = `performance`, `off` nếu khác |
| `toggle` | Nếu governor hiện tại = `performance` → set `schedutil`; ngược lại → set `performance`. Gọi helper script bằng `sudo` |

### `~/.config/eww/scripts/cc/set-cpu-governor.sh`

Script helper chạy **với quyền root** (được gọi qua `sudo`). Nhận 1 argument là
tên governor. Dùng vòng lặp để ghi cho tất cả CPUs:

```bash
#!/usr/bin/env bash
governor="${1:?}"
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "$governor" > "$cpu"
done
```

Tách riêng helper để sudoers có thể whitelist đường dẫn cụ thể (tránh glob issue).

---

## Sudoers

Tạo file `/etc/sudoers.d/sown-cpu-governor`:

```
sown ALL=(ALL) NOPASSWD: /home/sown/.config/eww/scripts/cc/set-cpu-governor.sh
```

Chỉ cho phép đúng script này, không mở rộng.

---

## eww.yuck

**Thêm poll:**
```lisp
(defpoll cpu_perf_state :interval "3s" "~/.config/eww/scripts/cc/cpu-governor.sh get")
```

**Thêm hàng 3 vào cc-grid** (sau hàng Wired/Volume/Mic):
```lisp
(box :orientation "horizontal" :space-evenly true
  (box :class "toggle-container" :orientation "vertical" :space-evenly false
    (box :class {cpu_perf_state == "on" ? "toggle-btn active" : "toggle-btn"}
         :orientation "horizontal" :space-evenly false
      (button :class "toggle-main"
              :onclick "~/.config/eww/scripts/cc/cpu-governor.sh toggle && ~/.config/eww/scripts/control_center.sh refresh"
        (label :text "")))
    (label :class "toggle-label" :text "Performance")))
```

Icon `` được viết bằng codepoint `` qua script thay vì paste glyph trực tiếp
(theo pattern Nerd Font đã dùng trong codebase — xem memory `waybar-icon-codepoints`).

---

## Luồng hoạt động

```
User click nút
  → cpu-governor.sh toggle
    → đọc cpu0 governor
    → gọi: sudo set-cpu-governor.sh [performance|schedutil]
      → vòng lặp ghi tất cả CPUs
  → control_center.sh refresh
    → eww update cpu_perf_state=...
  → poll 3s cũng tự cập nhật lại
```

---

## Kiểm tra

1. `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor` → xác nhận thay đổi
2. Nút highlight khi governor = `performance`
3. Click lần 2 → trả về `schedutil`, nút tắt highlight
4. Không có popup hỏi mật khẩu sudo

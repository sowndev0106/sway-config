# Mở rộng popup rofi (Super+D) nhiều chế độ — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gộp Apps/Run/Window/Files/Power vào một popup rofi mở bằng Super+D, có tab + icon, power menu xác nhận, và toggle đóng chắc ăn.

**Architecture:** Một điểm vào `Super+D` → `rofi-focused.sh`. rofi nạp `modi: drun,run,window,filebrowser,power`; `sidebar-mode` hiện tab có icon. Power là custom script modi `rofi-power.sh` dùng lại action của wlogout. `bindsym $mod+d` đổi thành toggle (mở/đóng).

**Tech Stack:** rofi 1.7.5 (XWayland), bash, sway, Papirus icons, JetBrains Mono Nerd Font.

**Lưu ý chung — đây là dotfiles:** không có test tự động. "Kiểm thử" = áp dụng thật rồi quan sát. Vì là symlink, sửa file trong repo = sửa config đang chạy. Glyph Nerd Font phải chèn bằng `printf` với codepoint (Edit/Write làm rớt ký tự PUA nếu paste glyph trực tiếp).

---

## File Structure

| File | Trách nhiệm | Create/Modify |
|---|---|---|
| `.config/rofi/config.rasi` | modi, display label + icon tab, window-format, click-to-exit | Modify |
| `.config/sway/scripts/rofi-power.sh` | script modi power: liệt kê mục + xác nhận + exec action | Create |
| `.config/sway/config` | đổi `bindsym $mod+d` thành toggle | Modify (dòng 60) |

---

## Task 1: Power menu script modi

**Files:**
- Create: `.config/sway/scripts/rofi-power.sh`

- [ ] **Step 1: Viết script**

Tạo file `.config/sway/scripts/rofi-power.sh` với nội dung:

```bash
#!/usr/bin/env bash
# Script modi cho rofi: power menu. Dùng lại đúng action của wlogout.
# Giao thức rofi script-mode:
#   - Gọi lần đầu không có $1  -> in danh sách mục (mỗi mục có thể kèm icon).
#   - Người dùng chọn -> rofi gọi lại với $1 = nhãn đã chọn.
# Mỗi dòng: "<nhãn>\0icon\x1f<tên-icon-papirus>"
# Hành động nguy hiểm (Logout/Reboot/Shutdown) phải qua một bước xác nhận.

set -u
esc=$'\0'      # tách nhãn và metadata
us=$'\x1f'     # tách key và value trong metadata

emit() { printf '%s%sicon%s%s\n' "$1" "$esc" "$us" "$2"; }

# Đặt prompt cho cột (hiển thị trên thanh nhập)
printf '\0prompt\x1fPower\n'

case "${1:-}" in
    "")
        # Menu gốc
        emit " Khoá màn"   "system-lock-screen"
        emit " Đăng xuất"  "system-log-out"
        emit " Ngủ"        "system-suspend"
        emit " Khởi động lại" "system-reboot"
        emit " Tắt máy"    "system-shutdown"
        ;;

    # Hành động an toàn -> chạy ngay
    *"Khoá màn"*)
        setsid -f "$HOME/.config/sway/scripts/lock.sh" >/dev/null 2>&1
        ;;
    *"Ngủ"*)
        setsid -f systemctl suspend >/dev/null 2>&1
        ;;

    # Hành động nguy hiểm -> hỏi xác nhận.
    # Dùng wildcard *"text"* để pattern không phụ thuộc glyph ở đầu nhãn.
    # Phân biệt menu-gốc vs bước-xác-nhận bằng chữ hoa/thường: nhãn gốc
    # "Đăng xuất" (Đ hoa) khớp nhánh này; nhãn xác nhận "Có, đăng xuất"
    # (đ thường) rơi xuống nhánh exec phía dưới. KHÔNG trùng nhau.
    *"Đăng xuất")
        emit "✓ Có, đăng xuất" "system-log-out"
        emit "✗ Huỷ"           "window-close"
        ;;
    *"Khởi động lại")
        emit "✓ Có, khởi động lại" "system-reboot"
        emit "✗ Huỷ"               "window-close"
        ;;
    *"Tắt máy")
        emit "✓ Có, tắt máy" "system-shutdown"
        emit "✗ Huỷ"         "window-close"
        ;;

    # Bước xác nhận "Có"
    *"đăng xuất")
        setsid -f swaymsg exit >/dev/null 2>&1
        ;;
    *"khởi động lại")
        setsid -f systemctl reboot >/dev/null 2>&1
        ;;
    *"tắt máy")
        setsid -f systemctl poweroff >/dev/null 2>&1
        ;;

    # Huỷ -> quay lại menu gốc
    *"Huỷ"*)
        emit " Khoá màn"   "system-lock-screen"
        emit " Đăng xuất"  "system-log-out"
        emit " Ngủ"        "system-suspend"
        emit " Khởi động lại" "system-reboot"
        emit " Tắt máy"    "system-shutdown"
        ;;
esac
```

LƯU Ý chèn glyph: các glyph ` ` (lock uf023), ` ` (logout/sign-out uf08b), ` ` (moon/suspend uf186), ` ` (reboot/rotate uf021), ` ` (power uf011) là ký tự Nerd Font. KHÔNG paste — sau khi tạo file với chỗ giữ tạm (ví dụ `[L]`,`[O]`,`[S]`,`[R]`,`[P]`), thay bằng glyph thật ở Step 2.

- [ ] **Step 2: Chèn glyph Nerd Font bằng printf**

Nếu đã viết placeholder `[L]/[O]/[S]/[R]/[P]`, thay bằng codepoint thật (lock uf023, sign-out uf08b, moon uf186, rotate-right uf021, power uf011):

```bash
cd ~/.config/sway/scripts
sed -i "s/\[L\]/$(printf '')/g; s/\[O\]/$(printf '')/g; s/\[S\]/$(printf '')/g; s/\[R\]/$(printf '')/g; s/\[P\]/$(printf '')/g" rofi-power.sh
```

(Nếu Step 1 đã chèn glyph đúng bằng printf thì bỏ qua step này.)

- [ ] **Step 3: Cho phép thực thi**

```bash
chmod +x ~/.config/sway/scripts/rofi-power.sh
```

- [ ] **Step 4: Kiểm thử script độc lập (in menu gốc)**

Run:
```bash
~/.config/sway/scripts/rofi-power.sh | cat -v
```
Expected: in 5 dòng, mỗi dòng dạng `<glyph> Nhãn^@icon^_<tên-icon>` (`^@` = NUL, `^_` = US). Dòng đầu là `^@prompt^_Power`.

- [ ] **Step 5: Kiểm thử bước xác nhận**

Run:
```bash
~/.config/sway/scripts/rofi-power.sh " Tắt máy" | cat -v
```
Expected: in 2 dòng `✓ Có, tắt máy ...` và `✗ Huỷ ...` (KHÔNG tắt máy thật vì chỉ là bước in menu xác nhận).

- [ ] **Step 6: Commit**

```bash
git add .config/sway/scripts/rofi-power.sh
git commit -m "feat: thêm script modi power menu cho rofi (có xác nhận)"
```

---

## Task 2: Nối modi + tab icon vào rofi config

**Files:**
- Modify: `.config/rofi/config.rasi:2` (modi), `:6-8` (display-*), thêm window-format & click-to-exit

- [ ] **Step 1: Sửa khối `configuration`**

Trong `.config/rofi/config.rasi`, thay khối `configuration { ... }` (dòng 1-10) thành:

```rasi
configuration {
    modi: "drun,run,window,filebrowser,power:~/.config/sway/scripts/rofi-power.sh";
    show-icons: true;
    icon-theme: "Papirus";
    drun-display-format: "{name}";
    display-drun: " Apps";
    display-run: " Run";
    display-window: " Window";
    display-filebrowser: " Files";
    window-format: "{w}   {c}   {t}";
    click-to-exit: true;
    sidebar-mode: true;
}
```

LƯU Ý glyph: `display-filebrowser` cần glyph folder (uf07b) trước "Files". Các glyph khác (` Apps`, ` Run`, ` Window`) đã có sẵn trong file — giữ nguyên byte cũ, đừng gõ lại. Nếu Edit làm rớt glyph, chèn lại bằng:

```bash
cd ~/.config/rofi
# chèn folder-glyph vào display-filebrowser nếu bị thiếu
sed -i "s/display-filebrowser: \" Files\"/display-filebrowser: \"$(printf '') Files\"/" config.rasi
```

- [ ] **Step 2: Kiểm tra cú pháp rofi**

Run:
```bash
rofi -show drun -dump-config 2>&1 | grep -E "modi:|filebrowser|window-format|click-to-exit"
```
Expected: in ra `modi: "drun,run,window,filebrowser,power:...";`, `window-format`, `click-to-exit: true;` — KHÔNG có dòng lỗi parse.

- [ ] **Step 3: Kiểm thử trực quan (áp dụng thật)**

Mở rofi:
```bash
~/.config/sway/scripts/rofi-focused.sh -show drun
```
Expected: thấy 5 tab `Apps | Run | Window | Files | Power` (mỗi tab có icon). Shift+→ chuyển qua tab Power thấy 5 mục có icon. Tab Files duyệt được thư mục. Tab Window hiện `workspace class title`. Đóng bằng Esc.

- [ ] **Step 4: Kiểm thử power qua rofi**

Trong rofi, chuyển tab Power → chọn "Khởi động lại" → Expected: hiện 2 mục xác nhận; chọn "✗ Huỷ" → quay lại menu power gốc (KHÔNG khởi động lại). Chọn "Khoá màn" → màn khoá thật (gtklock/swaylock).

- [ ] **Step 5: Commit**

```bash
git add .config/rofi/config.rasi
git commit -m "feat: thêm tab Files + Power + window-format + click-to-exit cho rofi"
```

---

## Task 3: Toggle Super+D (mở/đóng)

**Files:**
- Modify: `.config/sway/config:60`

- [ ] **Step 1: Đổi bind sang toggle**

Trong `.config/sway/config`, dòng 60 hiện tại:
```
bindsym $mod+d exec $menu
```
Thay thành:
```
bindsym $mod+d exec pgrep -x rofi >/dev/null && pkill -x rofi || $menu
```
(`$menu` = `~/.config/sway/scripts/rofi-focused.sh -show drun`, định nghĩa ở dòng 12 — giữ nguyên.)

- [ ] **Step 2: Reload sway**

Run:
```bash
swaymsg reload
```
Expected: không báo lỗi (`swaymsg reload` trả về im lặng nếu config hợp lệ).

- [ ] **Step 3: Kiểm thử toggle**

Bấm `Super+D` → rofi mở. Bấm `Super+D` lần nữa (khi rofi đang mở) → rofi đóng.
Expected: lần bấm thứ hai đóng popup. Esc vẫn đóng như cũ.

- [ ] **Step 4: Commit**

```bash
git add .config/sway/config
git commit -m "feat: Super+D bật/tắt rofi (toggle) thay vì chỉ mở"
```

---

## Cập nhật memory (sau khi xong)

Ghi nhớ pattern script-modi rofi + giới hạn click-to-exit XWayland vào memory để lần sau khỏi dò lại. Liên kết `[[eww-popup-closer-order]]` (cùng chủ đề popup toggle).

---

## Rà soát phụ thuộc

- `rofi-power.sh` phụ thuộc `lock.sh` (đã có), `swaymsg`, `systemctl` (có sẵn).
- Tên icon Papirus đã xác minh tồn tại: `system-lock-screen`, `system-log-out`, `system-suspend`, `system-reboot`, `system-shutdown`, `window-close`.
- `filebrowser`, `click-to-exit`, `window-format` đã xác minh có trong rofi 1.7.5.
- `display-power` KHÔNG đặt trong config.rasi: nhãn tab Power do `printf '\0prompt\x1fPower'` trong script và tên modi quyết định. Nếu muốn icon ở tab Power, kiểm chứng lúc implement xem rofi có lấy `display-<modi>` cho script-modi không; nếu không, chấp nhận tab "power" không icon hoặc đặt tên modi kèm glyph.

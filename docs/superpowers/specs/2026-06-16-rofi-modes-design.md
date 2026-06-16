# Thiết kế: Mở rộng popup rofi (Super+D) thành trung tâm nhiều chế độ

Ngày: 2026-06-16
Trạng thái: Đã duyệt thiết kế, chờ viết plan

## Bối cảnh

`Super+D` hiện mở rofi qua `scripts/rofi-focused.sh -show drun`, theme ở
`.config/rofi/config.rasi` (Catppuccin Mocha, `sidebar-mode: true`,
`modi: "drun,run,window"`). Power menu đang nằm riêng ở `wlogout`
(`Super+Shift+e`). rofi bản 1.7.5, **không cài plugin ngoài** (không có
rofi-calc/emoji), chạy qua **XWayland**.

Mục tiêu: gộp các chế độ thường dùng vào một popup Super+D có tab + icon, thêm
power menu trong rofi, file browser, cải thiện window switcher, và làm rõ hành vi
thoát popup.

## Phạm vi

Có làm:
1. **Mục 4** — thoát popup: bật `click-to-exit` tường minh + toggle Super+D chắc ăn.
2. **Mục 5** — power menu trong rofi (custom script modi), có xác nhận cho hành động nguy hiểm.
3. **Mục 7** — window switcher hiển thị workspace + class + title.
4. **Files** — thêm modi `filebrowser` (built-in).
5. **Icon** cho các tab/mục mới.

Không làm (đã loại trong brainstorm):
- Web lookup (mục 8) — bỏ.
- Calc/emoji — bỏ (cần plugin ngoài).

## Kiến trúc

Một điểm vào duy nhất: `Super+D`. rofi nạp `modi:
"drun,run,window,filebrowser,power"`. Với `sidebar-mode: true`, 5 chế độ hiện
thành tab ngang có icon; chuyển tab bằng **Shift+←/→** hoặc click tab. Tab thường
giữ vai trò completion (không đổi).

```
 Super+D
   └─ rofi (rofi-focused.sh, đúng màn đang focus)
        ├─ tab  Apps    (drun)        — sẵn có
        ├─ tab  Run     (run)         — sẵn có
        ├─ tab  Window  (window)      — cải thiện format (mục 7)
        ├─ tab  Files   (filebrowser) — mới
        └─ tab  Power   (power)       — mới, script modi → rofi-power.sh
```

### Thành phần

| Thành phần | Vai trò | Phụ thuộc |
|---|---|---|
| `.config/rofi/config.rasi` | modi, hiển thị, icon tab, window-format, click-to-exit | rofi 1.7.5 |
| `.config/sway/scripts/rofi-power.sh` | script modi: liệt kê mục power + xử lý chọn + xác nhận | rofi (env `ROFI_*`), `lock.sh`, `swaymsg`, `systemctl` |
| `.config/sway/config` | đổi `bindsym $mod+d` thành toggle (mở/đóng) | `pgrep`/`pkill` |

## Chi tiết từng phần

### Phần 1 — Tab + icon (config.rasi)
- `modi: "drun,run,window,filebrowser,power:~/.config/sway/scripts/rofi-power.sh"`.
- Thêm `display-filebrowser: " Files"` (glyph Nerd Font qua codepoint khi sửa file,
  KHÔNG paste glyph trực tiếp — xem ghi chú dưới).
- `display-window`, `display-drun`, `display-run` đã có icon, giữ nguyên.
- Tab "Power" nhận label từ `display-power` nếu rofi hỗ trợ; nếu không, label do
  chính script đặt qua `\0prompt`/tên modi. Sẽ kiểm chứng lúc implement.

### Phần 2 — Power menu (rofi-power.sh)
Script modi theo giao thức rofi script mode:
- **Lần gọi đầu** (`$ROFI_RETV=0`, không có `$1`): in 5 mục, mỗi mục kèm icon
  Papirus qua `\0icon\x1f<tên>`:
  - Lock (`system-lock-screen`) → `~/.config/sway/scripts/lock.sh`
  - Logout (`system-log-out`) → `swaymsg exit`
  - Suspend (`system-suspend`) → `systemctl suspend`
  - Reboot (`system-reboot`) → `systemctl reboot`
  - Shutdown (`system-shutdown`) → `systemctl poweroff`
- **Khi chọn 1 mục** (`$ROFI_RETV=1`, `$1` = nhãn):
  - Lock, Suspend: chạy ngay (không nguy hiểm/không mất dữ liệu phiên).
  - Logout, Reboot, Shutdown: in lại 2 mục xác nhận `✓ Có, <hành động>` / `✗ Huỷ`.
    Chỉ khi chọn "Có" mới exec action; "Huỷ" quay về (in lại menu gốc).
- Action dùng lại đúng lệnh wlogout để một nguồn hành vi. `setsid`/`swaymsg exec`
  để tránh rofi giết tiến trình con khi đóng (kiểm chứng lúc implement).
- wlogout (`Super+Shift+e`) giữ nguyên, độc lập.

### Phần 3 — Thoát popup (mục 4)
- `config.rasi`: thêm `click-to-exit: true;` (tường minh hoá ý định).
- **Giới hạn đã biết:** rofi chạy XWayland nên click vào cửa sổ Wayland native có
  thể không tạo focus-out → click-ra-ngoài *không đảm bảo* đóng. Đây là giới hạn
  nền tảng, không khắc phục hoàn toàn bằng config.
- Fallback chắc ăn — `bindsym $mod+d` thành toggle:
  `pgrep -x rofi >/dev/null && pkill -x rofi || exec rofi-focused.sh -show drun`.
  Bấm Super+D lần nữa = đóng. Esc giữ nguyên.

### Phần 4 — Window switcher (mục 7)
- `config.rasi`: `window-format: "{w}  {c}  {t}";` (workspace · class · title),
  giữ `show-icons: true`. Giúp phân biệt cửa sổ trùng tên theo workspace.

## Cách kiểm thử (dotfiles: áp dụng thật rồi quan sát)
1. `swaymsg reload` (nạp lại bind Super+D mới).
2. Super+D → thấy 5 tab có icon; Shift+←/→ chuyển tab; gõ lọc trong tab.
3. Tab Power → chọn Lock (khoá thật), chọn Reboot → thấy bước xác nhận, chọn Huỷ → quay lại.
4. Super+D đang mở → bấm Super+D lần nữa → đóng (toggle).
5. Tab Files → duyệt thư mục, mở file.
6. Tab Window → thấy định dạng `workspace class title`.

## Rủi ro / lưu ý
- **Icon glyph:** khi sửa file qua công cụ, ghi Nerd Font bằng codepoint `\uXXXX`
  (Write làm rớt ký tự PUA nếu paste glyph). Kiểm `fc-query`/`fc-list` trước.
- **click-to-exit** không đảm bảo dưới XWayland — đã có toggle bù.
- **Tiến trình con power** có thể bị rofi giết khi đóng popup; cần `setsid`/
  `swaymsg exec` và kiểm chứng.
- Tên icon Papirus (`system-shutdown`...) cần xác nhận tồn tại trong theme đang dùng.

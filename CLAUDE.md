# CLAUDE.md

Hướng dẫn cho Claude Code khi làm việc trong repo này. Chi tiết đầy đủ về phím
tắt, thành phần, xử lý sự cố → xem `README.md`.

## Repo này là gì

Dotfiles cấu hình **Sway** (Wayland tiling WM) của `sowndev0106`, quản lý bằng
**git + symlink**. Mọi thứ trong `.config/<tên>/` được `install.sh` symlink vào
`~/.config/<tên>/`. Vì là symlink, **sửa file trong repo = sửa luôn config đang
chạy** — không cần copy. Một nguồn duy nhất.

- Theme: **Catppuccin Mocha**. Phím `Mod` = **Super** (Windows).
- Máy đang dùng: GPU Intel Iris Xe (KHÔNG có Nvidia rời). Phần "Hybrid GPU"
  trong `install.sh`/README chỉ kích hoạt khi phát hiện module nvidia.

## Quy ước

- **Ngôn ngữ: tiếng Việt.** Mọi comment, commit message, tài liệu viết bằng
  tiếng Việt, giọng văn giải thích dễ hiểu cho người mới (xem README làm mẫu).
- File config là dotfiles thuần (không build, không test suite). "Kiểm thử" =
  áp dụng thật rồi quan sát.
- `*.bak` bị `.gitignore` bỏ qua (bản sao lưu config cũ lúc cài).

## Bố cục thư mục

| File | Vai trò |
|---|---|
| `.config/sway/config` | Cấu hình chính + toàn bộ phím tắt |
| `.config/sway/scripts/` | `vol.sh`, `bri.sh` (OSD), `lock.sh`, `record.sh`, `launch.sh` (Nvidia) |
| `.config/kanshi/config` | Bố cục đa màn hình (auto theo số màn cắm) |
| `.config/waybar/{config,style.css}` | Thanh trạng thái |
| `.config/{rofi,wofi,foot,mako,swaylock,wlogout,gtklock}/` | Launcher, terminal, thông báo, khóa màn, menu nguồn |
| `.config/environment.d/` | Biến môi trường (bộ gõ tiếng Việt, con trỏ) |
| `install.sh` | `apt install` package + tạo symlink (apt update lỗi repo bên thứ ba không làm dừng script) |

## Áp dụng / kiểm tra thay đổi

- **Sway config:** sau khi sửa, reload bằng `swaymsg reload` (hoặc `Mod+Shift+c`).
- **waybar / mako / kanshi:** cần khởi động lại tiến trình, vd:
  `pkill kanshi; (kanshi &)` rồi kiểm tra `swaymsg -t get_outputs`.
- **Xem trạng thái thật:** `swaymsg -t get_outputs` (màn hình),
  `swaymsg -t get_inputs` (bàn phím/touchpad).

## Git

- Remote: `git@github.com:sowndev0106/sway-config.git`, branch chính `main`.
- Commit message tiếng Việt, ngắn gọn, mô tả thay đổi.
- Chỉ commit/push khi người dùng yêu cầu.

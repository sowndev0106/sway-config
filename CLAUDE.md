# CLAUDE.md

Hướng dẫn cho Claude Code khi làm việc trong repo này. Chi tiết đầy đủ về phím
tắt, thành phần, xử lý sự cố → xem `README.md`.

## Repo này là gì

Dotfiles cấu hình **Sway** (Wayland tiling WM) của `sowndev0106`, quản lý bằng
**git + symlink**. Mọi thứ trong `.config/<tên>/` được `install.sh` symlink vào
`~/.config/<tên>/`. Vì là symlink, **sửa file trong repo = sửa luôn config đang
chạy** — không cần copy. Một nguồn duy nhất.

- Theme: **Catppuccin Mocha**. Phím `Mod` = **Super** (Windows).
- Config này dùng chung cho **2 máy**: một máy chỉ có iGPU Intel, một máy có
  thêm **Nvidia rời** (Intel Arrow Lake + Nvidia, màn hình cắm vào card Nvidia).
  Mọi thứ phải **tự dò GPU lúc chạy**, không hardcode. `launch.sh` lo việc này:
  vì màn hình cắm vào Nvidia, **Nvidia làm renderer chính** (đứng đầu
  `WLR_DRM_DEVICES`) để render thẳng trên GPU đang xuất hình, khỏi copy chéo GPU
  qua PCIe mỗi frame (đường vòng đó gây giật khi kéo cửa sổ). Chạy được mượt nhờ
  Sway 1.10 có explicit-sync (`build-sway.sh`); máy chỉ-Intel thì iGPU làm
  renderer. Session "Sway (Hybrid GPU)" + `--unsupported-gpu` chỉ bật khi
  `install.sh` thấy module nvidia; máy chỉ-Intel dùng session Sway thường
  (không qua `launch.sh`).

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
| `.config/nwg-dock-hyprland/{config.toml,style.css}` | Dock app dưới màn hình, tự ẩn |
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

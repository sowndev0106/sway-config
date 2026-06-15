# sway-config

Cấu hình Sway WM (Wayland tiling) của sowndev0106, quản lý bằng git + symlink.

## Thành phần

| Công cụ | Vai trò |
|---|---|
| **sway** | Cửa sổ tiling (Wayland) |
| **waybar** | Thanh trạng thái trên cùng |
| **wofi** | Trình khởi chạy ứng dụng (`Mod+d`) |
| **foot** | Terminal (`Mod+Enter`) |
| **mako** | Thông báo |
| **swaylock / swayidle** | Khóa & tự khóa màn hình |
| **grim / slurp** | Chụp màn hình (`Print`) |

## Cài trên máy mới

```bash
git clone git@github.com:sowndev0106/sway-config.git ~/sway-config
cd ~/sway-config
./install.sh
```

Script sẽ cài package qua `apt` và tạo symlink từ `~/.config/*` vào repo này
(config cũ nếu có sẽ được đổi tên thành `*.bak`).

## Phím tắt chính

| Phím | Hành động |
|---|---|
| `Mod+Enter` | Mở terminal |
| `Mod+d` | Trình khởi chạy ứng dụng |
| `Mod+q` | Đóng cửa sổ |
| `Mod+1..0` | Chuyển workspace |
| `Mod+Shift+1..0` | Chuyển cửa sổ sang workspace |
| `Mod+f` | Toàn màn hình |
| `Mod+r` | Chế độ resize |
| `Mod+Shift+x` | Khóa màn hình |
| `Mod+Shift+c` | Reload config |
| `Mod+Shift+e` | Thoát Sway |
| `Print` | Chụp toàn màn hình |
| `Shift+Print` | Chụp vùng → clipboard |

> `Mod` = phím Super (Windows). Đổi layout/theme trong `.config/sway/config`.

## Cấu trúc repo

```
.config/
├── sway/config        # cấu hình chính
├── waybar/{config,style.css}
├── wofi/{config,style.css}
├── foot/foot.ini
└── mako/config
install.sh             # cài package + tạo symlink
```

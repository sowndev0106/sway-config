# Làm lại waybar — thiết kế (2026-06-16)

## Mục tiêu
Refactor toàn diện waybar: icon hiển thị đúng, giao diện đẹp (pill gom nhóm,
Catppuccin Mocha), dọn module mạng, tổ chức lại bố cục. Bám theo ảnh tham khảo
do người dùng cung cấp (bar dày, gom cụm hai đầu, clock ở giữa).

## Ràng buộc / bối cảnh thật
- Máy: Intel Iris Xe (không Nvidia), laptop có pin `BAT0`, độ sáng `backlight`.
- Mạng: ethernet `enp1s0`, wifi `wlp0s20f3`, kèm nhiều `docker0`/`br-*`/`veth*`
  (module network chỉ bám iface có default route nên không hiện đống ảo này).
- 3 màn hình (eDP-1, HDMI-A-1, DP-1) → bar hiện trên **tất cả các màn**.
- Font hiện chỉ có **FontAwesome v4** → phải cài Nerd Font.
- Waybar **v0.9.24**.

## Quyết định đã chốt với người dùng
- Cài **JetBrainsMono Nerd Font** (user-level `~/.local/share/fonts`, không sudo);
  cập nhật `install.sh` để tự tải/cài.
- Bar trên **tất cả màn**; style **pill bo tròn, gom nhóm**.
- Clock **ở giữa**.
- **Thêm** nút nguồn `custom/power` (trái).
- **Bỏ** mic volume.
- **Thêm** `temperature` (tự dò hwmon nhiệt CPU).

## Bố cục
```
⏻  [1] 2 3   38°C  2%  27%        13:52        25%  wifi    0   ☀  ⏻
└pwr└─ws─┘  └── sensors ──┘      └clock┘    └audio┘└net┘└bt┘ └bri└tray┘
```

| Vùng | Module |
|---|---|
| modules-left | `custom/power`, `sway/workspaces`, `sway/mode`, `temperature`, `cpu`, `memory` |
| modules-center | `clock` |
| modules-right | `pulseaudio`, `network`, `bluetooth`, `backlight`, `battery`, `tray` |

## Chi tiết module
- `custom/power`: icon nguồn, on-click mở wlogout (đã có `.config/wlogout`).
- `temperature`: tự dò `hwmon` của Intel (coretemp/x86_pkg_temp); ngưỡng critical
  đổi màu đỏ. Format `{icon} {temperatureC}°C`.
- `network`: Nerd Font phân biệt rõ wifi () / ethernet (); wifi hiện %,
  ethernet hiện IP; mất mạng đỏ.
- `bluetooth`: giữ logic màu hiện có; module waybar là nguồn DUY NHẤT cho icon BT
  (blueman-applet tray đã tắt qua `~/.config/autostart/blueman.desktop` Hidden=true).
- `backlight`: icon mặt trời + %.
- `pulseaudio`: icon loa + %; muted đổi màu/icon; on-click pavucontrol.

## Style (style.css)
- Mỗi nhóm là khối pill: nền `surface0 #313244`, bo góc, padding, margin giữa nhóm.
- Bảng màu Catppuccin Mocha; trạng thái cảnh báo/đỏ giữ như cũ.
- Font-family đặt Nerd Font trước.

## Áp dụng / kiểm thử
1. Tải Nerd Font + `fc-cache -f`.
2. Sửa `.config/waybar/config` + `.config/waybar/style.css`.
3. Cập nhật `install.sh` (bước cài Nerd Font).
4. Reload: `pkill waybar; (waybar &)` rồi quan sát thật trên cả 3 màn.

## Ngoài phạm vi
- Không đụng module/màn khác ngoài waybar.
- Không commit/push (theo CLAUDE.md, chỉ khi người dùng yêu cầu).

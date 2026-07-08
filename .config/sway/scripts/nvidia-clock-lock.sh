#!/bin/sh
# Khoá xung TỐI THIỂU của GPU Nvidia để hết GIẬT trên Wayland.
#
# Lý do gốc: trên Wayland, Nvidia hay nằm lì ở pstate sâu nhất (P8, ~277 MHz)
# và tăng xung RẤT CHẬM cho những tải ngắn-giật-cục — animation của compositor,
# cuộn trang trong Chromium (Chrome/Antigravity), kéo cửa sổ. Mỗi lần animation
# chạy, GPU mới lục đục tăng xung; animation ngắn thì chưa kịp tăng đã xong ->
# frame ra trễ -> "lâu lâu giật một cái". (iGPU Intel đổi xung nhanh/mịn nên máy
# chỉ-Intel không bị.)
#
# Cách trị: nâng SÀN xung (min) đủ cao để GPU không tụt về P8 nữa, NHƯNG vẫn để
# trần ở max nên lúc tải nặng (game/render) GPU vẫn boost hết cỡ. Đây là PC để
# bàn nên không lo tốn pin; chỉ tốn chút điện/nhiệt khi rảnh — chấp nhận được.
#
# Máy chỉ-Intel không có nvidia-smi -> thoát êm, không làm gì.
# Gọi bởi nvidia-clock-lock.service (lúc khởi động + sau mỗi lần resume).

command -v nvidia-smi >/dev/null 2>&1 || exit 0      # không có Nvidia -> thôi

MIN_MHZ=1000   # sàn xung: đủ để thoát hố P8, hết giật

# Lấy xung max thật của card (mỗi GPU một khác) làm trần, để khỏi hardcode.
max=$(nvidia-smi --query-gpu=clocks.max.gr --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
[ -n "$max" ] || exit 0

exec nvidia-smi -lgc "${MIN_MHZ},${max}"

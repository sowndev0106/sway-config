#!/usr/bin/env bash
# Chỉnh bố cục màn hình bằng wdisplays rồi TỰ LƯU thành profile kanshi.
#
# Vì sao cần script này: kanshi và wdisplays cùng điều khiển output. Nếu để kanshi
# chạy trong lúc kéo wdisplays, kanshi sẽ áp lại profile cũ -> layout bị "reset".
# Nên ở đây ta TẮT kanshi trước, mở wdisplays để bạn sắp xếp + bấm Apply, và khi
# bạn ĐÓNG cửa sổ wdisplays thì tự chụp lại layout hiện tại -> lưu -> bật lại kanshi.
#
# Cách dùng: bấm phím tắt -> wdisplays mở ra -> kéo cho ưng -> bấm "Apply" trong
# wdisplays -> ĐÓNG cửa sổ. Thông báo "Đã lưu/Cập nhật bố cục..." sẽ hiện.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1) Tắt kanshi để nó không tranh chấp với wdisplays.
pkill -x kanshi 2>/dev/null
sleep 0.2

# 2) Mở wdisplays và CHỜ tới khi bạn đóng cửa sổ.
wdisplays

# 3) Chụp layout đang áp dụng -> ghi profile kanshi -> bật lại kanshi (script lo).
exec "$SCRIPT_DIR/save-display-layout.py"

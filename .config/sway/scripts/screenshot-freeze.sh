#!/usr/bin/env bash
# Đóng băng mọi màn hình rồi chạy một lệnh (thường là chọn vùng + chụp), xong thì rã đông.
#
# Vấn đề: `slurp` chỉ vẽ khung chọn lên màn hình ĐANG CHẠY THẬT, còn ảnh chỉ được chụp sau
# khi thả chuột — nên ảnh là khung hình lúc thả chuột chứ không phải lúc bấm phím (video,
# animation, chữ đang stream... đã trôi đi mất). wayfreeze chụp mọi màn hình ngay lúc bấm
# rồi phủ khung hình đó lên trên; slurp và grim chạy sau đó thấy màn hình đứng yên.
#
# Dùng: screenshot-freeze.sh LỆNH [ĐỐI SỐ...]      (mã thoát = mã thoát của LỆNH)
# Chưa cài wayfreeze thì chạy LỆNH như bình thường (cài bằng install.sh).
# Bấm phím lần 2 khi lần 1 còn chạy thì bị bỏ qua (không chồng hai lớp đóng băng).

# KHÔNG dùng `set -e`: dù lệnh lỗi hay bị huỷ vẫn phải chạy tới bước rã đông.
set -uo pipefail

# Sway/GDM không nạp ~/.profile nên PATH thiếu ~/.cargo/bin (nơi cargo cài wayfreeze).
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

if ! command -v wayfreeze >/dev/null 2>&1; then
    exec "$@"
fi

run_dir="${XDG_RUNTIME_DIR:-/tmp}"
exec 9>"$run_dir/screenshot-freeze.lock"
flock -n 9 || exit 0

ready="$(mktemp -u "$run_dir/screenshot-freeze.XXXXXX")"
wayfreeze --hide-cursor --after-freeze-cmd "touch '$ready'" &
freezer=$!
cmd_pid=""

unfreeze() {
    [ -n "$cmd_pid" ] && kill "$cmd_pid" 2>/dev/null
    kill "$freezer" 2>/dev/null
    for _ in $(seq 20); do
        kill -0 "$freezer" 2>/dev/null || break
        sleep 0.05
    done
    if kill -0 "$freezer" 2>/dev/null; then kill -9 "$freezer" 2>/dev/null; fi
    wait "$freezer" 2>/dev/null
    rm -f "$ready"
}
trap unfreeze EXIT
trap 'exit 143' TERM INT HUP

# Chờ wayfreeze báo đã đóng băng xong (tối đa ~2 giây). Nó hỏng/thoát sớm thì chạy lệnh luôn.
for _ in $(seq 40); do
    [ -e "$ready" ] && break
    kill -0 "$freezer" 2>/dev/null || break
    sleep 0.05
done

# Chạy nền rồi `wait` để tín hiệu TERM/INT ngắt được ngay (bash trì hoãn trap tới khi lệnh
# chạy nổi xong), nhờ đó huỷ giữa chừng vẫn rã đông kịp.
# 9>&- : đóng fd khóa cho lệnh. Tiến trình nền do lệnh sinh ra (vd wl-copy của grimshot ở lại
# chạy nền để giữ clipboard) mà thừa hưởng khóa thì mọi lần bấm sau bị bỏ qua mãi mãi.
"$@" <&0 9>&- &
cmd_pid=$!
wait "$cmd_pid"
rc=$?
cmd_pid=""
exit "$rc"

#!/usr/bin/env bash
# Bật/tắt header (waybar) riêng từng màn hình.
#
# Waybar chỉ có 1 tiến trình vẽ bar trên MỌI màn, và tín hiệu bật/tắt có sẵn của nó
# (SIGUSR1) ẩn/hiện tất cả bar cùng lúc. Nhưng waybar cho lọc bar theo màn bằng key
# "output" (vd ["!DP-5", "*"] = mọi màn trừ DP-5). Nên: giữ danh sách "màn ẩn header",
# sinh 1 config tạm chứa key "output" + include config thật của repo, rồi khởi động lại
# waybar với config đó. Phải khởi động lại chứ không nạp lại bằng SIGUSR2: waybar 0.9.24
# nạp lại nhưng GIỮ giá trị cũ của key đã định nghĩa, nên "output" chỉ đổi được đúng 1 lần.
#
# Dùng:
#   waybar-outputs.sh toggle [TÊN_MÀN]     bật/tắt header của màn (mặc định: màn đang focus)
#   waybar-outputs.sh [tham số waybar...]  chạy waybar — dùng thay cho `waybar` trần
#
# Sway gọi kiểu thứ hai qua exec_always (xem sway/config, mục Bar). Không dùng được khối
# `bar { swaybar_command ... }`: sway chỉ nhận đúng 1 tên chương trình trần ở đó (không tham
# số, không mở rộng ~), nên không trỏ tới script trong repo được.
# Bước chạy waybar luôn tạo config tạm trước: nếu file include không tồn tại thì waybar báo
# "Can't open config file" và KHÔNG hiện bar nào, lần đăng nhập đầu sẽ mất header. Trạng thái
# nằm ở $XDG_RUNTIME_DIR nên đăng nhập lại là header hiện đủ ở mọi màn.

set -euo pipefail

run_dir="${XDG_RUNTIME_DIR:-/tmp}"
state="$run_dir/waybar-hidden-outputs"   # mỗi dòng 1 tên màn đang ẩn header
config="$run_dir/waybar-config.json"     # config tạm waybar đọc (-c)
real_config="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/config"

# Báo lỗi bằng `return 1` tường minh: khi hàm được gọi trong `if`, bash tắt `set -e`
# bên trong nó, nên nếu không kiểm tra thì jq hỏng sẽ để lại config RỖNG.
write_config() {
    local tmp="$config.$$" hidden='[]'
    if [ -s "$state" ]; then
        hidden=$(jq -Rn '[inputs | select(length > 0) | "!" + .] + ["*"]' < "$state") || return 1
    fi
    # Không có màn nào ẩn thì bỏ hẳn key "output" (waybar hiện trên mọi màn như thường).
    jq -n --argjson hidden "$hidden" --arg real "$real_config" \
        '(if ($hidden | length) > 0 then {output: $hidden} else {} end) + {include: [$real]}' \
        > "$tmp" || { rm -f "$tmp"; return 1; }
    mv "$tmp" "$config"   # đổi tên nguyên tử: waybar không bao giờ đọc phải file ghi dở
}

# Tắt waybar cũ, đợi nó thoát hẳn (kẻo hai bar chồng nhau), rồi bật bản mới với config tạm.
restart_waybar() {
    local i
    pkill -x waybar || true   # waybar không chạy thì thôi, vẫn bật bản mới
    for i in $(seq 60); do    # đợi tối đa ~3 giây
        pgrep -x waybar >/dev/null || break
        sleep 0.05
    done
    # 9>&- : đóng fd khóa cho waybar, kẻo nó giữ khóa suốt đời và lần bấm sau treo mãi.
    setsid -f waybar -c "$config" >/dev/null 2>&1 9>&-
}

case "${1:-}" in
    toggle)
        # Xếp hàng: bấm liên tiếp / giữ phím lâu thì các lần toggle chạy lần lượt,
        # không ghi đè trạng thái của nhau hay bật hai waybar cùng lúc.
        exec 9>"$run_dir/waybar-outputs.lock"
        flock 9
        output="${2:-$(swaymsg -r -t get_outputs 2>/dev/null \
            | jq -r '.[] | select(.focused) | .name' | head -n1 || true)}"
        if [ -z "$output" ]; then
            echo "waybar-outputs: không xác định được màn hình đang focus" >&2
            exit 1
        fi
        touch "$state"
        if grep -qxF -- "$output" "$state"; then
            grep -vxF -- "$output" "$state" > "$state.$$" || true
            mv "$state.$$" "$state"
        else
            echo "$output" >> "$state"
        fi
        write_config
        restart_waybar
        ;;
    *)
        if write_config 2>/dev/null; then
            exec waybar -c "$config" "$@"
        fi
        # Không sinh được config tạm (thiếu jq?): vẫn chạy waybar như cũ, còn hơn mất bar.
        exec waybar "$@"
        ;;
esac

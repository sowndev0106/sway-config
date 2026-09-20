#!/usr/bin/env python3
# launch-pin — cửa sổ mới luôn hiện ở đúng MÀN HÌNH nơi bạn bấm mở app.
#
# Vấn đề: sway đặt cửa sổ mới lên màn đang focus vào lúc cửa sổ HIỆN RA, không phải
# lúc bạn bấm mở. App khởi động chậm (Chrome, Discord, Electron...) hiện ra sau vài
# giây; nếu lúc đó bạn đã rê chuột sang màn khác (focus theo chuột) thì app rơi sang
# màn đó. (App mở bằng `swaymsg exec` thì sway tự đặt đúng nhờ XDG_ACTIVATION_TOKEN;
# còn app do rofi / dock / terminal spawn thì không có token nên bị lỗi này.)
#
# Cách làm, KHÔNG cần móc vào launcher nào:
#   1. Ghi nhớ "màn nào có focus vào lúc nào" (nghe sự kiện workspace của sway).
#   2. Khi có cửa sổ mới, lấy PID của app -> biết app được KHỞI ĐỘNG lúc nào
#      (/proc/<pid>/stat). Lúc khởi động chính là lúc bạn bấm mở.
#   3. Nếu app còn mới (<= MAX_AGE giây) và lúc khởi động focus ở màn khác màn
#      cửa sổ vừa hiện ra -> chuyển cửa sổ về màn lúc mở (focus của bạn vẫn ở
#      chỗ đang làm, không bị app kéo đi).
#   Mỗi cửa sổ tự tra theo tiến trình của chính nó nên mở nhiều app ở nhiều màn
#   cùng lúc vẫn về đúng màn của từng app, bất kể app nào hiện ra trước.
#
# App đã chạy lâu (Chrome mở thêm cửa sổ, nemo...) không bị động tới: cửa sổ của
# chúng đến từ tiến trình cũ nên vượt ngưỡng MAX_AGE.
#
# Chạy nền từ sway config (exec_always). Bật log: LAUNCH_PIN_DEBUG=1

import json
import os
import signal
import socket
import struct
import sys
import time
from bisect import bisect_right

MAX_AGE = 45.0        # giây: chỉ ghim app vừa khởi động trong khoảng này
HISTORY_KEEP = 600.0  # giây: nhớ lịch sử focus bấy lâu là đủ
# starttime của kernel chỉ chính xác 10ms (làm tròn xuống) và sự kiện focus đến trễ
# vài ms, nên app bấm mở ngay sau lúc đổi focus có thể bị đọc ra là khởi động TRƯỚC
# lúc đổi focus. Cộng chút dung sai khi tra; người không thể đổi focus rồi bấm mở
# (hay ngược lại) trong vài chục ms nên không ảnh hưởng ca thật.
START_SLACK = 0.03

IPC_MAGIC = b"i3-ipc"
RUN_COMMAND, GET_WORKSPACES, SUBSCRIBE, GET_TREE = 0, 1, 2, 4  # loại message của sway IPC
EVENT_WORKSPACE = 0x80000000  # bit cao = sự kiện, số thấp = loại (0 = workspace)
EVENT_WINDOW = 0x80000003

DEBUG = bool(os.environ.get("LAUNCH_PIN_DEBUG"))


def log(msg):
    if DEBUG:
        print(f"launch-pin: {msg}", file=sys.stderr, flush=True)


# ---------------------------------------------------------------------------
# Logic thuần (không đụng sway) — có test riêng
# ---------------------------------------------------------------------------

class FocusHistory:
    """Nhớ màn hình nào có focus vào thời điểm nào (giây tính từ lúc máy khởi động)."""

    def __init__(self):
        self._times = []
        self._outputs = []

    def record(self, t, output):
        if self._outputs and self._outputs[-1] == output:
            return
        self._times.append(t)
        self._outputs.append(output)
        # Quên lịch sử quá cũ, nhưng giữ lại 1 mục đang còn hiệu lực tại mốc cắt
        # để tra cứu các thời điểm sát mốc vẫn đúng.
        drop = bisect_right(self._times, t - HISTORY_KEEP) - 1
        if drop > 0:
            del self._times[:drop]
            del self._outputs[:drop]

    def output_at(self, t):
        """Màn đang focus tại thời điểm t; None nếu lúc đó daemon chưa biết gì."""
        i = bisect_right(self._times, t) - 1
        return self._outputs[i] if i >= 0 else None


def parse_start_boottime(stat_text, hz):
    """Thời điểm tiến trình khởi động (giây từ lúc boot) từ nội dung /proc/<pid>/stat."""
    # Tên tiến trình nằm trong (...) và có thể chứa dấu cách/ngoặc: cắt ở ')' cuối.
    fields = stat_text.rsplit(")", 1)[1].split()
    return int(fields[19]) / hz  # trường số 22 của stat


def launch_output(history, start):
    """Màn đang focus vào lúc app khởi động (có bù sai số START_SLACK)."""
    return history.output_at(start + START_SLACK)


def pick_target(history, start, now, current_output, outputs, max_age=MAX_AGE):
    """Màn cần chuyển cửa sổ về, hoặc None nếu cứ để yên."""
    if now - start > max_age:
        return None  # app chạy lâu rồi: cửa sổ này không phải từ lần bấm mở gần đây
    launch = launch_output(history, start)
    if launch is None or launch == current_output or launch not in outputs:
        return None
    return launch


def output_names(tree):
    return {n["name"] for n in tree.get("nodes", [])
            if n.get("type") == "output" and n.get("name") != "__i3"}


def locate(tree, con_id):
    """(tên output, tên workspace) chứa cửa sổ con_id; None nếu không thấy / ở scratchpad."""
    def walk(node, output, workspace):
        if node.get("type") == "output":
            output = node.get("name")
        elif node.get("type") == "workspace":
            workspace = node.get("name")
        if node.get("id") == con_id:
            return output, workspace
        for child in node.get("nodes", []) + node.get("floating_nodes", []):
            found = walk(child, output, workspace)
            if found:
                return found
        return None

    found = walk(tree, None, None)
    return None if found is None or found[0] == "__i3" else found


# ---------------------------------------------------------------------------
# Nối với sway
# ---------------------------------------------------------------------------

def boottime():
    # Cùng gốc thời gian với trường starttime trong /proc/<pid>/stat.
    return time.clock_gettime(time.CLOCK_BOOTTIME)


class Ipc:
    def __init__(self, path):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(path)

    def _read_exact(self, n):
        data = b""
        while len(data) < n:
            chunk = self.sock.recv(n - len(data))
            if not chunk:
                raise EOFError
            data += chunk
        return data

    def recv(self):
        magic, length, mtype = struct.unpack("=6sII", self._read_exact(14))
        if magic != IPC_MAGIC:
            raise EOFError
        return mtype, json.loads(self._read_exact(length).decode("utf-8"))

    def request(self, mtype, payload=""):
        body = payload.encode("utf-8")
        self.sock.sendall(struct.pack("=6sII", IPC_MAGIC, len(body), mtype) + body)
        return self.recv()[1]


def focused_output(cmd):
    for ws in cmd.request(GET_WORKSPACES):
        if ws.get("focused"):
            return ws.get("output")
    return None


def handle_new_window(cmd, history, hz, container):
    pid, con_id = container.get("pid"), container.get("id")
    if not pid or con_id is None:
        return
    try:
        with open(f"/proc/{pid}/stat") as f:
            start = parse_start_boottime(f.read(), hz)
    except (OSError, IndexError, ValueError):
        return  # tiến trình đã thoát / không đọc được: bỏ qua
    now = boottime()

    tree = cmd.request(GET_TREE)
    where = locate(tree, con_id)
    if not where:
        return
    target = pick_target(history, start, now, where[0], output_names(tree))
    log(f"{container.get('app_id') or (container.get('window_properties') or {}).get('class')} "
        f"pid={pid} tuổi={now - start:.1f}s ở {where[0]} mở-ở={launch_output(history, start)} -> {target}")
    if not target:
        return

    # Chuyển xong sway tự giữ focus ở màn bạn đang làm (đã kiểm tra thật), nên
    # cửa sổ hiện ở màn cũ mà không cướp focus của bạn.
    cmd.request(RUN_COMMAND, f'[con_id={con_id}] move container to output "{target}"')


def take_over_pidfile():
    """Mỗi lần reload sway chạy lại script: tắt bản cũ để không bị nhân đôi."""
    pidfile = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "sway-launch-pin.pid")
    try:
        with open(pidfile) as f:
            old = int(f.read().strip())
        with open(f"/proc/{old}/cmdline") as f:
            if old != os.getpid() and "launch-pin" in f.read():
                os.kill(old, signal.SIGTERM)
    except (OSError, ValueError):
        pass
    with open(pidfile, "w") as f:
        f.write(str(os.getpid()))


def main():
    swaysock = os.environ.get("SWAYSOCK")
    if not swaysock:
        sys.exit("launch-pin: chưa có SWAYSOCK (chạy trong session sway)")
    take_over_pidfile()

    events, cmd = Ipc(swaysock), Ipc(swaysock)
    events.request(SUBSCRIBE, json.dumps(["workspace", "window"]))
    hz = os.sysconf("SC_CLK_TCK")

    history = FocusHistory()
    start_focus = focused_output(cmd)
    if start_focus:
        history.record(boottime(), start_focus)
    log(f"chạy, focus ban đầu: {start_focus}")

    try:
        while True:
            etype, event = events.recv()
            if etype == EVENT_WORKSPACE and event.get("change") == "focus":
                output = (event.get("current") or {}).get("output")
                if output:
                    history.record(boottime(), output)
            elif etype == EVENT_WINDOW and event.get("change") == "new":
                handle_new_window(cmd, history, hz, event.get("container") or {})
    except EOFError:
        pass  # sway đã thoát


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Lưu bố cục màn hình hiện tại thành một profile kanshi.

Quy trình: kéo sắp xếp màn hình bằng wdisplays cho ưng -> chạy script này
(gắn phím Super+Shift+O). Script đọc trạng thái hiện tại từ `swaymsg -t get_outputs`,
tạo/ghi-đè một profile trong vùng AUTO của ~/.config/kanshi/config.

Nhận diện màn hình: theo TÊN CỔNG (eDP-1 / DP-1 / HDMI-A-1). Các màn ở máy này
báo serial rỗng/Unknown nên không khớp được kiểu "hãng model serial"; tên cổng
ổn định cho dàn cố định.

Profile được đặt trong vùng giữa hai mốc:
  # >>> AUTO PROFILES ... <<<   và   # <<< AUTO PROFILES <<<
Mỗi profile có dòng `# @auto-key: ...` để script tìm và thay thế khi lưu lại cùng bộ màn.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys

KANSHI_CONFIG = os.path.expanduser("~/.config/kanshi/config")
START_MARK = "# >>> AUTO PROFILES"
END_MARK = "# <<< AUTO PROFILES <<<"


def notify(msg: str, urgency: str = "normal") -> None:
    print(msg)
    try:
        subprocess.run(
            ["notify-send", "-u", urgency, "-a", "kanshi", "Bố cục màn hình", msg],
            check=False,
        )
    except FileNotFoundError:
        pass


def get_outputs() -> list[dict]:
    raw = subprocess.check_output(["swaymsg", "-t", "get_outputs"])
    return [o for o in json.loads(raw) if o.get("active")]


def selector(o: dict) -> str:
    """Chuỗi để kanshi khớp output.

    Dùng TÊN CỔNG (eDP-1 / DP-1 / HDMI-A-1): các màn ở đây báo serial rỗng/Unknown
    nên kiểu "hãng model serial" không khớp được với kanshi. Tên cổng ổn định cho
    dàn cố định; nếu cắm màn sang cổng khác thì cần lưu lại profile.
    """
    return o.get("name", "")


def mode_str(o: dict) -> str:
    m = o.get("current_mode") or {}
    if not m:
        return ""
    hz = m["refresh"] / 1000.0
    hz = f"{hz:.3f}".rstrip("0").rstrip(".")
    return f'{m["width"]}x{m["height"]}@{hz}Hz'


def output_line(o: dict) -> str:
    sel = selector(o)
    rect = o.get("rect", {})
    pos = f'{rect.get("x", 0)},{rect.get("y", 0)}'
    parts = [f'output "{sel}"', "enable"]
    mode = mode_str(o)
    if mode:
        parts += ["mode", mode]
    parts += ["position", pos]
    scale = o.get("scale", 1.0)
    if scale and abs(scale - 1.0) > 1e-6:
        parts += ["scale", f"{scale:g}"]
    transform = o.get("transform", "normal")
    if transform and transform != "normal":
        parts += ["transform", transform]
    return "    " + " ".join(parts)


def slugify(s: str) -> str:
    return re.sub(r"[^A-Za-z0-9]+", "-", s).strip("-").lower() or "profile"


def build_profile(outputs: list[dict]) -> tuple[str, str]:
    selectors = sorted(selector(o) for o in outputs)
    key = " + ".join(selectors)
    name = "auto-" + slugify("-".join(selectors))[:60]
    lines = [
        f"# @auto-key: {key}",
        f"profile {name} {{",
        *[output_line(o) for o in sorted(outputs, key=lambda x: x.get("rect", {}).get("x", 0))],
        "}",
    ]
    return key, "\n".join(lines)


def split_auto_blocks(region: str) -> dict[str, str]:
    """Tách vùng AUTO thành dict key -> block, dựa trên dòng '# @auto-key:'."""
    blocks: dict[str, str] = {}
    cur_key: str | None = None
    cur: list[str] = []
    for line in region.splitlines():
        m = re.match(r"#\s*@auto-key:\s*(.+)$", line)
        if m:
            if cur_key is not None:
                blocks[cur_key] = "\n".join(cur).rstrip()
            cur_key = m.group(1).strip()
            cur = [line]
        elif cur_key is not None:
            cur.append(line)
    if cur_key is not None:
        blocks[cur_key] = "\n".join(cur).rstrip()
    return blocks


def main() -> int:
    outputs = get_outputs()
    if not outputs:
        notify("Không thấy màn hình nào đang bật.", "critical")
        return 1

    with open(KANSHI_CONFIG, encoding="utf-8") as f:
        text = f.read()

    if START_MARK not in text or END_MARK not in text:
        notify("Thiếu mốc AUTO trong ~/.config/kanshi/config.", "critical")
        return 1

    head, rest = text.split(START_MARK, 1)
    start_line, _, after = rest.partition("\n")
    region, _, tail = after.partition(END_MARK)

    blocks = split_auto_blocks(region)
    key, block = build_profile(outputs)
    existed = key in blocks
    blocks[key] = block

    new_region = "\n\n".join(blocks[k] for k in sorted(blocks)) + "\n"
    new_text = (
        head + START_MARK + start_line + "\n"
        + new_region + END_MARK + tail
    )

    with open(KANSHI_CONFIG, "w", encoding="utf-8") as f:
        f.write(new_text)

    # Khởi động lại kanshi để nạp profile mới (layout không đổi vì đang đúng trạng thái này).
    subprocess.run(["pkill", "-x", "kanshi"], check=False)
    subprocess.Popen(
        ["kanshi"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        start_new_session=True,
    )

    verb = "Cập nhật" if existed else "Đã lưu"
    notify(f"{verb} bố cục cho: {key}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

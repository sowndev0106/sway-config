#!/usr/bin/env python3
import os
import sys
import json
import socket
import struct
import subprocess

SWAYSOCK = os.environ.get("SWAYSOCK")
if not SWAYSOCK:
    print("Error: SWAYSOCK is not set.")
    sys.exit(1)

# Sway IPC Protocol Header
# Magic: i3-ipc (6 bytes) + length (4 bytes) + type (4 bytes)
IPC_MAGIC = b"i3-ipc"
TYPE_SUBSCRIBE = 2
EVENT_WORKSPACE = 0x80000015  # 21 in hex with event bit set

def send_msg(sock, msg_type, payload):
    payload_bytes = payload.encode('utf-8')
    header = struct.pack("=6sII", IPC_MAGIC, len(payload_bytes), msg_type)
    sock.sendall(header + payload_bytes)

def read_exact(sock, n):
    data = b""
    while len(data) < n:
        packet = sock.recv(n - len(data))
        if not packet:
            return None
        data += packet
    return data

def read_msg(sock):
    header = read_exact(sock, 14)
    if not header:
        return None, None
    magic, length, msg_type = struct.unpack("=6sII", header)
    if magic != IPC_MAGIC:
        return None, None
    payload = read_exact(sock, length)
    return msg_type, payload.decode('utf-8')

def capture_workspace(ws_name, rect):
    if not ws_name or not rect:
        return
    # Chỉ chụp nếu kích thước hợp lệ
    if rect["width"] <= 0 or rect["height"] <= 0:
        return
    geom = f"{rect['x']},{rect['y']} {rect['width']}x{rect['height']}"
    dest = f"/tmp/sway-ws-{ws_name}.png"
    
    # Tạo thư mục chứa nếu chưa có (mặc định là /tmp)
    try:
        subprocess.Popen(
            ["grim", "-g", geom, dest],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    except Exception as e:
        pass

def main():
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.connect(SWAYSOCK)
    except Exception as e:
        print(f"Error connecting to SWAYSOCK: {e}")
        sys.exit(1)

    # Đăng ký sự kiện workspace
    send_msg(sock, TYPE_SUBSCRIBE, json.dumps(["workspace"]))
    msg_type, reply = read_msg(sock)
    
    print("Workspace daemon is running...")

    # Chụp ảnh workspace hiện tại lúc khởi động
    try:
        res = subprocess.run(["swaymsg", "-t", "get_workspaces"], capture_output=True, text=True)
        workspaces = json.loads(res.stdout)
        active_ws = next((w for w in workspaces if w.get("focused")), None)
        if active_ws:
            ws_name = active_ws.get("name")
            # Lấy thông tin rect của output tương ứng
            res_tree = subprocess.run(["swaymsg", "-t", "get_tree"], capture_output=True, text=True)
            tree = json.loads(res_tree.stdout)
            
            # Tìm output chứa workspace đó
            def find_output_rect(node, name):
                if node.get("type") == "output" and any(w.get("name") == name for w in node.get("nodes", [])):
                    return node.get("rect")
                for child in node.get("nodes", []) + node.get("floating_nodes", []):
                    rect = find_output_rect(child, name)
                    if rect:
                        return rect
                return None
                
            rect = find_output_rect(tree, ws_name)
            if rect:
                capture_workspace(ws_name, rect)
    except Exception:
        pass

    # Vòng lặp nhận sự kiện
    while True:
        ev_type, payload = read_msg(sock)
        if ev_type is None:
            break
        
        # Kiểm tra nếu là sự kiện workspace
        if ev_type == EVENT_WORKSPACE:
            try:
                data = json.loads(payload)
                change = data.get("change")
                if change == "focus":
                    old_ws = data.get("old")
                    if old_ws:
                        # Lấy tên và kích thước của workspace cũ để chụp lại
                        name = old_ws.get("name")
                        rect = old_ws.get("rect")
                        capture_workspace(name, rect)
            except Exception as e:
                pass

if __name__ == "__main__":
    main()

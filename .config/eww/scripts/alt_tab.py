#!/usr/bin/env python3
import os
import sys
import json
import glob
import subprocess
import signal
import time

EWW_BIN = os.path.expanduser("~/.local/bin/eww")
if not os.path.exists(EWW_BIN):
    EWW_BIN = "eww"

EWW_DIR = os.path.expanduser("~/.config/eww")
STATE_FILE = "/tmp/eww-switcher-state.json"
PID_FILE = "/tmp/eww-switcher-daemon.pid"

# Global daemon state variables
workspaces = []
index = 0
monitor = ""

def get_sway_data(cmd_type):
    res = subprocess.run(["swaymsg", "-t", cmd_type], capture_output=True, text=True)
    return json.loads(res.stdout)

def get_fallback_icon():
    fallbacks = [
        "/usr/share/icons/Papirus/48x48/apps/application-default-icon.svg",
        "/usr/share/icons/Yaru/48x48/apps/application-default-icon.png",
        "/usr/share/icons/Adwaita/48x48/apps/application-default-icon.png",
        "/usr/share/icons/Papirus/48x48/apps/utilities-terminal.svg",
    ]
    for path in fallbacks:
        if os.path.exists(path):
            return path
    return ""

def resolve_icon(app_id):
    if not app_id:
        return get_fallback_icon()
    
    app_id_lower = app_id.lower()
    desktop_dirs = [
        os.path.expanduser("~/.local/share/applications"),
        "/usr/share/applications",
        "/usr/local/share/applications"
    ]
    
    icon_name = app_id_lower
    
    # Tìm file .desktop để lấy tên icon chính xác
    for ddir in desktop_dirs:
        if not os.path.exists(ddir):
            continue
        pattern = os.path.join(ddir, f"*{app_id_lower}*.desktop")
        matches = glob.glob(pattern)
        if matches:
            try:
                with open(matches[0], 'r', errors='ignore') as f:
                    for line in f:
                        if line.startswith("Icon="):
                            icon_name = line.split("=", 1)[1].strip()
                            break
            except Exception:
                pass
            break
            
    # Tra cứu file ảnh icon theo tên icon tìm được
    icon_themes = ["Papirus", "Papirus-Dark", "Yaru", "Adwaita", "hicolor"]
    base_dirs = ["/usr/share/icons", os.path.expanduser("~/.local/share/icons")]
    
    for base in base_dirs:
        for theme in icon_themes:
            theme_dir = os.path.join(base, theme)
            if not os.path.exists(theme_dir):
                continue
            search_paths = [
                os.path.join(theme_dir, "scalable", "apps"),
                os.path.join(theme_dir, "48x48", "apps"),
                os.path.join(theme_dir, "symbolic", "apps"),
                os.path.join(theme_dir, "scalable"),
                os.path.join(theme_dir, "48x48"),
            ]
            for spath in search_paths:
                if os.path.exists(spath):
                    for ext in [".svg", ".png"]:
                        exact_file = os.path.join(spath, f"{icon_name}{ext}")
                        if os.path.exists(exact_file):
                            return exact_file
                        lower_file = os.path.join(spath, f"{icon_name.lower()}{ext}")
                        if os.path.exists(lower_file):
                            return lower_file
                            
    pixmap_dir = "/usr/share/pixmaps"
    if os.path.exists(pixmap_dir):
        for ext in [".svg", ".png"]:
            exact_file = os.path.join(pixmap_dir, f"{icon_name}{ext}")
            if os.path.exists(exact_file):
                return exact_file
            lower_file = os.path.join(pixmap_dir, f"{icon_name.lower()}{ext}")
            if os.path.exists(lower_file):
                return lower_file
                
    return get_fallback_icon()

def find_apps_in_workspace(node, apps_list):
    """Hàm đệ quy tìm các app nằm trong một node workspace."""
    node_type = node.get("type")
    if node_type in ("con", "floating_con"):
        if not node.get("nodes") and not node.get("floating_nodes"):
            node_name = node.get("name")
            if node_name and (node.get("app_id") or node.get("window_properties")):
                app_id = node.get("app_id") or node.get("window_properties", {}).get("class")
                if app_id and "eww" not in app_id.lower() and "waybar" not in app_id.lower():
                    apps_list.append({
                        "app_id": app_id,
                        "icon": resolve_icon(app_id)
                    })
    
    children = node.get("nodes", []) + node.get("floating_nodes", [])
    for child in children:
        find_apps_in_workspace(child, apps_list)

def handle_next(signum, frame):
    global index, workspaces
    if not workspaces:
        return
    index = (index + 1) % len(workspaces)
    subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_index={index}"])

def handle_prev(signum, frame):
    global index, workspaces
    if not workspaces:
        return
    index = (index - 1) % len(workspaces)
    subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_index={index}"])

def handle_select(signum, frame):
    global index, workspaces
    if workspaces and 0 <= index < len(workspaces):
        target_ws = workspaces[index]
        subprocess.run(["swaymsg", f"workspace {target_ws['name']}"])
    cleanup_and_exit()

def handle_cancel(signum, frame):
    cleanup_and_exit()

def cleanup_and_exit():
    subprocess.run([EWW_BIN, "--config", EWW_DIR, "close", "switcher"])
    if os.path.exists(STATE_FILE):
        try:
            os.remove(STATE_FILE)
        except Exception:
            pass
    if os.path.exists(PID_FILE):
        try:
            os.remove(PID_FILE)
        except Exception:
            pass
    sys.exit(0)

def start_daemon(start_prev=False):
    global index, workspaces, monitor
    
    try:
        # 0. Đăng ký signal trước để nhận diện sự kiện ngay khi chạy
        signal.signal(signal.SIGUSR1, handle_next)
        signal.signal(signal.SIGUSR2, handle_prev)
        signal.signal(signal.SIGTERM, handle_select)
        signal.signal(signal.SIGINT, handle_cancel)
        
        # 1. Ghi đè file PID để báo hiệu tiến trình đã sẵn sàng nhận signal
        my_pid = os.getpid()
        with open(PID_FILE, "w") as f:
            f.write(str(my_pid))
        
        # 1. Truy vấn Sway IPC
        tree = get_sway_data("get_tree")
        outputs = get_sway_data("get_outputs")
        workspaces_data = get_sway_data("get_workspaces")
        
        monitor = next((o["name"] for o in outputs if o["focused"]), None)
        if not monitor:
            cleanup_and_exit()
            return
            
        output_workspaces = [w for w in workspaces_data if w["output"] == monitor]
        output_workspaces.sort(key=lambda w: w["name"])
        
        workspace_nodes = {}
        def find_ws_nodes(node):
            if node.get("type") == "workspace":
                workspace_nodes[node.get("name")] = node
            for child in node.get("nodes", []) + node.get("floating_nodes", []):
                find_ws_nodes(child)
        find_ws_nodes(tree)
        
        workspaces = []
        for idx, ws in enumerate(output_workspaces):
            ws_name = ws["name"]
            node = workspace_nodes.get(ws_name, {})
            apps = []
            find_apps_in_workspace(node, apps)
            
            preview_path = f"/tmp/sway-ws-{ws_name}.png"
            if not os.path.exists(preview_path):
                preview_path = ""
                
            workspaces.append({
                "name": ws_name,
                "idx": idx,
                "apps": apps,
                "thumbnail": preview_path,
                "focused": ws.get("focused", False)
            })
            
        if not workspaces:
            cleanup_and_exit()
            return
            
        active_idx = next((w["idx"] for w in workspaces if w["focused"]), 0)
        if start_prev:
            index = (active_idx - 1) % len(workspaces)
        else:
            index = (active_idx + 1) % len(workspaces) if len(workspaces) > 1 else active_idx
            
        state = {
            "workspaces": workspaces,
            "index": index,
            "monitor": monitor
        }
        with open(STATE_FILE, "w") as f:
            json.dump(state, f)
            
        # Cập nhật Eww
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_workspaces={json.dumps(workspaces)}"])
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_index={index}"])
        
        # Mở Eww Switcher
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "open", "switcher", "--arg", f"monitor={monitor}"])
        
        # Vòng lặp chờ tín hiệu
        while True:
            signal.pause()
            
    except Exception as e:
        cleanup_and_exit()

def main():
    if len(sys.argv) < 2:
        sys.exit(1)
    cmd = sys.argv[1]
    
    if cmd == "start":
        # Kiểm tra xem có daemon cũ còn sống không
        if os.path.exists(PID_FILE):
            try:
                with open(PID_FILE, "r") as f:
                    old_pid = int(f.read().strip())
                os.kill(old_pid, 0)
                # Nếu process còn sống -> thoát
                sys.exit(0)
            except Exception:
                pass
        # Khởi chạy daemon thực tế chạy ngầm
        subprocess.Popen([sys.executable, __file__, "daemon"])
        # Chờ cho đến khi daemon ghi file PID báo hiệu sẵn sàng (tối đa 1 giây)
        for _ in range(200):
            if os.path.exists(PID_FILE):
                break
            time.sleep(0.005)
        sys.exit(0)
        
    elif cmd == "start_prev":
        if os.path.exists(PID_FILE):
            try:
                with open(PID_FILE, "r") as f:
                    old_pid = int(f.read().strip())
                os.kill(old_pid, 0)
                sys.exit(0)
            except Exception:
                pass
        subprocess.Popen([sys.executable, __file__, "daemon_prev"])
        # Chờ cho đến khi daemon ghi file PID báo hiệu sẵn sàng (tối đa 1 giây)
        for _ in range(200):
            if os.path.exists(PID_FILE):
                break
            time.sleep(0.005)
        sys.exit(0)
        
    elif cmd == "daemon":
        start_daemon(start_prev=False)
        
    elif cmd == "daemon_prev":
        start_daemon(start_prev=True)
        
    elif cmd == "toggle_next":
        if os.path.exists(PID_FILE):
            try:
                with open(PID_FILE, "r") as f:
                    pid = int(f.read().strip())
                os.kill(pid, signal.SIGUSR1)
            except Exception:
                pass
                
    elif cmd == "toggle_prev":
        if os.path.exists(PID_FILE):
            try:
                with open(PID_FILE, "r") as f:
                    pid = int(f.read().strip())
                os.kill(pid, signal.SIGUSR2)
            except Exception:
                pass
                
    elif cmd == "check_and_select" or cmd == "select":
        if os.path.exists(PID_FILE):
            try:
                with open(PID_FILE, "r") as f:
                    pid = int(f.read().strip())
                os.kill(pid, signal.SIGTERM)
            except Exception:
                pass
                
    elif cmd == "close":
        if os.path.exists(PID_FILE):
            try:
                with open(PID_FILE, "r") as f:
                    pid = int(f.read().strip())
                os.kill(pid, signal.SIGINT)
            except Exception:
                pass

if __name__ == "__main__":
    main()

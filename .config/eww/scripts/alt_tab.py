#!/usr/bin/env python3
import os
import sys
import json
import glob
import subprocess
import signal
from datetime import datetime

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

def write_state():
    global workspaces, index, monitor
    try:
        state = {
            "workspaces": workspaces,
            "index": index,
            "monitor": monitor
        }
        with open(STATE_FILE, "w") as f:
            json.dump(state, f)
    except Exception:
        pass

def handle_next(signum, frame):
    global index, workspaces
    if not workspaces:
        return
    index = (index + 1) % len(workspaces)
    write_state()
    subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_index={index}"])

def handle_prev(signum, frame):
    global index, workspaces
    if not workspaces:
        return
    index = (index - 1) % len(workspaces)
    write_state()
    subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_index={index}"])

def handle_select(signum, frame):
    cleanup_and_exit()

def handle_cancel(signum, frame):
    cleanup_and_exit()

def cleanup_and_exit(close_eww=True):
    if close_eww:
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
    if os.path.exists("/tmp/alt-tab-grabbed"):
        try:
            os.remove("/tmp/alt-tab-grabbed")
        except Exception:
            pass
    os._exit(0)

def kill_daemon():
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, "r") as f:
                pid = int(f.read().strip())
            os.kill(pid, signal.SIGKILL)
        except Exception:
            pass
        try:
            os.remove(PID_FILE)
        except Exception:
            pass
    if os.path.exists("/tmp/alt-tab-grabbed"):
        try:
            os.remove("/tmp/alt-tab-grabbed")
        except Exception:
            pass

def select_and_exit(close_eww=True):
    global index, workspaces
    try:
        if workspaces and 0 <= index < len(workspaces):
            target_ws = workspaces[index]
            subprocess.run(["swaymsg", f"workspace {target_ws['name']}"])
    except Exception:
        pass
    cleanup_and_exit(close_eww)

def close_and_exit(close_eww=True):
    cleanup_and_exit(close_eww)

class KeyboardGrabber:
    def __init__(self):
        import gi
        gi.require_version('Gtk', '3.0')
        gi.require_version('Gdk', '3.0')
        gi.require_version('GtkLayerShell', '0.1')
        from gi.repository import Gtk, Gdk, GtkLayerShell
        
        self.Gtk = Gtk
        self.Gdk = Gdk
        self.GtkLayerShell = GtkLayerShell
        
        self.win = Gtk.Window()
        self.GtkLayerShell.init_for_window(self.win)
        
        # Cấu hình cửa sổ ẩn 1x1, trên cùng và trong suốt
        self.win.set_size_request(1, 1)
        self.win.set_keep_above(True)
        self.win.set_opacity(0.0)
        
        self.GtkLayerShell.set_layer(self.win, self.GtkLayerShell.Layer.OVERLAY)
        self.GtkLayerShell.set_keyboard_mode(self.win, self.GtkLayerShell.KeyboardMode.EXCLUSIVE)
        
        self.win.connect("key-press-event", self.on_key_press)
        self.win.connect("key-release-event", self.on_key_release)
        self.win.connect("focus-in-event", self.on_focus_in)
        self.win.connect("destroy", self.Gtk.main_quit)
        
        self.popup_opened = False
        
    def start(self):
        from gi.repository import GLib
        self.win.show_all()
        self.win.present()
        
        # Trì hoãn mở popup Eww 150ms
        GLib.timeout_add(150, self.open_switcher_popup)
        
        self.Gtk.main()
        
    def open_switcher_popup(self):
        global monitor
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "open", "switcher", "--arg", f"monitor={monitor}"])
        self.popup_opened = True
        return False
        
    def on_focus_in(self, widget, event):
        now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")
        try:
            with open("/tmp/alt-tab.log", "a") as f:
                f.write(f"{now_str} - GTK Focus In\n")
        except Exception:
            pass
        try:
            with open("/tmp/alt-tab-grabbed", "w") as f:
                f.write("1")
        except Exception:
            pass
        return False
        
    def on_key_press(self, widget, event):
        global index, workspaces
        keyval = event.keyval
        state = event.state
        
        now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")
        try:
            with open("/tmp/alt-tab.log", "a") as f:
                f.write(f"{now_str} - GTK Press: {keyval}, state: {state}\n")
        except Exception:
            pass
            
        if keyval in (self.Gdk.KEY_Alt_L, self.Gdk.KEY_Alt_R):
            return True
            
        if keyval == self.Gdk.KEY_Tab:
            is_shift = bool(state & self.Gdk.ModifierType.SHIFT_MASK)
            if is_shift:
                index = (index - 1) % len(workspaces)
            else:
                index = (index + 1) % len(workspaces)
            write_state()
            subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_index={index}"])
            return True
            
        elif keyval == self.Gdk.KEY_ISO_Left_Tab:
            index = (index - 1) % len(workspaces)
            write_state()
            subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_index={index}"])
            return True
            
        elif keyval == self.Gdk.KEY_Escape:
            self.win.destroy()
            close_and_exit(self.popup_opened)
            return True
            
        return False
        
    def on_key_release(self, widget, event):
        keyval = event.keyval
        
        now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")
        try:
            with open("/tmp/alt-tab.log", "a") as f:
                f.write(f"{now_str} - GTK Release: {keyval}\n")
        except Exception:
            pass
            
        if keyval in (self.Gdk.KEY_Alt_L, self.Gdk.KEY_Alt_R):
            self.win.destroy()
            select_and_exit(self.popup_opened)
            return True
            
        return False


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
        
        # 2. Truy vấn Sway IPC
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
        
        # Chạy GTK grabber để bắt phím (Eww Switcher sẽ được mở sau 150ms trì hoãn trong grabber)
        grabber = KeyboardGrabber()
        grabber.start()
        
    except Exception as e:
        import traceback
        with open("/tmp/alt-tab-daemon-error.log", "w") as f:
            traceback.print_exc(file=f)
        cleanup_and_exit()

def cmd_select():
    # 0. Nếu grabber đã hoạt động và chiếm bàn phím, để grabber tự xử lý việc thả Alt
    if os.path.exists("/tmp/alt-tab-grabbed"):
        return
        
    # 1. Diệt daemon ngầm ngay lập tức
    kill_daemon()
    
    # 2. Đọc file trạng thái mới nhất để thực hiện chuyển workspace
    try:
        if os.path.exists(STATE_FILE):
            with open(STATE_FILE, "r") as f:
                state = json.load(f)
            workspaces_data = state.get("workspaces", [])
            curr_idx = state.get("index", 0)
            if workspaces_data and 0 <= curr_idx < len(workspaces_data):
                target_ws = workspaces_data[curr_idx]
                subprocess.run(["swaymsg", f"workspace {target_ws['name']}"])
    except Exception:
        pass
        
    # 3. Dọn dẹp giao diện
    subprocess.run([EWW_BIN, "--config", EWW_DIR, "close", "switcher"])
    if os.path.exists(STATE_FILE):
        try:
            os.remove(STATE_FILE)
        except Exception:
            pass

def cmd_close():
    # Diệt daemon và đóng giao diện
    kill_daemon()
    subprocess.run([EWW_BIN, "--config", EWW_DIR, "close", "switcher"])
    if os.path.exists(STATE_FILE):
        try:
            os.remove(STATE_FILE)
        except Exception:
            pass

def main():
    if len(sys.argv) < 2:
        sys.exit(1)
    cmd = sys.argv[1]
    
    if cmd == "start":
        kill_daemon()
        if os.path.exists("/tmp/alt-tab-grabbed"):
            try:
                os.remove("/tmp/alt-tab-grabbed")
            except Exception:
                pass
        log_file = open("/tmp/alt-tab-daemon.log", "w")
        p = subprocess.Popen([sys.executable, __file__, "daemon"], stdout=log_file, stderr=log_file)
        try:
            with open(PID_FILE, "w") as f:
                f.write(str(p.pid))
        except Exception:
            pass
        sys.exit(0)
        
    elif cmd == "start_prev":
        kill_daemon()
        if os.path.exists("/tmp/alt-tab-grabbed"):
            try:
                os.remove("/tmp/alt-tab-grabbed")
            except Exception:
                pass
        log_file = open("/tmp/alt-tab-daemon.log", "w")
        p = subprocess.Popen([sys.executable, __file__, "daemon_prev"], stdout=log_file, stderr=log_file)
        try:
            with open(PID_FILE, "w") as f:
                f.write(str(p.pid))
        except Exception:
            pass
        sys.exit(0)
        
    elif cmd == "daemon":
        start_daemon(start_prev=False)
        
    elif cmd == "daemon_prev":
        start_daemon(start_prev=True)
        
    elif cmd == "select":
        cmd_select()
        
    elif cmd == "close":
        cmd_close()

if __name__ == "__main__":
    main()

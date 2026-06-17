#!/usr/bin/env python3
import os
import sys
import json
import glob
import subprocess

EWW_BIN = os.path.expanduser("~/.local/bin/eww")
if not os.path.exists(EWW_BIN):
    EWW_BIN = "eww"

EWW_DIR = os.path.expanduser("~/.config/eww")
STATE_FILE = "/tmp/eww-switcher-state.json"

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

def find_windows_with_focus(node, visible_workspaces, path=(), current_output=None, current_workspace=None):
    node_id = node.get("id")
    node_type = node.get("type")
    node_name = node.get("name")
    
    if node_type == "output":
        current_output = node_name
    elif node_type == "workspace":
        current_workspace = node_name
        
    is_window = False
    if node_type in ("con", "floating_con"):
        if not node.get("nodes") and not node.get("floating_nodes"):
            if node_name and (node.get("app_id") or node.get("window_properties")):
                app_id = node.get("app_id") or node.get("window_properties", {}).get("class")
                if app_id and "eww" not in app_id.lower() and "waybar" not in app_id.lower():
                    is_window = True
                    
    if is_window:
        app_id = node.get("app_id") or node.get("window_properties", {}).get("class")
        is_visible = current_workspace in visible_workspaces
        return [{
            "id": node_id,
            "name": node_name,
            "app_id": app_id,
            "workspace": current_workspace,
            "output": current_output,
            "focused": node.get("focused", False),
            "focus_path": path,
            "visible": is_visible,
            "rect": node.get("rect")
        }]
        
    focus_list = node.get("focus", [])
    windows = []
    children = node.get("nodes", []) + node.get("floating_nodes", [])
    for child in children:
        child_id = child.get("id")
        try:
            focus_idx = focus_list.index(child_id)
        except ValueError:
            focus_idx = 9999
            
        child_path = path + (focus_idx,)
        windows.extend(find_windows_with_focus(child, visible_workspaces, child_path, current_output, current_workspace))
        
    return windows

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

def cmd_start():
    try:
        tree = get_sway_data("get_tree")
        outputs = get_sway_data("get_outputs")
        workspaces = get_sway_data("get_workspaces")
        
        focused_output = next((o["name"] for o in outputs if o["focused"]), None)
        if not focused_output:
            return
            
        # Chỉ lấy các workspace thuộc màn hình hiện tại
        output_workspaces = [w for w in workspaces if w["output"] == focused_output]
        
        # Sắp xếp các workspace theo tên/id
        output_workspaces.sort(key=lambda w: w["name"])
        
        # Đọc dữ liệu cây để lấy danh sách app của từng workspace
        workspace_nodes = {}
        def find_ws_nodes(node):
            if node.get("type") == "workspace":
                workspace_nodes[node.get("name")] = node
            for child in node.get("nodes", []) + node.get("floating_nodes", []):
                find_ws_nodes(child)
        find_ws_nodes(tree)
        
        formatted_workspaces = []
        for idx, ws in enumerate(output_workspaces):
            ws_name = ws["name"]
            node = workspace_nodes.get(ws_name, {})
            apps = []
            find_apps_in_workspace(node, apps)
            
            # Ảnh preview lưu bởi daemon
            preview_path = f"/tmp/sway-ws-{ws_name}.png"
            if not os.path.exists(preview_path):
                preview_path = ""
                
            formatted_workspaces.append({
                "name": ws_name,
                "idx": idx,
                "apps": apps,
                "thumbnail": preview_path,
                "focused": ws.get("focused", False)
            })
            
        if not formatted_workspaces:
            return
            
        # Xác định workspace cần chuyển tới đầu tiên (kế tiếp của active)
        active_idx = next((w["idx"] for w in formatted_workspaces if w["focused"]), 0)
        sel_idx = (active_idx + 1) % len(formatted_workspaces) if len(formatted_workspaces) > 1 else active_idx
        
        state = {
            "workspaces": formatted_workspaces,
            "index": sel_idx,
            "monitor": focused_output
        }
        with open(STATE_FILE, "w") as f:
            json.dump(state, f)
            
        # Cập nhật Eww ngay lập tức
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_workspaces={json.dumps(formatted_workspaces)}"])
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_index={sel_idx}"])
        
        # Mở Eww Switcher trên màn hình
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "open", "switcher", "--arg", f"monitor={focused_output}"])
        
    except Exception as e:
        emergency_cleanup()

def cmd_next():
    navigate(1)

def cmd_prev():
    navigate(-1)

def cmd_toggle_next():
    """Nếu switcher đang mở → navigate next. Nếu chưa mở → start mới."""
    if os.path.exists(STATE_FILE):
        navigate(1)
    else:
        cmd_start()

def cmd_toggle_prev():
    """Nếu switcher đang mở → navigate prev. Nếu chưa mở → start."""
    if os.path.exists(STATE_FILE):
        navigate(-1)
    else:
        cmd_start()

def navigate(step):
    try:
        if not os.path.exists(STATE_FILE):
            return
        with open(STATE_FILE, "r") as f:
            state = json.load(f)
            
        workspaces = state["workspaces"]
        if not workspaces:
            return
            
        curr_idx = state["index"]
        new_idx = (curr_idx + step) % len(workspaces)
        state["index"] = new_idx
        
        with open(STATE_FILE, "w") as f:
            json.dump(state, f)
            
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_index={new_idx}"])
    except Exception:
        emergency_cleanup()

def cmd_select():
    try:
        if not os.path.exists(STATE_FILE):
            emergency_cleanup()
            return
        with open(STATE_FILE, "r") as f:
            state = json.load(f)
            
        workspaces = state["workspaces"]
        curr_idx = state["index"]
        
        if workspaces and 0 <= curr_idx < len(workspaces):
            target_ws = workspaces[curr_idx]
            subprocess.run(["swaymsg", f"workspace {target_ws['name']}"])
            
        emergency_cleanup()
    except Exception:
        emergency_cleanup()

def cmd_check_and_select():
    """Chỉ select nếu switcher đang mở (state file tồn tại)."""
    if os.path.exists(STATE_FILE):
        cmd_select()

def emergency_cleanup():
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
        cmd_start()
    elif cmd == "toggle_next":
        cmd_toggle_next()
    elif cmd == "toggle_prev":
        cmd_toggle_prev()
    elif cmd == "next":
        cmd_next()
    elif cmd == "prev":
        cmd_prev()
    elif cmd == "select":
        cmd_select()
    elif cmd == "check_and_select":
        cmd_check_and_select()
    elif cmd == "close":
        emergency_cleanup()

if __name__ == "__main__":
    main()

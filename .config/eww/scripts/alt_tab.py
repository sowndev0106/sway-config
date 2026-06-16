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

def cmd_start():
    try:
        tree = get_sway_data("get_tree")
        outputs = get_sway_data("get_outputs")
        workspaces = get_sway_data("get_workspaces")
        
        focused_output = next((o["name"] for o in outputs if o["focused"]), None)
        if not focused_output:
            return
            
        output_workspaces = {w["name"] for w in workspaces if w["output"] == focused_output}
        visible_workspaces = {w["name"] for w in workspaces if w["output"] == focused_output and w["visible"]}
        
        # Lấy danh sách cửa sổ và sắp xếp theo MRU
        all_windows = find_windows_with_focus(tree, visible_workspaces)
        output_windows = [w for w in all_windows if w["workspace"] in output_workspaces]
        output_windows.sort(key=lambda w: w["focus_path"])
        
        if not output_windows:
            return
            
        # Ban đầu, tạo danh sách cửa sổ với thumbnail trống để hiển thị giao diện ngay lập tức
        formatted_windows = []
        for idx, win in enumerate(output_windows):
            formatted_windows.append({
                "id": win["id"],
                "idx": idx,
                "name": win["name"],
                "app_id": win["app_id"],
                "workspace": win["workspace"],
                "visible": win["visible"],
                "thumbnail": "",  # Hiển thị icon placeholder trước
                "icon": resolve_icon(win["app_id"])
            })
            
        sel_idx = 1 if len(formatted_windows) > 1 else 0
        
        state = {
            "windows": formatted_windows,
            "index": sel_idx,
            "monitor": focused_output
        }
        with open(STATE_FILE, "w") as f:
            json.dump(state, f)
            
        # Cập nhật Eww ngay lập tức
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_windows={json.dumps(formatted_windows)}"])
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_index={sel_idx}"])
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_focused_title={formatted_windows[sel_idx]['name']}"])
        
        # Mở Eww Switcher trên màn hình
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "open", "switcher", "--arg", f"monitor={focused_output}"])
        
        # Không dùng mode nữa — tất cả bindings ở global default mode
        # (--release Alt_L chỉ fire ược ở default mode)
        
        # Fork một tiến trình con để chụp ảnh màn hình các cửa sổ visible trong nền
        try:
            pid = os.fork()
            if pid == 0:
                # Tiến trình con
                # Đóng luồng xuất nhập chuẩn để tránh treo tiến trình gọi
                try:
                    sys.stdout.close()
                    sys.stderr.close()
                    os.close(0)
                except Exception:
                    pass
                
                processes = []
                for win in output_windows:
                    if win["visible"] and win["rect"]:
                        rect = win["rect"]
                        geom = f"{rect['x']},{rect['y']} {rect['width']}x{rect['height']}"
                        thumbnail_path = f"/tmp/sway-win-{win['id']}.png"
                        try:
                            p = subprocess.Popen(
                                ["grim", "-g", geom, thumbnail_path],
                                stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL
                            )
                            processes.append((p, win["id"], thumbnail_path))
                        except Exception:
                            pass
                
                # Đợi các tiến trình grim hoàn thành
                for p, win_id, t_path in processes:
                    try:
                        p.wait()
                    except Exception:
                        pass
                
                # Đọc lại file state hiện tại và cập nhật đường dẫn thumbnail mới chụp
                if os.path.exists(STATE_FILE):
                    try:
                        with open(STATE_FILE, "r") as f:
                            state = json.load(f)
                        
                        updated_wins = []
                        for win in state.get("windows", []):
                            # Tìm xem cửa sổ này có ảnh vừa chụp không
                            for p, win_id, t_path in processes:
                                if win["id"] == win_id:
                                    win["thumbnail"] = t_path
                                    break
                            updated_wins.append(win)
                        
                        state["windows"] = updated_wins
                        with open(STATE_FILE, "w") as f:
                            json.dump(state, f)
                            
                        # Cập nhật lại Eww để hiển thị ảnh chụp màn hình
                        subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_windows={json.dumps(updated_wins)}"])
                    except Exception:
                        pass
                
                sys.exit(0)
        except Exception:
            pass
            
    except Exception:
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
    """Nếu switcher đang mở → navigate prev. Nếu chưa mở → start và đến item cuối."""
    if os.path.exists(STATE_FILE):
        navigate(-1)
    else:
        cmd_start()  # start sẽ chọn idx=1 (previous window theo MRU)

def navigate(step):
    try:
        if not os.path.exists(STATE_FILE):
            return
        with open(STATE_FILE, "r") as f:
            state = json.load(f)
            
        windows = state["windows"]
        if not windows:
            return
            
        curr_idx = state["index"]
        new_idx = (curr_idx + step) % len(windows)
        state["index"] = new_idx
        
        with open(STATE_FILE, "w") as f:
            json.dump(state, f)
            
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_index={new_idx}"])
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_focused_title={windows[new_idx]['name']}"])
    except Exception:
        emergency_cleanup()

def cmd_select():
    try:
        if not os.path.exists(STATE_FILE):
            emergency_cleanup()
            return
        with open(STATE_FILE, "r") as f:
            state = json.load(f)
            
        windows = state["windows"]
        curr_idx = state["index"]
        
        if windows and 0 <= curr_idx < len(windows):
            target_win = windows[curr_idx]
            subprocess.run(["swaymsg", f"[con_id={target_win['id']}] focus"])
            
        emergency_cleanup()
    except Exception:
        emergency_cleanup()

def cmd_check_and_select():
    """Chỉ select nếu switcher đang mở (state file tồn tại).
    Dùng cho binding --release Alt_L ở global scope — an toàn gọi khi switcher đóng."""
    if os.path.exists(STATE_FILE):
        cmd_select()

def emergency_cleanup():
    # Không cần reset mode nữa (không dùng mode "switcher")
    subprocess.run([EWW_BIN, "--config", EWW_DIR, "close", "switcher"])
    # Xoá ảnh tạm để tránh tốn dung lượng
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                state = json.load(f)
            for win in state.get("windows", []):
                if win.get("thumbnail") and os.path.exists(win["thumbnail"]):
                    os.remove(win["thumbnail"])
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

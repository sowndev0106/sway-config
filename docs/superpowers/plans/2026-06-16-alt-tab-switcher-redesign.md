# Alt+Tab Switcher UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thiết kế lại bộ chuyển đổi Alt+Tab để khớp chính xác với thiết kế mockup: hiển thị dưới dạng một popup nổi nhỏ ở giữa màn hình (không phủ mờ toàn màn hình), hiển thị ảnh chụp màn hình thật (thumbnail) của các cửa sổ đang mở trên màn hình bằng `grim`, và hiển thị icon ứng dụng chồng ở góc dưới bên phải của thumbnail bằng widget `overlay` của Eww.

**Architecture:** 
1. Script `alt_tab.py` được nâng cấp để xác định các cửa sổ thuộc workspace đang hiển thị (visible) và gọi lệnh `grim` song song để lấy ảnh chụp màn hình cửa sổ đó lưu vào `/tmp`.
2. Eww window `switcher` được chuyển sang kích thước nhỏ cố định (ví dụ: `800px` x `200px`) căn giữa màn hình.
3. Sử dụng widget `overlay` trong Eww để vẽ đè icon ứng dụng lên trên thumbnail/placeholder ở góc dưới bên phải.
4. Điều chỉnh CSS để tạo bóng đổ, bo góc ứng dụng và tạo viền sáng màu xanh dương nổi bật khi di chuyển.

**Tech Stack:** Sway IPC, grim, Python 3 (subprocess), Eww (overlay, box, image), CSS.

---

## File Structure

- [MODIFY] [alt_tab.py](file:///home/sown/workplace/sway-config/.config/eww/scripts/alt_tab.py)
  - Xác định trạng thái visible của workspace, chụp màn hình song song và truyền đường dẫn ảnh sang Eww.
- [MODIFY] [eww.yuck](file:///home/sown/workplace/sway-config/.config/eww/eww.yuck)
  - Đổi kích thước cửa sổ `switcher` thành popup nhỏ và cấu trúc widget sử dụng `overlay` vẽ đè icon.
- [MODIFY] [eww.css](file:///home/sown/workplace/sway-config/.config/eww/eww.css)
  - Cấu trúc lại CSS để tạo giao diện popup nổi, thumbnail bo góc tròn, badge chứa icon ứng dụng ở góc dưới bên phải và viền phát sáng.

---

### Task 1: Update Python Script for Window Capturing

**Files:**
- Modify: `.config/eww/scripts/alt_tab.py`

- [ ] **Step 1: Cập nhật mã nguồn chụp màn hình song song trong alt_tab.py**
Mở file `/home/sown/workplace/sway-config/.config/eww/scripts/alt_tab.py` và thay thế toàn bộ nội dung bằng mã nguồn tối ưu hóa dưới đây để xác định tính hiển thị của cửa sổ và chụp ảnh bằng `grim` song song:

```python
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

def is_switcher_open():
    res = subprocess.run([EWW_BIN, "--config", EWW_DIR, "active-windows"], capture_output=True, text=True)
    return "switcher" in res.stdout

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
            
        # Chụp ảnh màn hình cửa sổ đang hiển thị song song
        processes = []
        formatted_windows = []
        for idx, win in enumerate(output_windows):
            thumbnail_path = ""
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
                    processes.append(p)
                except Exception:
                    thumbnail_path = ""
            
            formatted_windows.append({
                "id": win["id"],
                "idx": idx,
                "name": win["name"],
                "app_id": win["app_id"],
                "workspace": win["workspace"],
                "visible": win["visible"],
                "thumbnail": thumbnail_path,
                "icon": resolve_icon(win["app_id"])
            })
            
        # Đợi tất cả tiến trình grim hoàn thành
        for p in processes:
            p.wait()
            
        sel_idx = 1 if len(formatted_windows) > 1 else 0
        
        state = {
            "windows": formatted_windows,
            "index": sel_idx,
            "monitor": focused_output
        }
        with open(STATE_FILE, "w") as f:
            json.dump(state, f)
            
        # Cập nhật Eww
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_windows={json.dumps(formatted_windows)}"])
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_index={sel_idx}"])
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_focused_title={formatted_windows[sel_idx]['name']}"])
        
        # Mở Eww Switcher trên màn hình
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "open", "switcher", "--arg", f"monitor={focused_output}"])
        
        # Chuyển mode Sway
        subprocess.run(["swaymsg", "mode", "switcher"])
    except Exception:
        emergency_cleanup()

def cmd_next():
    navigate(1)

def cmd_prev():
    navigate(-1)

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

def emergency_cleanup():
    subprocess.run(["swaymsg", "mode", "default"])
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
    elif cmd == "next":
        cmd_next()
    elif cmd == "prev":
        cmd_prev()
    elif cmd == "select":
        cmd_select()
    elif cmd == "close":
        emergency_cleanup()

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Kiểm tra cú pháp script python**
Chạy lệnh kiểm tra:
```bash
python3 -m py_compile .config/eww/scripts/alt_tab.py
```
Expected: Lệnh trả về thành công không báo lỗi (exit code 0).

---

### Task 2: Redesign Eww Window and Widgets Layout

**Files:**
- Modify: `.config/eww/eww.yuck`

- [ ] **Step 1: Cấu trúc lại eww.yuck cho switcher**
Mở file `/home/sown/workplace/sway-config/.config/eww/eww.yuck`. Tìm phần định nghĩa `switcher` ở cuối file và thay thế bằng mã nguồn sử dụng `overlay` chồng icon lên góc dưới bên phải:

```scheme
;; ── Cấu hình biến trạng thái Alt+Tab Switcher ──
(defvar switcher_windows "[]")
(defvar switcher_index 0)
(defvar switcher_focused_title "")

;; Cửa sổ switcher popup nổi nhỏ căn giữa màn hình
(defwindow switcher [monitor]
  :monitor monitor
  :geometry (geometry
    :width "800px"
    :height "200px"
    :anchor "center")
  :stacking "overlay"
  :exclusive false
  :focusable false
  :namespace "eww-switcher"
  (switcher-card))

(defwidget switcher-card []
  (box :class "switcher-card" :orientation "vertical" :space-evenly false
    ;; Danh sách các cửa sổ nằm ngang
    (box :class "switcher-list" :orientation "horizontal" :space-evenly false :halign "center"
      (for win in switcher_windows
        (box :class {win.idx == switcher_index ? "switcher-item active" : "switcher-item"}
             :orientation "vertical"
             :space-evenly false
          (overlay
            ;; 1. Preview Box (Chứa ảnh chụp màn hình hoặc placeholder)
            (box :class "preview-box"
              (if {win.visible && win.thumbnail != ""}
                (image :class "window-thumbnail" :path {win.thumbnail} :image-width 130 :image-height 80)
                (box :class "window-thumbnail-placeholder" :width 130 :height 80
                  (image :class "placeholder-icon" :path {win.icon} :image-width 40 :image-height 40))))
            ;; 2. App Icon ở góc dưới bên phải
            (box :class "app-icon-badge" :halign "end" :valign "end"
              (image :class "app-icon" :path {win.icon} :image-width 24 :image-height 24))))))
    ;; Tên tiêu đề của cửa sổ đang chọn
    (label :class "switcher-title" :text switcher_focused_title :limit-width 70 :halign "center")))
```

- [ ] **Step 2: Xác thực cú pháp eww.yuck**
Chạy lệnh:
```bash
/home/sown/.local/bin/eww --config ~/.config/eww check
```
Expected: Lệnh debug hoặc check thành công.

---

### Task 3: Restructure CSS Switcher Styling

**Files:**
- Modify: `.config/eww/eww.css`

- [ ] **Step 1: Cập nhật CSS cho bộ chuyển đổi trong eww.css**
Mở file `/home/sown/workplace/sway-config/.config/eww/eww.css`. Tìm phần `/* ── Alt+Tab Switcher Styles ── */` ở cuối file và thay thế bằng các quy tắc CSS căn chỉnh và thiết kế hoàn chỉnh sau:

```css
/* ── Alt+Tab Switcher Styles ── */

/* Hộp thoại chính căn giữa màn hình */
.switcher-card {
  background: rgba(30, 30, 46, 0.95); /* Catppuccin Mocha Base bán trong suốt */
  border: 2px solid #313244; /* Surface 0 */
  border-radius: 20px;
  padding: 24px 32px;
  box-shadow: 0 16px 48px rgba(0, 0, 0, 0.7);
  min-width: 600px;
}

/* Danh sách các ứng dụng hiển thị ngang */
.switcher-list {
  margin-bottom: 16px;
  justify-content: center;
}

/* Từng phần tử ứng dụng */
.switcher-item {
  margin: 0 10px;
  border-radius: 12px;
}

/* Khung bọc thumbnail hoặc placeholder */
.switcher-item .preview-box {
  background: #181825; /* Mantle */
  border: 2px solid #313244; /* Surface 0 */
  border-radius: 12px;
  min-width: 130px;
  min-height: 80px;
  overflow: hidden; /* Cắt ảnh tràn viền bo góc */
  transition: all 0.2s ease;
}

/* Ảnh chụp màn hình cửa sổ */
.switcher-item .window-thumbnail {
  border-radius: 10px;
  object-fit: cover;
}

/* Hộp placeholder cho cửa sổ bị ẩn ở workspace khác */
.switcher-item .window-thumbnail-placeholder {
  background: #11111b; /* Crust */
  border-radius: 10px;
  justify-content: center;
  align-items: center;
}

/* Badge chứa app icon góc dưới bên phải */
.switcher-item .app-icon-badge {
  background: #1e1e2e; /* Base */
  border: 2px solid #313244; /* Surface 0 */
  border-radius: 6px;
  padding: 3px;
  box-shadow: 0 4px 10px rgba(0, 0, 0, 0.4);
  margin-right: -4px;
  margin-bottom: -4px;
}

/* Item được chọn hoạt động */
.switcher-item.active .preview-box {
  border-color: #89b4fa; /* Catppuccin Blue */
  box-shadow: 0 0 16px rgba(137, 180, 250, 0.4);
  transform: scale(1.05); /* Phóng to nhẹ */
}

.switcher-item.active .app-icon-badge {
  border-color: #89b4fa; /* Đổi màu viền badge khi active */
}

/* Tiêu đề ứng dụng ở dưới cùng */
.switcher-title {
  font-size: 13px;
  font-weight: 700;
  color: #cdd6f4;
  background: #181825; /* Mantle */
  padding: 6px 20px;
  border-radius: 8px;
  border: 1px solid #313244;
  margin-top: 10px;
}
```

---

### Task 4: Runtime Verification

**Files:**
- Runtime only

- [ ] **Step 1: Nhấn tổ hợp phím Alt+Tab**
Nhấn giữ `Alt` và bấm `Tab`.
Expected:
- Một popup nhỏ xuất hiện giữa màn hình (không có lớp nền phủ đen mờ cả màn hình).
- Danh sách ứng dụng có dạng: ảnh thu nhỏ (thumbnail) của cửa sổ thực tế (nếu thuộc workspace hiện tại) hoặc hộp placeholder có icon lớn ở giữa (nếu thuộc workspace ẩn).
- Icon ứng dụng nằm chồng lên ở góc dưới bên phải của mỗi thumbnail.
- Cửa sổ đang chọn có viền sáng xanh dương bao quanh và icon ứng dụng ở góc cũng có viền sáng xanh dương tương ứng.

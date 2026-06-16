# Alt+Tab Window Switcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triển khai tính năng Alt+Tab nâng cao giúp chuyển đổi giữa các cửa sổ/workspace đang hoạt động trên cùng một màn hình (output) với giao diện UI đẹp mắt bằng Eww (theo mockup của người dùng).

**Architecture:** Sử dụng một kịch bản Python (`alt_tab.py`) để lấy danh sách cửa sổ từ Sway theo thứ tự focus (MRU) và lọc theo màn hình hiện tại. Một Eww popup hiển thị danh sách cửa sổ dưới dạng các thẻ bo góc (giống preview thu nhỏ) kèm icon ứng dụng lớn. Sway sẽ chuyển sang một mode tạm thời ("switcher") để bắt sự kiện thả phím Alt (nhả Alt_L/Alt_R) để xác nhận focus hoặc phím Tab/Shift+Tab để di chuyển.

**Tech Stack:** Sway IPC, Python 3, Eww, CSS, Catppuccin Mocha theme.

---

## File Structure

- [NEW] [alt_tab.py](file:///home/sown/workplace/sway-config/.config/eww/scripts/alt_tab.py)
  - Quản lý logic Alt+Tab: lấy cửa sổ MRU, phân giải icon, cập nhật biến Eww, điều hướng và focus.
- [MODIFY] [eww.yuck](file:///home/sown/workplace/sway-config/.config/eww/eww.yuck)
  - Thêm định nghĩa biến trạng thái và cửa sổ UI `switcher` cùng widget hiển thị danh sách.
- [MODIFY] [eww.css](file:///home/sown/workplace/sway-config/.config/eww/eww.css)
  - Định dạng CSS cho giao diện switcher (lớp phủ làm mờ, thẻ căn giữa, viền phát sáng khi chọn, icon ứng dụng).
- [MODIFY] [config](file:///home/sown/workplace/sway-config/.config/sway/config)
  - Cấu hình phím tắt Alt+Tab và chế độ mode `"switcher"` tạm thời trong Sway.

---

### Task 1: Create Python Alt+Tab Logic Script

**Files:**
- Create: `.config/eww/scripts/alt_tab.py`

- [ ] **Step 1: Tạo kịch bản Python điều khiển Alt+Tab**
Tạo file script `/home/sown/workplace/sway-config/.config/eww/scripts/alt_tab.py` với mã nguồn hoàn chỉnh dưới đây để quản lý vòng đời và trạng thái Alt+Tab.

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

def find_windows_with_focus(node, path=(), current_output=None, current_workspace=None):
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
        return [{
            "id": node_id,
            "name": node_name,
            "app_id": app_id,
            "workspace": current_workspace,
            "output": current_output,
            "focused": node.get("focused", False),
            "focus_path": path
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
        windows.extend(find_windows_with_focus(child, child_path, current_output, current_workspace))
        
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
        
        # Lấy danh sách cửa sổ và sắp xếp theo MRU
        all_windows = find_windows_with_focus(tree)
        output_windows = [w for w in all_windows if w["workspace"] in output_workspaces]
        output_windows.sort(key=lambda w: w["focus_path"])
        
        if not output_windows:
            return
            
        # Format JSON gửi sang Eww
        formatted_windows = []
        for idx, win in enumerate(output_windows):
            formatted_windows.append({
                "id": win["id"],
                "idx": idx,
                "name": win["name"],
                "app_id": win["app_id"],
                "workspace": win["workspace"],
                "icon": resolve_icon(win["app_id"])
            })
            
        # Nếu có nhiều hơn 1 cửa sổ, mặc định chọn cửa sổ thứ 2 (lần gần nhất hoạt động)
        sel_idx = 1 if len(formatted_windows) > 1 else 0
        
        # Ghi trạng thái vào file tạm
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
        
        # Mở cửa sổ Eww trên monitor hiện tại
        subprocess.run([EWW_BIN, "--config", EWW_DIR, "open", "switcher", "--arg", f"monitor={focused_output}"])
        
        # Chuyển mode Sway
        subprocess.run(["swaymsg", "mode", "switcher"])
    except Exception as e:
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
            # Focus cửa sổ đã chọn
            subprocess.run(["swaymsg", f"[con_id={target_win['id']}] focus"])
            
        emergency_cleanup()
    except Exception:
        emergency_cleanup()

def emergency_cleanup():
    # Đảm bảo an toàn không bị kẹt mode
    subprocess.run(["swaymsg", "mode", "default"])
    subprocess.run([EWW_BIN, "--config", EWW_DIR, "close", "switcher"])
    if os.path.exists(STATE_FILE):
        try:
            os.remove(STATE_FILE)
        except OSError:
            pass

def main():
    if len(sys.argv) < 2:
        print("Usage: alt_tab.py [start|next|prev|select|close]")
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

- [ ] **Step 2: Cấp quyền thực thi cho kịch bản**
Chạy lệnh:
```bash
chmod +x .config/eww/scripts/alt_tab.py
```

- [ ] **Step 3: Kiểm tra cú pháp script python**
Chạy lệnh kiểm tra cú pháp:
```bash
python3 -m py_compile .config/eww/scripts/alt_tab.py
```
Expected: Lệnh chạy thành công và không in ra lỗi nào (trả về exit code 0).

---

### Task 2: Configure Eww UI Windows and Widgets

**Files:**
- Modify: `.config/eww/eww.yuck`

- [ ] **Step 1: Khai báo các biến và Widget Switcher trong eww.yuck**
Sử dụng `replace_file_content` để thêm khai báo biến và widget switcher vào cuối tập tin `/home/sown/workplace/sway-config/.config/eww/eww.yuck`.

Thêm đoạn mã sau vào cuối file `.config/eww/eww.yuck`:

```scheme
;; ── Cấu hình biến trạng thái Alt+Tab Switcher ──
(defvar switcher_windows "[]")
(defvar switcher_index 0)
(defvar switcher_focused_title "")

;; Cửa sổ switcher phủ toàn màn hình làm mờ nền
(defwindow switcher [monitor]
  :monitor monitor
  :geometry (geometry
    :x "0px"
    :y "0px"
    :width "100%"
    :height "100%"
    :anchor "center")
  :stacking "overlay"
  :exclusive false
  :focusable false
  :namespace "eww-switcher"
  (box :class "switcher-overlay" :orientation "vertical" :valign "center" :halign "center"
    (box :class "switcher-card" :orientation "vertical" :space-evenly false
      ;; Danh sách các cửa sổ nằm ngang
      (box :class "switcher-list" :orientation "horizontal" :space-evenly false :halign "center"
        (for win in switcher_windows
          (box :class {win.idx == switcher_index ? "switcher-item active" : "switcher-item"}
               :orientation "vertical"
               :space-evenly false
            (box :class "preview-box"
              (image :class "app-icon" :path {win.icon} :image-width 64 :image-height 64))
            (label :class "switcher-ws-label" :text "WS ${win.workspace}"))))
      ;; Tên tiêu đề của cửa sổ đang chọn
      (label :class "switcher-title" :text switcher_focused_title :limit-width 60 :halign "center"))))
```

- [ ] **Step 2: Xác thực cú pháp eww.yuck**
Chạy lệnh kiểm tra cấu trúc yuck:
```bash
/home/sown/.local/bin/eww --config ~/.config/eww check
```
Expected: Lệnh trả về thành công không báo lỗi cú pháp.

---

### Task 3: Design Switcher Styling

**Files:**
- Modify: `.config/eww/eww.css`

- [ ] **Step 1: Thêm lớp CSS mới vào eww.css**
Thêm các định dạng CSS đẹp mắt cho bộ chuyển đổi Alt+Tab (backdrop mờ tối, popup căn giữa, viền gradient/glowing cho phần tử active) vào cuối tập tin `/home/sown/workplace/sway-config/.config/eww/eww.css`.

Thêm nội dung sau vào cuối file `.config/eww/eww.css`:

```css
/* ── Alt+Tab Switcher Styles ── */

/* Lớp phủ toàn màn hình */
.switcher-overlay {
  background: rgba(15, 15, 23, 0.75); /* Làm mờ/dim các vùng xung quanh */
  min-width: 1920px; /* Bao phủ chiều rộng màn hình lớn */
  min-height: 1080px; /* Bao phủ chiều cao màn hình lớn */
  justify-content: center;
}

/* Hộp thoại chính căn giữa màn hình */
.switcher-card {
  background: #1e1e2e; /* Catppuccin Mocha Base */
  border: 2px solid #313244; /* Surface 0 */
  border-radius: 24px;
  padding: 32px 40px;
  box-shadow: 0 16px 40px rgba(0, 0, 0, 0.6);
  min-width: 600px;
}

/* Danh sách các ứng dụng hiển thị ngang */
.switcher-list {
  margin-bottom: 24px;
  justify-content: center;
}

/* Từng phần tử cửa sổ trong danh sách */
.switcher-item {
  margin: 0 12px;
  border-radius: 16px;
  padding: 8px;
}

/* Hộp preview giả lập cửa sổ */
.switcher-item .preview-box {
  background: #181825; /* Mantle */
  border: 2px solid #313244; /* Surface 0 */
  border-radius: 16px;
  min-width: 110px;
  min-height: 110px;
  justify-content: center;
  align-items: center;
  transition: all 0.2s ease;
}

/* Icon ứng dụng */
.switcher-item .app-icon {
  opacity: 0.8;
}

/* Nhãn Workspace hiển thị phía dưới preview */
.switcher-ws-label {
  font-size: 11px;
  font-weight: 700;
  color: #6c7086; /* Overlay 0 */
  margin-top: 8px;
  text-align: center;
}

/* Phần tử đang được chọn hoạt động */
.switcher-item.active .preview-box {
  background: #313244; /* Surface 0 */
  border-color: #89b4fa; /* Catppuccin Blue */
  box-shadow: 0 0 18px rgba(137, 180, 250, 0.4);
  transform: scale(1.05); /* Phóng to nhẹ tạo hiệu ứng động */
}

.switcher-item.active .app-icon {
  opacity: 1.0;
}

.switcher-item.active .switcher-ws-label {
  color: #89b4fa; /* Làm sáng nhãn workspace khi active */
}

/* Tiêu đề cửa sổ đang chọn ở dưới cùng */
.switcher-title {
  font-size: 14px;
  font-weight: 700;
  color: #cdd6f4; /* Text */
  background: #181825; /* Mantle */
  padding: 8px 24px;
  border-radius: 12px;
  border: 1px solid #313244;
  margin-top: 12px;
}
```

---

### Task 4: Configure Sway Key Bindings and Switcher Mode

**Files:**
- Modify: `.config/sway/config`

- [ ] **Step 1: Khai báo phím tắt Alt+Tab và chế độ mode "switcher"**
Mở file `/home/sown/workplace/sway-config/.config/sway/config`. Tìm khu vực thích hợp (ví dụ dưới phần `# Di chuyển focus` hoặc trước phần `### Layout`) để thêm các định nghĩa phím tắt và chế độ switcher.

Thêm cấu hình sau:

```sway
# Khởi động Alt+Tab Switcher (nhấn Alt+Tab lần đầu)
bindsym Mod1+Tab exec python3 ~/.config/eww/scripts/alt_tab.py start

# Chế độ điều khiển Alt+Tab Switcher tạm thời
mode "switcher" {
    # Nhấn Tab tiếp tục di chuyển tới cửa sổ tiếp theo
    bindsym Tab exec python3 ~/.config/eww/scripts/alt_tab.py next
    # Shift+Tab di chuyển ngược lại
    bindsym Shift+Tab exec python3 ~/.config/eww/scripts/alt_tab.py prev
    
    # Xác nhận chọn bằng Enter hoặc Space
    bindsym Return exec python3 ~/.config/eww/scripts/alt_tab.py select
    bindsym Space exec python3 ~/.config/eww/scripts/alt_tab.py select
    
    # Hủy và đóng bằng phím Escape
    bindsym Escape exec python3 ~/.config/eww/scripts/alt_tab.py close
    
    # Nhả phím Alt (Alt_L/Alt_R) để tự động chọn và focus cửa sổ đang chọn
    bindsym --release Alt_L exec python3 ~/.config/eww/scripts/alt_tab.py select
    bindsym --release Alt_R exec python3 ~/.config/eww/scripts/alt_tab.py select
}
```

- [ ] **Step 2: Nạp lại cấu hình Sway**
Chạy lệnh reload cấu hình Sway hiện tại:
```bash
swaymsg reload
```
Expected: Lệnh reload thành công không trả về lỗi cú pháp config.

---

### Task 5: Runtime Verification

**Files:**
- Runtime only

- [ ] **Step 1: Mở nhiều cửa sổ ứng dụng**
Đảm bảo bạn đang mở ít nhất 2-3 cửa sổ trên các workspace thuộc màn hình hiện tại (ví dụ: Terminal foot, Trình duyệt firefox/chromium, IDE).

- [ ] **Step 2: Nhấn thử Alt+Tab**
Nhấn tổ hợp phím `Alt` + `Tab` và giữ phím `Alt`.
Expected:
- Giao diện Eww Switcher mở ra ở chính giữa màn hình với lớp nền phủ mờ sang trọng.
- Hiển thị danh sách các cửa sổ kèm icon phân giải chính xác.
- Thẻ thứ hai (cửa sổ MRU gần nhất) tự động được chọn và có viền sáng màu xanh dương bao quanh.
- Tiêu đề cửa sổ đó hiển thị ở thanh phía dưới.

- [ ] **Step 3: Nhấn phím Tab liên tiếp**
Tiếp tục giữ `Alt` và nhấn phím `Tab` vài lần.
Expected:
- Ô sáng viền màu xanh chuyển động xoay vòng qua các ứng dụng trong danh sách.
- Nhãn workspace (ví dụ: `WS 3`, `WS 4`) được tô sáng tương ứng.
- Tên tiêu đề phía dưới thay đổi đúng theo cửa sổ được chọn.

- [ ] **Step 4: Nhả phím Alt**
Nhả phím `Alt`.
Expected:
- Cửa sổ Eww Switcher biến mất ngay lập tức.
- Tiêu điểm (focus) được chuyển sang cửa sổ bạn đã chọn. Nếu cửa sổ đó nằm ở workspace khác, Sway tự động chuyển sang workspace đó.
- Trạng thái bàn phím trở về chế độ bình thường (`default` mode).

- [ ] **Step 5: Kiểm tra các phím chức năng phụ**
Mở lại Alt+Tab, giữ `Alt`, sau đó bấm `Escape` để hủy, hoặc bấm phím `Space`/`Enter` để chọn trực tiếp.
Expected:
- Mọi phím tắt hoạt động đồng nhất, thoát khỏi chế độ `switcher` thành công và không gây kẹt bàn phím.

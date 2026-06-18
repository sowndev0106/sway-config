# Alt+Tab Workspace Switcher & Tabbed Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chuyển đổi Alt+Tab hiện tại của Sway từ quản lý cửa sổ đơn lẻ sang quản lý Workspace kèm ảnh chụp màn hình preview và hàng icon ứng dụng, đồng thời làm đẹp các tab trong Tabbed Layout (`Mod+w`).

**Architecture:** Sử dụng một Python Daemon chạy ngầm kết nối trực tiếp với Sway IPC Socket để bắt sự kiện `workspace::focus`. Daemon này tự động dùng `grim` chụp lưu ảnh preview của workspace cũ trước khi chuyển đi. Script Alt+Tab sẽ đọc các ảnh preview này và cung cấp dữ liệu cho Eww hiển thị dưới dạng card ngang, mỗi card chứa ảnh preview và hàng icon ứng dụng tương ứng.

**Tech Stack:** Python 3 (socket, subprocess, json), Eww (Yuck, CSS), Sway WM config.

---

### Task 1: Thiết kế Tabbed Layout (Mod + w) trong Sway Config

**Files:**
- Modify: `.config/sway/config`

- [ ] **Step 1: Cấu hình phong cách hiển thị titlebars (tab)**

  Thêm cấu hình font, padding, border và bảng màu cho các tab ở cuối phần `Màu viền (theme Catppuccin Mocha-ish)` trong file `.config/sway/config`:

  ```sway
  # Titlebar & Tab styling
  font pango:Inter Semi-Bold 10
  titlebar_border_thickness 1
  titlebar_padding 10 6

  # Màu sắc cho tab/cửa sổ (Catppuccin Mocha)
  # Cấu trúc: class border backgr text indicator child_border
  client.focused          #89b4fa #89b4fa #1e1e2e #f38ba8 #89b4fa
  client.unfocused        #181825 #181825 #a6adc8 #181825 #181825
  client.focused_inactive #313244 #313244 #cdd6f4 #313244 #313244
  client.urgent           #f38ba8 #f38ba8 #1e1e2e #f38ba8 #f38ba8
  ```

- [ ] **Step 2: Reload cấu hình Sway và kiểm thử**

  Run: `swaymsg reload`
  Expected: Nạp lại cấu hình thành công không lỗi. Mở một vài cửa sổ, ấn `Mod+w` để đưa vào tabbed layout và quan sát xem các tab có padding rộng rãi và màu sắc Catppuccin Mocha rõ rệt hay chưa.

- [ ] **Step 3: Commit**

  ```bash
  git add .config/sway/config
  git commit -m "style: configure browser-style tab styling for tabbed layout"
  ```

---

### Task 2: Phát triển Daemon Chụp ảnh màn hình Workspace (`sway_workspace_daemon.py`)

**Files:**
- Create: `.config/sway/scripts/sway_workspace_daemon.py`
- Modify: `.config/sway/config`

- [ ] **Step 1: Viết script Python kết nối IPC socket của Sway**

  Tạo file `.config/sway/scripts/sway_workspace_daemon.py` sử dụng thư viện `socket` mặc định của Python để lắng nghe sự kiện đổi workspace và chụp màn hình qua `grim`:

  ```python
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
  ```

- [ ] **Step 2: Cấp quyền thực thi và kiểm thử chạy tay**

  Run: `chmod +x .config/sway/scripts/sway_workspace_daemon.py`
  Chạy thử bằng lệnh: `python3 .config/sway/scripts/sway_workspace_daemon.py`
  Trong khi script đang chạy, chuyển workspace vài lần rồi kiểm tra xem trong `/tmp/` có xuất hiện các file `sway-ws-*.png` chưa.
  Run: `ls -la /tmp/sway-ws-*.png`
  Expected: Xuất hiện các file ảnh preview của các workspace vừa rời đi.

- [ ] **Step 3: Đăng ký Autostart cho Daemon trong Sway Config**

  Mở file `.config/sway/config`, thêm dòng sau vào phần khởi động (`exec`):
  ```sway
  exec_always python3 ~/.config/sway/scripts/sway_workspace_daemon.py
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add .config/sway/scripts/sway_workspace_daemon.py .config/sway/config
  git commit -m "feat: add sway workspace daemon for capturing workspace screenshots on focus change"
  ```

---

### Task 3: Cập nhật Logic Alt+Tab (`alt_tab.py`)

**Files:**
- Modify: `.config/eww/scripts/alt_tab.py`

- [ ] **Step 1: Cấu trúc lại luồng lấy thông tin Workspace và ứng dụng**

  Sửa đổi hàm `cmd_start` để tìm danh sách tất cả các Workspace đang hoạt động trên màn hình (output) hiện tại. Nhóm các ứng dụng tương ứng vào mỗi Workspace.
  Đọc file `.config/eww/scripts/alt_tab.py` từ dòng 147 đến hết và thay đổi logic lấy thông tin:

  ```python
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
          
          # Sắp xếp các workspace theo tên/id hoặc thứ tự hiển thị
          output_workspaces.sort(key=lambda w: w["name"])
          
          # Đọc dữ liệu cây để lấy danh sách app của từng workspace
          workspace_nodes = {}
          # Tìm các node workspace trong cây
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
                  preview_path = "" # Eww sẽ hiển thị nền gradient
                  
              formatted_workspaces.append({
                  "name": ws_name,
                  "idx": idx,
                  "apps": apps,
                  "thumbnail": preview_path,
                  "focused": ws.get("focused", False)
              })
              
          if not formatted_workspaces:
              return
              
          # Xác định workspace cần chuyển tới đầu tiên (workspace đang focused hoặc workspace kế tiếp)
          active_idx = next((w["idx"] for w in formatted_workspaces if w["focused"]), 0)
          sel_idx = (active_idx + 1) % len(formatted_workspaces) if len(formatted_workspaces) > 1 else active_idx
          
          state = {
              "workspaces": formatted_workspaces,
              "index": sel_idx,
              "monitor": focused_output
          }
          with open(STATE_FILE, "w") as f:
              json.dump(state, f)
              
          # Cập nhật Eww
          subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_workspaces={json.dumps(formatted_workspaces)}"])
          subprocess.run([EWW_BIN, "--config", EWW_DIR, "update", f"switcher_index={sel_idx}"])
          
          # Mở Eww Switcher
          subprocess.run([EWW_BIN, "--config", EWW_DIR, "open", "switcher", "--arg", f"monitor={focused_output}"])
          
      except Exception as e:
          emergency_cleanup()
  ```

- [ ] **Step 2: Cập nhật logic điều hướng & chọn (`navigate`, `cmd_select`)**

  Sửa đổi hàm `navigate` và `cmd_select` trong `.config/eww/scripts/alt_tab.py` để hoạt động trên danh sách `workspaces`:

  ```python
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
  ```

- [ ] **Step 3: Loại bỏ phần dọn dẹp ảnh preview khi đóng switcher**

  Vì ảnh preview hiện được quản lý/cập nhật bởi Daemon và lưu trữ dài hạn tại `/tmp/sway-ws-*.png` để tái sử dụng, ta không nên xóa chúng trong `emergency_cleanup`. Sửa hàm `emergency_cleanup`:

  ```python
  def emergency_cleanup():
      subprocess.run([EWW_BIN, "--config", EWW_DIR, "close", "switcher"])
      if os.path.exists(STATE_FILE):
          try:
              os.remove(STATE_FILE)
          except Exception:
              pass
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add .config/eww/scripts/alt_tab.py
  git commit -m "feat: refactor alt_tab.py to switch between workspaces instead of individual windows"
  ```

---

### Task 4: Cập nhật Giao diện Eww Switcher (Yuck & CSS)

**Files:**
- Modify: `.config/eww/eww.yuck`
- Modify: `.config/eww/eww.css`

- [ ] **Step 1: Cấu hình biến trạng thái mới trong `eww.yuck`**

  Đổi biến `switcher_windows` thành `switcher_workspaces` ở dòng 447 của file `.config/eww/eww.yuck`:

  ```yuck
  (defvar switcher_workspaces "[]")
  (defvar switcher_index 0)
  ```

- [ ] **Step 2: Cập nhật Widget `switcher-card` hiển thị Workspace Previews**

  Thay thế định nghĩa widget `switcher-card` trong `.config/eww/eww.yuck` từ dòng 465 đến hết file:

  ```yuck
  (defwidget switcher-card []
    (box :class "switcher-card" :orientation "vertical" :space-evenly false
      ;; Dòng danh sách các workspace card nằm ngang
      (box :class "switcher-list" :orientation "horizontal" :space-evenly false :halign "center"
        (for ws in {switcher_workspaces ?: "[]"}
          (box :class {ws.idx == switcher_index ? "switcher-item active" : "switcher-item"}
               :orientation "vertical"
               :space-evenly false
               :halign "center"
            
            ;; 1. Vùng hiển thị ảnh Preview (thumbnail) hoặc gradient nền tối
            (box :class "switcher-preview-wrap"
                 :style {ws.thumbnail != "" ? "background-image: url('${ws.thumbnail}');" : "background: linear-gradient(135deg, #1e1e2e, #313244);"}
              ;; Nếu không có preview, hiển thị icon app lớn ở giữa hoặc chữ đại diện
              (box :visible {ws.thumbnail == ""} :halign "center" :valign "center"
                   (label :class "switcher-empty-lbl" :text "Workspace ${ws.name}")))

            ;; 2. Hàng ngang chứa các icon nhỏ của ứng dụng đang mở trong workspace đó
            (box :class "switcher-apps-row" :orientation "horizontal" :space-evenly false :halign "center"
              (for app in {ws.apps ?: "[]"}
                (image :class "switcher-app-mini-icon"
                       :path {app.icon}
                       :image-width 20
                       :image-height 20)))
                       
            ;; 3. Tên Workspace
            (label :class "switcher-ws-name"
                   :text "Workspace ${ws.name}"))))))
  ```

- [ ] **Step 3: Cập nhật Style CSS tương ứng trong `eww.css`**

  Cập nhật lại phần style của Switcher trong `.config/eww/eww.css` (bắt đầu từ dòng 614):

  ```css
  /* ── Alt+Tab Switcher — Workspace Style ── */

  .switcher-card {
    background: rgba(30, 30, 46, 0.85);
    border: 1px solid rgba(255, 255, 255, 0.10);
    border-radius: 20px;
    padding: 24px;
    box-shadow:
      0 20px 60px rgba(0, 0, 0, 0.70),
      0 0 0 1px rgba(0, 0, 0, 0.3);
    backdrop-filter: blur(10px);
  }

  .switcher-list {
    margin-bottom: 0px;
  }

  .switcher-item {
    margin: 0 8px;
    padding: 12px;
    border-radius: 16px;
    border: 2px solid transparent;
    background: rgba(255, 255, 255, 0.02);
    transition: background 120ms ease, border-color 120ms ease;
    min-width: 180px;
  }

  .switcher-item.active {
    background: rgba(255, 255, 255, 0.08);
    border-color: rgba(137, 180, 250, 0.50); /* Catppuccin Blue */
    box-shadow: 0 0 15px rgba(137, 180, 250, 0.15);
  }

  /* Khung chứa ảnh preview */
  .switcher-preview-wrap {
    width: 160px;
    height: 90px;
    border-radius: 8px;
    background-size: cover;
    background-position: center;
    background-repeat: no-repeat;
    border: 1px solid rgba(255, 255, 255, 0.05);
    margin-bottom: 10px;
  }

  .switcher-empty-lbl {
    font-size: 11px;
    color: rgba(255, 255, 255, 0.4);
    font-weight: 500;
  }

  /* Hàng icon ứng dụng nhỏ bên dưới preview */
  .switcher-apps-row {
    margin-top: 6px;
    gap: 6px;
    min-height: 24px;
  }

  .switcher-app-mini-icon {
    border-radius: 4px;
    background: rgba(0, 0, 0, 0.2);
    padding: 2px;
  }

  /* Tên Workspace dưới cùng của card */
  .switcher-ws-name {
    font-size: 11px;
    font-weight: 600;
    color: rgba(255, 255, 255, 0.85);
    margin-top: 8px;
  }
  ```

- [ ] **Step 4: Khởi động lại eww để nhận cấu hình mới và kiểm thử**

  Run: `eww kill && eww daemon` (hoặc phím tắt reload).
  Thử nhấn phím tắt Alt+Tab để kiểm chứng xem giao diện Workspace Switcher có hoạt động và hiển thị đúng như mong đợi hay không.

- [ ] **Step 5: Commit**

  ```bash
  git add .config/eww/eww.yuck .config/eww/eww.css
  git commit -m "feat: design new workspace-based Alt+Tab switcher UI with layout previews"
  ```

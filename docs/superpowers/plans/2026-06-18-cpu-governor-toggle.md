# CPU Governor Toggle — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Performance toggle button (performance ↔ schedutil) to the eww Control Center popup.

**Architecture:** Two new shell scripts handle governor reads/writes; a sudoers entry grants passwordless sysfs write access; eww.yuck gets a new `defpoll` and a third toggle row; `control_center.sh refresh` updated to include the new state var.

**Tech Stack:** bash, eww (lisp config), sysfs `/sys/devices/system/cpu/*/cpufreq/scaling_governor`, sudo/sudoers

## Global Constraints

- All scripts: `#!/usr/bin/env bash` + `set -euo pipefail`
- Scripts live in repo at `.config/eww/scripts/cc/`, symlinked to `~/.config/eww/scripts/cc/`
- Sudoers entry uses symlink path `/home/sown/.config/eww/scripts/cc/set-cpu-governor.sh`
- Commit messages in English (user preference overrides CLAUDE.md)
- No automated test suite — verification is manual `cat /sys/.../scaling_governor`

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `.config/eww/scripts/cc/set-cpu-governor.sh` | Create | Root helper: writes governor to all CPUs |
| `.config/eww/scripts/cc/cpu-governor.sh` | Create | User script: get state (`on`/`off`) + toggle |
| `/etc/sudoers.d/sown-cpu-governor` | Create (sudo) | NOPASSWD for set-cpu-governor.sh |
| `.config/eww/scripts/control_center.sh` | Modify | Add `cpu_perf_state` to `refresh` subcommand |
| `.config/eww/eww.yuck` | Modify | Add `defpoll cpu_perf_state` + third toggle row |

---

### Task 1: Create helper scripts

**Files:**
- Create: `.config/eww/scripts/cc/set-cpu-governor.sh`
- Create: `.config/eww/scripts/cc/cpu-governor.sh`

**Interfaces:**
- Produces:
  - `sudo set-cpu-governor.sh <governor>` — writes to all CPUs, exits 0
  - `cpu-governor.sh get` → stdout `on` (if performance) or `off` (anything else)
  - `cpu-governor.sh toggle` → changes governor, no stdout

- [ ] **Step 1: Create set-cpu-governor.sh**

```bash
# File: .config/eww/scripts/cc/set-cpu-governor.sh
#!/usr/bin/env bash
set -euo pipefail
governor="${1:?Usage: set-cpu-governor.sh <governor>}"
for path in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -f "$path" ] && echo "$governor" > "$path"
done
```

- [ ] **Step 2: Create cpu-governor.sh**

```bash
# File: .config/eww/scripts/cc/cpu-governor.sh
#!/usr/bin/env bash
set -euo pipefail

HELPER="$(dirname -- "${BASH_SOURCE[0]}")/set-cpu-governor.sh"
GOV_FILE="/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"

case "${1:-}" in
    get)
        gov=$(cat "$GOV_FILE" 2>/dev/null || echo "unknown")
        [ "$gov" = "performance" ] && echo "on" || echo "off"
        ;;
    toggle)
        gov=$(cat "$GOV_FILE" 2>/dev/null || echo "unknown")
        if [ "$gov" = "performance" ]; then
            sudo "$HELPER" schedutil
        else
            sudo "$HELPER" performance
        fi
        ;;
    *)
        echo "Usage: cpu-governor.sh get|toggle" >&2; exit 1 ;;
esac
```

- [ ] **Step 3: Make both scripts executable**

```bash
chmod +x .config/eww/scripts/cc/set-cpu-governor.sh
chmod +x .config/eww/scripts/cc/cpu-governor.sh
```

- [ ] **Step 4: Verify scripts are syntactically valid**

```bash
bash -n .config/eww/scripts/cc/set-cpu-governor.sh
bash -n .config/eww/scripts/cc/cpu-governor.sh
```

Expected: no output, exit 0.

- [ ] **Step 5: Commit**

```bash
git add .config/eww/scripts/cc/set-cpu-governor.sh .config/eww/scripts/cc/cpu-governor.sh
git commit -m "feat(eww): add cpu governor helper scripts for performance toggle"
```

---

### Task 2: Configure sudoers NOPASSWD

**Files:**
- Create: `/etc/sudoers.d/sown-cpu-governor` (system file, outside repo)

**Interfaces:**
- Consumes: `set-cpu-governor.sh` from Task 1
- Produces: `sudo -n ~/.config/eww/scripts/cc/set-cpu-governor.sh <gov>` runs without password prompt

- [ ] **Step 1: Create sudoers file**

```bash
echo 'sown ALL=(ALL) NOPASSWD: /home/sown/.config/eww/scripts/cc/set-cpu-governor.sh' \
    | sudo tee /etc/sudoers.d/sown-cpu-governor
sudo chmod 440 /etc/sudoers.d/sown-cpu-governor
```

- [ ] **Step 2: Validate syntax with visudo**

```bash
sudo visudo -c -f /etc/sudoers.d/sown-cpu-governor
```

Expected: `/etc/sudoers.d/sown-cpu-governor: parsed OK`

- [ ] **Step 3: Test passwordless sudo**

```bash
sudo -n ~/.config/eww/scripts/cc/set-cpu-governor.sh schedutil
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

Expected: prints `schedutil`, no password prompt.

- [ ] **Step 4: Test get/toggle scripts end-to-end**

```bash
~/.config/eww/scripts/cc/cpu-governor.sh get          # → off (schedutil)
~/.config/eww/scripts/cc/cpu-governor.sh toggle
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor  # → performance
~/.config/eww/scripts/cc/cpu-governor.sh get          # → on
~/.config/eww/scripts/cc/cpu-governor.sh toggle
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor  # → schedutil
```

No password prompts throughout.

---

### Task 3: Wire into eww.yuck + control_center.sh

**Files:**
- Modify: `.config/eww/scripts/control_center.sh` (line ~194–202, `refresh` case)
- Modify: `.config/eww/eww.yuck` (add defpoll ~line 109, add widget row ~line 395)

**Interfaces:**
- Consumes: `cpu-governor.sh get` from Task 1
- Produces: `cpu_perf_state` eww variable (`"on"` / `"off"`)

- [ ] **Step 1: Add `cpu_perf_state` to control_center.sh refresh**

In `.config/eww/scripts/control_center.sh`, find the `refresh)` block and add one line:

Old block (lines ~194–203):
```bash
    refresh)
        EWW="$(eww_bin)"
        "$EWW" --config "$CONFIG_DIR" update \
            wifi_state="$("$0" wifi-state)" \
            wifi_ssid="$("$0" wifi-ssid)" \
            bt_state="$("$0" bt-state)" \
            airplane_state="$("$0" airplane-state)" \
            wired_state="$("$0" wired-state)" \
            vol_muted="$("$0" vol-muted)" \
            vol_level="$("$0" vol-level)" \
            mic_muted="$("$0" mic-muted)"
        ;;
```

New block — append `cpu_perf_state` line:
```bash
    refresh)
        EWW="$(eww_bin)"
        "$EWW" --config "$CONFIG_DIR" update \
            wifi_state="$("$0" wifi-state)" \
            wifi_ssid="$("$0" wifi-ssid)" \
            bt_state="$("$0" bt-state)" \
            airplane_state="$("$0" airplane-state)" \
            wired_state="$("$0" wired-state)" \
            vol_muted="$("$0" vol-muted)" \
            vol_level="$("$0" vol-level)" \
            mic_muted="$("$0" mic-muted)" \
            cpu_perf_state="$(~/.config/eww/scripts/cc/cpu-governor.sh get)"
        ;;
```

- [ ] **Step 2: Add defpoll to eww.yuck**

After the `mic_muted` defpoll line (around line 107), add:

```lisp
;; Trạng thái CPU governor: on = performance, off = schedutil
(defpoll cpu_perf_state :interval "3s" "~/.config/eww/scripts/cc/cpu-governor.sh get")
```

- [ ] **Step 3: Add Performance toggle row to cc-grid in eww.yuck**

After the closing `)` of the second `(box :orientation "horizontal" :space-evenly true` row (Wired/Volume/Mic, around line 427), add a third row.

The icon is the Nerd Font lightning bolt (U+F0E7). Since Edit handles PUA glyphs, include the literal character. If it appears corrupted after saving, regenerate with:
```bash
python3 -c "print('')"   # → 
```

Add this block:
```lisp
        (box :orientation "horizontal" :space-evenly true
          ;; Performance Governor Toggle
          (box :class "toggle-container" :orientation "vertical" :space-evenly false
            (box :class {cpu_perf_state == "on" ? "toggle-btn active" : "toggle-btn"}
                 :orientation "horizontal" :space-evenly false
              (button :class "toggle-main"
                      :onclick "~/.config/eww/scripts/cc/cpu-governor.sh toggle && ~/.config/eww/scripts/control_center.sh refresh"
                (label :text "")))
            (label :class "toggle-label" :text "Performance")))
```

(The `` glyph in the label is U+F0E7.)

- [ ] **Step 4: Reload eww and verify**

```bash
swaymsg reload
```

Open the control center popup. Verify:
- A third row appears below the Mic row
- Clicking "Performance" highlights the button and sets governor to `performance`
- Clicking again un-highlights and sets back to `schedutil`
- `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor` matches the toggle state

- [ ] **Step 5: Commit**

```bash
git add .config/eww/eww.yuck .config/eww/scripts/control_center.sh
git commit -m "feat(eww): add Performance governor toggle to control center"
```

---

### Task 4: Commit spec + plan docs

- [ ] **Step 1: Commit docs**

```bash
git add docs/superpowers/specs/2026-06-18-cpu-governor-toggle-design.md \
        docs/superpowers/plans/2026-06-18-cpu-governor-toggle.md
git commit -m "docs: add cpu governor toggle spec and implementation plan"
```

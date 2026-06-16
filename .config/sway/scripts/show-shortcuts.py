#!/usr/bin/env python3
import os
import re
import sys
import subprocess

CONFIG_PATH = os.path.expanduser("~/.config/sway/config")

def main():
    if not os.path.exists(CONFIG_PATH):
        print(f"Error: Config file not found at {CONFIG_PATH}")
        sys.exit(1)

    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        lines = f.readlines()

    variables = {}
    shortcuts = []
    
    current_section = "General"
    comment_buffer = []

    for line in lines:
        stripped = line.strip()
        
        # 1. Parse variables: set $var_name value
        if stripped.startswith("set $"):
            match = re.match(r"^set\s+(\$\w+)\s+(.+)$", stripped)
            if match:
                var_name = match.group(1)
                var_value = match.group(2).split('#')[0].strip() # ignore inline comment
                variables[var_name] = var_value
            continue
            
        # 2. Section Headers: ### Section Name
        if stripped.startswith("###"):
            section_name = stripped.lstrip("#").strip()
            # If section name ends with a dash/marker, clean it up
            section_name = re.split(r"\s+—\s+|\s+-\s+", section_name)[0]
            current_section = section_name.strip()
            comment_buffer = []
            continue
            
        # 3. Comments
        if stripped.startswith("#"):
            comment_text = stripped.lstrip("#").strip()
            if comment_text:
                comment_buffer.append(comment_text)
            continue
            
        # 4. Bindings
        if stripped.startswith("bindsym") or stripped.startswith("bindgesture"):
            # Syntax: bindsym [--options] <keys> <action>
            is_gesture = stripped.startswith("bindgesture")
            cmd_type = "Gesture" if is_gesture else "Key"
            
            content = stripped.split(None, 1)[1].strip()
            
            # Skip flags like --release or --locked or --whole-window
            while content.startswith("--"):
                parts = content.split(None, 1)
                if len(parts) > 1:
                    content = parts[1].strip()
                else:
                    break
            
            # Split keys and action
            parts = content.split(None, 1)
            if len(parts) < 2:
                continue
            keys, action = parts[0], parts[1]
            
            # If there is inline comment in action
            description = ""
            if "#" in action:
                action, inline_comment = action.split("#", 1)
                action = action.strip()
                description = inline_comment.strip()
            elif comment_buffer:
                description = " ".join(comment_buffer)
            else:
                description = ""
                
            # Clear comment buffer after consuming
            comment_buffer = []
            
            shortcuts.append({
                "type": cmd_type,
                "section": current_section,
                "keys": keys,
                "action": action,
                "description": description
            })
            continue
            
        # If empty line or other command, clear comment buffer unless it's just a blank line between comments
        if not stripped:
            comment_buffer = []

    # Post-process keys to expand variables and make them pretty
    if "$mod" not in variables:
        variables["$mod"] = "Mod4"
        
    def resolve_keys(keys_str):
        # Resolve variables
        for var, val in variables.items():
            keys_str = keys_str.replace(var, val)
        
        # Make key names user-friendly
        replacements = {
            "Mod4": "Super",
            "Mod1": "Alt",
            "Control": "Ctrl",
            "Shift": "Shift",
            "Return": "Enter",
            "plus": "+",
            "minus": "-",
            "slash": "/",
            "semicolon": ";",
            "space": "Space",
            "apostrophe": "'",
            "comma": ",",
            "period": ".",
            "equal": "=",
            "Print": "PrintScr"
        }
        
        parts = keys_str.split("+")
        pretty_parts = []
        for p in parts:
            p_clean = p.strip()
            pretty_parts.append(replacements.get(p_clean, p_clean))
        return " + ".join(pretty_parts)

    formatted_rows = []
    for s in shortcuts:
        pretty_keys = resolve_keys(s["keys"])
        desc = s["description"] or s["action"]
        
        # Clean up description if it's too long or has too many raw command details
        if desc.startswith("exec "):
            desc = desc[5:].strip()
            
        formatted_rows.append({
            "keys": pretty_keys,
            "desc": desc,
            "section": s["section"],
            "action": s["action"]
        })

    if not formatted_rows:
        sys.exit(0)

    # Find max length of columns for clean tabular alignment
    max_keys_len = max(len(r["keys"]) for r in formatted_rows)
    max_desc_len = max(len(r["desc"]) for r in formatted_rows)
    
    # Pad columns to make them align beautifully
    lines_out = []
    for r in formatted_rows:
        keys_col = r["keys"].ljust(max_keys_len)
        desc_col = r["desc"].ljust(max_desc_len)
        section_col = f"[{r['section']}]"
        
        line_str = f"{keys_col}  │  {desc_col}  │  {section_col}"
        lines_out.append((line_str, r["action"]))

    # Pass lines to rofi
    rofi_input = "\n".join(l[0] for l in lines_out)
    
    # Run rofi
    rofi_cmd = [
        os.path.expanduser("~/.config/sway/scripts/rofi-focused.sh"),
        "-dmenu",
        "-p", "Sway Shortcuts",
        "-i", # case-insensitive
        "-theme-str", "window { width: 1100px; } listview { lines: 18; } entry { placeholder: \"Search shortcuts...\"; }"
    ]
    
    try:
        proc = subprocess.Popen(rofi_cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        stdout, _ = proc.communicate(input=rofi_input)
        
        if proc.returncode == 0 and stdout.strip():
            selected_line = stdout.strip()
            # Find the corresponding action to execute
            for line_str, action in lines_out:
                if line_str == selected_line:
                    # Execute the shortcut's action if they selected it!
                    if action.startswith("exec "):
                        action_cmd = action[5:].strip()
                        # Run it in background
                        subprocess.Popen(action_cmd, shell=True, start_new_session=True)
                    elif action.startswith("mode "):
                        # Sway command
                        subprocess.run(["swaymsg", action])
                    else:
                        # General swaymsg command
                        subprocess.run(["swaymsg", action])
                    break
    except Exception as e:
        print(f"Error running rofi: {e}")

if __name__ == "__main__":
    main()

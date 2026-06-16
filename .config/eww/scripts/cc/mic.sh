#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    sources)
        # JSON mảng thiết bị thu âm (source), bỏ qua monitor.
        # Trường: id (số), name (chuỗi), default (bool)
        default_src=$(pactl get-default-source 2>/dev/null || true)
        pactl list sources 2>/dev/null \
            | awk -v default_src="$default_src" '
                function print_src() {
                    if (id != "" && !is_monitor) {
                        gsub(/"/, "\\\"", desc)
                        is_default = (name == default_src) ? "true" : "false"
                        printf "{\"id\":%s,\"name\":\"%s\",\"default\":%s}\n", id, desc, is_default
                    }
                }
                /^Source #/ {
                    print_src()
                    id = substr($2, 2)
                    name = ""
                    desc = ""
                    is_monitor = 0
                }
                /^[ \t]*Name:/ {
                    name = $2
                    if (name ~ /\.monitor$/) is_monitor = 1
                }
                /^[ \t]*Description:/ {
                    desc = $0
                    sub(/^[ \t]*Description:[ \t]*/, "", desc)
                }
                END {
                    print_src()
                }
            ' \
            | paste -sd ',' - \
            | sed 's/^/[/;s/$/]/'
        ;;
    set-source)
        pactl set-default-source "${2}" >/dev/null 2>&1
        ;;
    level)
        wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | awk '{printf "%.0f\n", $2*100}'
        ;;
    set-level)
        mic_val=$(printf "%.0f" "${2}" 2>/dev/null || echo "${2}" | cut -d. -f1)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0
        wpctl set-volume @DEFAULT_AUDIO_SOURCE@ "${mic_val}%"
        EWW="${EWW_BIN:-$HOME/.local/bin/eww}"
        [ -x "$EWW" ] || EWW="$(command -v eww)"
        "$EWW" --config "$HOME/.config/eww" update mic_muted="off" mic_level="${mic_val}"
        ;;
    *)
        echo "Unknown: ${1:-}" >&2; exit 1 ;;
esac

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
        wpctl set-volume @DEFAULT_AUDIO_SOURCE@ "${2}%"
        ;;
    *)
        echo "Unknown: ${1:-}" >&2; exit 1 ;;
esac

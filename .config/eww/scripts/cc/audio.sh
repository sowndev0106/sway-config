#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    sinks)
        # JSON mảng thiết bị âm thanh ra (sink).
        # Trường: id (số), name (chuỗi), default (bool)
        default_sink=$(pactl get-default-sink 2>/dev/null || true)
        pactl list sinks 2>/dev/null \
            | awk -v default_sink="$default_sink" '
                function print_sink() {
                    if (id != "") {
                        gsub(/"/, "\\\"", desc)
                        is_default = (name == default_sink) ? "true" : "false"
                        printf "{\"id\":%s,\"name\":\"%s\",\"default\":%s}\n", id, desc, is_default
                    }
                }
                /^Sink #/ {
                    print_sink()
                    id = substr($2, 2)
                    name = ""
                    desc = ""
                }
                /^[ \t]*Name:/ { name = $2 }
                /^[ \t]*Description:/ {
                    desc = $0
                    sub(/^[ \t]*Description:[ \t]*/, "", desc)
                }
                END {
                    print_sink()
                }
            ' \
            | paste -sd ',' - \
            | sed 's/^/[/;s/$/]/'
        ;;
    set-sink)
        pactl set-default-sink "${2}" >/dev/null 2>&1
        # Di chuyển tất cả sink-input sang sink mới
        inputs=$(pactl list sink-inputs short 2>/dev/null | cut -f1) || true
        if [ -n "$inputs" ]; then
            for input_id in $inputs; do
                pactl move-sink-input "$input_id" "${2}" >/dev/null 2>&1 || true
            done
        fi
        ;;
    apps)
        # JSON mảng ứng dụng đang phát âm thanh (sink-inputs).
        # Trường: id (số), name (chuỗi), volume (0-100)
        pactl list sink-inputs 2>/dev/null \
            | awk '
                function print_app() {
                    if (id != "" && name != "") {
                        gsub(/"/, "\\\"", name)
                        printf "{\"id\":%s,\"name\":\"%s\",\"volume\":%s}\n", id, name, vol
                    }
                }
                /^Sink Input #/ {
                    print_app()
                    id = substr($3, 2)
                    name = ""
                    vol = 0
                }
                /application\.name =/ {
                    name = $0
                    sub(/^.*application\.name = "/, "", name)
                    sub(/"$/, "", name)
                }
                /Volume:/ {
                    if (match($0, /[0-9]+%/)) {
                        vol = substr($0, RSTART, RLENGTH - 1)
                    }
                }
                END {
                    print_app()
                }
            ' \
            | paste -sd ',' - \
            | sed 's/^/[/;s/$/]/'
        ;;
    set-app-vol)
        # set-app-vol <sink-input-id> <volume-percent>
        pactl set-sink-input-volume "${2}" "${3}%" >/dev/null 2>&1
        ;;
    *)
        echo "Unknown: ${1:-}" >&2; exit 1 ;;
esac

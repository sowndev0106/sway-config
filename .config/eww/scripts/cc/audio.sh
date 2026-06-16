#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${EWW_CONFIG:-$HOME/.config/eww}"

eww_bin() {
    local eww="${EWW_BIN:-$HOME/.local/bin/eww}"
    [ -x "$eww" ] || eww="$(command -v eww)"
    printf '%s\n' "$eww"
}

sink_nodes_json() {
    pw-dump | jq '[.[] |
        select(.type == "PipeWire:Interface:Node" and .info.props["media.class"] == "Audio/Sink") |
        {
            id: .id,
            pactl_id: .info.props["object.serial"],
            sink: .info.props["node.name"],
            name: (.info.props["node.description"] // .info.props["media.name"] // .info.props["node.name"])
        }
        | . + {
            display_name: (
                .name
                | sub("^Raptor Lake-P/U/H cAVS "; "")
                | sub("^Built-in Audio "; "")
            )
        }
    ]'
}

resolve_sink() {
    local target="${1}"

    sink_nodes_json | jq -r --arg target "$target" '
        .[] |
        select((.id | tostring) == $target or (.pactl_id | tostring) == $target or .sink == $target) |
        [.id, .sink] |
        @tsv
    ' | head -n1
}

set_sink() {
    local target="${1}" wp_id sink_name

    IFS=$'\t' read -r wp_id sink_name < <(resolve_sink "$target")
    if [ -z "${wp_id:-}" ] || [ -z "${sink_name:-}" ]; then
        echo "Unknown sink: $target" >&2
        exit 1
    fi

    wpctl set-default "$wp_id" >/dev/null 2>&1

    # Move currently playing streams too; changing the default only affects new streams.
    inputs=$(pactl list sink-inputs short 2>/dev/null | cut -f1) || true
    if [ -n "$inputs" ]; then
        for input_id in $inputs; do
            pactl move-sink-input "$input_id" "$sink_name" >/dev/null 2>&1 || true
        done
    fi
}

case "${1:-}" in
    sinks)
        # JSON mảng thiết bị âm thanh ra (sink).
        # Trường: id (wpctl node id), name (chuỗi đầy đủ), display_name (chuỗi ngắn), default (bool)
        default_sink=$(pactl get-default-sink 2>/dev/null || true)
        sink_nodes_json | jq -c --arg default_sink "$default_sink" '
            map(. + {default: (.sink == $default_sink)})
        '
        ;;
    set-sink)
        set_sink "${2}"
        ;;
    select-sink)
        set_sink "${2}"
        EWW="$(eww_bin)"
        "$EWW" --config "$CONFIG_DIR" update \
            audio_sinks="$("$0" sinks)" \
            audio_apps="$("$0" apps)"
        "$HOME/.config/eww/scripts/control_center.sh" refresh
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
        app_val=$(printf "%.0f" "${3}" 2>/dev/null || echo "${3}" | cut -d. -f1)
        pactl set-sink-input-volume "${2}" "${app_val}%" >/dev/null 2>&1
        ;;
    *)
        echo "Unknown: ${1:-}" >&2; exit 1 ;;
esac

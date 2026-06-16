#!/usr/bin/env bash
# Quản lý microphone (Audio/Source) qua PipeWire.
# Tương tự audio.sh: dùng pw-dump + wpctl thay cho pactl set-default-source
# (lệnh pactl set-default-source ghi vào PulseAudio state, KHÔNG thay đổi
# PipeWire default node → app không nhận mic mới).
#
# Mỗi thiết bị thu âm ứng với một PipeWire node có media.class=Audio/Source.
# Để chuyển mic: gọi `wpctl set-default <node-id>`. App đang thu (browser,
# Zoom, v.v.) đang mở sẽ KHÔNG tự chuyển — cần `pactl move-source-output` để
# gắn stream đang thu sang node mới.

set -euo pipefail

CONFIG_DIR="${EWW_CONFIG:-$HOME/.config/eww}"

eww_bin() {
    local eww="${EWW_BIN:-$HOME/.local/bin/eww}"
    [ -x "$eww" ] || eww="$(command -v eww)"
    printf '%s\n' "$eww"
}

source_nodes_json() {
    pw-dump | jq '[.[] |
        select(.type == "PipeWire:Interface:Node" and .info.props["media.class"] == "Audio/Source") |
        {
            id: .id,
            pactl_id: .info.props["object.serial"],
            source: .info.props["node.name"],
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

resolve_source() {
    local target="${1}"

    source_nodes_json | jq -r --arg target "$target" '
        .[] |
        select((.id | tostring) == $target or (.pactl_id | tostring) == $target or .source == $target) |
        [.id, .source] |
        @tsv
    ' | head -n1
}

set_source() {
    local target="${1}" wp_id source_name

    IFS=$'\t' read -r wp_id source_name < <(resolve_source "$target")
    if [ -z "${wp_id:-}" ] || [ -z "${source_name:-}" ]; then
        echo "Unknown source: $target" >&2
        exit 1
    fi

    wpctl set-default "$wp_id" >/dev/null 2>&1

    # Chuyển các stream đang thu (Zoom, Meet, browser tab...) sang source mới.
    # Trên PipeWire pulse-server, các stream ghi = source-outputs (tương ứng
    # PulseAudio source-inputs — pactl list source-inputs sẽ báo lỗi, phải
    # dùng source-outputs).
    outputs=$(pactl list source-outputs short 2>/dev/null | cut -f1) || true
    if [ -n "$outputs" ]; then
        for output_id in $outputs; do
            pactl move-source-output "$output_id" "$source_name" >/dev/null 2>&1 || true
        done
    fi
}

case "${1:-}" in
    sources)
        # JSON mảng thiết bị thu âm. Trường: id (wpctl node id), name, display_name, default.
        default_source=$(pactl get-default-source 2>/dev/null || true)
        source_nodes_json | jq -c --arg default_source "$default_source" '
            map(. + {default: (.source == $default_source)})
        '
        ;;
    set-source)
        # Backward compat — set mà không refresh UI.
        set_source "${2}"
        ;;
    select-source)
        # Dùng trong onclick của eww: set + refresh state.
        set_source "${2}"
        EWW="$(eww_bin)"
        "$EWW" --config "$CONFIG_DIR" update \
            mic_sources="$("$0" sources)" \
            mic_level="$("$0" level)"
        "$HOME/.config/eww/scripts/control_center.sh" refresh
        ;;
    level)
        # Mức mic hiện tại (0-100). Nếu mic đang mute thì trả 0 để slider hiển thị đúng.
        wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | awk '{printf "%.0f\n", $2*100}'
        ;;
    set-level)
        mic_val=$(printf "%.0f" "${2}" 2>/dev/null || echo "${2}" | cut -d. -f1)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0
        wpctl set-volume @DEFAULT_AUDIO_SOURCE@ "${mic_val}%"
        EWW="$(eww_bin)"
        [ -x "$EWW" ] || EWW="$(command -v eww)"
        "$EWW" --config "$HOME/.config/eww" update mic_muted="off" mic_level="${mic_val}"
        ;;
    *)
        echo "Unknown: ${1:-}" >&2; exit 1 ;;
esac

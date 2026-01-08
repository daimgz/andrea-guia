#!/bin/bash

OUTPUT_ALIASES="
    alsa_output.pci-0000_00_lf.3.analog-stereo:🔊,
    bluez_output.84_AC_60_29_EE_08.1:🎧
"
VOLUME_STEP=1

get_default_output() {
    pactl info | grep "Default Sink:" | cut -d' ' -f3
}

get_volume_and_mute() {
    local device=$1
    local output=$(pactl list sinks | grep -A 20 "Name: $device")
    
    local muted=$(echo "$output" | grep "Mute:" | cut -d' ' -f2)
    local volume=$(echo "$output" | grep "Volume:" | head -n1 | awk '{print $5}' | sed 's/%//')
    
    echo "$muted:$volume"
}

get_all_outputs() {
    pactl list sinks | grep "Name:" | cut -d' ' -f2
}

parse_output_aliases() {
    local outputs="$1"
    local aliases="$OUTPUT_ALIASES"
    
    echo "$outputs" | while read -r output; do
        local alias=$(echo "$aliases" | grep "$output:" | cut -d':' -f2 | tr -d ', ')
        if [[ -z "$alias" ]]; then
            echo "$output"
        else
            echo "$alias"
        fi
    done
}

CURRENT_OUTPUT_FILE="/tmp/polybar_audio_current_output"
OUTPUT_INDEX_FILE="/tmp/polybar_audio_output_index"

case "$1" in
    toggle)
        DEFAULT_OUTPUT=$(get_default_output)
        MUTE_VOL=$(get_volume_and_mute "$DEFAULT_OUTPUT")
        MUTE_STATUS=$(echo "$MUTE_VOL" | cut -d':' -f1)
        
        if [[ "$MUTE_STATUS" == "yes" ]]; then
            amixer -D pulse set Master unmute
        else
            amixer -D pulse set Master mute
        fi
        ;;
    cycle)
        OUTPUTS=($(get_all_outputs))
        if [[ -f "$OUTPUT_INDEX_FILE" ]]; then
            CURRENT_INDEX=$(cat "$OUTPUT_INDEX_FILE")
        else
            CURRENT_INDEX=0
        fi
        
        NEXT_INDEX=$(( (CURRENT_INDEX + 1) % ${#OUTPUTS[@]} ))
        pactl set-default-sink "${OUTPUTS[$NEXT_INDEX]}"
        echo "$NEXT_INDEX" > "$OUTPUT_INDEX_FILE"
        ;;
    up)
        DEFAULT_OUTPUT=$(get_default_output)
        pactl set-sink-volume "$DEFAULT_OUTPUT" "+${VOLUME_STEP}%"
        ;;
    down)
        DEFAULT_OUTPUT=$(get_default_output)
        pactl set-sink-volume "$DEFAULT_OUTPUT" "-${VOLUME_STEP}%"
        ;;
esac

DEFAULT_OUTPUT=$(get_default_output)
MUTE_VOL=$(get_volume_and_mute "$DEFAULT_OUTPUT")
MUTE_STATUS=$(echo "$MUTE_VOL" | cut -d':' -f1)
VOLUME=$(echo "$MUTE_VOL" | cut -d':' -f2)

OUTPUTS=($(get_all_outputs))
CURRENT_OUTPUT_INDEX=0
for i in "${!OUTPUTS[@]}"; do
    if [[ "${OUTPUTS[$i]}" == "$DEFAULT_OUTPUT" ]]; then
        CURRENT_OUTPUT_INDEX=$i
        break
    fi
done

CURRENT_OUTPUT_ALIAS=$(echo "$OUTPUT_ALIASES | grep "$DEFAULT_OUTPUT:" | cut -d':' -f2 | tr -d ', ')
if [[ -z "$CURRENT_OUTPUT_ALIAS" ]]; then
    CURRENT_OUTPUT_ALIAS="$DEFAULT_OUTPUT"
fi

if [[ "$MUTE_STATUS" == "yes" ]]; then
    echo "%{F#FF0000}$CURRENT_OUTPUT_ALIAS: $VOLUME%%{F-}"
else
    echo "$CURRENT_OUTPUT_ALIAS: $VOLUME%"
fi
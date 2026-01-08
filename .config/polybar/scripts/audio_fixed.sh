#!/bin/bash

# Script audio mejorado basado en soluciones de GitHub
# Referencia: https://github.com/amrit073/polybar-pipewire

# Configuración
STEP=5
SINK=$(pactl get-default-sink)

get_volume() {
    pactl list sinks | grep -A 20 "Name: $SINK" | grep 'Volume:' | head -n1 | awk '{print $5}' | sed 's/%//'
}

get_mute() {
    pactl list sinks | grep -A 20 "Name: $SINK" | grep 'Mute:' | awk '{print $2}'
}

case "$1" in
    toggle)
        MUTE=$(get_mute)
        if [[ "$MUTE" == "yes" ]]; then
            pactl set-sink-mute "$SINK" 0
        else
            pactl set-sink-mute "$SINK" 1
        fi
        ;;
    cycle)
        # Obtener todos los outputs y ciclar al siguiente
        OUTPUTS=$(pactl list sinks | grep "Name:" | cut -d' ' -f2)
        if [[ -z "$OUTPUTS" ]]; then
            exit 1
        fi
        
        CURRENT_INDEX=0
        COUNTER=0
        for OUTPUT in $OUTPUTS; do
            if [[ "$OUTPUT" == "$SINK" ]]; then
                CURRENT_INDEX=$COUNTER
                break
            fi
            COUNTER=$((COUNTER + 1))
        done
        
        NEXT_INDEX=$(((CURRENT_INDEX + 1) % COUNTER))
        COUNTER=0
        for OUTPUT in $OUTPUTS; do
            if [[ $COUNTER -eq $NEXT_INDEX ]]; then
                pactl set-default-sink "$OUTPUT"
                break
            fi
            COUNTER=$((COUNTER + 1))
        done
        ;;
    up)
        pactl set-sink-volume "$SINK" "+${STEP}%"
        ;;
    down)
        pactl set-sink-volume "$SINK" "-${STEP}%"
        ;;
    *)
        # Mostrar estado actual (llamada principal de polybar)
        VOLUME=$(get_volume)
        MUTE=$(get_mute)
        
        # Determinar alias del dispositivo
        if [[ "$SINK" == *"bluez"* ]]; then
            ICON="🎧"
        else
            ICON="🔊"
        fi
        
        if [[ "$MUTE" == "yes" ]]; then
            echo "%{F#FF0000}$ICON: $VOLUME%%{F-}"
        else
            echo "$ICON: $VOLUME%"
        fi
        ;;
esac
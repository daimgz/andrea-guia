#!/bin/bash

DISPLAY_FILE="/tmp/polybar_space_display"
PARTITION="/"

case "$1" in
    left)
        if [[ -f "$DISPLAY_FILE" ]]; then
            CURRENT=$(cat "$DISPLAY_FILE")
            CURRENT=$(( (CURRENT + 1) % 3 ))
        else
            CURRENT=1
        fi
        echo "$CURRENT" > "$DISPLAY_FILE"
        ;;
esac

if [[ -f "$DISPLAY_FILE" ]]; then
    CURRENT=$(cat "$DISPLAY_FILE")
else
    CURRENT=0
fi

usage=$(df -h "$PARTITION" | tail -n1)

case $CURRENT in
    0)
        echo "%{T2}💾%{T-}"
        ;;
    1)
        free_gb=$(echo "$usage" | awk '{print $4}')
        echo "%{T2}💾%{T-} $free_gb"
        ;;
    2)
        used_percent=$(echo "$usage" | awk '{print $5}' | sed 's/%//')
        echo "%{T2}💾%{T-} ${used_percent}%"
        ;;
esac
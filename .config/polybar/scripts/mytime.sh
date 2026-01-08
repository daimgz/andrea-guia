#!/bin/bash

STATE_FILE="/tmp/polybar_mytime_state"

case "$1" in
    toggle)
        if [[ -f "$STATE_FILE" ]]; then
            rm "$STATE_FILE"
        else
            echo "show_time=true" > "$STATE_FILE"
        fi
        ;;
esac

if [[ -f "$STATE_FILE" ]]; then
    DATE=$(date '+%a %Y-%m-%d %H:%M:%S')
else
    DATE=$(date '+%a %Y-%m-%d')
fi

echo "%{T2}📅%{T-} $DATE"
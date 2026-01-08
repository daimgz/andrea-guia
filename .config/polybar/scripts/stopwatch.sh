#!/bin/bash

STATE_FILE="/tmp/polybar_stopwatch_state"
DISPLAY_FILE="/tmp/polybar_stopwatch_display"

get_state() {
    if [[ -f "$STATE_FILE" ]]; then
        source "$STATE_FILE"
    else
        RUNNING=false
        ELAPSED=0
        START_TIME=""
    fi
}

save_state() {
    cat > "$STATE_FILE" << EOF
RUNNING=$RUNNING
ELAPSED=$ELAPSED
START_TIME="$START_TIME"
EOF
}

get_display() {
    if [[ -f "$DISPLAY_FILE" ]]; then
        source "$DISPLAY_FILE"
    else
        DISPLAY=full
    fi
}

save_display() {
    echo "DISPLAY=$DISPLAY" > "$DISPLAY_FILE"
}

case "$1" in
    toggle)
        get_state
        if [[ "$RUNNING" == "true" ]]; then
            ELAPSED=$((ELAPSED + $(date +%s) - START_TIME))
            RUNNING=false
            START_TIME=""
        else
            RUNNING=true
            START_TIME=$(date +%s)
        fi
        save_state
        ;;
    reset)
        echo "RUNNING=false" > "$STATE_FILE"
        echo "ELAPSED=0" >> "$STATE_FILE"
        echo "START_TIME=" >> "$STATE_FILE"
        ;;
    display)
        get_display
        if [[ "$DISPLAY" == "full" ]]; then
            DISPLAY=icon
        else
            DISPLAY=full
        fi
        save_display
        ;;
esac

get_state
get_display

if [[ "$RUNNING" == "true" ]]; then
    TOTAL=$((ELAPSED + $(date +%s) - START_TIME))
    ICON="⏸"
    COLOR="#a3be8c"
else
    TOTAL=$ELAPSED
    ICON="▶️"
    COLOR="#E0AAFF"
fi

HOURS=$((TOTAL / 3600))
MINUTES=$(((TOTAL % 3600) / 60))
SECONDS=$((TOTAL % 60))

if [[ "$DISPLAY" == "icon" ]]; then
    OUTPUT="%{T2}$ICON%{T-}"
else
    if [[ $HOURS -gt 0 ]]; then
        TIME_STR=$(printf "%02d:%02d:%02d" $HOURS $MINUTES $SECONDS)
    else
        TIME_STR=$(printf "%02d:%02d" $MINUTES $SECONDS)
    fi
    OUTPUT="%{T2}$ICON%{T-} $TIME_STR"
fi

echo "%{F$COLOR}$OUTPUT%{F-}"
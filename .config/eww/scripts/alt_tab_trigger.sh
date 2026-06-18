#!/bin/bash
PID_FILE="/tmp/eww-switcher-daemon.pid"
LOG_FILE="/tmp/alt-tab.log"

echo "$(date '+%Y-%m-%d %H:%M:%S.%N') - Called with arg: $1" >> "$LOG_FILE"

if [ "$1" = "next" ]; then
    if [ -f "$PID_FILE" ]; then
        kill -USR1 $(cat "$PID_FILE") 2>/dev/null
    else
        python3 ~/.config/eww/scripts/alt_tab.py start
    fi
elif [ "$1" = "prev" ]; then
    if [ -f "$PID_FILE" ]; then
        kill -USR2 $(cat "$PID_FILE") 2>/dev/null
    else
        python3 ~/.config/eww/scripts/alt_tab.py start_prev
    fi
elif [ "$1" = "select" ]; then
    python3 ~/.config/eww/scripts/alt_tab.py select
elif [ "$1" = "cancel" ]; then
    python3 ~/.config/eww/scripts/alt_tab.py close
fi


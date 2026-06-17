#!/bin/bash
PID_FILE="/tmp/eww-switcher-daemon.pid"

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
    if [ -f "$PID_FILE" ]; then
        kill -TERM $(cat "$PID_FILE") 2>/dev/null
    fi
elif [ "$1" = "cancel" ]; then
    if [ -f "$PID_FILE" ]; then
        kill -INT $(cat "$PID_FILE") 2>/dev/null
    fi
fi

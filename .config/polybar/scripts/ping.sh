#!/bin/bash

STATE_FILE="/tmp/polybar_ping_state"
LAST_UP_FILE="/tmp/polybar_ping_last_up"
LAST_DOWN_FILE="/tmp/polybar_ping_last_down"
HOST="8.8.8.8"

case "$1" in
    toggle)
        if [[ -f "$STATE_FILE" ]]; then
            rm "$STATE_FILE"
            echo "1" > "$LAST_UP_FILE"
            echo "1" > "$LAST_DOWN_FILE"
        else
            echo "show_ping=true" > "$STATE_FILE"
        fi
        ;;
esac

if [[ ! -f "$STATE_FILE" ]]; then
    echo "%{T2}🖧%{T-}"
    exit 0
fi

python3 - << EOF
import subprocess
import psutil
import os

def get_ping(host):
    try:
        output = subprocess.check_output(['ping', '-c', '1', host])
        for line in output.splitlines():
            if b'time=' in line:
                ping_time = line.split(b'time=')[1].split(b' ')[0]
                return float(ping_time)
    except:
        return -1.0

def get_network_usage():
    net_io = psutil.net_io_counters()
    return net_io.bytes_sent, net_io.bytes_recv

try:
    last_up = 1
    last_down = 1
    if os.path.exists('/tmp/polybar_ping_last_up'):
        with open('/tmp/polybar_ping_last_up') as f:
            last_up = int(f.read())
    if os.path.exists('/tmp/polybar_ping_last_down'):
        with open('/tmp/polybar_ping_last_down') as f:
            last_down = int(f.read())
    
    ping = get_ping('$HOST')
    current_up, current_down = get_network_usage()
    
    up_speed = (current_up - last_up) / 1024
    down_speed = (current_down - last_down) / 1024
    
    result = f"%{{T2}}🖧%{{T-}} {ping:.2f} ms ↑{up_speed:.2f} KB/s ↓{down_speed:.2f} KB/s"
    
    with open('/tmp/polybar_ping_last_up', 'w') as f:
        f.write(str(current_up))
    with open('/tmp/polybar_ping_last_down', 'w') as f:
        f.write(str(current_down))
    
    print(result)
except Exception as e:
    print(f"%{{T2}}🖧%{{T-}} Error: {e}")
EOF
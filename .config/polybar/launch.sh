#!/bin/bash

# Kill existing polybar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -x polybar >/dev/null; do sleep 1; done

# Launch bars
echo "---" | tee -a /tmp/polybar-bar1.log /tmp/polybar-bar2.log
polybar bar1 2>&1 | tee -a /tmp/polybar-bar1.log & disown
polybar bar2 2>&1 | tee -a /tmp/polybar-bar2.log & disown

echo "Bars launched..."
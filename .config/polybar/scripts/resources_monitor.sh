#!/bin/bash

python3 - << 'EOF'
import psutil
import subprocess

def get_cpu_temperature():
    try:
        output = subprocess.check_output(['sensors']).decode('utf-8')
        for line in output.split('\n'):
            if 'Core' in line:
                temp = line.split(':')[1].strip().split()[0]
                return temp
    except Exception as e:
        return f"Error: {e}"

def get_cpu_usage():
    return psutil.cpu_percent(interval=0.1)

def get_ram():
    memory = psutil.virtual_memory()
    return memory.percent

cpu_usage = get_cpu_usage()
ram_usage = get_ram()
cpu_temp = get_cpu_temperature()

print(f"RAM: {ram_usage}% | CPU: {cpu_usage}% {cpu_temp}")
EOF
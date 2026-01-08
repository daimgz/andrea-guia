#!/usr/bin/env python3
import subprocess
import sys
from re import search
from typing import Optional, Tuple


# =========================
# CONFIG
# =========================
VOLUME_STEP = 1
MUTED_COLOR = "#FF0000"

# output:alias separados por coma
OUTPUT_ALIASES = {
    "bluez_output.84_AC_60_29_EE_08.1": "🎧",
    "alsa_output.pci-0000_00_1f.3.analog-stereo": "🔊",
}


# =========================
# HELPERS
# =========================
def sh(cmd: list[str]) -> str:
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def get_default_output() -> str:
    for line in sh(["pactl", "info"]).splitlines():
        if "Default Sink:" in line:
            return line.split(": ", 1)[1]
    return ""


def get_outputs() -> list[str]:
    return [
        line.split(": ", 1)[1]
        for line in sh(["pactl", "list", "sinks"]).splitlines()
        if line.startswith("Name:")
    ]


def get_volume_and_mute_status(device: str) -> Optional[Tuple[bool, int]]:
    for block in sh(["pactl", "list", "sinks"]).split("\n\n"):
        if device in block:
            muted = search(r"Mute:\s+(yes|no)", block)
            volume = search(r"Volume:.*?(\d+)%", block)
            if muted and volume:
                return muted.group(1) == "yes", int(volume.group(1))
    return None


def alias(name: str) -> str:
    return OUTPUT_ALIASES.get(name, name)


# =========================
# ACTIONS
# =========================
def toggle_mute():
    subprocess.run(["amixer", "-D", "pulse", "set", "Master", "toggle"],
                   stdout=subprocess.DEVNULL)


def volume(delta: int):
    sink = get_default_output()
    # Usar el volumen actual como base y aplicar delta relativo
    info = get_volume_and_mute_status(sink)
    if info:
        _, current_vol = info
        new_vol = max(0, current_vol + delta)
        subprocess.run(["pactl", "set-sink-volume", sink, f"{new_vol}%"])


def next_sink():
    outputs = get_outputs()
    current = get_default_output()
    if current in outputs:
        i = (outputs.index(current) + 1) % len(outputs)
        subprocess.run(["pactl", "set-default-sink", outputs[i]])


# =========================
# MAIN
# =========================
def print_status():
    sink = get_default_output()
    info = get_volume_and_mute_status(sink)

    if not info:
        print("Audio error")
        return

    muted, vol = info
    text = f"{alias(sink)}: {vol}%"

    if muted:
        print(f"%{{F{MUTED_COLOR.strip('#')}}}{text}%{{F-}}")
    else:
        print(text)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        arg = sys.argv[1]

        if arg == "mute":
            toggle_mute()
        elif arg == "up":
            volume(+VOLUME_STEP)
        elif arg == "down":
            volume(-VOLUME_STEP)
        elif arg == "next":
            next_sink()

    print_status()
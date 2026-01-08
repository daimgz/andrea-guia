#!/usr/bin/env python3

import subprocess
from re import search, Match
from typing import Optional, Tuple
import sys
import json

def get_default_output() -> str:
    """
    Returns name of the current default audio output.
    """
    try:
        result = subprocess.run(['pactl', 'info'], capture_output=True, text=True)
        for line in result.stdout.splitlines():
            if "Default Sink:" in line:
                return line.split(": ")[1]
        return ""
    except:
        return ""

def get_volume_and_mute_status(device_name: str) -> Optional[Tuple[bool, int]]:
    """
    Retrieves the mute status and volume percentage of the specified audio output device.
    """
    try:
        result = subprocess.run(['pactl', 'list', 'sinks'], capture_output=True, text=True)
        output: str = result.stdout

        # Split output into sections, one for each audio device
        audio_devices: list[str] = output.split('\n\n')
        for device in audio_devices:
            if device_name in device:
                muted_match: Match | None = search(r'Mute:\s+(yes|no)', device)
                volume_match: Match | None = search(r'Volume:.*?(\d+)%', device)

                if muted_match and volume_match:
                    is_muted: bool = muted_match.group(1).lower() == 'yes'
                    volume = int(volume_match.group(1))
                    return is_muted, volume

        return None
    except:
        return None

def update_outputs() -> Tuple[list[str], int]:
    """
    Updates the list of available audio outputs and sets the current output index.
    """
    default_output = get_default_output()
    
    result = subprocess.run(['pactl', 'list', 'sinks'], capture_output=True, text=True)
    outputs: list[str] = [
        line.split(": ")[1] for line in result.stdout.splitlines() if "Name:" in line
    ]

    current_output_index: int = outputs.index(default_output) if default_output in outputs else 0
    
    return outputs, current_output_index

def parse_output_aliases(output_aliases: str, outputs: list[str]) -> dict[str, str]:
    """
    Converts the output_aliases string into a dictionary that maps output names to their aliases.
    
    Example input:
        output_aliases = "bluez_output.84_AC_60_29_EE_08.1:🎧, alsa_output.pci-0000_00_lf.3.analog-stereo:🔊"
    
    Example output:
        {
            "bluez_output.84_AC_60_29_EE_08.1": "🎧",
            "alsa_output.pci-0000_00_lf.3.analog-stereo": "🔊"
        }
    """
    # Initialize dictionary with outputs mapping to themselves
    alias_dict: dict[str, str] = {output: output for output in outputs}

    # Return early if no aliases are provided
    if not output_aliases:
        return alias_dict

    # Clean and split alias string into key-value pairs
    output_aliases = output_aliases.strip().strip('"')
    alias_pairs = [pair.strip() for pair in output_aliases.split(",") if pair.strip()]

    # Process each alias pair and update the dictionary
    for pair in alias_pairs:
        try:
            key, value = pair.split(":", 1)  # Split into key and value
            key, value = key.strip(), value.strip()  # Clean extra spaces
            if key in alias_dict:  # Only update if the key exists in outputs
                alias_dict[key] = value
        except:
            continue

    return alias_dict

class Audio:
    """
    Audio module for polybar with all functionality from i3status.
    """
    
    def __init__(self):
        self.outputs: list[str] = []
        self.current_output_index: int = 0
        self.output_aliases: str = ""
        self.muted_color: str = '#FF0000'
        self.volume_step: int = 1
        
        # Load outputs and aliases on initialization
        self.outputs, self.current_output_index = update_outputs()
        self.output_aliases = (
            "bluez_output.84_AC_60_29_EE_08.1:🎧,"
            "alsa_output.pci-0000_00_lf.3.analog-stereo:🔊"
        )
    
    def audio(self) -> str:
        """
        Returns audio information for the current output.
        """
        output_aliases_dict: dict[str, str] = parse_output_aliases(self.output_aliases, self.outputs)
        
        current_output: str = self.outputs[self.current_output_index]
        volume_info: Tuple[bool, int] | None = get_volume_and_mute_status(current_output)
        
        if not volume_info:
            return "Error: Unable to fetch volume info"
        
        is_muted, volume = volume_info
        
        current_output = output_aliases_dict[current_output]
        
        if is_muted:
            return f"%{{F{self.muted_color.strip('#')}}}{current_output}: {volume}%%{{F-}}"
        else:
            return f"{current_output}: {volume}%"
    
    def handle_action(self, action: str) -> str:
        """
        Handles mouse click events with better debugging.
        - Left click (action "toggle"): Toggles mute/unmute.
        - Right click (action "cycle"): Cycles through available audio outputs.
        - Scroll up (action "up"): Increases volume.
        - Scroll down (action "down"): Decreases volume.
        """
        current_output: str = self.outputs[self.current_output_index]
        
        print(f"DEBUG: handle_action called with action='{action}', current_output='{current_output}'")
        
        if action == "toggle":
            # Toggle mute/unmute con debouncing
            volume_info: Tuple[bool, int] | None = get_volume_and_mute_status(current_output)
            if volume_info:
                is_muted, _ = volume_info
                print(f"DEBUG: Current mute status={is_muted}, volume={volume}")
                
                # Usar pactl en lugar de amixer para mejor compatibilidad
                if is_muted:
                    print("DEBUG: Unmuting...")
                    subprocess.run(['pactl', 'set-sink-mute', current_output, '0'], stdout=False)
                else:
                    print("DEBUG: Muting...")
                    subprocess.run(['pactl', 'set-sink-mute', current_output, '1'], stdout=False)
        elif action == "cycle":
            # Cycle to next audio output
            print("DEBUG: Cycling output...")
            self.current_output_index = (self.current_output_index + 1) % len(self.outputs)
            new_output_name: str = self.outputs[self.current_output_index]
            subprocess.run(['pactl', 'set-default-sink', new_output_name])
        elif action == "up":
            # Increase volume
            print("DEBUG: Increasing volume...")
            subprocess.run(['pactl', 'set-sink-volume', current_output, f"+{self.volume_step}%"], stdout=False)
        elif action == "down":
            # Decrease volume
            print("DEBUG: Decreasing volume...")
            subprocess.run(['pactl', 'set-sink-volume', current_output, f"-{self.volume_step}%"], stdout=False)
        
        return self.audio()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        # When called without arguments (like polybar), just show current status
        audio = Audio()
        print(audio.audio())
        sys.exit(0)
    
    action = sys.argv[1]
    audio = Audio()
    result = audio.handle_action(action)
    print(result)
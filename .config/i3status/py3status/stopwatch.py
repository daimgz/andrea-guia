import time
from typing import Dict


class Py3status:
    """
    Stopwatch / Chronometer for py3status

    Left click   : start / pause
    Right click  : toggle hide/show (solo icono cuando oculto)
    Middle click : reset
    """

    interval: float = 1.0
    running_color: str = "#A3BE8C"
    stopped_color: str = "#5E81AC"

    ICON_STOPPED = "▶️"
    ICON_RUNNING = "⏸"

    DISPLAY_ICON_ONLY = 0
    DISPLAY_FULL = 1

    display: int = DISPLAY_FULL

    def post_config_hook(self):
        self.running: bool = False
        self.start_time: float | None = None
        self.elapsed: float = 0.0

    def stopwatch(self) -> Dict:
        if self.running and self.start_time is not None:
            total = self.elapsed + (time.monotonic() - self.start_time)
            color = self.running_color
            icon = self.ICON_RUNNING
        else:
            total = self.elapsed
            color = self.stopped_color
            icon = self.ICON_STOPPED

        hours, rem = divmod(int(total), 3600)
        minutes, seconds = divmod(rem, 60)

        if self.display == self.DISPLAY_ICON_ONLY:
            full_text = icon
        else:
            if hours > 0:
                time_str = f"{hours:02d}:{minutes:02d}:{seconds:02d}"
            else:
                time_str = f"{minutes:02d}:{seconds:02d}"
            full_text = f"{icon} {time_str}"

        return {
            "full_text": full_text,
            "color": color,
            "cached_until": self.py3.time_in(self.interval),
        }

    def on_click(self, event: Dict):
        button = event.get("button")

        # Left click: start / pause
        if button == 1:
            if self.running:
                if self.start_time is not None:
                    self.elapsed += time.monotonic() - self.start_time
                self.running = False
                self.start_time = None
            else:
                self.start_time = time.monotonic()
                self.running = True

        # Right click: toggle hide/show (solo icono)
        elif button == 3:
            if self.display == self.DISPLAY_FULL:
                self.display = self.DISPLAY_ICON_ONLY
            else:
                self.display = self.DISPLAY_FULL

        # Middle click: reset
        elif button == 2:
            self.running = False
            self.elapsed = 0.0
            self.start_time = None

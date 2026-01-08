"""
Módulo py3status para contar notificaciones de Dunst
Muestra el número de notificaciones pendientes en la barra de i3
"""

import json
import subprocess
from py3status.module import Py3status


class DunstNotificationCount(Py3status):
    """
    Contador de notificaciones de Dunst para py3status
    """

    def __init__(self):
        super().__init__()

    def _get_notification_count(self):
        """Obtener el número de notificaciones activas"""
        try:
            # Obtener historial de notificaciones
            result = subprocess.run(
                ["dunstctl", "history"],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                data = json.loads(result.stdout)
                # Contar notificaciones que están mostrándose (data[0])
                count = len(data.get("data", [])[0])
                return count
            else:
                return 0
        except (subprocess.TimeoutExpired, json.JSONDecodeError, Exception):
            return 0

    def notification_count(self):
        """Método principal que py3status ejecuta"""
        count = self._get_notification_count()
        
        if count == 0:
            return {
                "full_text": "",
                "color": None
            }
        elif count <= 3:
            return {
                "full_text": f"🔔 {count}",
                "color": "#89b4fa"  # Blue
            }
        else:
            return {
                "full_text": f"🔔 {count}",
                "color": "#f38ba8"  # Red
            }

    def on_click(self, event):
        """Manejar clics en el módulo"""
        if event["button"] == 1:  # Clic izquierdo
            # Abrir historial con nuestro script
            subprocess.Popen(["~/.local/bin/dunst-history-rofi.sh"])
        elif event["button"] == 3:  # Clic derecho
            # Cerrar todas las notificaciones
            subprocess.run(["dunstctl", "close-all"])


if __name__ == "__main__":
    """
    Test local
    """
    module = DunstNotificationCount()
    print(module.notification_count())
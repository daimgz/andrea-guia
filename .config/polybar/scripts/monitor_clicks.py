#!/usr/bin/env python3

import sys
import time

def monitor_polybar_clicks():
    """
    Monitorea exactamente qué está haciendo polybar con los clicks.
    Se ejecuta en segundo plano para no interferir con polybar.
    """
    print("🔍 Iniciando monitoreo de clicks de polybar...")
    print("📝 Abra esta terminal y haga scroll en la barra de audio")
    print("🔍 Presione Ctrl+C para detener el monitoreo")
    print("📝 Se mostrará cada evento que polybar genera:")
    print("")
    
    try:
        # Usar xev para monitorear eventos de X11
        import subprocess
        result = subprocess.run([
            'xev', '-display', ':0'
        ], capture_output=True, text=True)
        
        for line in result.stdout.splitlines():
            if "ButtonPress" in line and ("4" in line or "5" in line):
                # Scroll up (button 4) o scroll down (button 5)
                if "ButtonRelease" in line:
                    button_num = "4" if "4" in line else "5"
                    action = "Scroll Up" if button_num == "4" else "Scroll Down"
                    print(f"🔄 EVENTO DETECTADO: {action}")
                    print(f"📋 Línea original: {line.strip()}")
                    print("")
        
        time.sleep(0.1)
        
    except KeyboardInterrupt:
        print("\n🛑 Monitoreo detenido")
        return
    except Exception as e:
        print(f"❌ Error en monitoreo: {e}")
        return

if __name__ == "__main__":
    monitor_polybar_clicks()
import sys
import os
import subprocess
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QObject, Slot, QAbstractListModel, QModelIndex, Qt, QTimer

class DevicesModel(QAbstractListModel):
    NameRole = Qt.UserRole + 1
    MacRole = Qt.UserRole + 2
    ConnectedRole = Qt.UserRole + 3

    def __init__(self, parent=None):
        super().__init__(parent)
        self._devices = []

    def roleNames(self):
        return {
            self.NameRole: b"name",
            self.MacRole: b"mac",
            self.ConnectedRole: b"connected"
        }

    def rowCount(self, parent=QModelIndex()):
        return len(self._devices)

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid() or not (0 <= index.row() < len(self._devices)):
            return None
        device = self._devices[index.row()]
        if role == self.NameRole: return device['name']
        if role == self.MacRole: return device['mac']
        if role == self.ConnectedRole: return device['connected']
        return None

    def update_devices(self, new_devices):
        self.beginResetModel()
        self._devices = new_devices
        self.endResetModel()


class Backend(QObject):
    def __init__(self, model):
        super().__init__()
        self.model = model

    def fetch_all_devices(self):
        """Собирает ВСЕ подключенные устройства: USB, мыши, клавиатуры + Bluetooth."""
        devices = []
        seen_names = set()

        # 1. СБОР УСТРОЙСТВ ВВОДА (Мыши, клавиатуры, ресиверы)
        try:
            input_dir = "/sys/class/input"
            if os.path.exists(input_dir):
                for item in os.listdir(input_dir):
                    if item.startswith("event"):
                        name_file = os.path.join(input_dir, item, "device", "name")
                        if os.path.exists(name_file):
                            with open(name_file, "r") as f:
                                dev_name = f.read().strip()
                            
                            # Игнорируем чисто системные переключатели
                            ignorable = ["power button", "sleep button", "at translated", "pc speaker", "video bus", "button"]
                            if dev_name and dev_name not in seen_names:
                                # ИСПРАВЛЕНО: .lower() вместо .toLowerCase()
                                if not any(x in dev_name.lower() for x in ignorable):
                                    seen_names.add(dev_name)
                                    devices.append({
                                        'name': f"🖱️  {dev_name}",
                                        'mac': "USB",
                                        'connected': True
                                    })
        except Exception as e:
            print(f"Ошибка чтения USB/Input устройств: {e}")

        # 2. СБОР BLUETOOTH УСТРОЙСТВ
        try:
            paired_out = subprocess.check_output(["bluetoothctl", "paired-devices"], text=True, timeout=2)
            
            for line in paired_out.strip().split('\n'):
                if not line or "Device" not in line: continue
                parts = line.split(' ', 2)
                if len(parts) < 3: continue
                mac = parts[1]
                name = parts[2]

                info_out = subprocess.check_output(["bluetoothctl", "info", mac], text=True, timeout=2)
                is_connected = "Connected: yes" in info_out
                
                devices.append({
                    'name': f"🎧  {name}",
                    'mac': mac,
                    'connected': is_connected
                })
        except Exception as e:
            print(f"Bluetooth недоступен (пропускаем): {e}")
            
        self.model.update_devices(devices)

    @Slot(str, bool)
    def toggle_connect(self, mac, is_connected):
        if ":" in mac:
            action = "disconnect" if is_connected else "connect"
            subprocess.Popen(["bluetoothctl", action, mac])
            QTimer.singleShot(1000, self.fetch_all_devices)

    @Slot(str)
    def remove_device(self, mac):
        if ":" in mac:
            subprocess.Popen(["bluetoothctl", "remove", mac])
            QTimer.singleShot(1000, self.fetch_all_devices)


if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    devices_model = DevicesModel()
    backend = Backend(devices_model)

    engine.rootContext().setContextProperty("btModel", devices_model)
    engine.rootContext().setContextProperty("backend", backend)

    backend.fetch_all_devices()
    
    timer = QTimer()
    timer.timeout.connect(backend.fetch_all_devices)
    timer.start(4000)

    current_dir = os.path.dirname(os.path.abspath(__file__))
    qml_path = os.path.join(current_dir, "main.qml")
    
    engine.load(qml_path)
    if not engine.rootObjects():
        sys.exit(-1)
    sys.exit(app.exec())

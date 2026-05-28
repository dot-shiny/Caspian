import customtkinter as ctk
import threading
import asyncio
from bleak import BleakScanner, BleakClient

ctk.set_appearance_mode("dark")
WHINE = "#73022f"
PINK = "#fa0567"
BG = "#1a1a1a"

class BleakBlueManager(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("BlueManager Pro")
        self.geometry("450x600")
        self.configure(fg_color=BG)

        # Карта для отслеживания уникальных устройств {MAC: Кнопка}
        self.device_widgets = {}

        # Настройка асинхронного цикла в фоновом потоке
        self.loop = asyncio.new_event_loop()
        threading.Thread(target=self._run_async_loop, daemon=True).start()

        # UI Шапка
        self.label = ctk.CTkLabel(self, text="БЛЮТУЗ (D-BUS)", font=("JetBrainsMono Nerd Font", 26, "bold"), text_color="white")
        self.label.pack(pady=20)

        # Индикатор
        self.status_bar = ctk.CTkLabel(self, text="🔄 Поиск устройств в реальном времени...", font=("sans-serif", 12), text_color="#aaa")
        self.status_bar.pack(pady=10)

        # Список устройств
        self.scroll = ctk.CTkScrollableFrame(self, fg_color=BG, border_color=WHINE, border_width=2)
        self.scroll.pack(padx=20, pady=20, fill="both", expand=True)

        # Запускаем бесконечный асинхронный поиск
        asyncio.run_coroutine_threadsafe(self.start_live_scan(), self.loop)

    def _run_async_loop(self):
        asyncio.set_event_loop(self.loop)
        self.loop.run_forever()

    async def start_live_scan(self):
        """Сканирует эфир напрямую через D-Bus и ловит изменения имен"""
        def detection_callback(device, advertisement_data):
            # Извлекаем человеческое имя (Bleak сам парсит EIR/SSP пакеты Apple)
            name = advertisement_data.local_name or device.name
            mac = device.address.upper()

            # Жесткий фильтр: если имени нет, или это Find My маяк, или мусор — игнорируем
            if not name or "find my" in name.lower() or len(name) < 2:
                return
            if name.upper().replace("-", ":") == mac:
                return

            # Безопасно обновляем GUI из асинхронного потока
            self.after(0, lambda: self.update_device_ui(mac, name))

        # Регистрируем callback-слушатель пакетов
        scanner = BleakScanner(detection_callback)
        await scanner.start()
        
        # Держим сканер активным всегда
        while True:
            await asyncio.sleep(1)

    def update_device_ui(self, mac, name):
        """Добавляет или обновляет кнопку устройства без дублирования"""
        if mac in self.device_widgets:
            # Если имя устройства обновилось на более точное
            btn = self.device_widgets[mac]
            if btn.cget("text") != f"{name}\n({mac})":
                btn.configure(text=f"{name}\n({mac})")
            return

        # Создаем уникальную кнопку
        btn = ctk.CTkButton(
            self.scroll, 
            text=f"{name}\n({mac})", 
            anchor="w", 
            fg_color="transparent", 
            text_color="white", 
            hover_color=WHINE,
            command=lambda m=mac, n=name: self.connect_device(m, n)
        )
        btn.pack(fill="x", pady=5)
        self.device_widgets[mac] = btn

    def connect_device(self, mac, name):
        """Создает модальное окно и запускает асинхронный коннект"""
        dialog = ctk.CTkToplevel(self)
        dialog.title("Подключение")
        dialog.geometry("400x180")
        dialog.configure(fg_color=BG)
        dialog.attributes('-topmost', True)

        ctk.CTkLabel(dialog, text=f"Устройство: {name}", text_color="white", font=("sans-serif", 12)).pack(pady=(15, 5))
        status_label = ctk.CTkLabel(dialog, text="Прямое подключение D-Bus...", text_color=PINK, font=("sans-serif", 14, "bold"))
        status_label.pack(pady=10)

        async def _async_connect():
            try:
                self.after(0, lambda: status_label.configure(text="Создание зашифрованного канала..."))
                # Bleak устанавливает низкоуровневое сопряжение напрямую
                async with BleakClient(mac, timeout=15.0) as client:
                    if client.is_connected:
                        self.after(0, lambda: status_label.configure(text="Успешно подключено!", text_color="green"))
                        await asyncio.sleep(3)
                    else:
                        self.after(0, lambda: status_label.configure(text="Ошибка протокола связи", text_color="red"))
                        await asyncio.sleep(3)
            except Exception as e:
                self.after(0, lambda: status_label.configure(text="Ошибка. Зажмите кнопку на кейсе!", text_color="red"))
                await asyncio.sleep(3)
            finally:
                self.after(0, dialog.destroy)

        asyncio.run_coroutine_threadsafe(_async_connect(), self.loop)

if __name__ == '__main__':
    app = BleakBlueManager()
    app.mainloop()

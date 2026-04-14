import customtkinter as ctk
import os

ctk.set_appearance_mode("dark")
WHINE = "#73022f"
PINK = "#fa0567"
BG = "#1a1a1a"

class Net (ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("NetManager")
        self.geometry("450x600")
        self.configure(fg_color=BG)

        self.label = ctk.CTkLabel(self, text="NETWORK", font=("JetBrainsMono Nerd Font", 26, "bold"), text_color="white")
        self.label.pack(pady=20)

        self.btn_frame = ctk.CTkFrame(self, fg_color="transparent")
        self.btn_frame.pack(pady=10)

        self.scan_btn = ctk.CTkButton(self.btn_frame, text="Scan", fg_color=WHINE, hover_color=PINK, command=self.scan_wifi, width=120)
        self.scan_btn.grid(row=0, column=0, padx=10)

        self.disc_btn = ctk.CTkButton(self.btn_frame, text="Disconnect", fg_color="#444", hover_color=PINK, command=self.disconnect, width=120)
        self.disc_btn.grid(row=0, column=1, padx=10)

        self.scroll = ctk.CTkScrollableFrame(self, fg_color=BG, border_color=WHINE, border_width=2)
        self.scroll.pack(padx=20, pady=20, fill="both", expand=True)
    def scan_wifi(self):
        for widget in self.scroll.winfo_children():
            widget.destroy()

        cmd = "nmcli -t -f SSID,SECURITY device wifi list | sort -u"
        networks = os.popen(cmd).read().splitlines()

        for line in networks:
            if line and not line.startswith('--'):
                ssid, security = line.split(':')
                btn = ctk.CTkButton(self.scroll, text=f"{ssid}", anchor="w", fg_color="transparent",
                                  text_color="white", hover_color=WHINE,
                                  command=lambda s=ssid, sec=security: self.ask_credentials(s, sec))
                btn.pack(fill="x", pady=5)

    def ask_credentials(self, ssid, security):
        dialog = ctk.CTkToplevel(self)
        dialog.title(f"Connect to {ssid}")
        dialog.geometry("350x250")
        dialog.configure(fg_color=BG)
        dialog.attributes('-topmost', True)

        ctk.CTkLabel(dialog, text=f"Connecting to {ssid}", text_color=PINK).pack(pady=10)

        is_uni = "802.1X" in security

        user_entry = None
        if is_uni:
            user_entry = ctk.CTkEntry(dialog, placeholder_text="Login", fg_color=WHINE, border_color=PINK)
            user_entry.pack(pady=5, padx=20, fill="x")
	
        pass_entry = ctk.CTkEntry(dialog, placeholder_text="Password", show="*", fg_color=WHINE, border_color=PINK)
        pass_entry.pack(pady=5, padx=20, fill="x")

        def submit():
            pwd = pass_entry.get()
            identity = user_entry.get() if user_entry else None
            dialog.destroy()
            self.connect(ssid, identity, pwd)

        ctk.CTkButton(dialog, text="Connect", fg_color=PINK, text_color="white", command=submit).pack(pady=20)

    def connect(self, ssid, identity, pwd):
            if identity:
                os.system(f"nmcli connection delete '{ssid}' > /dev/null 2>&1")

                create_cmd = (
                    f"nmcli connection add type wifi con-name '{ssid}' ifname wlan0 ssid '{ssid}' " 
                    f"802-11-wireless-security.key-mgmt wpa-eap " 
                    f"802-1x.eap peap "
                    f"802-1x.phase2-auth mschapv " 
                    f"802-1x.identity '{identity}' "
                    f"802-1x.password '{pwd}'"
                )

                os.system(f"{create_cmd} && nmcli connection up  '{ssid}' &")
            else:
                cmd = f"nmcli device wifi connect '{ssid}' password '{pwd}'"

    def disconnect(self):
        os.system("nmcli device disconnect wlan0")

if __name__ == '__main__':
    app = Net()
    app.mainloop()

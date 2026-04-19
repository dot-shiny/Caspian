import customtkinter as ctk
import subprocess
import os

WINE = "#73022f"
PINK = "#fa0567"
BG = "#1a1a1a"

class CaspianMouth(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.geometry("500x45+710+5")

        self.overrideredirect(True)
        self.attributes("-topmost", True)
        self.configure(fg_color=WINE)

        self.entry = ctk.CTkEntry(self,
                                 placeholder_text="What's up?",
                                 fg_color="transparent",
                                 border_width=0,
                                 text_color="white",
                                 font=("JetBrainsMono Nerd Font", 14))
        self.entry.pack(fill="both", expand=True, padx=15)

        self.entry.focus_set()

        self.entry.bind("<Return>", self.send_to_brain)
        self.entry.bind("<Escape>", lambda e: self.destroy())

    def send_to_brain(self, event):
        thought = self.entry.get()
        if thought:
            subprocess.Popen(["python", os.path.expanduser("~/dotfiles/.config/hypr/scripts/caspian_brain.py"), thought])

        self.destroy()

if __name__ == "__main__":
    app = CaspianMouth()
    app.mainloop()


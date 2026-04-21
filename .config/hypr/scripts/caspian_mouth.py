import customtkinter as ctk
import subprocess
import os
import threading

WINE = "#73022f"
PINK = "#fa0567"
BG = "#1a1a1a"

class CaspianMouth(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.geometry("500x300+710+5")

        self.title("CASPIAN_DIALOG")
        self.attributes("-topmost", True)
        self.configure(fg_color=WINE)

        self.header = ctk.CTkLabel(self, text="CASPIAN", font=("JetBrainsMono Nerd Font", 15, "bold"), text_color=PINK)
        self.header.pack(pady=5)

        self.output_text = ctk.CTkTextbox(self, fg_color=BG, text_color="white",
                                        font=("JetBrainsMono Nerd Font", 10))
        self.output_text.pack(fill="both", expand=True, padx=15, pady=10)
        self.output_text.insert("0.0", "what's next")
        self.output_text.configure(state="disabled")

        self.entry = ctk.CTkEntry(self,
                                 placeholder_text="What's up?",
                                 fg_color="transparent",
                                 border_width=0,
                                 text_color="white",
                                 font=("JetBrainsMono Nerd Font", 14))
        self.entry.pack(fill="both", expand=True, padx=15)

        self.entry.focus_set()

        self.entry.bind("<Return>", self.start_thought_thread)
        self.entry.bind("<Escape>", lambda e: self.destroy())

        self.pending_command = None

        import sys

        if len(sys.argv) > 1:
            incoming_msg = " ".join(sys.argv[1:])
            self.after(200, lambda: self.update_output(incoming_msg))

    def update_output(self, text):
        self.output_text.configure(state="normal")
        self.output_text.insert("end", f"{text}")
        self.output_text.see("end")
        self.output_text.configure(state="disabled")

    def start_thought_thread(self, event):
        thought = self.entry.get().strip()
        if thought:
            self.update_output("Thinking...")
            self.entry.delete(0, "end")
            threading.Thread(target=self.talk_logic, args=(thought,), daemon=True).start()

    def talk_logic(self, thought):
        path = os.path.expanduser("~/dotfiles/.config/hypr/scripts/caspian_brain.py")

        try:
            response = subprocess.check_output(["python", path, thought], text=True, timeout=15)
            self.after(0, lambda: self.update_output(response))
        except Exception as e:
            self.after(0, lambda: self.update_output(f"Error: {e}"))


if __name__ == "__main__":
    app = CaspianMouth()
    app.mainloop()


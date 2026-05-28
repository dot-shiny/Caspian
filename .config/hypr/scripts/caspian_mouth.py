import customtkinter as ctk
import subprocess
import os
import threading
import sys

WINE = "#73022f"
PINK = "#fa0567"
BG = "#1a1a1a"

class CaspianMouth(ctk.CTk):
    def __init__(self):
        super().__init__()

        # Window settings
        self.geometry("500x350+710+5")
        self.title("CASPIAN_DIALOG")
        self.attributes("-topmost", True)
        self.configure(fg_color=WINE)

        # Header
        self.header = ctk.CTkLabel(self, text="CASPIAN", font=("JetBrainsMono Nerd Font", 15, "bold"), text_color=PINK)
        self.header.pack(pady=(10, 5))

        # Output Box (Expands to take available space)
        self.output_text = ctk.CTkTextbox(self, fg_color=BG, text_color="white",
                                        font=("JetBrainsMono Nerd Font", 11))
        self.output_text.pack(fill="both", expand=True, padx=15, pady=(5, 10))
        self.output_text.insert("0.0", "System ready. What's next?")
        self.output_text.configure(state="disabled")

        # Input Frame (Keeps entry and border fixed during resizing)
        self.input_frame = ctk.CTkFrame(self, fg_color="transparent", height=40)
        self.input_frame.pack(fill="x", side="bottom", padx=15, pady=(0, 15))
        self.input_frame.pack_propagate(False) # Prevents frame from collapsing

        # Fixed-height Input Entry
        self.entry = ctk.CTkEntry(self.input_frame,
                                 placeholder_text="What's up?",
                                 fg_color=BG,
                                 border_color=PINK,
                                 border_width=1,
                                 text_color="white",
                                 font=("JetBrainsMono Nerd Font", 13))
        self.entry.pack(fill="both", expand=True)

        self.entry.focus_set()
        self.entry.bind("<Return>", self.start_thought_thread)
        self.entry.bind("<Escape>", lambda e: self.destroy())

        if len(sys.argv) > 1:
            incoming_msg = " ".join(sys.argv[1:])
            self.after(200, lambda: self.update_output(incoming_msg))

    def update_output(self, text, sender="CASPIAN"):
        self.output_text.configure(state="normal")
        prefix = f"\n\n{sender}: "
        self.output_text.insert("end", f"{prefix}{text}")
        self.output_text.see("end")
        self.output_text.configure(state="disabled")

    def start_thought_thread(self, event):
        thought = self.entry.get().strip()
        if thought:
            self.update_output(thought, sender="YOU")
            self.update_output("Thinking...", sender="CASPIAN")
            self.entry.delete(0, "end")
            threading.Thread(target=self.talk_logic, args=(thought,), daemon=True).start()

    def talk_logic(self, thought):
        # Quick exit if user explicitly typed a departure word
        if thought.lower() in ["bye", "goodbye", "exit", "quit"]:
            self.after(0, self.destroy)
            return
        path = os.path.expanduser("~/dotfiles/.config/hypr/scripts/caspian_brain.py")
        try:
            response = subprocess.check_output(["python", path, thought],
                                             text=True,
                                             stderr=subprocess.STDOUT,
                                             timeout=20)
            clean_response = response.strip()
            
            # Close the window if the brain confirms or tells us to shut down
            if "bye" in clean_response.lower() or "goodbye" in clean_response.lower():
                self.after(0, lambda r=clean_response: self.replace_last_line(r))
                self.after(1000, self.destroy)  # 1-second delay so you can read the final words
                return

            self.after(0, lambda r=clean_response: self.replace_last_line(r))
            
        except subprocess.CalledProcessError as e:
            self.after(0, lambda err=e.output: self.replace_last_line(f"BRAIN CRASH:\n{err}"))
        except Exception as e:
            self.after(0, lambda err=e: self.replace_last_line(f"SYSTEM ERROR: {err}"))

    def replace_last_line(self, new_text):
        """Replaces the 'Thinking...' line with the actual answer cleanly."""
        self.output_text.configure(state="normal")
        idx = self.output_text.search("Thinking...", "end-2c", backwards=True)
        if idx:
            # Clears from the found index to the end
            self.output_text.delete(idx, "end")
            self.output_text.insert("end", f"Thinking...\n\nCASPIAN: {new_text}")
        else:
            self.output_text.insert("end", f"\n\nCASPIAN: {new_text}")
            
        self.output_text.see("end")
        self.output_text.configure(state="disabled")

if __name__ == "__main__":
    app = CaspianMouth()
    app.mainloop()

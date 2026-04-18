import customtkinter as ctk
import os
import sys # Used for restarting the script
from pathlib import Path
from watchdog.observers import Observer 
from watchdog.events import FileSystemEventHandler 

WINE = "#73022f"
PINK = "#fa0567"
BG = "#1a1a1a"

class FileManage(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("File Explorer")
        self.geometry("1100x700")
        self.configure(fg_color=BG)


        self.current_path = Path.home().resolve()
        
        self.is_root = os.geteuid() == 0


        self.setup_ui()
        self.change_dir(self.current_path)

    def setup_ui(self):

        self.sidebar = ctk.CTkFrame(self, width=220, fg_color="#121212", corner_radius=0)
        self.sidebar.pack(side="left", fill="y")
        
        status_text = "MODE: ROOT" if self.is_root else "MODE: USER"
        status_color = PINK if self.is_root else "gray"
        ctk.CTkLabel(self.sidebar, text=status_text, text_color=status_color).pack(side="bottom", pady=10)


        self.add_shortcut("Home", Path.home(), "  ")
        self.add_shortcut("System Root", Path("/"), "  ")
        self.add_shortcut("Etc Config", Path("/etc"), "  ")


        self.main_view = ctk.CTkFrame(self, fg_color="transparent")
        self.main_view.pack(side="right", fill="both", expand=True)

        self.nav_bar = ctk.CTkFrame(self.main_view, fg_color="transparent")
        self.nav_bar.pack(fill="x", padx=20, pady=15)

        self.path_entry = ctk.CTkEntry(self.nav_bar, fg_color="#121212", border_color=WINE)
        self.path_entry.pack(side="left", fill="x", expand=True, padx=10)

        self.scroll_frame = ctk.CTkScrollableFrame(self.main_view, fg_color=BG, border_color=WINE, border_width=1)
        self.scroll_frame.pack(fill="both", expand=True, padx=20, pady=(0, 20))

    def add_shortcut(self, name, path, icon):
        btn = ctk.CTkButton(self.sidebar, text=f"{icon} {name}", anchor="w", fg_color="transparent",
                          hover_color=WINE, command=lambda p=path: self.change_dir(p))
        btn.pack(fill="x", padx=10, pady=2)

    def change_dir(self, new_path):
        self.current_path = Path(new_path).resolve()
        self.refresh_list()

    def refresh_list(self):
        for widget in self.scroll_frame.winfo_children():
            widget.destroy()

        self.path_entry.delete(0, "end")
        self.path_entry.insert(0, str(self.current_path))

        try:
            items = sorted(self.current_path.iterdir(), key=lambda p: (not p.is_dir(), p.name.lower()))
            for item in items:
                icon = "  " if item.is_dir() else "  "
                btn = ctk.CTkButton(self.scroll_frame, text=f"{icon}  {item.name}", anchor="w",
                                  fg_color="transparent", text_color="white", hover_color=WINE,
                                  command=lambda i=item: self.handle_click(i))
                btn.pack(fill="x", pady=1)

        except PermissionError:
            self.show_elevation_prompt()

    def show_elevation_prompt(self):
        """Creates a Wine-themed prompt to ask for root access."""
        label = ctk.CTkLabel(self.scroll_frame, text=" Restricted Folder\nElevate to Root?", 
                            font=("JetBrainsMono Nerd Font", 16), text_color=PINK)
        label.pack(pady=20)

        elevate_btn = ctk.CTkButton(self.scroll_frame, text="Unlock with Password", 
                                   fg_color=WINE, hover_color=PINK, command=self.request_elevation)
        elevate_btn.pack(pady=10)

    def request_elevation(self):
        """Uses pkexec to restart the script as Root."""

        cmd = f"pkexec {sys.executable} {os.path.abspath(__file__)}"
        

        os.system(f"{cmd} &")
        sys.exit()

    def handle_click(self, item):
        if item.is_dir():
            self.change_dir(item)
        else:
            os.system(f"xdg-open '{item}' &")

if __name__ == "__main__":
    app = FileManage()
    app.mainloop()

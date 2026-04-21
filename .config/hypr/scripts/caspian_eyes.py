import socket
import os
import subprocess

BRAIN_PATH = os.path.expanduser("~/dotfiles/.config/hypr/scripts/caspian_brain")

def monitor_windows():
    his = os.environ.get("HYPRLAND_INTANCE_SIGNATURE")
    if not his:
        return

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(f"/tmp/hypr/{his}/.socket2.sock")

    print("Wathing...")

    while True:
        data = sock.recv(4096).decode('utf-8')
        for line in deta.split('\n'):
            if "activewindow>>" in line:
                window_class = line.split(">>")[1].split(",")[0]
                on_change(window_class)

def on_change(window_class):
    subrocess.Popen(["python", BRAIN_PATH, f"context {window_class}"])

if __name__ == "__main__":
    monitor_windows()

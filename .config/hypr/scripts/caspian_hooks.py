import time
import subprocess
import os
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

PROJECT_PATH = os.path.expanduser("~/dotfiles")
MOUTH_PATH = os.path.expanduser("~/dotfiles/.config/hypr/scripts/caspian_mouth.py")

class CodeWatcher(FileSystemEventHandler):
    def __init__(self):
        self.last_run = 0

    def on_modified(self, event):
        if event.src_path.endswith(".py"):
            if time.time() - self.last_run < 2:
                return
            if "caspian_" in event.src_path:
                return
            self.last_run = time.time()
            print(f"Analyzing {os.path.basename(event.src_path)}")            
            self.check_code(event.src_path)

    def check_code(self, file_path):
        try:
            cmd = f"flake8 {file_path} --select=E9,F --ignore=E2,E3,E501"
            result = subprocess.getoutput(cmd)

            if result:
                msg = f"Found a bug in {os.path.basename(file_path)}:\n\n{result}"
                subprocess.Popen(["python", MOUTH_PATH, msg])

        except Exception as e:
            print(f"Hook Error: {e}")

if __name__ == "__main__":
    observer = Observer()
    handler = CodeWatcher()
    observer.schedule(handler, PROJECT_PATH, recursive=True)
    observer.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()

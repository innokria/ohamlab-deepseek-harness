"""Run the upstream Harness web server with an isolated data directory."""
from __future__ import annotations
import os
from pathlib import Path
import shlex
import subprocess
import threading
import time
import urllib.request
import webbrowser
from .installer import InstallError

def start(home: Path, *, command: str="pnpm dsh web", host: str="127.0.0.1", port: int=3080, open_browser: bool=False):
    home=home.expanduser().resolve()
    app=home/"app"
    if not (app/"package.json").is_file():
        raise InstallError(f"Harness not installed at {app}. Run 'ohamlab-harness install' first.")
    if not (home/"data"/"skills"/"web-search"/"SKILL.md").is_file():
        raise InstallError("OhamLab skills missing; rerun installation")
    env=os.environ.copy()
    env.update({"DSH_HOME":str(home/"data"),"DSH_HOST":host,"DSH_PORT":str(port),"PORT":str(port)})
    venv_bin=home/"python-env"/("Scripts" if os.name=="nt" else "bin")
    if venv_bin.is_dir():
        env["PATH"]=str(venv_bin)+os.pathsep+env.get("PATH","")
        env["OHAM_PYTHON"]=str(venv_bin/("python.exe" if os.name=="nt" else "python"))
    argv=shlex.split(command,posix=os.name!="nt")
    if not argv:
        raise InstallError("Empty startup command")
    url=f"http://{host}:{port}"
    print(f"[OHAMLAB] Starting Harness at {url}",flush=True)
    print("[OHAMLAB] MCP gateway registration must be configured and verified separately.",flush=True)
    if open_browser:
        def open_when_ready():
            for _ in range(40):
                try:
                    with urllib.request.urlopen(url,timeout=1):
                        webbrowser.open(url)
                        return
                except Exception:
                    time.sleep(1)
        threading.Thread(target=open_when_ready,daemon=True).start()
    return subprocess.call(argv,cwd=app,env=env)

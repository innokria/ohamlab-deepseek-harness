"""User-facing OhamLab Harness CLI."""
from __future__ import annotations
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
from . import __version__
from .installer import REPO_URL, InstallError, install, SKILLS
from .runtime import start

def default_home():
    return Path(os.environ.get("OHAMLAB_HARNESS_HOME",str(Path.home()/".ohamlab-harness")))

def doctor(home: Path):
    print(f"OhamLab Harness {__version__}")
    missing=[]
    for exe in ("git","node","pnpm"):
        path=shutil.which(exe)
        print(f"{exe}: {path or 'MISSING'}")
        if not path: missing.append(exe)
    node=shutil.which("node")
    if node:
        version=subprocess.run([node,"--version"],capture_output=True,text=True,check=False).stdout.strip()
        print("Node version:",version)
        try:
            if int(version.lstrip("v").split(".")[0])<22: missing.append("Node.js 22+")
        except (ValueError,IndexError): missing.append("Node.js version unknown")
    app=home/"app"
    print("Harness checkout:", "OK" if (app/"package.json").is_file() else "NOT INSTALLED")
    if not (app/"package.json").is_file(): missing.append("Harness checkout")
    for skill in SKILLS:
        exists=(home/"data"/"skills"/skill/"SKILL.md").is_file()
        print(f"Skill {skill}:","OK" if exists else "MISSING")
        if not exists: missing.append(skill)
    py=home/"python-env"/("Scripts/python.exe" if os.name=="nt" else "bin/python")
    print("Gateway Python:","OK" if py.is_file() else "MISSING")
    if not py.is_file(): missing.append("Gateway Python")
    print("MCP registration: NOT VERIFIED (requires live Harness test)")
    return 1 if missing else 0

def main(argv=None):
    parser=argparse.ArgumentParser(prog="ohamlab-harness")
    parser.add_argument("--version",action="version",version=__version__)
    parser.add_argument("--home",type=Path,default=default_home(),help="Installation directory")
    subs=parser.add_subparsers(dest="action",required=True)
    setup=subs.add_parser("install",help="Fetch, build, and install Harness")
    setup.add_argument("--repo-url",default=REPO_URL)
    setup.add_argument("--harness-ref",default="1.0")
    setup.add_argument("--vendor-ref",default="main")
    setup.add_argument("--vendor-path",type=Path)
    setup.add_argument("--skip-python",action="store_true")
    subs.add_parser("doctor",help="Check runtime prerequisites and installed files")
    run=subs.add_parser("start",help="Start local Harness web UI")
    run.add_argument("--start-command",default=os.environ.get("OHAMLAB_HARNESS_START_CMD","pnpm dsh web"))
    run.add_argument("--host",default="127.0.0.1")
    run.add_argument("--port",type=int,default=3080)
    run.add_argument("--open-browser",action="store_true")
    args=parser.parse_args(argv)
    try:
        if args.action=="install":
            install(args.home,repo_url=args.repo_url,harness_ref=args.harness_ref,vendor_ref=args.vendor_ref,vendor_path=args.vendor_path,skip_python=args.skip_python)
            return 0
        if args.action=="doctor": return doctor(args.home)
        return start(args.home,command=args.start_command,host=args.host,port=args.port,open_browser=args.open_browser)
    except (InstallError,OSError,subprocess.CalledProcessError) as exc:
        print(f"[OHAMLAB] ERROR: {exc}",file=sys.stderr)
        return 1

if __name__=="__main__":
    sys.exit(main())

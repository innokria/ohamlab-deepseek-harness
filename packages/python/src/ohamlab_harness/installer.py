"""Fetch and build an isolated Harness runtime, without modifying the source repository."""
from __future__ import annotations
import os
from pathlib import Path
import shutil
import subprocess
import sys
import venv

REPO_URL = "https://github.com/innokria/ohamlab-deepseek-harness.git"
SKILLS = ("web-search", "agent-lab", "research-workflow")

class InstallError(RuntimeError):
    pass

def run(argv, *, cwd=None, env=None):
    print("+", " ".join(map(str, argv)), flush=True)
    subprocess.run([str(x) for x in argv], cwd=cwd, env=env, check=True)

def require(binary):
    found = shutil.which(binary)
    if not found:
        raise InstallError(f"Missing executable: {binary}. Install it and retry.")
    return found

def git_checkout(url: str, ref: str, destination: Path):
    if destination.exists():
        raise InstallError(f"Refusing to overwrite existing directory: {destination}")
    run([require("git"), "clone", "--no-checkout", url, destination])
    run(["git", "-C", destination, "checkout", ref])

def install_skills(source: Path, target: Path):
    target.mkdir(parents=True, exist_ok=True)
    for skill in SKILLS:
        src = source / skill
        if not (src / "SKILL.md").is_file():
            raise InstallError(f"Required skill missing: {src / 'SKILL.md'}")
        shutil.copytree(src, target / skill, dirs_exist_ok=True)
        print(f"[OHAMLAB] Installed skill: {skill}")

def install(home: Path, *, repo_url: str=REPO_URL, harness_ref: str="1.0", vendor_ref: str="main", vendor_path: Path|None=None, skip_python: bool=False):
    require("git"); require("node"); require("pnpm")
    home = home.expanduser().resolve()
    home.mkdir(parents=True, exist_ok=True)
    app = home / "app"
    if app.exists():
        raise InstallError(f"Harness already installed at {app}. Remove it manually to reinstall; no automatic overwrite.")
    git_checkout(repo_url, harness_ref, app)
    if not (app / "package.json").is_file():
        raise InstallError("Selected Harness ref has no package.json at repository root")
    vendor_dest = app / "vendor" / "ohamlab"
    if vendor_path:
        vendor_src = vendor_path.expanduser().resolve()
        if not vendor_src.is_dir():
            raise InstallError(f"Vendor directory missing: {vendor_src}")
    else:
        vendor_repo = home / "vendor-checkout"
        git_checkout(repo_url, vendor_ref, vendor_repo)
        vendor_src = vendor_repo / "vendor" / "ohamlab"
        if not vendor_src.is_dir():
            raise InstallError(f"Vendor integration missing: {vendor_src}")
    vendor_dest.parent.mkdir(parents=True,exist_ok=True)
    if vendor_dest.exists():
        shutil.rmtree(vendor_dest)
    shutil.copytree(vendor_src,vendor_dest)
    if not vendor_path:
        shutil.rmtree(home / "vendor-checkout")
    requirements = vendor_dest / "gateway" / "requirements.txt"
    if not requirements.is_file():
        raise InstallError(f"Gateway requirements missing: {requirements}")
    run(["pnpm", "install", "--frozen-lockfile"],cwd=app)
    run(["pnpm", "run", "build"],cwd=app)
    branding = vendor_dest / "plugins" / "harness-brand"
    if branding.is_dir():
        run(["pnpm", "dsh", "plugin", "--profile", "web", "add", branding], cwd=app)
    if not skip_python:
        venv_dir=home / "python-env"
        venv.EnvBuilder(with_pip=True).create(venv_dir)
        python=venv_dir / ("Scripts/python.exe" if os.name=="nt" else "bin/python")
        run([python,"-m","pip","install","-r",requirements])
        run([python,"-m","pip","install","ohamlab-agent==0.1.2","ohamlab-agent-lab==7.0.0"])
    install_skills(vendor_dest / "skills", home / "data" / "skills")
    print(f"[OHAMLAB] Installed into {home}")
    print("[OHAMLAB] Next: ohamlab-harness doctor && ohamlab-harness start")
    return app

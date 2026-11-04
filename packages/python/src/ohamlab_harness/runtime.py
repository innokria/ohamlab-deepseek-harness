"""Cross-platform executable discovery and Harness launcher."""
import os
import shutil
import subprocess
import sys
from pathlib import Path


def default_home():
    return Path(os.environ.get("OHAMLAB_HARNESS_HOME", Path.home() / ".ohamlab-harness")).expanduser().resolve()


def executable(name):
    found = shutil.which(name)
    if found:
        return found
    if os.name == "nt":
        for suffix in (".cmd", ".exe", ".bat"):
            found = shutil.which(name + suffix)
            if found:
                return found
    return None


def require_tools(*names):
    missing = [name for name in names if not executable(name)]
    if missing:
        raise RuntimeError("Missing required executables: " + ", ".join(missing) + ". Install Node.js 22+, pnpm, and Git as appropriate.")


def run(args, cwd=None, env=None):
    print("[OHAMLAB]", " ".join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), cwd=cwd, env=env, check=True)


def start(home=None, host=None, port=None, trusted_host=None):
    home = Path(home) if home else default_home()
    app = home / "app"
    if not (app / "package.json").is_file():
        raise RuntimeError(f"Harness not installed at {app}. Run 'ohamlab-harness install'.")
    require_tools("node", "pnpm")
    host = host or os.environ.get("DSH_HOST", "127.0.0.1")
    port = str(port or os.environ.get("DSH_PORT", "3080"))
    trusted_host = trusted_host or os.environ.get("DSH_TRUSTED_HOST")
    cmd = [executable("pnpm"), "dsh", "web", "--host", host, "--port", port, "--no-open"]
    if trusted_host:
        cmd += ["--trusted-host", trusted_host]
    env = os.environ.copy()
    env.setdefault("DSH_HOME", str(home / "data"))
    Path(env["DSH_HOME"]).mkdir(parents=True, exist_ok=True)
    print(f"[OHAMLAB] Serving Harness at http://{host}:{port}", flush=True)
    return subprocess.call(cmd, cwd=app, env=env)

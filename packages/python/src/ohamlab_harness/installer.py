
"""Install OhamLab Harness with automatic OhamLab branding."""

import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

from .runtime import default_home, executable, require_tools, run

REPO = "https://github.com/innokria/ohamlab-deepseek-harness.git"
PLUGIN_NAME = "@ohamlab/harness-brand"


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def validate_branding(plugin):
    manifest_path = plugin / "package.json"

    if not manifest_path.is_file():
        raise RuntimeError(f"Branding package.json missing: {manifest_path}")

    manifest = read_json(manifest_path)

    if manifest.get("name") != PLUGIN_NAME:
        raise RuntimeError(
            f"Unexpected branding package name: {manifest.get('name')}"
        )

    for entry in ("lib/index.js", "lib/client.js"):
        path = plugin / entry
        if not path.is_file():
            raise RuntimeError(f"Branding build output missing: {path}")

    client_config = manifest.get("dsh", {}).get("client")

    if not client_config:
        raise RuntimeError(
            "Branding package is missing its dsh.client configuration."
        )

    return manifest



def install(
    home: Path,
    *,
    repo_url: str = REPO_URL,
    harness_ref: str = "1.0",
    vendor_ref: str = "main",
    vendor_path: Path | None = None,
    skip_python: bool = False,
):
    require("git")
    require("node")
    require("pnpm")

    home = home.expanduser().resolve()
    home.mkdir(parents=True, exist_ok=True)

    app = home / "app"
    data = Path(
        os.environ.get("DSH_HOME", str(home / "data"))
    ).expanduser().resolve()

    data.mkdir(parents=True, exist_ok=True)

    if app.exists():
        raise InstallError(
            f"Harness already installed: {app}"
        )

    git_checkout(repo_url, harness_ref, app)

    if not (app / "package.json").is_file():
        raise InstallError(
            "Harness package.json missing"
        )

    vendor_dest = app / "vendor" / "ohamlab"

    if vendor_path:
        vendor_src = vendor_path.expanduser().resolve()
        if not vendor_src.is_dir():
            raise InstallError(
                f"Vendor missing: {vendor_src}"
            )
    else:
        vendor_repo = home / "vendor-checkout"
        git_checkout(repo_url, vendor_ref, vendor_repo)
        vendor_src = vendor_repo / "vendor" / "ohamlab"

    if not vendor_src.is_dir():
        raise InstallError(
            f"Vendor integration missing: {vendor_src}"
        )

    vendor_dest.parent.mkdir(
        parents=True, exist_ok=True
    )

    if vendor_dest.exists():
        shutil.rmtree(vendor_dest)

    shutil.copytree(vendor_src, vendor_dest)

    if not vendor_path:
        shutil.rmtree(home / "vendor-checkout")

    # Build the main Harness.
    run(
        ["pnpm", "install", "--frozen-lockfile"],
        cwd=app,
    )
    run(["pnpm", "run", "build"], cwd=app)

    # Build OhamLab branding separately.
    branding = vendor_dest / "plugins" / "harness-brand"

    if not (branding / "package.json").is_file():
        raise InstallError(
            f"Brand plugin missing: {branding}"
        )

    if not (branding / "build.mjs").is_file():
        raise InstallError(
            "Brand plugin build.mjs missing. "
            "Restore its build script before installation."
        )

    run(["pnpm", "install"], cwd=branding)
    run(["pnpm", "run", "build"], cwd=branding)

    for output in ("lib/index.js", "lib/client.js"):
        if not (branding / output).is_file():
            raise InstallError(
                f"Brand build output missing: {output}"
            )

    # Install Python dependencies.
    if not skip_python:
        venv_dir = home / "python-env"

        venv.EnvBuilder(with_pip=True).create(venv_dir)

        python = venv_dir / (
            "Scripts/python.exe"
            if os.name == "nt"
            else "bin/python"
        )

        requirements = (
            vendor_dest / "gateway" / "requirements.txt"
        )

        if not requirements.is_file():
            raise InstallError(
                f"Requirements missing: {requirements}"
            )

        run([
            python, "-m", "pip", "install",
            "-r", requirements
        ])

        run([
            python, "-m", "pip", "install",
            "ohamlab-agent==0.1.2",
            "ohamlab-agent-lab[server]==7.0.0",
        ])

    # Install skills into actual DSH_HOME.
    install_skills(
        vendor_dest / "skills",
        data / "skills",
    )

    # Register the compiled brand plugin.
    plugin_env = os.environ.copy()
    plugin_env["DSH_HOME"] = str(data)

    run(
        [
            "pnpm", "dsh", "plugin",
            "--profile", "web",
            "add", str(branding)
        ],
        cwd=app,
        env=plugin_env,
    )

    print("[OHAMLAB] Harness installed")
    print("[OHAMLAB] Brand plugin built and registered")
    print("[OHAMLAB] Python dependencies installed")
    print(f"[OHAMLAB] DSH_HOME: {data}")

    return app


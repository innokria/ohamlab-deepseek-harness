
"""Install OhamLab Harness and Python integrations without a branding build."""

import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

from .runtime import default_home, executable, require_tools, run

REPO = "https://github.com/innokria/ohamlab-deepseek-harness.git"
def install(home=None, repo=None, harness_tag=None,
            integration_tag=None, force=False):

    require_tools("git", "node", "pnpm")

    pnpm = executable("pnpm")

    home = (
        Path(home).expanduser().resolve()
        if home else default_home()
    )

    dsh_home = Path(
        os.environ.get("DSH_HOME", home / "data")
    ).expanduser().resolve()

    repo = repo or os.environ.get("OHAMLAB_REPO_URL", REPO)

    harness_tag = (
        harness_tag
        or os.environ.get("OHAMLAB_HARNESS_TAG", "1.0")
    )

    integration_tag = (
        integration_tag
        or os.environ.get("OHAMLAB_INTEGRATION_TAG", "2.0")
    )

    app = home / "app"

    if app.exists() and not force:
        raise RuntimeError(
            f"{app} already exists; use --force to reinstall."
        )

    home.mkdir(parents=True, exist_ok=True)
    dsh_home.mkdir(parents=True, exist_ok=True)

    for directory in (
        dsh_home / "plugins",
        dsh_home / "profiles",
        dsh_home / "sessions",
        dsh_home / "cache",
        dsh_home / "logs",
    ):
        directory.mkdir(parents=True, exist_ok=True)

    # Keep backups until the new installation has passed verification.
    backup_app = home / "app.previous"
    app_backed_up = False
    new_app_deployed = False

    try:
        with tempfile.TemporaryDirectory(
            prefix="ohamlab-build-", dir=home
        ) as temp:

            tmp = Path(temp)
            source = tmp / "app"
            integration = tmp / "integration"

            print("[OHAMLAB] Cloning Harness...")

            run([
                "git", "clone",
                "--branch", harness_tag,
                "--depth", "1",
                repo, str(source),
            ])

            print("[OHAMLAB] Cloning OhamLab integration...")

            run([
                "git", "clone",
                "--branch", integration_tag,
                "--depth", "1",
                "--filter=blob:none",
                "--sparse",
                repo, str(integration),
            ])

            run(
                [
                    "git", "sparse-checkout",
                    "set", "vendor/ohamlab",
                ],
                cwd=integration,
            )

            vendor = integration / "vendor" / "ohamlab"
            requirements = vendor / "gateway" / "requirements.txt"
            skills = vendor / "skills"

            for required in (requirements, skills):
                if not required.exists():
                    raise RuntimeError(
                        f"Required integration file missing: {required}"
                    )

            # Copy OhamLab integration into the Harness source.
            target_vendor = source / "ohamlab" / "vendor" / "ohamlab"
            target_vendor.parent.mkdir(parents=True, exist_ok=True)

            if target_vendor.exists():
                shutil.rmtree(target_vendor)

            shutil.copytree(vendor, target_vendor)

            # Install Python integrations.
            python = (
                os.environ.get("OHAM_PYTHON")
                or os.environ.get("PYTHON")
                or sys.executable
            )

            print("[OHAMLAB] Installing Python dependencies...")

            run([
                python, "-m", "pip",
                "install", "-r", str(requirements),
            ])

            run([
                python, "-m", "pip",
                "install",
                "ohamlab-agent==0.1.2",
                "ohamlab-agent-lab[server]==7.0.0",
            ])

            run([python, "-m", "pip", "check"])

            # Install Harness dependencies.
            print("[OHAMLAB] Installing Harness dependencies...")

            run([pnpm, "install"], cwd=source)

            # Back up the existing application.
            if app.exists():
                app.rename(backup_app)
                app_backed_up = True

            # Deploy the new application.
            shutil.move(str(source), str(app))
            new_app_deployed = True

            # Build Harness without installing the optional branding plugin.
            print("[OHAMLAB] Building Harness...")
            run([pnpm, "run", "build"], cwd=app)

            print("[OHAMLAB] Harness build completed.")

        # Keep the old installation until all deployment checks pass.
        if backup_app.exists():
            shutil.rmtree(backup_app)

    except Exception:
        print("[OHAMLAB] Installation failed. Restoring previous app...")

        if new_app_deployed and app.exists():
            shutil.rmtree(app)

        if app_backed_up and backup_app.exists():
            backup_app.rename(app)

        raise

    print("========================================")
    print("[OHAMLAB] Installation successful")
    print(f"[OHAMLAB] Harness: {app}")
    print("========================================")

    return app

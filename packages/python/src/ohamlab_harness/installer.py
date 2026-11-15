
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
    plugin = dsh_home / "plugins" / "harness-brand"
    profile = dsh_home / "profiles" / "web"
    profile_package = profile / "package.json"

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
    backup_plugin = dsh_home / "plugins" / "harness-brand.previous"

    if backup_app.exists():
        raise RuntimeError(
            f"Previous app backup already exists: {backup_app}. "
            "Inspect or move it before reinstalling."
        )

    if backup_plugin.exists():
        raise RuntimeError(
            f"Previous branding backup already exists: {backup_plugin}. "
            "Inspect or move it before reinstalling."
        )

    app_backed_up = False
    plugin_backed_up = False
    new_app_deployed = False
    new_plugin_deployed = False

    try:
        with tempfile.TemporaryDirectory(
            prefix="ohamlab-build-", dir=home
        ) as temp:

            tmp = Path(temp)
            source = tmp / "app"
            integration = tmp / "integration"
            plugin_target = tmp / "harness-brand"

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
            branding = vendor / "plugins" / "harness-brand"
            skills = vendor / "skills"

            for required in (requirements, branding, skills):
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

            # Prepare the branding package.
            shutil.copytree(branding, plugin_target)

            manifest_path = plugin_target / "package.json"

            if not manifest_path.is_file():
                raise RuntimeError("Branding package.json is missing.")

            manifest = read_json(manifest_path)

            if manifest.get("name") != PLUGIN_NAME:
                raise RuntimeError(
                    f"Unexpected branding package name: "
                    f"{manifest.get('name')}"
                )

            # Build the branding package before deploying it.
            print("[OHAMLAB] Building branding package...")

            run([pnpm, "install"], cwd=plugin_target)

            if "build" in manifest.get("scripts", {}):
                run([pnpm, "run", "build"], cwd=plugin_target)

            validate_branding(plugin_target)

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

            # Back up the existing application and branding package.
            if app.exists():
                app.rename(backup_app)
                app_backed_up = True

            if plugin.exists():
                plugin.rename(backup_plugin)
                plugin_backed_up = True

            # Deploy the new application.
            shutil.move(str(source), str(app))
            new_app_deployed = True

            # Deploy branding into persistent DSH storage.
            plugin.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(plugin_target, plugin)
            new_plugin_deployed = True

            validate_branding(plugin)

            print(f"[OHAMLAB] Branding copied to {plugin}")

            # Initialize the web profile if needed.
            if not profile_package.exists():
                print("[OHAMLAB] Initializing web profile...")

                run(
                    [
                        pnpm, "dsh", "plugin",
                        "--profile", "web",
                        "add", str(plugin),
                    ],
                    cwd=app,
                )

            if not profile_package.is_file():
                raise RuntimeError(
                    f"Web profile was not created: {profile_package}"
                )

            # Ensure the profile references the persistent plugin path.
            profile_data = read_json(profile_package)
            dependencies = profile_data.setdefault("dependencies", {})

            dependencies[PLUGIN_NAME] = f"link:{plugin}"

            write_json(profile_package, profile_data)

            print(
                f"[OHAMLAB] Profile dependency: "
                f"{PLUGIN_NAME} -> {plugin}"
            )

            # Install the profile dependencies.
            print("[OHAMLAB] Installing web profile plugins...")

            run([pnpm, "install"], cwd=profile)

            # Verify that pnpm installed the linked package.
            installed_plugin = (
                profile / "node_modules" / "@ohamlab" / "harness-brand"
            )

            if not installed_plugin.exists():
                raise RuntimeError(
                    "Branding plugin was not installed in the web profile: "
                    f"{installed_plugin}"
                )

            validate_branding(installed_plugin)

            print("[OHAMLAB] Branding profile dependency verified.")

            # Build Harness after the client plugin is registered.
            print("[OHAMLAB] Building Harness with OhamLab branding...")

            run(
                [pnpm, "run", "build"],
                cwd=app,
            )

            print("[OHAMLAB] Harness build completed.")

        # Keep the old installation until all deployment checks pass.
        if backup_app.exists():
            shutil.rmtree(backup_app)

        if backup_plugin.exists():
            shutil.rmtree(backup_plugin)

    except Exception:
        print("[OHAMLAB] Installation failed. Restoring previous app...")

        if new_app_deployed and app.exists():
            shutil.rmtree(app)

        if app_backed_up and backup_app.exists():
            backup_app.rename(app)

        if new_plugin_deployed and plugin.exists():
            shutil.rmtree(plugin)

        if plugin_backed_up and backup_plugin.exists():
            backup_plugin.rename(plugin)

        raise

    print("========================================")
    print("[OHAMLAB] Installation successful")
    print(f"[OHAMLAB] Harness: {app}")
    print(f"[OHAMLAB] Branding: {plugin}")
    print(f"[OHAMLAB] Profile: {profile}")
    print("========================================")

    return app

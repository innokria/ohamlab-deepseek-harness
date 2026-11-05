
"""Install OhamLab Harness with automatic OhamLab branding."""

import json
import os
import shutil
import tempfile
from pathlib import Path

from .runtime import default_home, executable, require_tools, run

REPO = "https://github.com/innokria/ohamlab-deepseek-harness.git"

PLUGIN_NAME = "@ohamlab/harness-brand"


def install(home=None, repo=None, harness_tag=None,
            integration_tag=None, force=False):

    require_tools("git", "node", "pnpm")

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
            repo, source
        ])

        print("[OHAMLAB] Cloning OhamLab integration...")

        run([
            "git", "clone",
            "--branch", integration_tag,
            "--depth", "1",
            "--filter=blob:none",
            "--sparse",
            repo, integration
        ])

        run(
            [
                "git", "sparse-checkout",
                "set", "vendor/ohamlab"
            ],
            cwd=integration
        )

        vendor = integration / "vendor" / "ohamlab"

        requirements = (
            vendor / "gateway" / "requirements.txt"
        )

        branding = (
            vendor / "plugins" / "harness-brand"
        )

        skills = vendor / "skills"

        for required in (
            requirements,
            branding,
            skills,
        ):
            if not required.exists():
                raise RuntimeError(
                    f"Required integration file missing: {required}"
                )

        # Copy OhamLab vendor integration into Harness source.
        target_vendor = (
            source / "ohamlab" / "vendor" / "ohamlab"
        )

        target_vendor.parent.mkdir(
            parents=True, exist_ok=True
        )

        if target_vendor.exists():
            shutil.rmtree(target_vendor)

        shutil.copytree(vendor, target_vendor)

        # Prepare branding package.
        shutil.copytree(branding, plugin_target)

        plugin_manifest = plugin_target / "package.json"

        if not plugin_manifest.is_file():
            raise RuntimeError(
                "Branding package.json is missing."
            )

        manifest = json.loads(
            plugin_manifest.read_text(encoding="utf-8")
        )

        if manifest.get("name") != PLUGIN_NAME:
            raise RuntimeError(
                f"Unexpected branding package name: "
                f"{manifest.get('name')}"
            )

        # Verify browser client entry.
        client_entry = plugin_target / "lib" / "client.js"

        if not client_entry.is_file():
            raise RuntimeError(
                f"Branding client entry missing: {client_entry}"
            )

        # Install Python integrations.
        python = (
            os.environ.get("OHAM_PYTHON")
            or os.environ.get("PYTHON")
            or __import__("sys").executable
        )

        print("[OHAMLAB] Installing Python dependencies...")

        run([
            python, "-m", "pip",
            "install", "-r", str(requirements)
        ])

        run([
            python, "-m", "pip",
            "install",
            "ohamlab-agent==0.1.2",
            "ohamlab-agent-lab[server]==7.0.0"
        ])

        run([python, "-m", "pip", "check"])

        # Install Harness dependencies.
        print("[OHAMLAB] Installing Harness dependencies...")

        run(
            [executable("pnpm"), "install"],
            cwd=source
        )

        # Preserve the existing installation.
        old_app = home / "app.previous"

        if old_app.exists():
            shutil.rmtree(old_app)

        if app.exists():
            app.rename(old_app)

        try:
            # Deploy application.
            shutil.move(str(source), str(app))

            # Deploy branding into persistent DSH storage.
            plugin.parent.mkdir(
                parents=True, exist_ok=True
            )

            if plugin.exists():
                shutil.rmtree(plugin)

            shutil.copytree(plugin_target, plugin)

            print(
                f"[OHAMLAB] Branding package copied to {plugin}"
            )

            # Initialize the web profile if it does not exist.
            if not profile_package.exists():
                print("[OHAMLAB] Initializing web profile...")

                run(
                    [
                        executable("pnpm"),
                        "dsh",
                        "plugin",
                        "--profile", "web",
                        "add", str(plugin)
                    ],
                    cwd=app
                )

            # Correct the profile dependency.
            if not profile_package.exists():
                raise RuntimeError(
                    f"Web profile was not created: {profile_package}"
                )

            profile_data = json.loads(
                profile_package.read_text(encoding="utf-8")
            )

            dependencies = profile_data.setdefault(
                "dependencies", {}
            )

            # Replace any stale OhamLab plugin reference.
            dependencies[PLUGIN_NAME] = f"link:{plugin}"

            profile_package.write_text(
                json.dumps(
                    profile_data,
                    indent=2,
                    ensure_ascii=False
                ) + "\n",
                encoding="utf-8"
            )

            print(
                "[OHAMLAB] Corrected branding dependency:"
            )
            print(
                f"[OHAMLAB] {PLUGIN_NAME} -> {plugin}"
            )

            # Install the corrected profile dependency.
            print("[OHAMLAB] Installing web profile plugins...")

            run(
                [executable("pnpm"), "install"],
                cwd=profile
            )

            # Build AFTER the client plugin is registered.
            print("[OHAMLAB] Building Harness with branding...")

            run(
                [executable("pnpm"), "run", "build"],
                cwd=app
            )

            print("[OHAMLAB] Branding installation verified.")

        except Exception:
            if app.exists():
                shutil.rmtree(app)

            if old_app.exists():
                old_app.rename(app)

            raise

        if old_app.exists():
            shutil.rmtree(old_app)

    print("========================================")
    print("[OHAMLAB] Installation successful")
    print(f"[OHAMLAB] Harness: {app}")
    print(f"[OHAMLAB] Branding: {plugin}")
    print(f"[OHAMLAB] Profile: {profile}")
    print("========================================")

    return app

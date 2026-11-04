"""Install the same tagged GitHub sources used by the known-working Docker build."""
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from .runtime import default_home, executable, require_tools, run

REPO = "https://github.com/innokria/ohamlab-deepseek-harness.git"


def install(home=None, repo=None, harness_tag=None, integration_tag=None, force=False):
    require_tools("git", "node", "pnpm")
    home = Path(home).expanduser().resolve() if home else default_home()
    repo = repo or os.environ.get("OHAMLAB_REPO_URL", REPO)
    harness_tag = harness_tag or os.environ.get("OHAMLAB_HARNESS_TAG", "1.0")
    integration_tag = integration_tag or os.environ.get("OHAMLAB_INTEGRATION_TAG", "2.0")
    app = home / "app"
    plugin = home / "plugins" / "harness-brand"
    if app.exists() and not force:
        raise RuntimeError(f"{app} already exists; use --force to reinstall (existing app will be replaced).")
    home.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="ohamlab-build-", dir=home) as temp:
        tmp = Path(temp)
        source = tmp / "app"
        integration = tmp / "integration"
        run(["git", "clone", "--branch", harness_tag, "--depth", "1", repo, source])
        run(["git", "clone", "--branch", integration_tag, "--depth", "1", "--filter=blob:none", "--sparse", repo, integration])
        run(["git", "sparse-checkout", "set", "vendor/ohamlab"], cwd=integration)
        vendor = integration / "vendor" / "ohamlab"
        requirements = vendor / "gateway" / "requirements.txt"
        branding = vendor / "plugins" / "harness-brand"
        skills = vendor / "skills"
        for required in (requirements, branding, skills):
            if not required.exists():
                raise RuntimeError(f"Required integration file missing: {required}")
        target_vendor = source / "ohamlab" / "vendor" / "ohamlab"
        target_vendor.parent.mkdir(parents=True, exist_ok=True)
        if target_vendor.exists():
            shutil.rmtree(target_vendor)
        shutil.copytree(vendor, target_vendor)
        plugin_target = tmp / "harness-brand"
        shutil.copytree(branding, plugin_target)
        python = os.environ.get("OHAM_PYTHON") or os.environ.get("PYTHON") or __import__("sys").executable
        run([python, "-m", "pip", "install", "-r", requirements])
        run([python, "-m", "pip", "install", "ohamlab-agent==0.1.2", "ohamlab-agent-lab[server]==7.0.0"])
        run([python, "-m", "pip", "check"])
        run([executable("pnpm"), "install"], cwd=source)
        run([executable("pnpm"), "run", "build"], cwd=source)
        # Replace only after the entire new installation has built successfully.
        old_app = home / "app.previous"
        if old_app.exists():
            shutil.rmtree(old_app)
        if app.exists():
            app.rename(old_app)
        try:
            shutil.move(str(source), str(app))
            plugin.parent.mkdir(parents=True, exist_ok=True)
            if plugin.exists():
                shutil.rmtree(plugin)
            shutil.copytree(plugin_target, plugin)
            run([executable("pnpm"), "dsh", "plugin", "--profile", "web", "add", plugin], cwd=app)
        except Exception:
            if app.exists():
                shutil.rmtree(app)
            if old_app.exists():
                old_app.rename(app)
            raise
        if old_app.exists():
            shutil.rmtree(old_app)
    print(f"[OHAMLAB] Installed at {app}")
    return app

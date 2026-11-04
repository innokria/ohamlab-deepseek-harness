# OhamLab Harness Python installer (candidate 0.1.0b2)

This lightweight Python package installs and launches the **Node.js** Harness from the tagged GitHub source releases. The Node application is **not** bundled into the wheel.

## Prerequisites

- Python 3.9+
- Node.js 22+
- pnpm (the previously working Dockerfile uses `pnpm@11.7.0`)
- Git

On Windows, use a supported Node/pnpm environment; Windows support has not been integration-tested. The gateway's Python dependencies may also have platform-specific constraints.

## Local installation

```bash
python -m pip install .
ohamlab-harness install
ohamlab-harness status
ohamlab-harness start
```

The installer clones Harness tag `1.0`, overlays OhamLab integration from tag `2.0`, installs gateway Python dependencies and the two pinned OhamLab Python packages, runs `pnpm install` and `pnpm run build`, then registers the branding plugin. This mirrors the supplied working Dockerfile.

Set `OHAMLAB_HARNESS_HOME` to choose an installation directory, or pass `--home`. To reinstall, run `ohamlab-harness install --force`. The existing app is retained until the replacement builds successfully. `DSH_HOME` controls persistent runtime data.

## Hugging Face

Copy `deploy/huggingface/Dockerfile` and `deploy/huggingface/README.md` to the Space root. The Dockerfile installs Node.js, pnpm and Python, then installs this package from PyPI and runs the installer. It serves Harness directly on `0.0.0.0:7860` **without Nginx**.

If the Harness web server requires trusted-host settings for your Space domain, set `DSH_TRUSTED_HOST` using the exact format supported by the Harness version you deploy. Do not disable host checks without understanding the security implications.

Persistent `/data` storage requires a configured HF persistent volume; otherwise data is ephemeral.

## Publish only after integration testing

```bash
python -m pip install build twine
python -m build
python -m twine check dist/*
# Test installation in a clean environment first
python -m twine upload dist/*
```

This candidate was not tested against live GitHub releases or PyPI in the creation environment. Confirm the two tags, CLI arguments, build output and branding plugin behavior before publishing. PyPI version `0.1.0b2` is a proposed next version and cannot overwrite an existing release.

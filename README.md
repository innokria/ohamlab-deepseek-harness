

## CLI PYPY
```
pip install ohamlab-harness==0.1.0b1
```



## UI With Ox Alpha
<img width="1408" height="658" alt="image" src="https://github.com/user-attachments/assets/7460b85f-da82-4703-8005-ea2b609a80cc" />



<img width="2349" height="1410" alt="image" src="https://github.com/user-attachments/assets/4f699c11-33cb-4ab0-9548-3b2db811463d" />



```
<img width="1184" height="566" alt="image" src="https://github.com/user-attachments/assets/adbc4646-d929-4d16-bb64-25f872ac84a8" />


````
## Mermaid
```
flowchart LR
    subgraph DSH["DSH (DeepSeek Harness)"]
        HOST[Host Aggregate]
        CLIENT[Client Aggregate]
        WEB[Web App]
    end

    subgraph ohamlab["ohamlab Ecosystem"]
        AGENT_AGENT["ohamlab-agent (PyPI: v0.1.2)"]
        AGENT_LAB["ohamlab-agent-lab (PyPI: v7.0.0)"]
        SKILLS["Skills Package"]
        PLUGINS["Plugins (harness-brand)"]
    end

    subgraph MCP["MCP Layer (Model-Context-Protocol)"]
        MCP_CLIENT["mcp-client Plugin"]
        MCP_TOOLS["Registered Tools"]
    end

    %% Fixed labeled arrows (lines 35-50)
    DSH -->|Consumes MCP tools| MCP
    ohamlab -->|Provides MCP tools| MCP
    AGENT_AGENT -->|Web search, extraction| MCP_CLIENT
    AGENT_LAB -->|Agent runtime, storage| MCP_CLIENT
    SKILLS -->|Tool implementations| MCP_CLIENT
    PLUGINS -->|Branding/customization| HOST

    %% Web search fallback chain (lines 43-45)
    WEB -->|User queries| web_search["web_search MCP Tool"]
    web_search -->|Remote: DeepSeek| Remote["DeepSeek MCP Server"]
    web_search -->|Local fallback: ohamlab search| Local["ohamlab search (PyPI)"]

    %% Agent lifecycle (lines 48-50)
    HOST -->|Remote contributions, types| AGENT_LAB
    AGENT_LAB -->|agent IDs, task results| CLIENT
    CLIENT -->|Agent UI, task submission| WEB
```
```
<img width="1184" height="566" alt="image" src="https://github.com/user-attachments/assets/134aa9da-30fa-4def-bc5e-c8e75151885c" />

```

# OhamLab Harness

**A local-first AI development environment powered by DeepSeek Harness and OhamLab integrations.**

OhamLab Harness provides a Python-based installer and launcher for deploying the Harness application together with OhamLab Agent, OhamLab Search and OhamLab branding.

Install the Python package, provision the application and launch the browser-based interface.

```bash
pip install ohamlab-harness
```

---

## What is included?

| Component | Description |
|---|---|
| DeepSeek Harness | Core AI harness application and browser UI |
| OhamLab Agent | Agent execution and agent-lab integration |
| OhamLab Search | OhamLab search integration |
| OhamLab Branding | OhamLab web interface branding plugin |
| Python CLI | Installation, status and startup commands |

The project brings these components together through a single installation workflow while keeping the Harness application and OhamLab integrations separately maintained.

## Architecture

The deployment is designed around three responsibilities.

```text
                 OhamLab Harness
                        |
          +-------------+-------------+
          |             |             |
       Python         start.sh       Docker
       Installer      Runtime        Hosting
          |             |             |
          |             |             |
       Harness       Installation    Node.js
       Agent         Checks          Python
       Search        Plugin Repair   pnpm
       Branding      Service Start   Nginx
                     Monitoring
```

### Python installer

The Python package is responsible for provisioning the application and integrations:

- Clone and install the selected Harness release.
- Retrieve the OhamLab integration source.
- Install OhamLab Agent and its dependencies.
- Install OhamLab Search and gateway dependencies.
- Install and activate the OhamLab branding plugin.
- Build the Harness application.

### Runtime startup script

For container deployments, `deploy/huggingface/start.sh` manages runtime operations:

- Check whether installation has already completed.
- Run the installer when required.
- Repair optional plugin configuration.
- Start the Harness web application.
- Start Nginx as the public-facing reverse proxy.
- Monitor the running services.

### Docker

The Docker image provides the runtime environment:

- Node.js 22
- Python and virtual environment
- pnpm
- Git and system dependencies
- Nginx
- Container process management

Docker does not independently install Agent, Search or Branding. Those responsibilities belong to the Python installer.

---

## Requirements

For a native installation:

- Python 3.9+
- Node.js 22+
- Git
- pnpm 11.7.0 or compatible
- Internet access for initial installation

Enable pnpm through Corepack:

```bash
corepack enable
corepack prepare pnpm@11.7.0 --activate
```

For Docker deployments, the required runtime dependencies are installed by the image.

---

## Installation

Install the package:

```bash
python -m pip install ohamlab-harness
```

Check the installed version:

```bash
ohamlab-harness --version
```

Install Harness and OhamLab integrations:

```bash
ohamlab-harness install
```

The installer provisions the Harness application and its OhamLab integrations.

### Installation options

The installer supports the following options:

| Option | Description |
|---|---|
| `--home` | Custom Harness installation directory |
| `--repo` | Git repository URL |
| `--harness-tag` | Harness release tag |
| `--integration-tag` | OhamLab integration release tag |
| `--force` | Reinstall an existing Harness installation |

Example using explicit release tags:

```bash
ohamlab-harness install \
  --harness-tag 1.0 \
  --integration-tag 2.0
```

Example using a custom installation directory:

```bash
ohamlab-harness install \
  --home /opt/ohamlab-harness
```

**Release reproducibility:** Release tags provide a convenient version selection. For strict reproducibility, pin the source revisions to immutable Git commits in the deployment configuration.

---

## Running Harness

Check installation status:

```bash
ohamlab-harness status
```

Start the browser application:

```bash
ohamlab-harness start
```

The default runtime configuration is:

| Setting | Default |
|---|---|
| Harness home | `~/.ohamlab-harness` |
| DSH home | `~/.ohamlab-harness/data` |
| Host | `127.0.0.1` |
| Port | `3080` |

### Environment variables

The launcher supports environment-based configuration.

| Variable | Purpose |
|---|---|
| `OHAMLAB_HARNESS_HOME` | Harness installation directory |
| `DSH_HOME` | Harness data and profile directory |
| `DSH_HOST` | Local bind address |
| `DSH_PORT` | Harness web server port |
| `DSH_TRUSTED_HOST` | Optional trusted host setting |
| `OHAMLAB_HARNESS_TAG` | Default Harness release tag |
| `OHAMLAB_INTEGRATION_TAG` | Default integration release tag |

Example:

```bash
export OHAMLAB_HARNESS_HOME="$HOME/ohamlab"
export DSH_HOME="$HOME/ohamlab-data"
export DSH_HOST="127.0.0.1"
export DSH_PORT="3080"

ohamlab-harness install
ohamlab-harness start
```

---

## Hugging Face Docker deployment

The repository includes a Docker deployment under:

```text
deploy/huggingface/
```

The deployment uses:

- Node.js 22 as the base runtime.
- A dedicated Python virtual environment.
- pnpm for Harness installation and builds.
- The OhamLab Python installer for application provisioning.
- The repository startup script for runtime management.
- Nginx as the external HTTP reverse proxy.

### Deployment architecture

```text
Hugging Face Docker Space
          |
          v
      Nginx :7860
          |
          v
   Harness :3080
          |
          v
      DSH_HOME
      /data/dsh
          |
     +----+-----+
     |    |     |
  Profiles Plugins Sessions
```

### Persistent data

The Harness data directory is separated from the application installation:

```text
/app/
  ohamlab-harness/
    app/
    plugins/

/data/
  dsh/
    profiles/
    plugins/
    sessions/
    cache/
    logs/
```

Mount persistent storage at `/data/dsh` when the hosting platform supports it. This preserves profiles, sessions and plugin configuration across container restarts.

### Build and startup

The Docker image installs system dependencies and the Python package during image construction.

At runtime:

1. `start.sh` checks the installation state.
2. The Python installer provisions Harness and integrations if needed.
3. The startup script performs runtime plugin checks and repairs.
4. Harness starts on the internal port.
5. Nginx exposes the service on port `7860`.

---

## Project structure

```text
ohamlab-deepseek-harness/
│
├── packages/
│   └── python/
│       ├── pyproject.toml
│       └── src/
│           └── ohamlab_harness/
│               ├── __init__.py
│               ├── cli.py
│               ├── installer.py
│               └── runtime.py
│
├── deploy/
│   └── huggingface/
│       ├── Dockerfile
│       ├── start.sh
│       └── nginx.conf
│
├── vendor/
│   └── ohamlab/
│       ├── plugins/
│       ├── skills/
│       └── gateway/
│
├── docs/
│   ├── architecture.md
│   └── development.md
│
├── tests/
│
├── AGENTS.md
└── README.md
```

---

## Development

Start with the project documentation:

- [Development guide](docs/development.md)
- [Architecture documentation](docs/architecture.md)
- [Agent instructions](AGENTS.md)

### Set up a development environment

Clone the repository:

```bash
git clone https://github.com/innokria/ohamlab-deepseek-harness.git

cd ohamlab-deepseek-harness
```

Install the Python package in editable mode:

```bash
python -m pip install -e packages/python
```

Install development tools:

```bash
python -m pip install pytest build twine
```

Run tests:

```bash
python -m pytest tests -q
```

Build the Python distribution:

```bash
python -m build packages/python
```

Validate the distribution:

```bash
python -m twine check packages/python/dist/*
```

Test the CLI:

```bash
ohamlab-harness --version
ohamlab-harness status
```

For a full installation test, use a clean environment with Node.js, pnpm and Git available.

---

## PyPI packaging and publishing

The Python package is located at:

```text
packages/python/
```

Package metadata and versioning are defined in:

```text
packages/python/pyproject.toml
```

Build distributions:

```bash
python -m build packages/python
```

Validate:

```bash
python -m twine check packages/python/dist/*
```

The repository release workflow is:

```text
.github/workflows/release.yml
```

The PyPI publishing workflow uses GitHub Actions and should be configured with PyPI Trusted Publishing.

Before publishing a release:

- Run Python tests.
- Validate the wheel and source distribution.
- Test installation on a clean machine.
- Verify Harness installation and browser startup.
- Verify Agent and Search integration.
- Verify branding plugin activation.
- Test Docker deployment and container restarts.
- Confirm upstream redistribution and licensing permissions.

Do not treat passing Python unit tests alone as proof of a working deployment.

---

## Security

OhamLab Harness is designed for local-first deployment.

For local installations, keep the service bound to `127.0.0.1` unless remote access is intentionally configured.

For hosted deployments:

- Use an appropriate authentication and access-control layer.
- Avoid exposing internal service ports directly.
- Keep persistent data directories protected.
- Do not commit API keys, credentials or private deployment configuration.
- Review plugin permissions before enabling third-party integrations.

---

## Roadmap

The project is intended to evolve into a more complete local-first AI development environment.

Potential future areas include:

- Improved offline and local LLM integration.
- More complete MCP integration and tool discovery.
- Agent-assisted software development workflows.
- Automated development and testing workflows.
- CI/CD integration.
- Agent-based system monitoring.
- Enterprise deployment and management.

These are roadmap directions, not claims that every capability is currently implemented.

---

## License

See the repository license file for applicable licensing terms.

OhamLab integrations and upstream Harness components may have their own licensing and redistribution requirements. Review the relevant upstream licenses before redistributing bundled components.

---

**Repository:** [innokria/ohamlab-deepseek-harness](https://github.com/innokria/ohamlab-deepseek-harness)

**Python package:** [ohamlab-harness on PyPI](https://pypi.org/project/ohamlab-harness/)

**OhamLab:** [ohamlab.com](https://ohamlab.com)

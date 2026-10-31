# OhamLab — Architecture and Design

**Repository:** `innokria/ohamlab-deepseek-harness`  
**Product:** OhamLab  
**Distribution:** PyPI (`ohamlab`)  
**Status:** Architecture proposal  
**Primary goal:** Turn the existing DeepSeek Harness into a complete, installable OhamLab platform.

---

## 1. Vision

OhamLab is a complete AI workspace built around DeepSeek Harness.

A user should be able to install OhamLab locally or deploy it to Hugging Face Spaces without manually cloning, configuring and connecting multiple projects.

The intended installation experience is:

- Install `ohamlab` from PyPI.
- Run the OhamLab setup process.
- OhamLab provisions the required components.
- Start the application.
- Access the complete OhamLab experience.

The platform consists of three independently maintained application components and OhamLab's own custom extensions.

## 2. Core components

### 2.1 DeepSeek Harness

DeepSeek Harness is the primary application and user interface.

Responsibilities:

- Main AI chat interface.
- Model and provider configuration.
- Session and conversation management.
- Profiles and plugin management.
- Skills and tool integration.
- User-facing application experience.

The existing DeepSeek Harness source remains the foundation of this repository.

OhamLab-specific changes must be isolated from the upstream Harness implementation wherever possible.

### 2.2 Search MCP

Install the existing PyPI package:

`pip install ohamlab-agent`

Responsibilities:

- Web search.
- Web page fetching.
- Search and fetch workflows.
- Document storage.
- Document retrieval.
- MCP server functionality.

Do not copy or duplicate its implementation into this repository.

### 2.3 Agent Lab

Install the existing PyPI package:

`pip install ohamlab-agent-lab==7.0.0`

Responsibilities:

- Create agents.
- Clone agent profiles.
- Configure agent roles and system prompts.
- Assign individual tasks.
- Execute multi-agent and swarm workflows.
- Generate task reports and summaries.
- Expose its supported UI, API and MCP functionality.

Do not copy or duplicate its implementation into this repository.

### 2.4 OhamLab custom extensions

OhamLab owns its branding and custom assets.

These live under:

`vendor/ohamlab/`

They include:

- Harness branding.
- Custom plugins.
- Skills.
- Custom tools.
- Profile templates.
- MCP connection configuration.
- Default application settings.
- OhamLab-specific UI customisations.

These assets are maintained in GitHub and deployed or registered using the supported DeepSeek Harness extension mechanisms.

## 3. Architecture principles

1. **One installation experience:** Users install and manage the platform through OhamLab.
2. **No duplicated component source:** Agent Lab and Search MCP are installed from their existing PyPI distributions.
3. **Upstream separation:** Preserve the DeepSeek Harness base and isolate OhamLab customisations.
4. **Pinned dependencies:** Use known-compatible versions of every component.
5. **Local-first:** A local installation must work without Hugging Face.
6. **Hugging Face support:** Support container deployment with persistent bucket storage.
7. **Persistent user data:** Application upgrades must not overwrite user sessions, profiles, documents or agent data.
8. **Reproducible deployment:** A clean environment and an empty bucket must be sufficient to initialise a deployment.
9. **Independent component lifecycle:** Agent Lab and Search MCP can be upgraded independently through controlled OhamLab releases.
10. **No secrets in Git:** API keys, credentials and private configuration belong in environment variables or secure runtime configuration.

## 4. OhamLab Python distribution

The future PyPI distribution is named:

`ohamlab`

It provides the installer, CLI, environment detection, dependency management, configuration management and lifecycle operations.

The Python package does not replace DeepSeek Harness or reimplement Agent Lab and Search MCP.

It manages their installation and integration.

### Expected CLI experience

The following commands are proposed, not implemented:

| Command | Responsibility |
|---|---|
| `ohamlab init` | Initialise an OhamLab workspace |
| `ohamlab setup` | Provision all required components |
| `ohamlab install` | Install or repair application components |
| `ohamlab start` | Start the complete platform |
| `ohamlab stop` | Stop managed services |
| `ohamlab status` | Show component and service status |
| `ohamlab doctor` | Diagnose missing dependencies and configuration |
| `ohamlab update` | Apply a compatible application update |
| `ohamlab backup` | Back up persistent application data |

The exact command names and behaviour will be finalised during implementation.

### Runtime provisioning

OhamLab must manage:

- Python dependencies.
- Node.js runtime.
- pnpm.
- Pinned DeepSeek Harness source/runtime.
- Agent Lab installation.
- Search MCP installation.
- Component configuration.
- Service startup and shutdown.

A Python package installation alone does not automatically start the complete application. The setup and start lifecycle must handle that.

## 5. Deployment targets

### Local deployment

The local installation must:

- Detect the operating system.
- Check required system dependencies.
- Install or provision the required Node.js runtime and pnpm.
- Install the pinned Harness runtime.
- Install both PyPI components.
- Deploy OhamLab branding, plugins and skills.
- Initialise local persistent storage.
- Configure and start required services.

Local persistent data should be kept outside the Git checkout and installed application source.

### Hugging Face deployment

The Hugging Face deployment must:

- Build from the GitHub repository.
- Use the existing Docker deployment contract.
- Install the pinned Harness runtime and PyPI components.
- Mount the user's persistent HF bucket.
- Initialise missing directories on first launch.
- Reuse existing user data on restarts.
- Start the required application services.
- Expose the application on the configured public port.

Preserve the existing Hugging Face entry-point files at the repository root if required by the current Space configuration.

### Deployment independence

The same OhamLab application and component definitions must be used in both environments.

Only deployment-specific settings should differ.

## 6. Persistent storage

Application source code and persistent user data must remain separate.

The storage layer must support:

- Local filesystem storage.
- Hugging Face persistent bucket storage.
- Existing DeepSeek Harness data.
- Sessions and conversations.
- Profiles.
- Logs.
- Skills and runtime-managed assets.
- Agent Lab data.
- Search MCP documents.
- Backups.

The existing HF bucket structure should be preserved during the initial integration.

Do not delete, rename or migrate existing data automatically.

A migration must first create a backup and validate the destination.

### First-run behaviour

If the storage directory is empty:

- Create required directories.
- Initialise default settings.
- Install default OhamLab extensions.
- Initialise the Harness profile.
- Configure component connections.

### Restart behaviour

If persistent data already exists:

- Reuse existing settings.
- Preserve sessions and user profiles.
- Preserve documents and agent data.
- Avoid overwriting user modifications.
- Only apply safe, versioned migrations.

## 7. Version management

Maintain a central component manifest.

It must define:

- DeepSeek Harness version or immutable Git revision.
- Node.js version.
- pnpm version.
- `ohamlab-agent` version.
- `ohamlab-agent-lab` version.
- Required plugin versions.
- Compatibility requirements.

Agent Lab initially uses version `7.0.0`.

Search MCP and Harness must also be pinned to validated versions.

A release must be reproducible from its manifest.

## 8. Security

- Never commit secrets or API credentials.
- Keep runtime credentials outside source-controlled configuration.
- Restrict plugin installation to trusted sources.
- Pin external plugin revisions where possible.
- Validate configuration before starting services.
- Do not expose internal service ports unnecessarily.
- Provide safe backup and recovery mechanisms.

## 9. Upgrade strategy

Application code and persistent data must have independent lifecycles.

An upgrade must:

1. Identify the current component versions.
2. Back up important persistent data where required.
3. Validate component compatibility.
4. Update the application and extensions.
5. Apply versioned configuration migrations.
6. Verify service health.
7. Retain a recovery path if the update fails.

Never replace the persistent user-data directory as part of an ordinary application update.

## 10. Development phases

### Phase 1 — Repository foundation

- Preserve the existing DeepSeek Harness base.
- Add the OhamLab Python package structure.
- Add `vendor/ohamlab/`.
- Define the component manifest.
- Add the architecture and installation documentation.

### Phase 2 — Component installation

- Install Agent Lab from PyPI.
- Install Search MCP from PyPI.
- Provision the pinned Harness runtime.
- Validate component versions and compatibility.

### Phase 3 — OhamLab integration

- Deploy branding.
- Register custom skills.
- Register custom plugins and tools.
- Configure Search MCP.
- Configure Agent Lab.
- Validate the complete application workflow.

### Phase 4 — Local installation

- Implement workspace initialisation.
- Implement setup and start commands.
- Implement health checks and diagnostics.
- Validate clean local installations.

### Phase 5 — Hugging Face deployment

- Integrate with the existing Docker deployment.
- Support persistent bucket mounting.
- Implement first-run initialisation.
- Validate restart and upgrade behaviour.

### Phase 6 — PyPI release

- Build and publish the `ohamlab` distribution.
- Validate installation in a clean environment.
- Document supported operating systems and deployment requirements.
- Provide a complete installation and troubleshooting guide.

## 11. Acceptance criteria

The project is ready for its first complete release when:

- [ ] `pip install ohamlab` installs the OhamLab Python distribution.
- [ ] OhamLab can provision the pinned DeepSeek Harness runtime.
- [ ] Agent Lab is installed from its existing PyPI package.
- [ ] Search MCP is installed from its existing PyPI package.
- [ ] OhamLab branding and extensions are deployed automatically.
- [ ] The complete application works locally.
- [ ] The complete application works on Hugging Face Spaces.
- [ ] An empty persistent bucket can initialise successfully.
- [ ] Existing bucket data survives restarts.
- [ ] Application updates preserve user data.
- [ ] Component versions are reproducible.
- [ ] No Agent Lab or Search MCP source code is copied into this repository.

---

**Product definition**

OhamLab is a complete, installable AI workspace that combines DeepSeek Harness, Agent Lab, Search MCP and OhamLab's own branding and extensions under one installation and management experience.




## My proposed release roadmap
Release	Deliverable
OhamLab 0.1	Unified Harness + Agent Lab + Search
OhamLab 0.2	Shared LLM routing and stable API
OhamLab Browser Agent 0.1	Chrome sidebar with webpage understanding
OhamLab 0.3	Embedding memory and RAG
OhamLab Browser Agent 0.2	Controlled browser automation

These are suggested versions, not existing releases.
5. One issue to resolve now: CLI naming
Your architecture proposes publishing a new PyPI distribution called ohamlab, with commands such as ohamlab init, ohamlab setup, and ohamlab start. Pasted text.txt


But your existing ohamlab-agent package already installs an executable named ohamlab.

That's a potential conflict.

I would avoid having two packages install the same console command. Instead, the unified Harness should own the ohamlab CLI, while the Search package exposes its functions through imports or MCP. This requires a coordinated migration of the existing Search CLI, rather than simply adding another console-script entry point.

Also check whether the proposed ohamlab PyPI distribution name is available before committing to that name.
6. What I would do next
Don't build the Chrome extension today. First make sure the Unified Harness can perform this end-to-end task:
"Read this webpage, search for additional information, and explain the findings using my selected free LLM provider."

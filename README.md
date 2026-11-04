# DeepSeek Harness

English | [中文](README.zh.md)

DeepSeek Harness (`dsh`) is an open-source agent harness developed by [DeepSeek AI](https://deepseek.com).

## CLI PYPY
```
pip install ohamlab-harness==0.1.0b1
```

It uses an architecture where **everything is a plugin**, and is powered by [Cordis](https://github.com/cordiverse/cordis), whose design is described in [_A Programming Paradigm for Spatiotemporal Composability_](https://github.com/cordiverse/paper).

## use Docker and entrypoint.sh file to load
## CUSTOM LLM AGENT  

```
WITH LLAMA CPP and Custom GGUF .  RUNNING ON 2 CORE 16GB CPU 
```

```
DeepSeek Harness + llama.cpp
==========================================================
[DSH] Home:              /data
[DSH] Public port:      7860
[DSH] Internal port:    3080

[LLAMA] Server:         /app/llama-server
[LLAMA] Host:           127.0.0.1
[LLAMA] Port:           8000
[LLAMA] Model:          LFM2.5
[LLAMA] Model path:     /app/LFM2.5-VL-3B-Q4_0.gguf
[LLAMA] MMProj path:    /app/mmproj-LFM2.5-VL-3B-BF16.gguf
[LLAMA] Context:        22288
[LLAMA] Max tokens:     512
[LLAMA] Threads:        2
```

## UI With Ox Alpha
<img width="1408" height="658" alt="image" src="https://github.com/user-attachments/assets/7460b85f-da82-4703-8005-ea2b609a80cc" />



<img width="2349" height="1410" alt="image" src="https://github.com/user-attachments/assets/4f699c11-33cb-4ab0-9548-3b2db811463d" />



```
<img width="2349" height="1410" alt="image" src="https://github.com/user-attachments/assets/0ee7e6ba-751d-4c09-899c-b8b777b6b90f" />

````


## Developer preview

DeepSeek Harness is currently in _developer preview_ and is iterating rapidly. **THERE WILL BE COMPATIBILITY-BREAKING CHANGES.**

## Run

### Run from `npm`

Install `Node.js`, then run:

```sh
npx @deepseek-ai/dsh web
```

The command starts the Web UI at `http://127.0.0.1:3080` by default and opens it in the default browser for a local launch. An SSH launch only prints the host URL because the SSH client or editor owns the local forwarded address. Pass `--no-open` to run the server without opening a browser. See [Web UI guide](docs/user/guide/index.md).

### Run from source

To run from a repository checkout:

```sh
git clone https://github.com/deepseek-ai/deepseek-harness.git
cd deepseek-harness
pnpm install
pnpm run build
pnpm dsh web
```

`pnpm run build` prepares the repository artifacts. `pnpm dsh web` uses those built artifacts without rebuilding.

## Community and support

- Feel free to submit feedback or bug reports through [GitHub Discussions](https://github.com/deepseek-ai/deepseek-harness/discussions).
- Add the [`dsh-plugin`](https://github.com/topics/dsh-plugin) topic to your plugin repository for discoverability.
- Join <a href="https://discord.gg/Ycq5dCaS4">DeepSeek Harness Discord community</a>.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Development

Start with the [development guide](docs/development.md) and [architecture documentation](docs/architecture.md).

For agents, follow [AGENTS.md](AGENTS.md).


# OhamLab Harness — PyPI release candidate

**Local-first CLI and browser UI launcher.** The existing `vendor/ohamlab` source is deliberately **not included** in this archive. Merge this repository overlay into your existing GitHub repo. No personal Hugging Face files are included.

## Requirements

- Python 3.10+
- Git
- Node.js 22+
- pnpm (for example `corepack enable` then `corepack prepare pnpm@11.7.0 --activate`)
- Internet access for first installation

## Test locally before publishing

```bash
python -m pip install -e packages/python
python -m pip install pytest build twine
python -m pytest tests -q
python -m build packages/python
python -m twine check packages/python/dist/*
ohamlab-harness --version
ohamlab-harness install
ohamlab-harness doctor
ohamlab-harness start --open-browser
```

By default, `install` clones the **1.0** branch for the upstream Harness application and **main** for your vendor integration. This matches the prior Docker layout but is NOT a reproducible production release. For a pinned build, use `--harness-ref <sha> --vendor-ref <sha>`. To install from your current local vendor directory instead, use `--vendor-path /path/to/vendor/ohamlab`.

## Startup and MCP integration

The launcher defaults to `pnpm dsh web` in the installed Harness directory. This command has not been confirmed against your exact Harness release. If needed, pass `--start-command 'YOUR VERIFIED COMMAND'`. Skills are copied to the data directory and Python gateway dependencies installed into a dedicated virtual environment.

**Critical:** The current launcher does not automatically register the MCP gateway with Cordis. It does not yet provide remote-to-local MCP failover or guarantee LLM-powered Agent Lab execution. Your existing working Harness registration/setup must be ported and tested before advertising one-command fully integrated MCP support.

## Packaging and publishing

Builds are produced by `.github/workflows/release.yml`. The PyPI workflow is **manual** (`workflow_dispatch`) and requires configuring PyPI Trusted Publishing for this GitHub repository and `pypi` environment. The version is `0.1.0b1`. Before publishing, verify the package name, license, upstream redistribution permissions, Node startup, and end-to-end tools on a clean machine. Do not publish solely on the basis of Python unit tests.

## Browser support

`ohamlab-harness start` serves a local browser UI. Public hosted browser service and extension are separate later phases. Do not bind the service to a public address without access controls.


## License

[MIT](LICENSE)

Third-party dependencies and their licenses are disclosed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

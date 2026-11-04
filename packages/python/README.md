# OhamLab Harness CLI (beta)

This Python package bootstraps the Node-based Harness and the OhamLab vendor integration from GitHub. Node.js 22, Git and pnpm are required. Install and run:

```sh
pip install -e packages/python
# from any directory
ohamlab-harness doctor
ohamlab-harness install
ohamlab-harness start
```

By default `install` clones the Harness `1.0` branch and overlays `vendor/ohamlab` from `main` of the same repository. Override the refs with `--harness-ref` and `--vendor-ref`; pin immutable commit SHAs for reproducible production installs. For a local vendor checkout, pass `--vendor-path /path/to/vendor/ohamlab`. The installer creates a separate Python virtual environment for gateway dependencies and uses a persistent data directory.

The default Harness startup command is `pnpm dsh web`; confirm this against the selected Harness release. Override with `--start-command 'pnpm ...'` if needed. The launcher does not assert MCP registration automatically; use `doctor` and test actual tool calls in Harness.

`start` serves the upstream web UI locally; it is not a cloud-hosted service or browser extension. Use `--open-browser` to open the local URL. Do not expose the UI to the public Internet without authentication and TLS.

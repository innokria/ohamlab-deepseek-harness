# ohamlab-harness

*[English](README.md) | [简体中文](README.zh.md)*

A DeepSeek Harness (DSH) plugin that lets users **search for and install other plugins directly from the web GUI** — no need to drop to a command line.

It adds a **"Plugin market"** tab under **Settings → Plugins**:

- 🔍 Search GitHub repositories tagged [`dsh-plugin`](https://github.com/topics/dsh-plugin) (sorted by stars)
- 📋 Show each plugin's name, description, and star count, with a link to its GitHub repo
- ⚡ One-click install (internally runs `dsh plugin --profile web add github:owner/repo`)
- 🗑️ One-click uninstall of installed third-party plugins
- 📦 List the plugins currently installed in the profile (`dsh.profile.bundles`)

## Install

Install it like any other DSH bundle:

```sh
# Install into your web profile straight from GitHub
dsh plugin --profile web add github:innokria/ohamlab-deepseek-harness

# Restart the web GUI to activate it
dsh web
```

Or from a local checkout:

```sh
dsh plugin --profile web add ./dsh-plugin-market
```

> **Note:** this plugin is plain JavaScript with **no `prepare` build script**, so a
> `github:` install needs no `allowedBuilds` entry — it works out of the box.

## Directory layout

```
dsh-plugin-market/
├── package.json        # dsh.bundle (patch layer) + dsh.client (browser half) declaration
├── cordis.patch.yml    # inserts the loader row into the composition
├── index.js            # Host half: registers the /api/plugin-market HTTP bridge + search/install/uninstall
└── client.js           # Client half: Settings "Plugin market" tab UI
```

## How it works

- **Host half** (`index.js`): injects the `webServer` service and registers a same-origin
  prefix route `/api/plugin-market`:
  - `GET  /api/plugin-market/search?q=<keyword>` — calls the GitHub Search API (`topic:dsh-plugin`)
  - `POST /api/plugin-market/install` (body `{ "spec": "github:owner/repo" }`) — runs `dsh plugin add`
  - `GET  /api/plugin-market/list` — reads the profile's `dsh.profile.bundles`
  - `POST /api/plugin-market/remove` (body `{ "name": "…" }`) — runs `dsh plugin remove`
- **Client half** (`client.js`): registers the "Plugin market" page into the `settings.plugins.tab`
  slot and calls the HTTP bridge over same-origin `fetch`, rendering the search box, result list,
  install/uninstall buttons, and the installed list.

Because the bridge lives on the port the web GUI itself listens on (same origin), there is no
cross-origin issue and no change to the framework's own Remote descriptors.

## Publishing your own fork

Push this repo to your own GitHub and tag it with [`dsh-plugin`](https://github.com/topics/dsh-plugin)
so other users' plugin markets can find it. You can also publish to npm:

```sh
npm publish --access public
```

## Security note

Installing a third-party plugin runs its author's code on your machine (a `prepare` script may run
at install time, and the bundle is loaded at runtime). Only install plugins from sources you trust,
and pin to a commit (`github:owner/repo#<sha>`) when you want to prevent upstream changes from
silently altering behavior.

## License

MIT

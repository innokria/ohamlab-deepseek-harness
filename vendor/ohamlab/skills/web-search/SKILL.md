---
name: web-search
description: Search the live web through the OhamLab gateway, with local PyPI fallback when remote MCP is down.
---
# OhamLab Web Search
Use the registered `web_search` MCP tool for fresh facts, URLs and citations.
The gateway tries the configured remote Search MCP and automatically falls back to
`ohamlab search` installed from `ohamlab-agent==0.1.2`.
Do not run shell commands yourself, invent results, or assume a result is current without checking it.
If the gateway reports no results, say so. If both backends fail, report the error.

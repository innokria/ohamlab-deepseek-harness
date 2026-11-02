#!/usr/bin/env python3
"""OhamLab Search local subprocess adapter + optional standalone MCP stdio server.

Use invoke_search() from a unified gateway, or run this file as a standalone
MCP server. The CLI's actual stdout format is preserved if not JSON.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
from typing import Any

DEFAULT_TIMEOUT = int(os.getenv('OHAM_SEARCH_TIMEOUT', '90'))


def invoke_search(query: str, max_results: int = 5, timeout: int = DEFAULT_TIMEOUT) -> dict[str, Any]:
    if not isinstance(query, str) or not query.strip() or len(query) > 500:
        raise ValueError('query must contain 1–500 characters')
    if isinstance(max_results, bool) or not isinstance(max_results, int) or not 1 <= max_results <= 10:
        raise ValueError('max_results must be an integer between 1 and 10')
    executable = os.getenv('OHAM_SEARCH_BIN') or shutil.which('ohamlab')
    if not executable:
        raise RuntimeError('OhamLab Search CLI missing; install ohamlab-agent==0.1.2')
    env = os.environ.copy()
    for key in ('DSH_SESSION_JSONL', 'DSH_PERMISSION_MODE', 'DSH_TELEMETRY_MODE'):
        env.pop(key, None)
    try:
        proc = subprocess.run(
            [executable, 'search', query.strip(), '--max-results', str(max_results)],
            capture_output=True, text=True, timeout=timeout, check=False, env=env,
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f'OhamLab Search timed out after {timeout}s') from exc
    if proc.returncode:
        detail = proc.stderr.strip() or proc.stdout.strip()
        raise RuntimeError(f'OhamLab Search exited {proc.returncode}: {detail[-600:]}')
    output = proc.stdout.strip()
    if 'DDGSException' in output:
        raise RuntimeError(f'Search provider error: {output[-600:]}')
    if not output or 'No results found' in output:
        return {'query': query, 'results': [], 'backend': 'local-cli'}
    try:
        parsed = json.loads(output)
    except json.JSONDecodeError:
        return {'query': query, 'results_text': output, 'backend': 'local-cli'}
    if isinstance(parsed, list):
        results = parsed
    elif isinstance(parsed, dict):
        if parsed.get('error'):
            raise RuntimeError(str(parsed['error']))
        results = parsed.get('results')
    else:
        results = None
    if isinstance(results, list):
        normalized = [
            {'title': str(x.get('title', '')), 'url': str(x.get('url', '')),
             'snippet': str(x.get('snippet', x.get('description', '')))}
            for x in results if isinstance(x, dict) and x.get('url')
        ]
        return {'query': query, 'results': normalized, 'backend': 'local-cli'}
    return {'query': query, 'results_text': output, 'backend': 'local-cli'}


def main() -> None:
    try:
        from mcp.server.fastmcp import FastMCP
    except ImportError as exc:
        raise SystemExit('Install MCP SDK: pip install "mcp>=1.9,<2"') from exc
    server = FastMCP('ohamlab-search-local')

    @server.tool(name='web_search')
    def web_search(query: str, max_results: int = 5) -> dict[str, Any]:
        """Search the public web via the installed OhamLab CLI."""
        return invoke_search(query, max_results)

    server.run(transport='stdio')


if __name__ == '__main__':
    main()

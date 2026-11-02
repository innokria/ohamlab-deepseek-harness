#!/usr/bin/env python3
"""OhamLab Agent Lab local CLI adapter + standalone MCP stdio server.

Uses the CLI grammar in the supplied Agent Lab source archive. Verify the
installed v7.0.0 CLI matches: `ohamlab-agent --help` or `python -m
 oh amlab_agent_lab.cli --help` (without the space). No HTTP service required.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Any

DATA_DIR = Path(os.getenv('OHAM_AGENT_DATA_DIR', str(Path.home() / '.ohamlab' / 'agents')))
CONFIG = os.getenv('OHAM_AGENT_LAB_CONFIG', '')


def _base_command() -> list[str]:
    explicit = os.getenv('OHAM_AGENT_LAB_BIN')
    if explicit:
        return [explicit]
    # The source CLI defines prog='ohamlab-agent'; a console entrypoint may
    # vary between published versions. Fall back to its Python module.
    binary = shutil.which('ohamlab-agent')
    if binary:
        return [binary]
    return [sys.executable, '-m', 'ohamlab_agent_lab.cli']


def lab_command(*args: str, timeout: int = 120) -> Any:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    argv = _base_command() + ['--data-dir', str(DATA_DIR)]
    if CONFIG:
        argv += ['--config', CONFIG]
    argv += list(args)
    try:
        proc = subprocess.run(argv, capture_output=True, text=True,
                              timeout=timeout, check=False)
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f'Agent Lab command timed out after {timeout}s') from exc
    if proc.returncode:
        detail = proc.stderr.strip() or proc.stdout.strip()
        raise RuntimeError(f'Agent Lab exited {proc.returncode}: {detail[-1000:]}')
    output = proc.stdout.strip()
    if not output:
        raise RuntimeError('Agent Lab returned empty output')
    try:
        return json.loads(output)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f'Agent Lab returned non-JSON output: {output[-600:]}') from exc


def list_agents() -> Any:
    return lab_command('list-agents')


def create_agent(name: str, role: str = 'research assistant',
                 system_prompt: str | None = None) -> Any:
    if not name.strip() or len(name) > 100:
        raise ValueError('name must contain 1–100 characters')
    args = ['create-agent', name.strip(), '--role', role]
    if system_prompt:
        args += ['--system-prompt', system_prompt]
    return lab_command(*args)


def run_agent(agent_id: str, task: str, timeout: int = 600) -> Any:
    if not agent_id.strip() or not task.strip():
        raise ValueError('agent_id and task are required')
    # Synchronous CLI operation: saves a report and returns its result.
    return lab_command('run-agent', agent_id, task, timeout=timeout)


def main() -> None:
    try:
        from mcp.server.fastmcp import FastMCP
    except ImportError as exc:
        raise SystemExit('Install MCP SDK: pip install "mcp>=1.9,<2"') from exc
    server = FastMCP('ohamlab-agent-lab-local')

    @server.tool(name='list_agents')
    def mcp_list_agents() -> Any:
        """List agents stored in the local OhamLab Agent Lab data directory."""
        return list_agents()

    @server.tool(name='create_agent')
    def mcp_create_agent(name: str, role: str = 'research assistant',
                         system_prompt: str | None = None) -> Any:
        """Create a persistent local agent."""
        return create_agent(name, role, system_prompt)

    @server.tool(name='run_agent')
    def mcp_run_agent(agent_id: str, task: str) -> Any:
        """Run a local agent synchronously and return its saved report details."""
        return run_agent(agent_id, task)

    server.run(transport='stdio')


if __name__ == '__main__':
    main()

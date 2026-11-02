"""OhamLab unified MCP stdio gateway.

Remote MCP for read-only discovery/search; verified local CLI for Agent Lab
mutations and persistent agent storage. No remote retries for mutating calls.
"""
from __future__ import annotations
import asyncio
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import uuid
from pathlib import Path

from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client
from mcp.server.fastmcp import FastMCP

mcp = FastMCP('ohamlab-unified')
SEARCH_MCP = os.getenv('OHAM_SEARCH_MCP_URL', 'https://rahul7star-ohamlab-plugin.hf.space/mcp/')
AGENT_MCP = os.getenv('OHAM_AGENT_MCP_URL', 'https://rahul7star-ohamlab-agentic.hf.space/mcp/')
LOCAL_ONLY = os.getenv('OHAM_LOCAL_ONLY', '0') == '1'
REMOTE_TIMEOUT = float(os.getenv('OHAM_REMOTE_TIMEOUT', '8'))
COOLDOWN = float(os.getenv('OHAM_REMOTE_COOLDOWN', '60'))
DATA_DIR = Path(os.getenv('OHAM_AGENT_DATA_DIR', str(Path.home() / '.ohamlab' / 'agents'))).expanduser().resolve()
TASK_DIR = DATA_DIR / 'gateway-tasks'
LAB_CONFIG = os.getenv('OHAM_AGENT_LAB_CONFIG', '')
fail_until = {'search': 0.0, 'agent': 0.0}
lock = threading.RLock()


def _log(msg):
    print(f'[OHAMLAB] {msg}', file=sys.stderr, flush=True)


async def _remote_call(url, tool, args):
    async with streamablehttp_client(url) as (read, write, _):
        async with ClientSession(read, write) as session:
            await session.initialize()
            names = {t.name for t in (await session.list_tools()).tools}
            if tool not in names:
                raise LookupError(f'{tool} not in remote MCP tools: {sorted(names)}')
            result = await session.call_tool(tool, args)
            if result.isError:
                raise RuntimeError(f'Remote tool returned an execution error: {result.content}')
            return {'backend': 'remote', 'tool': tool, 'content': [c.model_dump(mode='json') for c in result.content]}


def _remote(kind, url, tool, args):
    if LOCAL_ONLY or time.monotonic() < fail_until[kind]:
        return None
    try:
        return asyncio.run(asyncio.wait_for(_remote_call(url, tool, args), REMOTE_TIMEOUT))
    except RuntimeError:
        # An actual remote tool execution error is not an availability failure.
        raise
    except Exception as exc:
        _log(f'{kind} remote unavailable: {type(exc).__name__}: {exc}')
        fail_until[kind] = time.monotonic() + COOLDOWN
        return None


def _cli(binary, args, timeout=120):
    exe = shutil.which(binary)
    if not exe:
        raise RuntimeError(f'{binary} not found. Install the corresponding OhamLab PyPI package.')
    try:
        p = subprocess.run([exe, *args], capture_output=True, text=True, timeout=timeout, check=False)
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f'{binary} timed out after {timeout}s; operation outcome may be uncertain') from exc
    if p.returncode:
        raise RuntimeError(f'{binary} exited {p.returncode}: {(p.stderr.strip() or p.stdout.strip())[-1200:]}')
    out = p.stdout.strip()
    if not out:
        raise RuntimeError(f'{binary} returned empty output')
    return out


def _lab_args(*args):
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    argv = ['--data-dir', str(DATA_DIR)]
    if LAB_CONFIG:
        argv += ['--config', LAB_CONFIG]
    return argv + list(args)


def _lab_json(*args, timeout=120):
    out = _cli('ohamlab-lab', _lab_args(*args), timeout)
    try:
        return json.loads(out)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f'Agent Lab did not return JSON: {out[-600:]}') from exc


def _task_path(task_id):
    if not re.fullmatch(r'[a-f0-9]{32}', task_id):
        raise ValueError('Invalid task ID')
    return TASK_DIR / f'{task_id}.json'


def _write_task(task_id, value):
    TASK_DIR.mkdir(parents=True, exist_ok=True)
    target = _task_path(task_id)
    temp = target.with_suffix('.tmp')
    with lock:
        temp.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')
        temp.replace(target)


def _read_task(task_id):
    path = _task_path(task_id)
    if not path.exists():
        raise ValueError('Task not found')
    return json.loads(path.read_text(encoding='utf-8'))


def _run_task(task_id, agent_id, prompt):
    try:
        result = _lab_json('run-agent', agent_id, prompt, timeout=int(os.getenv('OHAM_AGENT_RUN_TIMEOUT', '600')))
        status = result.get('status', 'completed') if isinstance(result, dict) else 'completed'
        _write_task(task_id, {'task_id': task_id, 'agent_id': agent_id, 'status': status, 'result': result})
    except Exception as exc:
        _write_task(task_id, {'task_id': task_id, 'agent_id': agent_id, 'status': 'failed', 'error': str(exc)})


@mcp.tool()
def web_search(query: str, max_results: int = 5) -> dict:
    """Search remote MCP, automatically fall back to installed `ohamlab search`."""
    query = query.strip()
    if not 1 <= len(query) <= 500 or not 1 <= max_results <= 10:
        raise ValueError('Query length must be 1-500 and max_results 1-10')
    result = _remote('search', SEARCH_MCP, os.getenv('OHAM_REMOTE_SEARCH_TOOL', 'web_search'), {'query': query, 'max_results': max_results})
    if result is not None:
        return result
    out = _cli('ohamlab', ['search', query, '--max-results', str(max_results)], timeout=90)
    if 'DDGSException' in out:
        raise RuntimeError('Local search provider returned DDGSException')
    return {'backend': 'local', 'query': query, 'results_text': out, 'no_results': 'No results found' in out}


@mcp.tool()
def list_agents() -> dict:
    """List remote agents when available; otherwise list locally persisted agents."""
    result = _remote('agent', AGENT_MCP, 'list_agents', {})
    if result is not None:
        return result
    return {'backend': 'local', 'agents': _lab_json('list-agents')}


@mcp.tool()
def create_research_agent(name: str = 'Research Agent', role: str = 'research assistant') -> dict:
    """Create an agent locally using verified `ohamlab-lab create-agent`."""
    if not re.fullmatch(r'[\w .-]{1,80}', name) or not 1 <= len(role) <= 160:
        raise ValueError('Invalid agent name or role')
    agent = _lab_json('create-agent', name, '--role', role)
    return {'backend': 'local', 'agent': agent, 'agent_id': agent.get('id')}


@mcp.tool()
def assign_research_task(agent_id: str, research: str) -> dict:
    """Start a local Agent Lab run in a background worker; return a persistent task ID."""
    if not agent_id.strip() or not 1 <= len(research) <= 20000:
        raise ValueError('Invalid agent_id or research text')
    task_id = uuid.uuid4().hex
    _write_task(task_id, {'task_id': task_id, 'agent_id': agent_id, 'status': 'running'})
    threading.Thread(target=_run_task, args=(task_id, agent_id, research), daemon=True).start()
    return {'backend': 'local', 'task_id': task_id, 'status': 'running'}


@mcp.tool()
def get_research_task(task_id: str) -> dict:
    """Read a task status and final result from local persistent task storage."""
    return {'backend': 'local', **_read_task(task_id)}


@mcp.tool()
def run_research(topic: str, agent_name: str = 'Research Agent') -> dict:
    """Search, create agent, and queue research. Poll get_research_task for result."""
    if not 1 <= len(topic.strip()) <= 500:
        raise ValueError('Invalid topic')
    evidence = web_search(topic)
    agent = create_research_agent(agent_name)
    task = assign_research_task(agent['agent_id'],
        f'Research the following topic: {topic}\nUse this web search evidence and cite its source URLs; do not invent sources:\n{json.dumps(evidence, ensure_ascii=False)[:15000]}')
    return {'status': 'running', 'agent_id': agent['agent_id'], 'task_id': task['task_id'], 'search': evidence, 'agent_backend': 'local'}


if __name__ == '__main__':
    mcp.run(transport='stdio')

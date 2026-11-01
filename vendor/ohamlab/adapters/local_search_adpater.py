
## 3. `/app/deepseek-harness/vendor/ohamlab/adapters/local_search_adapter.py`

**Local MCP adapter for OhamLab Search**

```python
#!/usr/bin/env python3
"""
Local MCP adapter for OhamLab Search.

This adapter replaces a remote/streams HTTP MCP server with a local subprocess
that invokes the installed `ohamlab` CLI:

    ohamlab search "<query>" --max-results <n>

It satisfies the DSH @deepseek-ai/dsh-mcp-client bridge so the model can
discover and call the search tool without requiring a remote MCP endpoint,
API key, or hosted service.

Key design goals:
- Never shell-interpret the query (use argument-array subprocess).
- Validate query length and result limits.
- Apply per-call timeout via subprocess.run(timeout=...).
- Capture exit code, stdout, and stderr.
- Distinguish genuine empty results from CLI failures.
- Expose only the search tool; no general-purpose command execution.
"""

import json
import os
import subprocess
import shutil
from typing import Any, Dict, List, Optional

from mcp.server.models import InitializationOptions
from mcp.types import (
    Tool,
    TextContent,
    ContentBlock,
)


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# The `ohamlab` binary path — resolved from the runtime PATH at module load.
OHAMLAB_BIN = shutil.which("ohamlab")
if OHAMLAB_BIN is None:
    raise RuntimeError(
        "ohamlab CLI not found on PATH. Install with: "
        "pip install ohamlab-agent"
    )

# Default max results if the caller does not specify.
DEFAULT_MAX_RESULTS = 5

# Maximum allowed max_results.
MAX_MAX_RESULTS = 10

# Default timeout in seconds for each search call.
DEFAULT_TIMEOUT = 60

# ---------------------------------------------------------------------------
# Helper: invoke the ohamlab CLI
# ---------------------------------------------------------------------------

def _invoke_ohamlab_search(query: str, max_results: int = DEFAULT_MAX_RESULTS) -> dict:
    """
    Invoke ``ohamlab search <query> --max-results <n>`` as a local subprocess.

    Returns a dict with either:
    - "results": list of {title, url, snippet} on success, or
    - "error": string description on failure.

    Raises no exceptions — all errors are captured in the return dict.
    """

    # Validate query
    if not query or not query.strip():
        return {"error": "search query must not be empty"}

    # Validate max_results
    max_results = int(max_results)
    if max_results < 1:
        max_results = 1
    if max_results > MAX_MAX_RESULTS:
        max_results = MAX_MAX_RESULTS

    # Build the command as an argument array (no shell interpolation)
    binary = OHAMLAB_BIN
    args = [binary, "search", query.strip(), "--max-results", str(max_results)]

    # Prepare environment — start clean, inherit only essential vars
    env = os.environ.copy()
    # Remove potentially problematic vars
    for key in ["DSH_SESSION_JSONL", "DSH_PERMISSION_MODE", "DSH_TELEMETRY_MODE"]:
        env.pop(key, None)

    try:
        # Use subprocess.run with timeout — no external `timeout` package needed
        proc = subprocess.run(
            args,
            capture_output=True,
            text=True,
            env=env,
            timeout=DEFAULT_TIMEOUT,
        )

        # Check exit code
        if proc.returncode != 0:
            # Genuine CLI failure — report stderr, not the query
            return {
                "error": f"ohamlab search failed (exit {proc.returncode}): {proc.stderr.strip() or 'unknown error'}"
            }

        # Parse stdout — the CLI outputs JSON
        try:
            result = json.loads(proc.stdout.strip())
        except json.JSONDecodeError as decode_err:
            return {
                "error": f"ohamlab search returned invalid JSON: {str(decode_err)}"
            }

        # Normalise the result: ensure we have a list of result dicts
        if isinstance(result, list):
            normalized = []
            for item in result:
                if isinstance(item, dict) and "title" in item and "url" in item:
                    normalized.append(
                        {
                            "title": item.get("title", ""),
                            "url": item.get("url", ""),
                            "snippet": item.get("snippet", item.get("description", "")),
                        }
                    )
            if normalized:
                return {"results": normalized}
            # List was produced but none matched the expected shape
            return {"results": []}
        elif isinstance(result, dict) and "results" in result:
            return {"results": result["results"]}
        elif isinstance(result, dict) and "error" in result:
            return {"error": result["error"]}
        else:
            # Unknown shape — treat as empty/unknown
            return {"error": f"ohamlab search returned unexpected shape: {str(result)[:200]}"}

    except subprocess.TimeoutExpired as timeout_err:
        return {
            "error": f"ohamlab search timed out after {DEFAULT_TIMEOUT}s"
        }
    except FileNotFoundError:
        return {"error": f"ohamlab binary not found at {OHAMLAB_BIN}"}
    except Exception as exc:
        return {"error": f"unexpected error during ohamlab search: {str(exc)[:200]}"}


# ---------------------------------------------------------------------------
# MCP tool: web_search
# ---------------------------------------------------------------------------

def build_web_search_tool() -> Tool:
    """
    Build the MCP ``Tool`` description for ``web_search``.

    The DSH MCP client bridge requires a ``Tool`` definition with:
    - `name`: the public tool name (set by the bridge, e.g. `mcp__ohamlab_search__web_search`)
    - `description`: human-readable description
    - `inputSchema`: JSON Schema for the tool parameters
    """

    from mcp.types import Tool as MCPTool

    return MCPTool(
        name="web_search",  # will be namespaced by the bridge as mcp__ohamlab_search__web_search
        description=(
            "Search the web for public information about the given query. "
            "Returns a list of results with title, URL, and snippet."
        ),
        inputSchema={
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "The search query string.",
                },
                "max_results": {
                    "type": "integer",
                    "description": (
                        "Maximum number of results to return (1–10, default 5)."
                    ),
                },
            },
            "required": ["query"],
            "additionalProperties": False,
        },
    )


# ---------------------------------------------------------------------------
# Execution: bridge the CLI call to the MCP result shape
# ---------------------------------------------------------------------------

def execute_web_search(args: Dict[str, Any]) -> List[TextContent]:
    """
    Execute the ``web_search`` tool by invoking the local ``ohamlab`` CLI.

    Args:
        args: A dict with keys ``query`` and optionally ``max_results``.

    Returns:
        A list of TextContent entries compatible with the MCP `execute`
        result format. On error, returns a single TextContent with an error
        message (the MCP bridge will mark the result as IsError).
    """

    from mcp.types import TextContent

    query = args.get("query", "").strip()
    max_results = args.get("max_results", DEFAULT_MAX_RESULTS)

    # Invoke the CLI adapter
    result = _invoke_ohamlab_search(query, max_results)

    # Check for errors
    if "error" in result:
        # Return as a text content block; the MCP bridge will mark isError
        return [
            TextContent(type="text", text=f"Search error: {result['error']}")
        ]

    # Successful results
    results = result.get("results", [])

    if not results:
        # Genuine empty result — return a text note, not an error
        return [
            TextContent(type="text", text="No search results found for the given query.")
        ]

    # Format results as text with title, URL, and snippet
    lines: List[str] = []
    for i, r in enumerate(results, start=1):
        title = r.get("title", "").strip()
        url = r.get("url", "").strip()
        snippet = r.get("snippet", "").strip()
        lines.append(f"{i}. {title}\n   URL: {url}\n   Snippet: {snippet}")

    text = "\n\n".join(lines)
    return [
        TextContent(type="text", text=text)
    ]


# ---------------------------------------------------------------------------
# MCP server setup
# ---------------------------------------------------------------------------

def main():
    """
    Entry point when this adapter is run as the MCP stdio server.

    The DSH harness starts this process (or an equivalent) and the
    @deepseek-ai/dsh-mcp-client plugin connects over stdio to discover
    tools and invoke them.
    """

    # Build the tool registry
    tools = [build_web_search_tool()]

    # Run the MCP server over stdio
    # NOTE: The mcp 2.x API uses MCPServer
    from mcp.server.mcpserver import MCPServer
    from mcp.server.stdio import stdio_server

    mcp_server = MCPServer(tools=tools)

    async def run():
        async with stdio_server() as (read, write):
            await mcp_server.run(
                read,
                write,
                InitializationOptions(
                    server_name="ohamlab-search-adapter",
                    server_version="0.1.0",
                    client_info={
                        "name": "ohamlab-search-adapter",
                        "version": "0.1.0",
                    },
                ),
            )

    import asyncio
    asyncio.run(run())


if __name__ == "__main__":
    main()

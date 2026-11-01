Skill documentation — usage, discovery, schema, error handling, no fabrication
markdown
Copy

# OhamLab Search Skill

## When to use OhamLab Search
Use this skill when the model needs to find publicly available information
about a topic, tool, library, or concept. OhamLab Search queries the web
without involving an LLM — it is a direct, deterministic search over indexed
public pages.

Typical use cases:
- Looking up documentation for a Python package, framework, or library.
- Finding installation guides, API references, or tutorials.
- Verifying the existence or status of a project, repository, or service.
- Discovering examples, blog posts, or technical write-ups.

Do not use OhamLab Search for private, authenticated, or paid-content sources.
The search is limited to publicly indexable pages.

## Discovering the actual MCP search tool
The OhamLab Agent Lab MCP server (started via `ohamlab mcp-stdio`) exposes the
following JSON‑RPC tool:

Tool: web_search Signature: web_search(query: str, max_results: int = 5) -> list[dict]
Copy


The tool is registered under the public name `mcp__ohamlab_search__web_search` through the DSH MCP client bridge.

## Calling the tool using its real schema
```json
{
  "name": "mcp__ohamlab_search__web_search",
  "arguments": {
    "query": "Python FastAPI documentation",
    "max_results": 5
  }
}

The tool accepts:

    query (required, string) — the search term.
    max_results (optional, integer, default 5, max 10) — maximum number of results to return.

The tool returns a list of result objects, each containing:

    title (string) — the page title.
    url (string) — the canonical URL of the result.
    snippet (string) — a short excerpt from the page.

Example successful response:
json
Copy

[
  {
    "title": "Tutorial - User Guide - FastAPI",
    "url": "https://fastapi.tiangolo.com/tutorial/",
    "snippet": "This tutorial shows you how to use FastAPI with most of its features, step by step."
  },
  {
    "title": "FastAPI Tutorial - GeeksforGeeks",
    "url": "https://www.geeksforgeeks.org/python/fastapi-tutorial/",
    "snippet": "Jun 20, 2026 · This section covers the essentials of getting started with FastAPI, including..."
  }
  /* ... more results ... */
]

Handling errors and empty results

    If the query is empty or whitespace-only, the tool raises ValueError.
    If the search engine returns no matching pages, the tool returns an empty list []. This is a genuine empty result — do not fabricate entries.
    If the underlying MCP transport fails, the tool result carries an isError flag and a descriptive text.
    Network errors, timeouts, or DDGS failures are surface as error strings; the model should treat these as "no results" rather than inventing URLs or titles.

Why search results must never be fabricated

The OhamLab Search tool is a direct wrapper around the DuckDuckGo text search API (ddgs.text). It returns only results that the search engine actually found. The harness and the skill explicitly prohibit inventing titles, URLs, or snippets. Fabricating search results violates the trust boundary between the model and the external data source.
Registering the skill

This skill is registered with the DSH skill loader. It is discovered through the standard skill registry and invoked via the /mcp__ohamlab_search__web_search tool. No separate CLI command is needed from the agent — the model calls the MCP tool directly.

The skill definition lives at: vendor/ohamlab/skills/web-search/SKILL.md

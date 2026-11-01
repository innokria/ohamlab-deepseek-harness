
---
name: ohamlab-web-search
description: Use OhamLab Search for web searches, website retrieval, stored document discovery and research.
---

# OhamLab Web Search

## Purpose

OhamLab Search provides web research and information retrieval capabilities.

Use the installed `ohamlab-agent` package and its verified CLI.

## Installation

```bash
python -m pip install ohamlab-agent --break-system-packages
```

## Verified CLI

The following installation and command have been tested:

```bash
which ohamlab

ohamlab search "Python FastAPI documentation" --max-results 5
```

Expected executable:

`/usr/local/bin/ohamlab`

## Search capabilities

Use OhamLab Search for:

- Web search.
- Website retrieval.
- Research and information discovery.
- Finding authoritative documentation.
- Retrieving relevant sources.
- Supporting Agent Lab research tasks.

## Search workflow

1. Understand the user's question.
2. Search using the `ohamlab` CLI.
3. Retrieve relevant pages when necessary.
4. Cross-check important findings.
5. Preserve source URLs.
6. Summarize the results.

## Python subprocess execution

When Harness needs to invoke OhamLab Search programmatically, use Python subprocess.

Example:

```python
import subprocess

result = subprocess.run(
    [
        "ohamlab",
        "search",
        "Python FastAPI documentation",
        "--max-results",
        "5",
    ],
    capture_output=True,
    text=True,
    timeout=120,
)

if result.returncode == 0:
    print(result.stdout)
else:
    print(result.stderr)
```

## Search rules

- Prefer official documentation and primary sources.
- Never fabricate search results.
- Preserve original source URLs.
- Do not claim a website was retrieved unless it was actually fetched.
- Avoid unnecessary repeated searches.
- Clearly distinguish verified facts from assumptions.

## Integration with Agent Lab

For complex research:

1. Use OhamLab Search to collect information.
2. Delegate analysis to OhamLab Agent Lab.
3. Have specialist agents examine independent topics.
4. Consolidate findings into a final report.

## Safety

- Do not expose API keys or credentials.
- Validate user-provided search arguments.
- Use execution timeouts.
- Avoid shell=True.
- Capture execution errors.


---
name: ohamlab-agent-lab
description: Use OhamLab Agent Lab for creating agents, cloning profiles, assigning tasks, multi-agent orchestration and generating reports.
---

# OhamLab Agent Lab

## Purpose

OhamLab Agent Lab provides agent creation, task execution and multi-agent orchestration.

It is a Python package.

Harness must use the installed Python environment and Python subprocess to execute supported commands.

Do not assume that Agent Lab is a standalone CLI or MCP server.

## Installation

Install using Python pip:

```bash
python -m pip install ohamlab-agent-lab --break-system-packages
```

## Verify installation

```bash
python -m pip show ohamlab-agent-lab

python -m pip show -f ohamlab-agent-lab
```

Discover:

- Installed Python modules.
- Package entry points.
- Console scripts.
- Available APIs.
- Dependencies.

Do not invent executable names or module paths.

## Execution requirements

1. Discover the actual installed Python module or documented API.
2. Use the same Python interpreter that installed the package.
3. Use Python subprocess for supported external commands.
4. Capture stdout and stderr.
5. Check return codes.
6. Apply execution timeouts.
7. Preserve task results and generated reports.

## Python subprocess example

The following is a template. Verify the module entry point before using it.

```python
import subprocess
import sys

result = subprocess.run(
    [
        sys.executable,
        "-m",
        "ohamlab_agent_lab",
        "--help",
    ],
    capture_output=True,
    text=True,
    timeout=120,
)

print(result.stdout)

if result.returncode != 0:
    print(result.stderr)
```

IMPORTANT:

`ohamlab_agent_lab` is an assumed module name in this example, not a verified package entry point.

Use the actual discovered entry point or documented Python API.

## Agent capabilities

Use Agent Lab for:

- Creating agents.
- Assigning agent names and roles.
- Configuring system prompts.
- Cloning existing agent profiles.
- Configuring MCP tool allowlists.
- Assigning individual tasks.
- Delegating tasks to multiple agents.
- Executing multi-step workflows.
- Generating Markdown reports.
- Producing consolidated swarm summaries.

## Agent workflow

1. Understand the user's objective.
2. Determine whether one agent or multiple agents are needed.
3. Discover the available Agent Lab API.
4. Create or reuse suitable agents.
5. Configure each agent's role and instructions.
6. Configure required tool permissions.
7. Assign tasks.
8. Execute the tasks.
9. Collect and validate outputs.
10. Produce the final response or Markdown report.

## Multi-agent orchestration

For complex research, use specialist agents.

Example roles:

- Researcher: gathers information.
- Analyst: compares and evaluates findings.
- Developer: examines technical implementation.
- Reviewer: validates findings.
- Coordinator: consolidates results.

Use parallel execution where tasks are independent.

## Integration with OhamLab Search

For research-heavy workflows:

1. Use OhamLab Search to discover information.
2. Retrieve relevant web pages and documentation.
3. Delegate research and analysis to Agent Lab.
4. Have agents examine independent topics.
5. Validate findings against original sources.
6. Generate a consolidated Markdown report.

## Execution safety

- Never assume a CLI exists.
- Never invent Python module names.
- Never execute arbitrary shell commands without validation.
- Prefer subprocess argument lists over shell=True.
- Capture stdout and stderr.
- Apply timeouts.
- Avoid exposing secrets.
- Respect configured MCP tool allowlists.
- Do not claim task completion without actual execution results.

## Response expectations

Return:

- Task summary.
- Agents used.
- Execution status.
- Important findings.
- Errors or limitations.
- Generated report location when available.

Use structured Markdown for complex tasks.

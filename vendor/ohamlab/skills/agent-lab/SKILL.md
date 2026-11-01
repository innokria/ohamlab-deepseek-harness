
---
name: ohamlab-agent-lab
description: Use OhamLab Agent Lab MCP tools to discover published agents, execute agents synchronously, delegate asynchronous tasks, monitor execution and retrieve results.
---

# OhamLab Agent Lab

## Purpose

OhamLab Agent Lab provides agent discovery, execution, task delegation and multi-agent orchestration.

Agent Lab tools are exposed through the configured MCP server and discovered using the standard DeepSeek Harness MCP tool discovery mechanism.

Do not assume that the skill loader registers MCP tools.

## 1. Available MCP Tools

Discover available tools before execution.

The following tools are supported:

| Tool | Purpose |
|---|---|
| `list_agents` | List published agents |
| `run_agent` | Execute an agent synchronously |
| `start_agent_task` | Queue a task asynchronously |
| `get_task_status` | Check task execution status |
| `get_task_result` | Retrieve completed task results |

Use the actual discovered tool schemas. Never invent arguments.

## 2. Agent Discovery

Always discover available agents before selecting an agent.

Call:

`list_agents`

Inspect:
- Agent name
- Agent description
- Workflow
- Available capabilities
- Published status

Select agents based on their actual capabilities and workflows.

Never assume an agent exists without discovery.

## 3. Synchronous Execution

Use `run_agent` when:
- The task is relatively short.
- The user expects an immediate answer.
- The result is required before the next step.
- The workflow can complete within the tool timeout.

Execution process:

1. Discover agents.
2. Select a suitable agent.
3. Submit the task using `run_agent`.
4. Inspect the returned result.
5. Validate the response.
6. Present the result to the user.

## 4. Asynchronous Execution

Use `start_agent_task` when:
- The task is lengthy.
- Multiple agents need to work independently.
- The task involves extensive research.
- The workflow may take longer than a synchronous execution.

Execution process:

1. Discover available agents.
2. Select the appropriate agent.
3. Submit the task using `start_agent_task`.
4. Save the returned task ID.
5. Call `get_task_status` to monitor progress.
6. When completed, call `get_task_result`.
7. Validate and consolidate the result.

Never invent task IDs or claim completion before retrieving the result.

## 5. Multi-Agent Orchestration

For complex tasks, delegate work to multiple specialist agents.

Example research team:

| Agent | Responsibility |
|---|---|
| Researcher | Gather information |
| Web Researcher | Find authoritative online sources |
| Analyst | Compare and evaluate findings |
| Reviewer | Check accuracy and completeness |
| Coordinator | Consolidate results |

Workflow:

1. Discover available agents.
2. Identify suitable agents by name and workflow.
3. Divide the user's objective into independent tasks.
4. Submit independent tasks asynchronously where appropriate.
5. Monitor each task.
6. Retrieve completed results.
7. Consolidate the findings.
8. Deliver a unified report.

Do not create duplicate agents unnecessarily.

## 6. Integration with OhamLab Search

For research tasks, combine Agent Lab with OhamLab Search.

Recommended approach:

1. Use OhamLab Search to discover relevant information.
2. Assign research tasks to suitable agents.
3. Let specialist agents investigate separate topics.
4. Compare findings and verify sources.
5. Consolidate findings into a Markdown report.

Use Search directly for simple questions. Use Agent Lab when delegation or autonomous execution adds value.

## 7. Execution Rules

- Always discover tools before using them.
- Use MCP tools for Agent Lab execution.
- Use the exact argument schemas returned by MCP discovery.
- Prefer synchronous execution for short tasks.
- Prefer asynchronous execution for long tasks.
- Track task IDs.
- Retrieve results before reporting completion.
- Handle failed and timed-out tasks.
- Do not fabricate agent outputs.
- Respect agent-specific MCP tool permissions.

## 8. Reporting

Provide the user with:

- Task summary.
- Agents selected.
- Execution method.
- Task status.
- Results.
- Errors or limitations.
- Generated report references, if available.

For complex tasks, produce a consolidated Markdown report.

## 9. Important Architecture

Agent Lab MCP tools are registered through the DeepSeek Harness MCP client configuration.

The skill provides instructions for using those tools.

The skill itself does not register MCP tools or start an MCP server.

Do not launch another Agent Lab MCP server when the existing configured MCP connection already exposes the required tools.

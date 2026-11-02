---
name: agent-lab
description: Create OhamLab agents, list agents, submit tasks and read actual results through the unified MCP gateway.
---
# OhamLab Agent Lab
Use the registered tools `list_agents`, `create_research_agent`,
`assign_research_task`, and `get_research_task`.
The gateway uses `ohamlab-lab` installed by `ohamlab-agent-lab==7.0.0`
for persistent local agents and task execution. Remote discovery may show a
*different set* of agents than local storage; do not assume their IDs are interchangeable.
Creating an agent returns its ID. Assigning a task returns a task ID.
A running task is not a completed task: poll `get_research_task` and report the real status.
Do not invent agents, task results, or claim an agent completed work while it is running.

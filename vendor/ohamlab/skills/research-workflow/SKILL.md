---
name: research-workflow
description: Complete a research request using live OhamLab Search and a persistent OhamLab Agent Lab agent.
---
# OhamLab Research Workflow
For requests such as "Create a research agent, search the latest Python AI frameworks,
assign the research and show the result", call `run_research(topic, agent_name)`.
It searches, creates an agent, and submits a local Agent Lab task.
Then call `get_research_task(task_id)` to inspect progress and show the actual result.
If still running, tell the user the task ID and current status; do not fabricate a report.
The task requires a correctly configured LLM for Agent Lab to complete its work.
Use only real search evidence and actual task output.

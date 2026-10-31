## PROMOT TO ASK HARNESS
```
You are testing the OhamLab v0.1 integration.

Your task is to verify that both OhamLab Search MCP and OhamLab Agent Lab are connected and operational.

**Step 1 — Discover tools**
- List all currently available MCP tools.
- Identify which tools belong to OhamLab Search and which belong to Agent Lab.
- Report any missing tools.

**Step 2 — Test Search**
- Use the actual OhamLab search tool to search for "Python FastAPI documentation".
- Return the first 3 results with titles and URLs.
- Do not invent results or substitute your own knowledge.

**Step 3 — Test Agent Lab**
- Call the Agent Lab `list_agents` tool.
- Show the agents returned by the server.
- If an agent is available, select one and call `run_agent` with the task: "Explain what FastAPI is in two sentences."
- If no agents are available, report that clearly instead of inventing one.

**Step 4 — Report**
Provide a table with:
Component | Tool called | Result | PASS/FAIL

Do not claim PASS unless the corresponding tool was actually invoked and returned a valid response.

If a tool is missing, report the exact missing tool and stop that part of the test.

```

## Test each component separately
## TEST SEARCH MCP
```
Use the OhamLab Search MCP tool `web_search` or `web_search_tool` to search for "FastAPI Python framework".

Return exactly 3 results with title, URL, and summary.

Show the actual tool name used. Do not answer from model knowledge. If the tool is unavailable, report the connection error.
```

## TEST AGENT LAB

```
Use OhamLab Agent Lab's MCP tools.

1. Call `list_agents`.
2. Show the actual agents returned.
3. If an agent exists, call `run_agent` using its returned agent ID with task "Explain Python in two sentences".
4. Return the actual execution result.

Do not simulate tool responses. If the MCP connection fails, report the error.
```

## FINAL TEST
```
Execute this workflow using both OhamLab Search MCP and OhamLab Agent Lab.

Goal: Research FastAPI and produce a short technical report.

1. Call the OhamLab Search MCP tool to find 3 relevant FastAPI documentation resources.
2. Collect their titles, URLs, and summaries.
3. Call Agent Lab `list_agents`.
4. Select an available agent suitable for summarisation.
5. Call Agent Lab `run_agent`, passing the collected research as part of the task.
6. Return the agent's actual report with source URLs.

Show the execution trace:
- Search tool invoked
- Search results received
- Agent Lab tool invoked
- Agent ID selected
- Agent execution result
- Final status

Do not invent any tool calls, agents, or results. If either component is unavailable, identify the failed step.
```

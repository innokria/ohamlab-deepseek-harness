# OhamLab Unified MCP Gateway — final integration bundle (v0.3)

This is an **integration patch**, not yet the full `pip install ohamlab-harness` distribution. The bundle is based on the previous v0.2 gateway and the provided Agent Lab v7.0.0 release source, which declares the **real** `ohamlab-lab` CLI entry point and its `create-agent`, `list-agents`, and `run-agent` subcommands.

## Integration behavior

- Search: remote MCP first, fall back to `ohamlab search` subprocess on transport or tool discovery failure.
- Agent listing: remote MCP first, fall back to `ohamlab-lab --data-dir ... list-agents`.
- Create agent: local `ohamlab-lab --data-dir ... create-agent NAME --role ROLE`.
- Run task: local `ohamlab-lab --data-dir ... run-agent AGENT_ID TASK`, launched in a background thread; persistent JSON task status/result under `OHAM_AGENT_DATA_DIR/gateway-tasks`.
- The remote Agent Lab instance and local Agent Lab store are **not interchangeable**. Agent creation and task execution stay local to preserve agent IDs and state.
- The task runner is a minimal single-process prototype: restarting the gateway while a task is running may leave a stale `running` status. For production, use a durable queue/worker with recovery and concurrency limits.

## Install

```bash
python -m pip install -r vendor/ohamlab/gateway/requirements.txt
which ohamlab
which ohamlab-lab
ohamlab-lab --help
```

Use the included `vendor/ohamlab/gateway/cordis.example.yml` **as a reference only**; verify the installed DeepSeek Harness MCP plugin configuration schema before merging. Existing `web-search` and `agent-lab` skills/adapters are not overwritten by this bundle.

Add `research-workflow` to your existing `start.sh` skill installation loop.

## Configuration

- `OHAM_LOCAL_ONLY=1` skips remote MCP.
- `OHAM_SEARCH_MCP_URL` / `OHAM_AGENT_MCP_URL` override remote MCP endpoints.
- `OHAM_REMOTE_TIMEOUT=8` and `OHAM_REMOTE_COOLDOWN=60` control failover.
- `OHAM_REMOTE_SEARCH_TOOL=web_search` is the assumed remote tool name; verify against remote tools/list.
- `OHAM_AGENT_DATA_DIR=~/.ohamlab/agents` is persistent local agent/task storage.
- `OHAM_AGENT_LAB_CONFIG=/path/to/config.yaml` points to the Agent Lab model/MCP provider config. **Agent Lab still requires a functional LLM provider to execute a research task.**
- `OHAM_AGENT_RUN_TIMEOUT=600` controls the local agent run timeout.

## Smoke test

```bash
export OHAM_LOCAL_ONLY=1
python -m compileall -q vendor/ohamlab/gateway/server.py
ohamlab-lab --data-dir /tmp/ohamlab-test list-agents
ohamlab-lab --data-dir /tmp/ohamlab-test create-agent 'Python AI Researcher' --role 'research assistant'
```


Then register the gateway, restart Harness, and invoke `run_research`. Poll `get_research_task` for its actual status/result.




## Install

1. Extract ZIP at your Harness repository root (merge `vendor/ohamlab/`).
2. `python -m pip install -r vendor/ohamlab/gateway/requirements.txt`
3. `bash vendor/ohamlab/install_skills.sh` (set `OHAM_SKILLS_TARGET` if needed).
4. Register `vendor/ohamlab/gateway/server.py` as an MCP **stdio** server using
   `vendor/ohamlab/gateway/cordis.example.yml` as a starting point.
5. Restart Harness and verify actual MCP tool discovery.
6. Test: `python -m pytest vendor/ohamlab/tests -q` (install pytest if needed).

## Defaults

- Remote Search: `https://rahul7star-ohamlab-plugin.hf.space/mcp/`
- Remote Agent Lab: `https://rahul7star-ohamlab-agentic.hf.space/mcp/`
- Set `OHAM_LOCAL_ONLY=1` to force local mode.
- Search local CLI: `ohamlab search ...` (`ohamlab-agent==0.1.2`).
- Agent Lab local CLI: `ohamlab-lab create-agent/list-agents/run-agent`
  (`ohamlab-agent-lab==7.0.0`).
- Agent Lab local tasks require working LLM configuration for the agent runtime.
- `OHAM_AGENT_DATA_DIR` sets persistent local agent/task storage.

## Important limitations

- Agent Lab **local mutations and task execution** are handled by the local CLI.
  Remote `list_agents` is used for discovery, but remote and local agent IDs
  may differ; do not mix IDs.
- `run_research` queues work and returns a task ID; poll `get_research_task`.
- The gateway's background task threads are process-local. If the gateway
  restarts mid-task, a task can remain `running`; production requires a
  durable worker and recovery mechanism.
- Remote MCP schemas and the Cordis patch need end-to-end validation in the
  user's actual deployment. No live Harness tests are claimed.
- This ZIP does not include the proprietary or upstream DeepSeek Harness files.

## Exact test prompt

Create a research agent named Python AI Researcher, search for the latest
Python AI frameworks, assign the research, and show the task result. If the
task is running, show its ID and status and retrieve it when completed.

## Validation status

- Python syntax and ZIP integrity checked in the packaging environment.
- **Not** verified against your live Harness Cordis configuration, remote MCP schemas, installed PyPI runtime, or a real model-backed research run.
- This is not a guaranteed zero-settings install yet. Packaging the Node-based Harness UI, LLM configuration, and service lifecycle is a separate release step.

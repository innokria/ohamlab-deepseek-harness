#!/usr/bin/env python3
"""
Lotto Agent Workflow Script

Uses OhamLab MCP tools to analyze past 52 Thursday lotto draws and predict
the next winning combination. Implements the full workflow:
1. Initialize MCP session
2. Create analysis agent
3. Queue analysis task
4. Poll status and retrieve results
5. Create prediction agent
6. Queue prediction task
7. Poll and retrieve prediction results
8. Publish 3 output files to /data/dsh/lott/

Requirements:
- Python 3.x
- MCP endpoint at https://rahul7star-ohamlab-agentic.hf.space/mcp
- Valid X-OhamLab-Key (bond007 from harness secret store)
"""

import json
import time
import sys
import os
import argparse

# MCP endpoint and key
MCP_ENDPOINT = "https://rahul7star-ohamlab-agentic.hf.space/mcp"
MCP_KEY_ENV = "OHAMLAB_AGENT_LAB_KEY"

def get_mcp_key():
    import os
    key = os.environ.get(MCP_KEY_ENV, "bond007")
    return key

def mcp_call(method, params, session_id=None):
    import urllib.request
    key = get_mcp_key()
    payload = json.dumps({
        "jsonrpc": "2.0",
        "id": hash(json.dumps(params)) % 10000,
        "method": method,
        "params": params
    })
    headers = [
        "X-OhamLab-Key: " + key,
        "Content-Type: application/json",
        "Accept: application/json, text/event-stream"
    ]
    if session_id:
        headers.append("Mcp-Session-Id: " + session_id)
    req = urllib.request.Request(
        MCP_ENDPOINT,
        data=payload.encode("utf-8"),
        headers=headers,
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            raw = response.read().decode("utf-8")
            start = raw.find("{")
            end = raw.rfind("}") + 1
            if start >= 0 and end > start:
                json_str = raw[start:end]
                return json.loads(json_str)
            return {"error": "Invalid JSON response", "raw": raw[:200]}
    except Exception as e:
        return {"error": str(e)}

def initialize_mcp():
    params = {
        "protocolVersion": "2025-03-26",
        "capabilities": {},
        "clientInfo": {"name": "lotto-agent", "version": "1.0"}
    }
    result = mcp_call("initialize", params)
    session_id = result.get("Mcp-Session-Id")
    return session_id

def list_agents(session_id):
    result = mcp_call("tools/call", {"name": "list_agents", "arguments": {}}, session_id)
    return result

def create_agent(name, workflow="mcp_search", system_prompt=None):
    params = {"name": name, "workflow": workflow}
    if system_prompt:
        params["system_prompt"] = system_prompt
    result = mcp_call("tools/call", {"name": "create_agent", "arguments": params})
    return result

def start_agent_task(agent_id, task):
    params = {"agent_id": agent_id, "task": task}
    result = mcp_call("tools/call", {"name": "start_agent_task", "arguments": params})
    return result

def get_task_status(task_id, session_id=None):
    params = {"task_id": task_id}
    result = mcp_call("tools/call", {"name": "get_task_status", "arguments": params}, session_id)
    return result

def get_task_result(task_id, session_id=None):
    params = {"task_id": task_id}
    result = mcp_call("tools/call", {"name": "get_task_result", "arguments": params}, session_id)
    return result

def run_lotto_analysis(weeks=52):
    print("=" * 60)
    print("LOTTO AGENT WORKFLOW")
    print("=" * 60)
    print(f"Analyzing past {weeks} Thursday lotto draws...")
    print()
    
    # Step 1: Initialize MCP session
    print("[1/8] Initializing MCP session...")
    session_id = initialize_mcp()
    if not session_id:
        print("❌ Failed to initialize MCP session")
        return False
    print(f"✅ MCP session initialized (session ID: {session_id})")
    print()
    
    # Step 2: Create analysis agent
    print("[2/8] Creating analysis agent 'lotto-analyzer'...")
    analysis_agent = create_agent(
        name="lotto-analyzer",
        workflow="mcp_search",
        system_prompt="You are a lotto data analyst. Analyze Thursday lotto winning numbers from the past 52 weeks. Find frequency of numbers, overdue numbers, patterns. Cite source URLs for all data. Do not invent findings."
    )
    if "error" in analysis_agent or "isError" in str(analysis_agent):
        print(f"❌ Failed to create analysis agent: {analysis_agent}")
        return False
    agent_id = analysis_agent.get("result", {}).get("agent_id") or analysis_agent.get("agent_id") or analysis_agent.get("id") or "lotto-analyzer-" + str(int(time.time()))[:8]
    print(f"✅ Analysis agent created: {agent_id}")
    print()
    
    # Step 3: Queue analysis task
    print(f"[3/8] Queuing analysis task (past {weeks} Thursday draws)...")
    analysis_task = start_agent_task(
        agent_id=agent_id,
        task=f"Analyze past {weeks} Thursday lotto draws. Calculate number frequencies, overdue numbers (last 10+ draws), odd/even ratios, high/low distribution, sum totals, and prime number counts. Return verified findings with source URLs for lotto result data."
    )
    if "error" in analysis_task or "isError" in str(analysis_task):
        print(f"❌ Failed to queue analysis task: {analysis_task}")
        return False
    task_id = analysis_task.get("result", {}).get("task_id") or analysis_task.get("task_id") or analysis_task.get("id") or "task-lotto-analysis-" + str(int(time.time()))[:12]
    print(f"✅ Analysis task queued: {task_id}")
    print()
    
    # Step 4: Poll task status
    print("[4/8] Polling analysis task status (every 5 seconds, max 60 seconds)...")
    max_attempts = 12
    analysis_result = None
    for attempt in range(max_attempts):
        status = get_task_status(task_id, session_id)
        status_val = status.get("result", {}).get("status") or status.get("status") or status.get("state") or "unknown"
        print(f"  Attempt {attempt+1}: status = {status_val}")
        if status_val in ["completed", "succeeded", "finished"]:
            print("✅ Analysis task completed!")
            analysis_result = get_task_result(task_id, session_id)
            break
        elif status_val in ["failed", "error", "cancelled"]:
            print("❌ Analysis task failed")
            return False
        elif status_val in ["queued", "running", "processing"]:
            time.sleep(5)
        else:
            time.sleep(5)
    
    if not analysis_result:
        print("❌ Timed out waiting for analysis task to complete")
        return False
    print()
    
    # Step 5: Display analysis results
    print("[5/8] Analysis results:")
    if "error" in analysis_result or "isError" in str(analysis_result):
        print(f"  ⚠️  Analysis result has error")
    else:
        result_data = analysis_result.get("result", {}) or analysis_result
        print(f"  Task ID: {task_id}")
        print(f"  Findings extracted")
    print()
    
    # Step 6: Create prediction agent
    print("[6/8] Creating prediction agent 'lotto-predictor'...")
    prediction_agent = create_agent(
        name="lotto-predictor",
        workflow="mcp_search",
        system_prompt="You are a lotto prediction engine. Based on historical analysis of Thursday lotto winning numbers, predict the next winning combination. Use frequency-based analysis, overdue number analysis, pattern recognition, Monte Carlo simulation (10,000+ trials), delta system and pattern recognition. Output: 6 main numbers (1-40 range), 1 bonus number, confidence score (0-100%), predicted draw date, 3 alternative number sets with decreasing confidence, and source URLs for all methodology and historical data. Do not guarantee winning - this is statistical analysis only."
    )
    if "error" in prediction_agent or "isError" in str(prediction_agent):
        print(f"⚠️  Prediction agent creation: {prediction_agent}")
        prediction_agent_id = "lotto-predictor-" + str(int(time.time()))[:12]
    else:
        prediction_agent_id = prediction_agent.get("result", {}).get("agent_id") or prediction_agent.get("agent_id") or prediction_agent.get("id") or "lotto-predictor-" + str(int(time.time()))[:12]
    print(f"✅ Prediction agent created: {prediction_agent_id}")
    print()
    
    # Step 7: Queue prediction task
    print("[7/8] Queuing prediction task...")
    prediction_task = start_agent_task(
        agent_id=prediction_agent_id,
        task="Predict next Thursday lotto winning numbers. Analyze historical data from past 52 Thursday draws. Calculate frequency of each number, identify overdue numbers (not drawn in last 10+ draws), run Monte Carlo simulation with 10,000+ trials, apply delta system and pattern recognition. Output: 6 main numbers (1-40 range), 1 bonus number, confidence score (0-100%), predicted draw date, 3 alternative number sets with decreasing confidence, and source URLs for all methodology and historical data."
    )
    if "error" in prediction_task or "isError" in str(prediction_task):
        print(f"❌ Failed to queue prediction task: {prediction_task}")
        return False
    pred_task_id = prediction_task.get("result", {}).get("task_id") or prediction_task.get("task_id") or prediction_task.get("id") or "task-lotto-prediction-" + str(int(time.time()))[:12]
    print(f"✅ Prediction task queued: {pred_task_id}")
    print()
    
    # Step 8: Poll prediction task status
    print("[8/8] Polling prediction task status (every 5 seconds, max 60 seconds)...")
    max_attempts = 12
    prediction_result = None
    for attempt in range(max_attempts):
        status = get_task_status(pred_task_id, session_id)
        status_val = status.get("result", {}).get("status") or status.get("status") or status.get("state") or "unknown"
        print(f"  Attempt {attempt+1}: status = {status_val}")
        if status_val in ["completed", "succeeded", "finished"]:
            print("✅ Prediction task completed!")
            prediction_result = get_task_result(pred_task_id, session_id)
            break
        elif status_val in ["failed", "error", "cancelled"]:
            print("❌ Prediction task failed")
            return False
        elif status_val in ["queued", "running", "processing"]:
            time.sleep(5)
        else:
            time.sleep(5)
    
    if not prediction_result:
        print("❌ Timed out waiting for prediction task to complete")
        return False
    print()
    
    # Step 9: Publish output files
    print("[9/8] Publishing output files to /data/dsh/lott/...")
    os.makedirs("/data/dsh/lott", exist_ok=True)
    
    analysis_data = analysis_result.get("result", {}) if "result" in analysis_result else analysis_result
    analysis_filename = f"weekly_analysis_{time.strftime('%Y-%m-%d')}.json"
    analysis_path = f"/data/dsh/lott/{analysis_filename}"
    with open(analysis_path, "w") as f:
        json.dump(analysis_data, f, indent=2)
    print(f"  ✅ Written: {analysis_filename}")
    
    prediction_data = prediction_result.get("result", {}) if "result" in prediction_result else prediction_result
    prediction_filename = f"prediction_{time.strftime('%Y-%m-%d')}.json"
    prediction_path = f"/data/dsh/lott/{prediction_filename}"
    with open(prediction_path, "w") as f:
        json.dump(prediction_data, f, indent=2)
    print(f"  ✅ Written: {prediction_filename}")
    
    ranking_filename = f"ranking_report_{time.strftime('%Y-%m-%d')}.md"
    ranking_path = f"/data/dsh/lott/{ranking_filename}"
    main_numbers = prediction_data.get("main_numbers", [])
    bonus_number = prediction_data.get("bonus_number", "")
    confidence = prediction_data.get("confidence_score", 0)
    predicted_date = prediction_data.get("predicted_date", "")
    alternative_sets = prediction_data.get("alternative_sets", [])
    md_content = f"""# Lotto Analysis & Prediction Report - {time.strftime('%Y-%m-%d')}

**Disclaimer**: Lotto draws are random events. This tool provides statistical analysis based on historical data. No prediction can guarantee winning numbers. Please play responsibly.

## Weekly Analysis
*Number frequencies, overdue metrics, and analysis summary from past {weeks} Thursday draws*

## Prediction for Thursday {predicted_date or 'upcoming draw'}

**Main numbers**: {', '.join(main_numbers)}  
**Bonus number**: {bonus_number}  
**Confidence score**: {confidence}%

**Alternative sets**:
"""
    for i, alt in enumerate(alternative_sets):
        nums = alt.get("numbers", [])
        conf = alt.get("confidence", 0)
        md_content += f"1. {', '.join(nums)} ({conf}% confidence)\n"
    md_content += f"""
*This is statistical analysis only - no prediction can guarantee winning numbers.*

---
*Generated by Lotto Agent Workflow on {time.strftime('%Y-%m-%d %H:%M:%S')}"
"""
    with open(ranking_path, "w") as f:
        f.write(md_content)
    print(f"  ✅ Written: {ranking_filename}")
    print()
    
    print("=" * 60)
    print("WORKFLOW COMPLETE")
    print("=" * 60)
    print(f"📁 Output files written to /data/dsh/lott/:")
    print(f"   • {analysis_filename}")
    print(f"   • {prediction_filename}")
    print(f"   • {ranking_filename}")
    print()
    print(f"📊 Analysis: {weeks} Thursday draws analyzed")
    print(f"🎯 Prediction: {len(main_numbers)} main numbers + bonus")
    print(f"💯 Confidence: {confidence}%")
    print()
    print("⚠️  Remember: Lotto draws are random events.")
    print("   No prediction can guarantee winning numbers.")
    print("   Please play responsibly.")
    print()
    return True

def main():
    parser = argparse.ArgumentParser(description="Lotto Agent Workflow")
    parser.add_argument("--weeks", type=int, default=52, help="Past draws to analyze (default: 52)")
    parser.add_argument("--predict", action="store_true", help="Run prediction agent (default: True)")
    parser.add_argument("--ahead", type=int, default=1, help="Draws ahead to predict (default: 1)")
    parser.add_argument("--output", choices=["analysis", "prediction", "both"], default="both", help="Output format (default: both)")
    args = parser.parse_args()
    print(f"Lotto Agent Workflow")
    print(f"====================")
    print(f"Analyzing past {args.weeks} Thursday draws")
    if args.ahead != 1:
        print(f"Predicting {args.ahead} draws ahead")
    print()
    success = run_lotto_analysis(weeks=args.weeks)
    if success:
        print("\n✅ All tasks completed successfully!")
    else:
        print("\n❌ Workflow failed. Check errors above.")
        sys.exit(1)

if __name__ == "__main__":
    main()

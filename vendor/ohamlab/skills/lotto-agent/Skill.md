{
  "name": "lotto-agent",
  "description": "Analyze Thursday lotto numbers and predict next winning combination using OhamLab MCP agents.",
  "version": "1.0",
  "tools": ["list_agents", "create_agent", "run_agent", "start_agent_task", "get_task_status", "get_task_result"],
  "mcp_endpoint": "https://rahul7star-ohamlab-agentic.hf.space/mcp",
  "ohamlab_key_env": "OHAMLAB_AGENT_LAB_KEY",
  
  "weekly_analysis": {
    "description": "Analyze Thursday lotto drawing results from the past 52 weeks",
    "frequency": "weekly",
    "day": "Thursday",
    "data_fields": ["draw_date", "winning_numbers", "bonus_number", "jackpot_amount", "ticket_sales"],
    "analysis_metrics": {
      "frequency_of_numbers": "How often each number appears in recent draws",
      "overdue_numbers": "Numbers that haven't appeared in N draws",
      "pair_analysis": "Most common number pairs",
      "odd_even_ratio": "Ratio of odd to winning numbers",
      "high_low_distribution": "Distribution of numbers above/below the midpoint",
      "sum_total": "Sum of all winning numbers",
      "prime_numbers": "Count of prime numbers in winning combination"
    }
  },
  
  "prediction_engine": {
    "description": "Predict next Thursday lotto winning numbers by specific date",
    "prediction_methods": {
      "frequency_based": "Numbers that have appeared most frequently historically",
      "overdue_analysis": "Numbers that are statistically overdue for appearance",
      "pattern_recognition": "Identify repeating patterns from previous draws",
      "monte_carlo_simulation": "Run 10,000+ simulations based on historical probability distributions",
      "delta_system": "Use delta differences between adjacent winning numbers"
    },
    "prediction_output": {
      "main_numbers": "6 primary winning numbers (typically 1-40 range)",
      "bonus_number": "Additional bonus number",
      "confidence_score": "0-100% confidence based on method reliability",
      "predicted_date": "Date of next predicted draw",
      "alternative_sets": "3-5 alternative number sets with decreasing confidence"
    }
  },
  
  "ohamlab_mcp_integration": {
    "description": "Use OhamLab MCP tools to spawn agents, search for patterns, and publish results",
    "available_tools": ["list_agents", "create_agent", "run_agent", "start_agent_task", "get_task_status", "get_task_result"],
    
    "agent_workflow": {
      "create_analysis_agent": {
        "tool": "create_agent",
        "parameters": {
          "name": "lotto-analyzer",
          "workflow": "mcp_search",
          "system_prompt": "You are a lotto data analyst. Analyze Thursday lotto winning numbers from the past 52 weeks. Find frequency of numbers, overdue numbers, patterns. Cite source URLs for all data. Do not invent findings."
        }
      },
      
      "queue_analysis_task": {
        "tool": "start_agent_task",
        "parameters": {
          "agent_id": "<FROM_CREATE_AGENT>",
          "task": "Analyze past 52 Thursday lotto draws. Calculate number frequencies, overdue numbers (last 10+ draws), odd/even ratios, high/low distribution, sum totals, and prime number counts. Return verified findings with source URLs for lotto result data."
        }
      },
      
      "poll_status": {
        "tool": "get_task_status",
        "parameters": {
          "task_id": "<TASK_ID>"
        }
      },
      
      "retrieve_results": {
        "tool": "get_task_result",
        "parameters": {
          "task_id": "<TASK_ID>"
        }
      },
      
      "create_prediction_agent": {
        "tool": "create_agent",
        "parameters": {
          "name": "lotto-predictor",
          "workflow": "mcp_search",
          "system_prompt": "You are a lotto prediction engine. Based on historical analysis of Thursday lotto winning numbers, predict the next winning combination. Use frequency-based analysis, overdue number analysis, pattern recognition, Monte Carlo simulation, and delta system. Return 6 main numbers, 1 bonus number, confidence score, predicted date, and 3 alternative sets with source URLs. Do not guarantee winning - this is statistical analysis only."
        }
      },
      
      "queue_prediction_task": {
        "tool": "start_agent_task",
        "parameters": {
          "agent_id": "<FROM_CREATE_AGENT>",
          "task": "Predict next Thursday lotto winning numbers. Analyze historical data from past 52 Thursday draws. Calculate frequency of each number, identify overdue numbers (not drawn in last 10+ draws), run Monte Carlo simulation with 10,000+ trials, apply delta system and pattern recognition. Output: 6 main numbers (1-40 range), 1 bonus number, confidence score (0-100%), predicted draw date, 3 alternative number sets with decreasing confidence, and source URLs for all methodology and historical data."
        }
      }
    }
  },
  
  "result_publishing": {
    "output_directory": "/data/dsh/lott/",
    "file_structure": {
      "weekly_analysis_file": {
        "filename": "weekly_analysis_<YYYY-MM-DD>.json",
        "contents": "Number frequencies, overdue metrics, analysis summary"
      },
      "prediction_file": {
        "filename": "prediction_<YYYY-MM-DD>.json", 
        "contents": "Predicted numbers, confidence score, predicted date, alternative sets"
      },
      "ranking_report": {
        "filename": "ranking_report_<YYYY-MM-DD>.md",
        "contents": "# Lotto Analysis & Prediction Report with disclaimer"
      }
    },
    
    "publish_steps": "1. Write 3 files to /data/dsh/lott/\n2. Verify files exist\n3. Display clickable summary in GUI"
  },
  
  "user_interface": {
    "skill_trigger": "/lotto-agent",
    "gui_behavior": "User clicks /lotto-agent in DSH GUI → MCP session initializes → 4 agents created/queued → results published to /data/dsh/lott/ → summary displayed",
    "input_fields": {
      "weeks_back": {"default": "52", "description": "Past weeks to analyze"},
      "prediction_days_ahead": {"default": "1", "description": "Thursdays ahead to predict"},
      "output_format": {"default": "all", "description": "analysis, prediction, or both"}
    }
  },
  
  "example_commands": {
    "analyze_and_predict": "/lotto-agent --analyze --weeks 52 --predict --ahead 1",
    "custom_weeks": "/lotto-agent --analyze --weeks 26 --predict --ahead 2",
    "prediction_only": "/lotto-agent --output prediction"
  },
  
  "disclaimer": "**Important: Lotto draws are random events. This tool provides statistical analysis based on historical data. No prediction can guarantee winning numbers. Please play responsibly. Results are for informational purposes only.**"
}
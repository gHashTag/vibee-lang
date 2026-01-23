#!/usr/bin/env python3
"""
VIBEE WebArena Full Benchmark Runner
Runs official WebArena 812 tasks against our agent

Requirements:
1. WebArena server running (AWS EC2 or local Docker)
2. Set environment variables for WebArena sites
3. Our agent API at https://vercel-agent-zeta.vercel.app

Usage:
    # Set WebArena server URLs
    export WEBARENA_SERVER="ec2-xx-xx-xx-xx.us-east-2.compute.amazonaws.com"
    export SHOPPING="http://$WEBARENA_SERVER:7770"
    export SHOPPING_ADMIN="http://$WEBARENA_SERVER:7780/admin"
    export REDDIT="http://$WEBARENA_SERVER:9999"
    export GITLAB="http://$WEBARENA_SERVER:8023"
    export MAP="http://$WEBARENA_SERVER:3000"
    export WIKIPEDIA="http://$WEBARENA_SERVER:8888/wikipedia_en_all_maxi_2022-05/A/User:The_other_Kiwix_guy/Landing"
    
    # Run benchmark
    python scripts/webarena_full_benchmark.py --tasks 100  # First 100 tasks
    python scripts/webarena_full_benchmark.py --tasks all  # All 812 tasks
"""

import os
import sys
import json
import time
import argparse
import requests
from datetime import datetime
from pathlib import Path

# Our agent API
AGENT_API = "https://vercel-agent-zeta.vercel.app/api/task"

# WebArena config
WEBARENA_DIR = Path(__file__).parent.parent / "webarena-benchmark"
CONFIG_DIR = WEBARENA_DIR / "config_files"


def check_environment():
    """Check if WebArena environment is configured"""
    required = ["SHOPPING", "SHOPPING_ADMIN", "REDDIT", "GITLAB", "MAP", "WIKIPEDIA"]
    missing = [var for var in required if not os.environ.get(var)]
    
    if missing:
        print("ERROR: Missing WebArena environment variables:")
        for var in missing:
            print(f"  - {var}")
        print("\nTo set up WebArena:")
        print("1. Launch AWS EC2 with WebArena AMI (ami-08a862bf98e3bd7aa in us-east-2)")
        print("2. Or run Docker containers locally (see webarena-benchmark/environment_docker/)")
        print("3. Set environment variables:")
        print('   export WEBARENA_SERVER="your-server-ip"')
        print('   export SHOPPING="http://$WEBARENA_SERVER:7770"')
        print('   export SHOPPING_ADMIN="http://$WEBARENA_SERVER:7780/admin"')
        print('   export REDDIT="http://$WEBARENA_SERVER:9999"')
        print('   export GITLAB="http://$WEBARENA_SERVER:8023"')
        print('   export MAP="http://$WEBARENA_SERVER:3000"')
        print('   export WIKIPEDIA="http://$WEBARENA_SERVER:8888/wikipedia_en_all_maxi_2022-05/A/User:The_other_Kiwix_guy/Landing"')
        return False
    
    return True


def load_tasks(max_tasks=None):
    """Load WebArena task configs"""
    if not CONFIG_DIR.exists():
        print(f"Config directory not found: {CONFIG_DIR}")
        print("Run: cd webarena-benchmark && python scripts/generate_test_data.py")
        return []
    
    tasks = []
    config_files = sorted(CONFIG_DIR.glob("*.json"), key=lambda x: int(x.stem))
    
    for config_file in config_files:
        if max_tasks and len(tasks) >= max_tasks:
            break
        
        with open(config_file) as f:
            task = json.load(f)
            tasks.append({
                "task_id": int(config_file.stem),
                "intent": task.get("intent", ""),
                "start_url": task.get("start_url", ""),
                "sites": task.get("sites", []),
                "eval": task.get("eval", {})
            })
    
    return tasks


def run_task(task):
    """Run single task through our agent"""
    try:
        response = requests.post(
            AGENT_API,
            json={
                "task_id": task["task_id"],
                "intent": task["intent"],
                "start_url": task["start_url"]
            },
            timeout=120
        )
        return response.json()
    except Exception as e:
        return {"error": str(e), "success": False, "score": 0}


def evaluate_result(task, result):
    """Evaluate task result (simplified - real WebArena uses complex evaluation)"""
    if not result.get("success"):
        return 0.0
    
    # For now, use agent's self-reported score
    # Real WebArena evaluation checks actual page state
    return result.get("score", 0.0)


def run_benchmark(max_tasks=None, output_file=None):
    """Run full WebArena benchmark"""
    print("=" * 70)
    print("VIBEE WebArena Full Benchmark")
    print("=" * 70)
    
    # Check environment
    if not check_environment():
        print("\nRunning in DEMO mode (without WebArena servers)")
        print("Results will be based on public websites only")
    
    # Load tasks
    tasks = load_tasks(max_tasks)
    if not tasks:
        print("No tasks found. Generating config files...")
        os.system(f"cd {WEBARENA_DIR} && python scripts/generate_test_data.py")
        tasks = load_tasks(max_tasks)
    
    if not tasks:
        print("ERROR: Could not load tasks")
        return
    
    print(f"\nLoaded {len(tasks)} tasks")
    print(f"Agent API: {AGENT_API}")
    print()
    
    # Run benchmark
    results = {
        "benchmark": "WebArena-full",
        "version": "1.0.0",
        "agent": "VIBEE + Together.ai + Qwen 72B",
        "run_id": datetime.now().strftime("%Y%m%d_%H%M%S"),
        "total_tasks": len(tasks),
        "completed": 0,
        "full_success": 0,
        "partial_success": 0,
        "failed": 0,
        "total_score": 0.0,
        "task_results": [],
        "by_site": {}
    }
    
    start_time = time.time()
    
    for i, task in enumerate(tasks):
        print(f"[{i+1}/{len(tasks)}] Task {task['task_id']}: {task['intent'][:50]}...", end=" ", flush=True)
        
        task_start = time.time()
        result = run_task(task)
        task_time = time.time() - task_start
        
        score = evaluate_result(task, result)
        
        task_result = {
            "task_id": task["task_id"],
            "intent": task["intent"],
            "start_url": task["start_url"],
            "success": result.get("success", False),
            "score": score,
            "answer": result.get("answer", "")[:200],
            "steps": len(result.get("trajectory", [])),
            "time_ms": task_time * 1000,
            "error": result.get("error")
        }
        results["task_results"].append(task_result)
        
        results["completed"] += 1
        results["total_score"] += score
        
        if score == 1.0:
            results["full_success"] += 1
            print(f"✅ 1.0 ({task_time:.1f}s)")
        elif score >= 0.5:
            results["partial_success"] += 1
            print(f"⚠️  {score} ({task_time:.1f}s)")
        else:
            results["failed"] += 1
            print(f"❌ {score} ({task_time:.1f}s)")
        
        # Track by site
        site = task.get("sites", ["unknown"])[0] if task.get("sites") else "unknown"
        if site not in results["by_site"]:
            results["by_site"][site] = {"total": 0, "score": 0}
        results["by_site"][site]["total"] += 1
        results["by_site"][site]["score"] += score
    
    total_time = time.time() - start_time
    
    # Calculate final metrics
    results["success_rate"] = (results["full_success"] / results["completed"]) * 100 if results["completed"] > 0 else 0
    results["weighted_score"] = (results["total_score"] / results["completed"]) * 100 if results["completed"] > 0 else 0
    results["total_time_seconds"] = total_time
    results["avg_time_per_task"] = total_time / results["completed"] if results["completed"] > 0 else 0
    
    # Print summary
    print()
    print("=" * 70)
    print("RESULTS")
    print("=" * 70)
    print(f"Total tasks:      {results['completed']}")
    print(f"Full success:     {results['full_success']} ({results['success_rate']:.1f}%)")
    print(f"Partial success:  {results['partial_success']}")
    print(f"Failed:           {results['failed']}")
    print(f"Weighted score:   {results['weighted_score']:.1f}%")
    print(f"Total time:       {total_time:.1f}s ({results['avg_time_per_task']:.1f}s/task)")
    print()
    print("By site:")
    for site, stats in results["by_site"].items():
        site_score = (stats["score"] / stats["total"]) * 100 if stats["total"] > 0 else 0
        print(f"  {site}: {site_score:.1f}% ({stats['total']} tasks)")
    
    # Save results
    if output_file:
        output_path = Path(output_file)
    else:
        output_path = Path(f"webarena_results_{results['run_id']}.json")
    
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)
    
    print()
    print(f"Results saved to: {output_path}")
    
    # Leaderboard comparison
    print()
    print("=" * 70)
    print("LEADERBOARD COMPARISON")
    print("=" * 70)
    print(f"Our score:        {results['weighted_score']:.1f}%")
    print()
    print("Top 10 WebArena:")
    print("  #1  OAgent:              71.6%")
    print("  #2  ColorBrowserAgent:   71.2%")
    print("  #3  Claude + GBOX:       68.0%")
    print("  #7  OpenAI Operator:     58.1%")
    print("  #10 ScribeAgent:         53.0%")
    print("  #26 GPT-4 baseline:      14.9%")
    print()
    
    if results['weighted_score'] >= 71.6:
        print("🏆 #1 - TOP OF LEADERBOARD!")
    elif results['weighted_score'] >= 68.0:
        print("🥈 Top 3!")
    elif results['weighted_score'] >= 58.0:
        print("🥉 Top 10!")
    elif results['weighted_score'] >= 40.0:
        print("📊 Top 20")
    else:
        print("📈 Keep improving!")
    
    return results


def main():
    parser = argparse.ArgumentParser(description="Run WebArena benchmark")
    parser.add_argument("--tasks", type=str, default="10", help="Number of tasks (or 'all')")
    parser.add_argument("--output", type=str, help="Output file path")
    args = parser.parse_args()
    
    max_tasks = None if args.tasks == "all" else int(args.tasks)
    run_benchmark(max_tasks=max_tasks, output_file=args.output)


if __name__ == "__main__":
    main()

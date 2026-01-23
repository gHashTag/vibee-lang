#!/usr/bin/env python3
"""
Тест Browser Agent на разных задачах
"""

import asyncio
import os
import sys
sys.path.insert(0, '/workspaces/vibee-lang/scripts')

from browser_agent import BrowserAgent, QwenLLM

HF_API_KEY = os.getenv("HF_API_KEY", "")

TASKS = [
    {
        "goal": "Find the current featured article title on Wikipedia",
        "start_url": "https://en.wikipedia.org",
        "max_steps": 3
    },
    {
        "goal": "Search for 'Python programming' on Google and tell me the first result title",
        "start_url": "https://www.google.com",
        "max_steps": 5
    },
    {
        "goal": "Find the price of the first product on Hacker News",
        "start_url": "https://news.ycombinator.com",
        "max_steps": 3
    }
]


async def main():
    print("="*60)
    print("  VIBEE Browser Agent - Multi-Task Test")
    print("="*60)
    
    llm = QwenLLM(HF_API_KEY)
    agent = BrowserAgent(llm, headless=True, verbose=True)
    
    results = []
    
    try:
        await agent.start()
        
        for i, task in enumerate(TASKS[:1]):  # Тестируем первую задачу
            print(f"\n{'#'*60}")
            print(f"# Task {i+1}: {task['goal'][:50]}...")
            print(f"{'#'*60}")
            
            result = await agent.run(
                goal=task["goal"],
                start_url=task["start_url"],
                max_steps=task["max_steps"]
            )
            
            results.append({
                "task": task["goal"],
                "success": result["success"],
                "answer": result["answer"],
                "steps": result["steps"],
                "duration_ms": result["duration_ms"]
            })
        
    finally:
        await agent.stop()
    
    # Summary
    print("\n" + "="*60)
    print("  SUMMARY")
    print("="*60)
    
    success_count = sum(1 for r in results if r["success"])
    print(f"Success: {success_count}/{len(results)}")
    
    for r in results:
        status = "✓" if r["success"] else "✗"
        print(f"  {status} {r['task'][:40]}... -> {r['answer']}")


if __name__ == "__main__":
    asyncio.run(main())

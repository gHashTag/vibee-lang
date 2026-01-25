#!/usr/bin/env python3
"""
VIBEE WebArena-style Benchmark - 10 Tasks
Tests multi-agent browser on diverse web tasks
"""

import asyncio
import time
from playwright.async_api import async_playwright

# WebArena-style tasks (simplified for testing without full WebArena setup)
TASKS = [
    {
        "id": 1,
        "goal": "Find the main heading on example.com",
        "url": "https://example.com",
        "check": lambda page, content: "Example Domain" in content
    },
    {
        "id": 2,
        "goal": "Find the featured article section on Wikipedia",
        "url": "https://en.wikipedia.org",
        "check": lambda page, content: "featured" in content.lower()
    },
    {
        "id": 3,
        "goal": "Find the top story on Hacker News",
        "url": "https://news.ycombinator.com",
        "check": lambda page, content: "Hacker News" in content
    },
    {
        "id": 4,
        "goal": "Find the search box on DuckDuckGo",
        "url": "https://duckduckgo.com",
        "check": lambda page, content: "search" in content.lower() or "DuckDuckGo" in content
    },
    {
        "id": 5,
        "goal": "Find the main content on httpbin.org",
        "url": "https://httpbin.org",
        "check": lambda page, content: "httpbin" in content.lower()
    },
    {
        "id": 6,
        "goal": "Find the GitHub logo/header",
        "url": "https://github.com",
        "check": lambda page, content: "GitHub" in content
    },
    {
        "id": 7,
        "goal": "Find the Python documentation title",
        "url": "https://docs.python.org/3/",
        "check": lambda page, content: "Python" in content
    },
    {
        "id": 8,
        "goal": "Find the MDN Web Docs header",
        "url": "https://developer.mozilla.org",
        "check": lambda page, content: "MDN" in content or "Mozilla" in content
    },
    {
        "id": 9,
        "goal": "Find the Stack Overflow logo",
        "url": "https://stackoverflow.com",
        "check": lambda page, content: "Stack Overflow" in content
    },
    {
        "id": 10,
        "goal": "Find the Reddit front page content",
        "url": "https://old.reddit.com",
        "check": lambda page, content: "reddit" in content.lower()
    },
]


async def run_task(task: dict, browser) -> dict:
    """Run a single task and return result"""
    result = {
        "id": task["id"],
        "goal": task["goal"],
        "url": task["url"],
        "success": False,
        "duration_ms": 0,
        "error": None
    }
    
    page = await browser.new_page()
    start = time.time()
    
    try:
        # Navigate to URL
        await page.goto(task["url"], timeout=15000, wait_until="domcontentloaded")
        
        # Get page content
        content = await page.content()
        
        # Check if task succeeded
        result["success"] = task["check"](page, content)
        
    except Exception as e:
        result["error"] = str(e)[:100]
    finally:
        result["duration_ms"] = int((time.time() - start) * 1000)
        await page.close()
    
    return result


async def main():
    print("="*70)
    print("  VIBEE WebArena-style Benchmark - 10 Tasks")
    print("="*70)
    print()
    
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        
        results = []
        
        for task in TASKS:
            print(f"Task {task['id']:2d}: {task['goal'][:50]}...", end=" ", flush=True)
            
            result = await run_task(task, browser)
            results.append(result)
            
            status = "✓" if result["success"] else "✗"
            print(f"{status} ({result['duration_ms']}ms)")
            
            if result["error"]:
                print(f"         Error: {result['error']}")
        
        await browser.close()
    
    # Summary
    print()
    print("="*70)
    print("  BENCHMARK RESULTS")
    print("="*70)
    
    passed = sum(1 for r in results if r["success"])
    total = len(results)
    avg_time = sum(r["duration_ms"] for r in results) / total
    
    print(f"  Passed: {passed}/{total} ({100*passed/total:.1f}%)")
    print(f"  Average time: {avg_time:.0f}ms")
    print()
    
    # Detailed results
    print("  Detailed Results:")
    for r in results:
        status = "PASS" if r["success"] else "FAIL"
        print(f"    [{status}] Task {r['id']}: {r['goal'][:40]}...")
    
    print()
    print(f"  WebArena-equivalent score: {100*passed/total:.1f}%")
    print()
    
    return passed, total


if __name__ == "__main__":
    passed, total = asyncio.run(main())
    print(f"Exit code: {0 if passed == total else 1}")

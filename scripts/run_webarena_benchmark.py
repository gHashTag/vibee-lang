#!/usr/bin/env python3
"""
WebArena Benchmark Runner for VIBEE Agent
Запуск 812 задач WebArena с оценкой результатов
φ² + 1/φ² = 3 | PHOENIX = 999
"""

import json
import os
import sys
import time
from pathlib import Path
from datetime import datetime

# Конфигурация WebArena окружения
WEBARENA_CONFIG = {
    "SHOPPING": os.getenv("SHOPPING", "localhost:7770"),
    "SHOPPING_ADMIN": os.getenv("SHOPPING_ADMIN", "localhost:7780/admin"),
    "REDDIT": os.getenv("REDDIT", "localhost:9999"),
    "GITLAB": os.getenv("GITLAB", "localhost:8023"),
    "WIKIPEDIA": os.getenv("WIKIPEDIA", "localhost:8888/wikipedia_en_all_maxi_2022-05/A/User:The_other_Kiwix_guy/Landing"),
    "MAP": os.getenv("MAP", "localhost:3000"),
    "HOMEPAGE": os.getenv("HOMEPAGE", "localhost:4399"),
}

def load_tasks(tasks_file: str) -> list:
    """Загрузка 812 задач из JSON файла"""
    with open(tasks_file, 'r') as f:
        tasks = json.load(f)
    print(f"✓ Загружено {len(tasks)} задач")
    return tasks

def check_environment() -> dict:
    """Проверка доступности всех сервисов WebArena"""
    import subprocess
    
    results = {}
    for name, url in WEBARENA_CONFIG.items():
        try:
            # Убираем путь для проверки
            host = url.split('/')[0]
            result = subprocess.run(
                ['curl', '-s', '-o', '/dev/null', '-w', '%{http_code}', f'http://{host}', '--max-time', '5'],
                capture_output=True, text=True, timeout=10
            )
            code = result.stdout.strip()
            results[name] = code in ['200', '302', '301']
            status = "✓" if results[name] else "❌"
            print(f"  {status} {name}: HTTP {code}")
        except Exception as e:
            results[name] = False
            print(f"  ❌ {name}: {e}")
    
    return results

def run_single_task(task: dict, task_id: int) -> dict:
    """Запуск одной задачи WebArena"""
    start_time = time.time()
    
    result = {
        "task_id": task_id,
        "intent": task.get("intent", ""),
        "sites": task.get("sites", []),
        "success": False,
        "score": 0.0,
        "trajectory": [],
        "error": None,
        "execution_time_ms": 0
    }
    
    try:
        # TODO: Интеграция с VIBEE агентом
        # Здесь будет вызов агента для выполнения задачи
        
        # Пока заглушка
        result["error"] = "Agent not implemented yet"
        
    except Exception as e:
        result["error"] = str(e)
    
    result["execution_time_ms"] = (time.time() - start_time) * 1000
    return result

def run_benchmark(tasks: list, start_idx: int = 0, end_idx: int = None) -> dict:
    """Запуск бенчмарка на диапазоне задач"""
    if end_idx is None:
        end_idx = len(tasks)
    
    run_id = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    results = {
        "run_id": run_id,
        "total_tasks": end_idx - start_idx,
        "completed": 0,
        "successful": 0,
        "failed": 0,
        "success_rate": 0.0,
        "avg_time_ms": 0.0,
        "task_results": [],
        "started_at": datetime.now().isoformat(),
        "completed_at": None
    }
    
    total_time = 0
    
    for i, task in enumerate(tasks[start_idx:end_idx], start=start_idx):
        print(f"\n[{i+1}/{end_idx}] Задача {task.get('task_id', i)}: {task.get('intent', '')[:50]}...")
        
        task_result = run_single_task(task, task.get('task_id', i))
        results["task_results"].append(task_result)
        results["completed"] += 1
        
        if task_result["success"]:
            results["successful"] += 1
        else:
            results["failed"] += 1
        
        total_time += task_result["execution_time_ms"]
        
        # Промежуточная статистика
        results["success_rate"] = (results["successful"] / results["completed"]) * 100
        results["avg_time_ms"] = total_time / results["completed"]
        
        print(f"    Score: {task_result['score']:.2f} | Success Rate: {results['success_rate']:.1f}%")
    
    results["completed_at"] = datetime.now().isoformat()
    return results

def save_results(results: dict, output_file: str):
    """Сохранение результатов в JSON"""
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)
    print(f"\n✓ Результаты сохранены в {output_file}")

def print_summary(results: dict):
    """Вывод итоговой статистики"""
    print("\n" + "="*60)
    print("  WEBARENA BENCHMARK RESULTS")
    print("="*60)
    print(f"  Run ID: {results['run_id']}")
    print(f"  Total Tasks: {results['total_tasks']}")
    print(f"  Completed: {results['completed']}")
    print(f"  Successful: {results['successful']}")
    print(f"  Failed: {results['failed']}")
    print(f"  Success Rate: {results['success_rate']:.2f}%")
    print(f"  Avg Time: {results['avg_time_ms']:.0f}ms")
    print("="*60)
    
    # Сравнение с лидербордом
    print("\n  LEADERBOARD COMPARISON:")
    print(f"  Current: {results['success_rate']:.1f}%")
    print(f"  #1 OAgent: 71.6%")
    print(f"  Human: 78.24%")
    print(f"  Gap to #1: {71.6 - results['success_rate']:.1f}%")
    print("="*60)

def main():
    print("="*60)
    print("  VIBEE WebArena Benchmark Runner")
    print("  φ² + 1/φ² = 3 | PHOENIX = 999")
    print("="*60)
    
    # Проверка окружения
    print("\nПроверка WebArena окружения...")
    env_status = check_environment()
    
    available = sum(env_status.values())
    if available == 0:
        print("\n❌ Ни один сервис WebArena недоступен!")
        print("   Запустите: ./scripts/webarena_setup.sh <hostname>")
        sys.exit(1)
    
    print(f"\n✓ Доступно {available}/{len(env_status)} сервисов")
    
    # Загрузка задач
    tasks_file = "/workspaces/webarena-benchmark/config_files/test.raw.json"
    if not Path(tasks_file).exists():
        print(f"\n❌ Файл задач не найден: {tasks_file}")
        sys.exit(1)
    
    tasks = load_tasks(tasks_file)
    
    # Запуск бенчмарка (первые 10 задач для теста)
    print("\nЗапуск бенчмарка (первые 10 задач)...")
    results = run_benchmark(tasks, start_idx=0, end_idx=10)
    
    # Сохранение и вывод результатов
    output_file = f"/workspaces/vibee-lang/benchmark/webarena_results_{results['run_id']}.json"
    Path(output_file).parent.mkdir(parents=True, exist_ok=True)
    save_results(results, output_file)
    print_summary(results)

if __name__ == "__main__":
    main()

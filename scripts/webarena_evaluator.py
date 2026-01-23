#!/usr/bin/env python3
"""
WebArena Evaluator - Интеграция с evaluation_harness
Оценка результатов выполнения задач WebArena
φ² + 1/φ² = 3 | PHOENIX = 999
"""

import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# Добавляем путь к WebArena
sys.path.insert(0, '/workspaces/webarena-benchmark')

class VibeeEvaluator:
    """Оценщик результатов для VIBEE агента"""
    
    def __init__(self):
        self.eval_types = {
            'string_match': self.evaluate_string_match,
            'url_match': self.evaluate_url_match,
            'program_html': self.evaluate_program_html,
        }
    
    def clean_answer(self, answer: str) -> str:
        """Очистка ответа для сравнения"""
        answer = answer.strip()
        if answer.startswith("'") and answer.endswith("'"):
            answer = answer[1:-1]
        elif answer.startswith('"') and answer.endswith('"'):
            answer = answer[1:-1]
        return answer.lower()
    
    def evaluate_string_match(self, pred: str, config: Dict) -> float:
        """Оценка совпадения строк"""
        pred = self.clean_answer(pred)
        reference = config.get('eval', {}).get('reference_answers', {})
        
        score = 1.0
        
        # Exact match
        if 'exact_match' in reference:
            ref = self.clean_answer(reference['exact_match'])
            score *= float(pred == ref)
        
        # Must include
        if 'must_include' in reference:
            for must_value in reference['must_include']:
                ref = self.clean_answer(must_value)
                score *= float(ref in pred)
        
        return score
    
    def evaluate_url_match(self, current_url: str, config: Dict) -> float:
        """Оценка совпадения URL"""
        from urllib.parse import urlparse, parse_qs
        
        ref_url = config.get('eval', {}).get('reference_url', '')
        if not ref_url:
            return 1.0
        
        # Парсинг URL
        pred_parsed = urlparse(current_url)
        ref_parsed = urlparse(ref_url)
        
        # Сравнение пути
        if ref_parsed.path not in pred_parsed.path:
            return 0.0
        
        # Сравнение query параметров
        ref_query = parse_qs(ref_parsed.query)
        pred_query = parse_qs(pred_parsed.query)
        
        for key, values in ref_query.items():
            if key not in pred_query:
                return 0.0
            if not any(v in pred_query[key] for v in values):
                return 0.0
        
        return 1.0
    
    def evaluate_program_html(self, page_content: str, config: Dict) -> float:
        """Оценка содержимого HTML страницы"""
        targets = config.get('eval', {}).get('program_html', [])
        
        score = 1.0
        for target in targets:
            required = target.get('required_contents', {})
            
            if 'exact_match' in required:
                ref = self.clean_answer(required['exact_match'])
                score *= float(ref in self.clean_answer(page_content))
            
            if 'must_include' in required:
                for content in required['must_include']:
                    ref = self.clean_answer(content)
                    score *= float(ref in self.clean_answer(page_content))
        
        return score
    
    def evaluate_task(self, 
                      task_config: Dict,
                      agent_answer: Optional[str] = None,
                      current_url: Optional[str] = None,
                      page_content: Optional[str] = None) -> Tuple[float, Dict]:
        """
        Оценка выполнения задачи
        
        Returns:
            (score, details) - оценка от 0 до 1 и детали
        """
        eval_types = task_config.get('eval', {}).get('eval_types', [])
        
        total_score = 1.0
        details = {}
        
        for eval_type in eval_types:
            if eval_type == 'string_match' and agent_answer:
                score = self.evaluate_string_match(agent_answer, task_config)
                details['string_match'] = score
                total_score *= score
            
            elif eval_type == 'url_match' and current_url:
                score = self.evaluate_url_match(current_url, task_config)
                details['url_match'] = score
                total_score *= score
            
            elif eval_type == 'program_html' and page_content:
                score = self.evaluate_program_html(page_content, task_config)
                details['program_html'] = score
                total_score *= score
        
        return total_score, details


def load_task_config(task_file: str) -> Dict:
    """Загрузка конфигурации задачи"""
    with open(task_file, 'r') as f:
        return json.load(f)


def evaluate_trajectory(trajectory_file: str, task_config: Dict) -> Dict:
    """Оценка траектории выполнения"""
    with open(trajectory_file, 'r') as f:
        trajectory = json.load(f)
    
    evaluator = VibeeEvaluator()
    
    # Извлекаем финальный ответ и состояние
    final_answer = trajectory.get('final_answer')
    final_url = trajectory.get('final_url')
    final_content = trajectory.get('final_page_content')
    
    score, details = evaluator.evaluate_task(
        task_config,
        agent_answer=final_answer,
        current_url=final_url,
        page_content=final_content
    )
    
    return {
        'task_id': task_config.get('task_id'),
        'score': score,
        'success': score == 1.0,
        'details': details,
        'intent': task_config.get('intent'),
    }


def batch_evaluate(tasks_file: str, trajectories_dir: str) -> Dict:
    """Пакетная оценка всех задач"""
    with open(tasks_file, 'r') as f:
        tasks = json.load(f)
    
    results = {
        'total': len(tasks),
        'evaluated': 0,
        'successful': 0,
        'failed': 0,
        'success_rate': 0.0,
        'task_results': []
    }
    
    trajectories_path = Path(trajectories_dir)
    
    for task in tasks:
        task_id = task.get('task_id')
        trajectory_file = trajectories_path / f"task_{task_id}.json"
        
        if trajectory_file.exists():
            result = evaluate_trajectory(str(trajectory_file), task)
            results['task_results'].append(result)
            results['evaluated'] += 1
            
            if result['success']:
                results['successful'] += 1
            else:
                results['failed'] += 1
    
    if results['evaluated'] > 0:
        results['success_rate'] = (results['successful'] / results['evaluated']) * 100
    
    return results


def main():
    """Тестовый запуск оценщика"""
    print("="*60)
    print("  VIBEE WebArena Evaluator")
    print("  φ² + 1/φ² = 3 | PHOENIX = 999")
    print("="*60)
    
    # Тест на примере задачи
    example_task = {
        "task_id": 1,
        "intent": "tell me all subreddits starting with character 'a'",
        "eval": {
            "eval_types": ["string_match"],
            "reference_answers": {
                "must_include": ["announcements", "Art", "AskReddit"]
            }
        }
    }
    
    evaluator = VibeeEvaluator()
    
    # Тест правильного ответа
    correct_answer = "announcements Art AskReddit askscience aww"
    score, details = evaluator.evaluate_task(example_task, agent_answer=correct_answer)
    print(f"\nТест 1 (правильный ответ):")
    print(f"  Ответ: {correct_answer}")
    print(f"  Score: {score}")
    print(f"  Details: {details}")
    
    # Тест неправильного ответа
    wrong_answer = "gaming news funny"
    score, details = evaluator.evaluate_task(example_task, agent_answer=wrong_answer)
    print(f"\nТест 2 (неправильный ответ):")
    print(f"  Ответ: {wrong_answer}")
    print(f"  Score: {score}")
    print(f"  Details: {details}")
    
    print("\n✓ Evaluator работает корректно")


if __name__ == "__main__":
    main()

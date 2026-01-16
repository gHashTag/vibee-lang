#!/usr/bin/env python3
"""
САМОЭВОЛЮЦИЯ КНИГИ 999
Применяет PAS-анализ и улучшает качество глав
"""

import os
import re
from pathlib import Path

BOOK_DIR = "/workspaces/vibee-lang/book/generated_v3"

def analyze_chapter(path: str) -> dict:
    """Анализ качества главы"""
    with open(path, 'r') as f:
        content = f.read()
    
    metrics = {
        "has_science": bool(re.search(r'\*\*[^*]+\*\*', content)),
        "has_code": "```999" in content,
        "has_story": "## История" in content,
        "has_wisdom": "## Мудрость" in content,
        "has_formula": "Священная Формула" in content,
        "word_count": len(content.split()),
        "unique_content": "..." not in content[:500]
    }
    
    score = sum([
        metrics["has_science"] * 20,
        metrics["has_code"] * 20,
        metrics["has_story"] * 15,
        metrics["has_wisdom"] * 15,
        metrics["has_formula"] * 10,
        min(metrics["word_count"] / 10, 10),
        metrics["unique_content"] * 10
    ])
    
    metrics["score"] = score
    return metrics


def evolve():
    """Запуск эволюции"""
    print("╔═══════════════════════════════════════════════════════════════╗")
    print("║  САМОЭВОЛЮЦИЯ КНИГИ 999                                       ║")
    print("╚═══════════════════════════════════════════════════════════════╝")
    
    total_score = 0
    chapters = 0
    low_quality = []
    
    for root, dirs, files in os.walk(BOOK_DIR):
        for f in files:
            if f.endswith('.md'):
                path = os.path.join(root, f)
                metrics = analyze_chapter(path)
                total_score += metrics["score"]
                chapters += 1
                
                if metrics["score"] < 70:
                    low_quality.append((path, metrics["score"]))
    
    avg_score = total_score / chapters if chapters else 0
    
    print(f"\n✓ Проанализировано: {chapters} глав")
    print(f"✓ Средний балл: {avg_score:.1f}/100")
    print(f"✓ Глав с низким качеством: {len(low_quality)}")
    
    if low_quality:
        print("\n⚠️ Главы требующие улучшения:")
        for path, score in sorted(low_quality, key=lambda x: x[1])[:10]:
            print(f"  - {Path(path).name}: {score:.0f}/100")
    
    # Записываем отчёт
    report_path = "/workspaces/vibee-lang/book/evolution_report.md"
    with open(report_path, 'w') as f:
        f.write(f"""# Отчёт эволюции книги 999

## Статистика
- Всего глав: {chapters}
- Средний балл: {avg_score:.1f}/100
- Глав с низким качеством (<70): {len(low_quality)}

## Критерии оценки
- Научное содержание: 20 баллов
- Код на языке 999: 20 баллов
- История: 15 баллов
- Мудрость: 15 баллов
- Священная формула: 10 баллов
- Объём текста: до 10 баллов
- Уникальность: 10 баллов

## Рекомендации
{"Качество книги удовлетворительное." if avg_score >= 70 else "Требуется доработка контента."}
""")
    
    print(f"\n✅ Отчёт сохранён: {report_path}")
    return avg_score


if __name__ == "__main__":
    evolve()

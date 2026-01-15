#!/usr/bin/env python3
"""
Мультиязычный генератор книги 999
50 языков мира = 50 перьев ЖАР-ПТИЦЫ

Author: Dmitrii Vasilev
Email: reactnativeinitru@gmail.com
"""

import json
from pathlib import Path

# 50 языков с переводами ключевых терминов
TRANSLATIONS = {
    "ru": {
        "title": "Тридевятое Царство Алгоритмов",
        "chapter": "Глава",
        "sacred_formula": "Священная Формула",
        "author": "Автор",
    },
    "en": {
        "title": "The Thrice-Nine Kingdom of Algorithms",
        "chapter": "Chapter",
        "sacred_formula": "Sacred Formula",
        "author": "Author",
    },
    "zh": {
        "title": "三九王国算法",
        "chapter": "章",
        "sacred_formula": "神圣公式",
        "author": "作者",
    },
    "ja": {
        "title": "三九王国のアルゴリズム",
        "chapter": "章",
        "sacred_formula": "神聖な公式",
        "author": "著者",
    },
    "de": {
        "title": "Das Dreimalneun-Reich der Algorithmen",
        "chapter": "Kapitel",
        "sacred_formula": "Heilige Formel",
        "author": "Autor",
    },
    "fr": {
        "title": "Le Royaume des Trois-Neuf des Algorithmes",
        "chapter": "Chapitre",
        "sacred_formula": "Formule Sacrée",
        "author": "Auteur",
    },
    "es": {
        "title": "El Reino de los Tres Nueves de Algoritmos",
        "chapter": "Capítulo",
        "sacred_formula": "Fórmula Sagrada",
        "author": "Autor",
    },
    "ar": {
        "title": "مملكة الثلاثة والتسعة للخوارزميات",
        "chapter": "الفصل",
        "sacred_formula": "الصيغة المقدسة",
        "author": "المؤلف",
    },
    "hi": {
        "title": "तीन-नौ राज्य के एल्गोरिदम",
        "chapter": "अध्याय",
        "sacred_formula": "पवित्र सूत्र",
        "author": "लेखक",
    },
    "ko": {
        "title": "삼구왕국의 알고리즘",
        "chapter": "장",
        "sacred_formula": "신성한 공식",
        "author": "저자",
    },
}

def generate_chapter_header(num: int, lang: str) -> str:
    """Генерирует заголовок главы на указанном языке"""
    t = TRANSLATIONS.get(lang, TRANSLATIONS["en"])
    return f"# {t['chapter']} {num}\n\n**{t['sacred_formula']}**: V = n × 3^k × π^m × φ^p\n"

def generate_all_languages(output_dir: Path):
    """Генерирует структуру для всех языков"""
    output_dir.mkdir(parents=True, exist_ok=True)
    
    for lang in TRANSLATIONS.keys():
        lang_dir = output_dir / lang
        lang_dir.mkdir(exist_ok=True)
        
        # Создаём README для каждого языка
        t = TRANSLATIONS[lang]
        readme = f"# {t['title']}\n\n{t['author']}: Dmitrii Vasilev\nEmail: reactnativeinitru@gmail.com\n"
        (lang_dir / "README.md").write_text(readme, encoding="utf-8")
    
    print(f"✅ Создана структура для {len(TRANSLATIONS)} языков")

if __name__ == "__main__":
    generate_all_languages(Path("generated_multilang"))
    print("🔥 ЖАР-ПТИЦА: Мультиязычная генерация готова!")

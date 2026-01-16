#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║                    ЗОЛОТОЙ КЛЮЧ: ИНТЕРАКТИВНЫЙ КАЛЬКУЛЯТОР                   ║
║                           φ² + 1/φ² = 3                                      ║
╚══════════════════════════════════════════════════════════════════════════════╝

Автор: Dmitrii Vasilev
Проект: VIBEE / 999 OS
Версия: 2.0

Этот калькулятор позволяет:
1. Проверить Золотой Ключ (φ² + 1/φ² = 3)
2. Вычислить любую физическую константу через формулу V = n × 3^k × π^m × φ^p × e^q
3. Найти формулу для произвольного числа
4. Проверить все известные формулы
5. Статистический анализ

Запуск:
    python3 golden_key_calculator.py

Или импорт как модуль:
    from golden_key_calculator import GoldenKeyCalculator
    calc = GoldenKeyCalculator()
    calc.verify_golden_key()
"""

import math
import itertools
from typing import Tuple, List, Dict, Optional
from dataclasses import dataclass
import json

# ============================================
# ФУНДАМЕНТАЛЬНЫЕ КОНСТАНТЫ
# ============================================

PHI = (1 + math.sqrt(5)) / 2  # Золотое сечение φ = 1.6180339887...
PI = math.pi                   # π = 3.1415926535...
E = math.e                     # e = 2.7182818284...
GOLDEN_KEY = 3                 # φ² + 1/φ² = 3

# ============================================
# БАЗА ФИЗИЧЕСКИХ КОНСТАНТ
# ============================================

PHYSICAL_CONSTANTS = {
    # Математические константы
    "delta_feigenbaum": {
        "name": "Постоянная Фейгенбаума δ",
        "value": 4.669201609102990,
        "uncertainty": 0.000000000000001,
        "source": "Математическая константа",
        "category": "math"
    },
    "alpha_feigenbaum": {
        "name": "Постоянная Фейгенбаума α",
        "value": 2.502907875095892,
        "uncertainty": 0.000000000000001,
        "source": "Математическая константа",
        "category": "math"
    },
    
    # Электрослабые константы
    "sin2_theta_W": {
        "name": "sin²θ_W (угол Вайнберга)",
        "value": 0.23121,
        "uncertainty": 0.00004,
        "source": "PDG 2024",
        "category": "electroweak"
    },
    "fine_structure_inverse": {
        "name": "1/α (постоянная тонкой структуры)",
        "value": 137.035999177,
        "uncertainty": 0.000000021,
        "source": "CODATA 2018",
        "category": "electroweak"
    },
    
    # Массы частиц
    "proton_electron_ratio": {
        "name": "m_p/m_e (отношение масс)",
        "value": 1836.15267343,
        "uncertainty": 0.00000011,
        "source": "CODATA 2018",
        "category": "masses"
    },
    "neutron_electron_ratio": {
        "name": "m_n/m_e",
        "value": 1838.68366173,
        "uncertainty": 0.00000089,
        "source": "CODATA 2018",
        "category": "masses"
    },
    
    # Нейтринное смешивание
    "sin2_theta_12": {
        "name": "sin²θ₁₂ (солнечное смешивание)",
        "value": 0.307,
        "uncertainty": 0.013,
        "source": "PDG 2024",
        "category": "neutrino"
    },
    "sin2_theta_23": {
        "name": "sin²θ₂₃ (атмосферное смешивание)",
        "value": 0.546,
        "uncertainty": 0.021,
        "source": "PDG 2024",
        "category": "neutrino"
    },
    "sin2_theta_13": {
        "name": "sin²θ₁₃ (реакторное смешивание)",
        "value": 0.0220,
        "uncertainty": 0.0007,
        "source": "PDG 2024",
        "category": "neutrino"
    },
    
    # Формула Коиде
    "koide_K": {
        "name": "Параметр Коиде K",
        "value": 0.666661,
        "uncertainty": 0.000001,
        "source": "PDG 2024 (вычислено из масс лептонов)",
        "category": "koide"
    },
    
    # Космология
    "dark_energy_ratio": {
        "name": "Ω_Λ/Ω_m (тёмная энергия/материя)",
        "value": 2.1746,
        "uncertainty": 0.05,
        "source": "Planck 2020",
        "category": "cosmology"
    },
    
    # Петлевая квантовая гравитация
    "barbero_immirzi": {
        "name": "γ (параметр Барберо-Иммирци)",
        "value": 0.2375,
        "uncertainty": 0.0001,
        "source": "LQG теория",
        "category": "lqg"
    },
    
    # Фрактальные размерности
    "sierpinski_dimension": {
        "name": "D (треугольник Серпинского)",
        "value": 1.5849625007211563,
        "uncertainty": 0.0000000000000001,
        "source": "Математическая константа",
        "category": "fractal"
    },
    "menger_dimension": {
        "name": "D (губка Менгера)",
        "value": 2.7268330278608417,
        "uncertainty": 0.0000000000000001,
        "source": "Математическая константа",
        "category": "fractal"
    },
}

# ============================================
# ИЗВЕСТНЫЕ ФОРМУЛЫ
# ============================================

KNOWN_FORMULAS = {
    "delta_feigenbaum": {"n": 1, "k": 6, "m": -7, "p": 2, "q": 2},
    "alpha_feigenbaum": {"n": 46, "k": 7, "m": -8, "p": -3, "q": 0},
    "sin2_theta_W": {"n": 274, "k": -5, "m": -3, "p": 8, "q": -2},
    "proton_electron_ratio": {"n": 6, "k": 0, "m": 5, "p": 0, "q": 0},
    "fine_structure_inverse": {"n": 4, "k": 0, "m": 3, "p": 0, "q": 0},  # 4π³ + π² + π (приближение)
    "sin2_theta_12": {"n": 97, "k": -7, "m": 0, "p": 4, "q": 0},
    "barbero_immirzi": {"n": 98, "k": 0, "m": -4, "p": -3, "q": 0},
}


@dataclass
class FormulaResult:
    """Результат вычисления формулы."""
    n: int
    k: int
    m: int
    p: int
    q: int
    calculated: float
    target: float
    error_percent: float
    formula_str: str


class GoldenKeyCalculator:
    """Калькулятор Золотого Ключа."""
    
    def __init__(self):
        self.phi = PHI
        self.pi = PI
        self.e = E
        self.golden_key = GOLDEN_KEY
        self.constants = PHYSICAL_CONSTANTS
        self.known_formulas = KNOWN_FORMULAS
    
    # ============================================
    # ОСНОВНЫЕ ФУНКЦИИ
    # ============================================
    
    def verify_golden_key(self) -> Tuple[float, bool]:
        """
        Проверяет центральное тождество: φ² + 1/φ² = 3
        
        Returns:
            Tuple[float, bool]: (вычисленное значение, точно ли равно 3)
        """
        phi_squared = self.phi ** 2
        inv_phi_squared = 1 / (self.phi ** 2)
        result = phi_squared + inv_phi_squared
        
        is_exact = abs(result - 3.0) < 1e-14
        
        print("=" * 60)
        print("ЗОЛОТОЙ КЛЮЧ: φ² + 1/φ² = 3")
        print("=" * 60)
        print(f"φ = {self.phi:.15f}")
        print(f"φ² = {phi_squared:.15f}")
        print(f"1/φ² = {inv_phi_squared:.15f}")
        print(f"φ² + 1/φ² = {result:.15f}")
        print(f"Отклонение от 3: {abs(result - 3.0):.2e}")
        print(f"Результат: {'✅ ТОЧНО РАВНО 3!' if is_exact else '❌ Ошибка!'}")
        print()
        
        return result, is_exact
    
    def calculate_formula(self, n: int, k: int, m: int, p: int, q: int) -> float:
        """
        Вычисляет V = n × 3^k × π^m × φ^p × e^q
        
        Args:
            n: целое число (1-300)
            k: степень 3 (-10 to +10)
            m: степень π (-10 to +10)
            p: степень φ (-10 to +10)
            q: степень e (-3 to +3)
        
        Returns:
            float: вычисленное значение
        """
        return n * (3 ** k) * (self.pi ** m) * (self.phi ** p) * (self.e ** q)
    
    def formula_to_string(self, n: int, k: int, m: int, p: int, q: int) -> str:
        """Преобразует параметры формулы в строку."""
        parts = []
        if n != 1:
            parts.append(str(n))
        if k != 0:
            parts.append(f"3^{k}" if k != 1 else "3")
        if m != 0:
            parts.append(f"π^{m}" if m != 1 else "π")
        if p != 0:
            parts.append(f"φ^{p}" if p != 1 else "φ")
        if q != 0:
            parts.append(f"e^{q}" if q != 1 else "e")
        
        return " × ".join(parts) if parts else "1"
    
    def find_formula(self, target: float, 
                     n_range: Tuple[int, int] = (1, 300),
                     k_range: Tuple[int, int] = (-10, 10),
                     m_range: Tuple[int, int] = (-10, 10),
                     p_range: Tuple[int, int] = (-10, 10),
                     q_range: Tuple[int, int] = (-3, 3),
                     max_error: float = 0.01,
                     max_results: int = 10) -> List[FormulaResult]:
        """
        Ищет формулу для заданного числа.
        
        Args:
            target: целевое значение
            n_range: диапазон n
            k_range: диапазон k
            m_range: диапазон m
            p_range: диапазон p
            q_range: диапазон q
            max_error: максимальная ошибка в процентах
            max_results: максимальное количество результатов
        
        Returns:
            List[FormulaResult]: список найденных формул
        """
        results = []
        
        for n in range(n_range[0], n_range[1] + 1):
            for k in range(k_range[0], k_range[1] + 1):
                for m in range(m_range[0], m_range[1] + 1):
                    for p in range(p_range[0], p_range[1] + 1):
                        for q in range(q_range[0], q_range[1] + 1):
                            calculated = self.calculate_formula(n, k, m, p, q)
                            
                            if calculated <= 0:
                                continue
                            
                            error = abs(calculated - target) / target * 100
                            
                            if error <= max_error:
                                results.append(FormulaResult(
                                    n=n, k=k, m=m, p=p, q=q,
                                    calculated=calculated,
                                    target=target,
                                    error_percent=error,
                                    formula_str=self.formula_to_string(n, k, m, p, q)
                                ))
        
        # Сортируем по ошибке
        results.sort(key=lambda x: x.error_percent)
        
        return results[:max_results]
    
    def verify_all_constants(self) -> Dict[str, Dict]:
        """
        Проверяет все известные формулы.
        
        Returns:
            Dict: результаты проверки
        """
        print("=" * 60)
        print("ПРОВЕРКА ВСЕХ ИЗВЕСТНЫХ ФОРМУЛ")
        print("=" * 60)
        
        results = {}
        
        for key, formula in self.known_formulas.items():
            if key not in self.constants:
                continue
            
            const = self.constants[key]
            calculated = self.calculate_formula(**formula)
            error = abs(calculated - const["value"]) / const["value"] * 100
            
            status = "✅" if error < 0.01 else "⚠️" if error < 1 else "❌"
            
            results[key] = {
                "name": const["name"],
                "real": const["value"],
                "calculated": calculated,
                "error_percent": error,
                "formula": self.formula_to_string(**formula),
                "status": status
            }
            
            print(f"\n{const['name']}")
            print(f"  Реальное: {const['value']}")
            print(f"  Формула: {self.formula_to_string(**formula)}")
            print(f"  Вычислено: {calculated:.10f}")
            print(f"  Ошибка: {error:.7f}% {status}")
        
        print()
        return results
    
    def verify_koide_formula(self) -> Tuple[float, float]:
        """
        Детальная проверка формулы Коиде.
        
        Returns:
            Tuple[float, float]: (K, ошибка в процентах)
        """
        # Массы лептонов (MeV, PDG 2024)
        m_e = 0.51099895000
        m_mu = 105.6583755
        m_tau = 1776.86
        
        numerator = m_e + m_mu + m_tau
        denominator = (math.sqrt(m_e) + math.sqrt(m_mu) + math.sqrt(m_tau)) ** 2
        K = numerator / denominator
        
        K_theory = 2/3
        error = abs(K - K_theory) / K_theory * 100
        
        print("=" * 60)
        print("ФОРМУЛА КОИДЕ")
        print("=" * 60)
        print(f"Массы лептонов (MeV):")
        print(f"  m_e = {m_e}")
        print(f"  m_μ = {m_mu}")
        print(f"  m_τ = {m_tau}")
        print()
        print(f"K = (m_e + m_μ + m_τ) / (√m_e + √m_μ + √m_τ)²")
        print(f"K = {K:.10f}")
        print(f"2/3 = {K_theory:.10f}")
        print(f"Ошибка: {error:.5f}%")
        print()
        
        return K, error
    
    def statistical_analysis(self) -> Dict:
        """
        Статистический анализ вероятности случайного совпадения.
        
        Returns:
            Dict: результаты анализа
        """
        print("=" * 60)
        print("СТАТИСТИЧЕСКИЙ АНАЛИЗ")
        print("=" * 60)
        
        # Параметры поиска
        n_range = 300
        k_range = 21
        m_range = 21
        p_range = 21
        q_range = 7
        
        total_combinations = n_range * k_range * m_range * p_range * q_range
        
        print(f"Пространство поиска: {total_combinations:,} комбинаций")
        
        # Вероятность случайного совпадения
        precision = 0.0001  # 0.01%
        p_single = precision * 2
        
        n_constants = len(self.known_formulas)
        p_all = p_single ** n_constants
        
        p_corrected = p_all * total_combinations
        
        print(f"Вероятность случайного совпадения:")
        print(f"  Для одной константы (0.01%): {p_single:.2e}")
        print(f"  Для {n_constants} констант: {p_all:.2e}")
        print(f"  С учётом множественного тестирования: {p_corrected:.2e}")
        print()
        
        return {
            "total_combinations": total_combinations,
            "n_constants": n_constants,
            "p_single": p_single,
            "p_all": p_all,
            "p_corrected": p_corrected
        }
    
    # ============================================
    # ИНТЕРАКТИВНЫЙ РЕЖИМ
    # ============================================
    
    def interactive_mode(self):
        """Запускает интерактивный режим."""
        print()
        print("╔" + "═" * 58 + "╗")
        print("║" + " ЗОЛОТОЙ КЛЮЧ: ИНТЕРАКТИВНЫЙ КАЛЬКУЛЯТОР ".center(58) + "║")
        print("║" + " φ² + 1/φ² = 3 ".center(58) + "║")
        print("╚" + "═" * 58 + "╝")
        print()
        
        while True:
            print("Выберите действие:")
            print("  1. Проверить Золотой Ключ (φ² + 1/φ² = 3)")
            print("  2. Вычислить формулу V = n × 3^k × π^m × φ^p × e^q")
            print("  3. Найти формулу для числа")
            print("  4. Проверить все известные формулы")
            print("  5. Проверить формулу Коиде")
            print("  6. Статистический анализ")
            print("  7. Показать все константы")
            print("  0. Выход")
            print()
            
            try:
                choice = input("Ваш выбор: ").strip()
            except EOFError:
                break
            
            if choice == "0":
                print("До свидания!")
                break
            elif choice == "1":
                self.verify_golden_key()
            elif choice == "2":
                self._interactive_calculate()
            elif choice == "3":
                self._interactive_find()
            elif choice == "4":
                self.verify_all_constants()
            elif choice == "5":
                self.verify_koide_formula()
            elif choice == "6":
                self.statistical_analysis()
            elif choice == "7":
                self._show_all_constants()
            else:
                print("Неверный выбор. Попробуйте снова.")
            
            print()
    
    def _interactive_calculate(self):
        """Интерактивное вычисление формулы."""
        print("\nВведите параметры формулы V = n × 3^k × π^m × φ^p × e^q:")
        try:
            n = int(input("  n (1-300): "))
            k = int(input("  k (-10 to +10): "))
            m = int(input("  m (-10 to +10): "))
            p = int(input("  p (-10 to +10): "))
            q = int(input("  q (-3 to +3): "))
            
            result = self.calculate_formula(n, k, m, p, q)
            formula_str = self.formula_to_string(n, k, m, p, q)
            
            print(f"\nФормула: {formula_str}")
            print(f"Результат: {result}")
        except ValueError:
            print("Ошибка: введите целые числа.")
    
    def _interactive_find(self):
        """Интерактивный поиск формулы."""
        print("\nВведите число для поиска формулы:")
        try:
            target = float(input("  Число: "))
            max_error = float(input("  Максимальная ошибка (%, по умолчанию 0.01): ") or "0.01")
            
            print(f"\nИщу формулы для {target} с ошибкой < {max_error}%...")
            results = self.find_formula(target, max_error=max_error)
            
            if results:
                print(f"\nНайдено {len(results)} формул:")
                for i, r in enumerate(results, 1):
                    print(f"  {i}. {r.formula_str} = {r.calculated:.10f} (ошибка: {r.error_percent:.7f}%)")
            else:
                print("Формулы не найдены. Попробуйте увеличить максимальную ошибку.")
        except ValueError:
            print("Ошибка: введите число.")
    
    def _show_all_constants(self):
        """Показывает все константы."""
        print("\n" + "=" * 60)
        print("ВСЕ ФИЗИЧЕСКИЕ КОНСТАНТЫ")
        print("=" * 60)
        
        categories = {}
        for key, const in self.constants.items():
            cat = const.get("category", "other")
            if cat not in categories:
                categories[cat] = []
            categories[cat].append((key, const))
        
        for cat, items in categories.items():
            print(f"\n{cat.upper()}:")
            for key, const in items:
                print(f"  {const['name']}: {const['value']} ± {const['uncertainty']}")
                print(f"    Источник: {const['source']}")


def main():
    """Главная функция."""
    calc = GoldenKeyCalculator()
    
    # Проверяем, запущен ли скрипт интерактивно
    import sys
    if sys.stdin.isatty():
        calc.interactive_mode()
    else:
        # Неинтерактивный режим — запускаем все проверки
        calc.verify_golden_key()
        calc.verify_all_constants()
        calc.verify_koide_formula()
        calc.statistical_analysis()


if __name__ == "__main__":
    main()

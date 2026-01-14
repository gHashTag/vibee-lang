# Глава 5: Trinity Structures — Три Богатыря Данных

---

*«Три богатыря» — Илья Муромец, Добрыня Никитич, Алёша Попович —*
*вместе сильнее, чем каждый по отдельности.*
— Русский эпос

---

## Три Богатыря Структур Данных

Как три богатыря защищают Русь, так три структуры данных защищают наши алгоритмы:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   ИЛЬЯ МУРОМЕЦ      ДОБРЫНЯ НИКИТИЧ    АЛЁША ПОПОВИЧ   │
│   ─────────────     ────────────────   ──────────────  │
│   Trinity B-Tree    Trinity Hash       Trinity Graph   │
│   (Сила)            (Мудрость)         (Хитрость)      │
│                                                         │
│   Хранение          Быстрый доступ     Связи           │
│   упорядоченных     по ключу           между данными   │
│   данных                                               │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Илья Муромец: Trinity B-Tree

### Сила Упорядоченности

B-дерево — основа баз данных. Но какой branching factor оптимален?

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   ОПТИМАЛЬНЫЙ BRANCHING FACTOR                         │
│                                                         │
│   Минимизируем b/log(b):                               │
│                                                         │
│   b=2: 2/0.693 = 2.89                                  │
│   b=3: 3/1.099 = 2.73  ← МИНИМУМ!                      │
│   b=4: 4/1.386 = 2.89                                  │
│                                                         │
│   Оптимум: b = e ≈ 2.718                               │
│   Ближайшее целое: b = 3                               │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Trinity B-Tree: b = 3

```
                    [30, 60]
                   /    |    \
                  /     |     \
           [10, 20]  [40, 50]  [70, 80]
           /  |  \   /  |  \   /  |  \
          ... ... ... ... ... ... ... ...
```

Каждый узел имеет **3 ребёнка** (или 2 ключа).

### Результаты Бенчмарка

```
┌─────────────┬─────────────┬─────────────┬───────────┐
│ Branching   │ Сравнения   │ Относительно│ Примечание│
├─────────────┼─────────────┼─────────────┼───────────┤
│ b = 2       │ 16,610      │ 1.06x       │           │
│ b = 3       │ 15,612      │ 1.00x       │ ← ЛУЧШИЙ  │
│ b = 4       │ 16,234      │ 1.04x       │           │
│ b = 8       │ 18,456      │ 1.18x       │           │
│ b = 16      │ 21,234      │ 1.36x       │           │
└─────────────┴─────────────┴─────────────┴───────────┘

* 10,000 операций поиска
```

**Trinity B-Tree с b=3 требует на 6% меньше сравнений!**

### Код

```python
class TrinityBTreeNode:
    """Узел Trinity B-Tree с 3 детьми"""
    def __init__(self):
        self.keys = []      # Максимум 2 ключа
        self.children = []  # Максимум 3 ребёнка
        self.is_leaf = True

class TrinityBTree:
    """B-дерево с branching factor = 3"""
    def __init__(self):
        self.root = TrinityBTreeNode()
        self.t = 2  # Минимальная степень (max keys = 2t-1 = 3)
    
    def search(self, key, node=None):
        if node is None:
            node = self.root
        
        i = 0
        while i < len(node.keys) and key > node.keys[i]:
            i += 1
        
        if i < len(node.keys) and key == node.keys[i]:
            return (node, i)
        
        if node.is_leaf:
            return None
        
        return self.search(key, node.children[i])
```

---

## Добрыня Никитич: Trinity Hash

### Мудрость Трёх Функций

Cuckoo Hashing использует несколько хеш-функций. Сколько оптимально?

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   CUCKOO HASHING: LOAD FACTOR THRESHOLD                │
│                                                         │
│   d = 2 функции: 50% заполнения                        │
│   d = 3 функции: 91% заполнения  ← +82%!               │
│   d = 4 функции: 97% заполнения  ← +7%                 │
│                                                         │
│   МАКСИМАЛЬНЫЙ ПРИРОСТ ПРИ d = 3!                      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Три Богатыря Хеширования

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   ИЛЬЯ (h₁)       ДОБРЫНЯ (h₂)    АЛЁША (h₃)           │
│   ─────────       ───────────     ──────────           │
│   Таблица 1       Таблица 2       Таблица 3            │
│                                                         │
│   Если занято     Если занято     Если занято          │
│   → к Добрыне     → к Алёше       → к Илье             │
│                                                         │
│   Три богатыря вместе защищают данные!                 │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Алгоритм Вставки

```python
class TrinityHash:
    """Cuckoo Hashing с 3 таблицами"""
    
    def __init__(self, capacity):
        self.capacity = capacity
        self.tables = [
            [None] * capacity,  # Илья
            [None] * capacity,  # Добрыня
            [None] * capacity,  # Алёша
        ]
        self.MAX_KICKS = 500
    
    def _hash(self, key, table_idx):
        """Три разные хеш-функции"""
        if table_idx == 0:
            return hash(key) % self.capacity
        elif table_idx == 1:
            return hash(key * 2654435761) % self.capacity
        else:
            return hash(key * 0x9E3779B9) % self.capacity
    
    def insert(self, key):
        """Вставка с перемещением между богатырями"""
        for _ in range(self.MAX_KICKS):
            for i in range(3):
                pos = self._hash(key, i)
                if self.tables[i][pos] is None:
                    self.tables[i][pos] = key
                    return True
                # Выгоняем текущего жителя
                key, self.tables[i][pos] = self.tables[i][pos], key
        
        # Нужен rehash
        self._rehash()
        return self.insert(key)
    
    def lookup(self, key):
        """Поиск: проверяем всех трёх богатырей"""
        for i in range(3):
            pos = self._hash(key, i)
            if self.tables[i][pos] == key:
                return True
        return False
```

### Результаты

```
┌─────────────┬─────────────┬─────────────┐
│ Функций     │ Max Load    │ Прирост     │
├─────────────┼─────────────┼─────────────┤
│ d = 2       │ 50%         │ baseline    │
│ d = 3       │ 91%         │ +82%        │
│ d = 4       │ 97%         │ +7%         │
└─────────────┴─────────────┴─────────────┘
```

**Три хеш-функции дают максимальный прирост ёмкости!**

---

## Алёша Попович: Trinity Graph

### Хитрость Трёх Состояний

В алгоритмах на графах (DFS, поиск циклов) нужны **три состояния**:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   ТРИ СОСТОЯНИЯ ВЕРШИНЫ                                │
│                                                         │
│   БЕЛЫЙ (0)       СЕРЫЙ (1)       ЧЁРНЫЙ (2)           │
│   ─────────       ─────────       ──────────           │
│   Не посещён      В процессе      Завершён             │
│                                                         │
│   Первая          Вторая          Третья               │
│   попытка         попытка         попытка              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Почему Два Состояния Недостаточно?

```
Граф: A → B → C → A (цикл)

С двумя состояниями (visited/not visited):
  Посещаем A → помечаем visited
  Посещаем B → помечаем visited
  Посещаем C → помечаем visited
  Видим A → уже visited
  
  Но это цикл или просто пересечение путей?
  НЕ МОЖЕМ ОПРЕДЕЛИТЬ!

С тремя состояниями:
  Посещаем A → помечаем СЕРЫЙ (в процессе)
  Посещаем B → помечаем СЕРЫЙ
  Посещаем C → помечаем СЕРЫЙ
  Видим A → СЕРЫЙ = ЦИКЛ!
  
  После завершения: помечаем ЧЁРНЫЙ
```

### Алгоритм Поиска Циклов

```python
def has_cycle(graph):
    """Поиск цикла с тремя состояниями"""
    WHITE, GRAY, BLACK = 0, 1, 2
    color = {node: WHITE for node in graph}
    
    def dfs(node):
        color[node] = GRAY  # Вторая попытка
        
        for neighbor in graph[node]:
            if color[neighbor] == GRAY:
                return True  # ЦИКЛ!
            if color[neighbor] == WHITE:
                if dfs(neighbor):
                    return True
        
        color[node] = BLACK  # Третья попытка — успех
        return False
    
    for node in graph:
        if color[node] == WHITE:
            if dfs(node):
                return True
    
    return False
```

### Топологическая Сортировка

```python
def topological_sort(graph):
    """Топологическая сортировка с тремя состояниями"""
    WHITE, GRAY, BLACK = 0, 1, 2
    color = {node: WHITE for node in graph}
    result = []
    
    def dfs(node):
        color[node] = GRAY
        
        for neighbor in graph[node]:
            if color[neighbor] == GRAY:
                raise ValueError("Цикл! Топологическая сортировка невозможна")
            if color[neighbor] == WHITE:
                dfs(neighbor)
        
        color[node] = BLACK
        result.append(node)  # Добавляем после завершения
    
    for node in graph:
        if color[node] == WHITE:
            dfs(node)
    
    return result[::-1]  # Обратный порядок
```

### Сильно Связные Компоненты (Kosaraju)

```python
def strongly_connected_components(graph):
    """Алгоритм Косарайю с тремя состояниями"""
    WHITE, GRAY, BLACK = 0, 1, 2
    
    # Первый DFS: получаем порядок завершения
    color = {node: WHITE for node in graph}
    finish_order = []
    
    def dfs1(node):
        color[node] = GRAY
        for neighbor in graph[node]:
            if color[neighbor] == WHITE:
                dfs1(neighbor)
        color[node] = BLACK
        finish_order.append(node)
    
    for node in graph:
        if color[node] == WHITE:
            dfs1(node)
    
    # Транспонируем граф
    reversed_graph = transpose(graph)
    
    # Второй DFS: находим компоненты
    color = {node: WHITE for node in graph}
    components = []
    
    def dfs2(node, component):
        color[node] = GRAY
        component.append(node)
        for neighbor in reversed_graph[node]:
            if color[neighbor] == WHITE:
                dfs2(neighbor, component)
        color[node] = BLACK
    
    for node in reversed(finish_order):
        if color[node] == WHITE:
            component = []
            dfs2(node, component)
            components.append(component)
    
    return components
```

---

## Ternary Search Tree: Три Дороги для Строк

### Идея

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   TERNARY SEARCH TREE (TST)                            │
│                                                         │
│   Каждый узел имеет 3 ребёнка:                         │
│   • LEFT: символ < текущего                            │
│   • MIDDLE: следующий символ строки                    │
│   • RIGHT: символ > текущего                           │
│                                                         │
│   Три дороги для каждого символа!                      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Структура

```
Слова: "cat", "car", "card", "care", "dog"

              c
            / | \
           a  a  d
          /|  |  |\
         r t  r  o g
         |    |  |
         d    e  g
```

### Преимущества

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   TST vs TRIE vs HASH                                  │
│                                                         │
│   Операция        TST         Trie        Hash         │
│   ─────────────────────────────────────────────────    │
│   Поиск           O(log n+k)  O(k)        O(k)         │
│   Prefix search   O(log n+m)  O(m)        O(n)         │
│   Память          Меньше      Больше      Средне       │
│   Упорядоченность Да          Да          Нет          │
│                                                         │
│   k = длина ключа, m = длина префикса                  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Код

```python
class TSTNode:
    def __init__(self, char):
        self.char = char
        self.left = None    # < char
        self.middle = None  # следующий символ
        self.right = None   # > char
        self.is_end = False
        self.value = None

class TernarySearchTree:
    def __init__(self):
        self.root = None
    
    def insert(self, key, value=None):
        self.root = self._insert(self.root, key, 0, value)
    
    def _insert(self, node, key, idx, value):
        char = key[idx]
        
        if node is None:
            node = TSTNode(char)
        
        if char < node.char:
            node.left = self._insert(node.left, key, idx, value)
        elif char > node.char:
            node.right = self._insert(node.right, key, idx, value)
        elif idx < len(key) - 1:
            node.middle = self._insert(node.middle, key, idx + 1, value)
        else:
            node.is_end = True
            node.value = value
        
        return node
    
    def search(self, key):
        node = self._search(self.root, key, 0)
        return node.value if node and node.is_end else None
    
    def prefix_search(self, prefix):
        """Найти все слова с данным префиксом"""
        node = self._search(self.root, prefix, 0)
        if node is None:
            return []
        
        results = []
        if node.is_end:
            results.append(prefix)
        
        self._collect(node.middle, prefix, results)
        return results
```

---

## Сводная Таблица

```
┌─────────────────┬─────────────┬─────────────┬─────────────┐
│ Структура       │ Принцип 3   │ Результат   │ Образ       │
├─────────────────┼─────────────┼─────────────┼─────────────┤
│ Trinity B-Tree  │ b = 3       │ -6% сравн.  │ Илья        │
│ Trinity Hash    │ 3 функции   │ +82% ёмкости│ Добрыня     │
│ Trinity Graph   │ 3 состояния │ Циклы, SCC  │ Алёша       │
│ TST             │ 3 ребёнка   │ Prefix srch │ Три дороги  │
└─────────────────┴─────────────┴─────────────┴─────────────┘
```

---

## Мудрость Главы

> *И понял Иван-программист третью истину:*
>
> *Три богатыря вместе сильнее, чем каждый по отдельности.*
>
> *Илья Муромец (Trinity B-Tree) хранит данные упорядоченно,*
> *с оптимальным branching factor = 3.*
>
> *Добрыня Никитич (Trinity Hash) даёт быстрый доступ,*
> *с тремя хеш-функциями для 82% большей ёмкости.*
>
> *Алёша Попович (Trinity Graph) находит связи,*
> *с тремя состояниями для поиска циклов.*
>
> *И Ternary Search Tree — три дороги для каждого символа —*
> *объединяет силу дерева и хеша.*
>
> *Три богатыря защищают данные.*
> *Древние знали.*

---

[← Глава 4](04_trinity_sort.md) | [Глава 6: Trinity Compression →](06_trinity_compression.md)

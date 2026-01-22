# VIBEE E2E Pipeline v21 - Демонстрация

Автономный браузерный агент: Chrome CDP + Ollama LLM.

## Быстрый старт

```bash
# 1. Запустить Chrome
google-chrome --headless=new --remote-debugging-port=9222 --no-sandbox &

# 2. Запустить Ollama
ollama serve &
ollama pull qwen2.5:3b

# 3. Запустить агента
./scripts/agent_loop.sh "What is the page title?" "https://example.com"
```

## Примеры задач

### Простая задача (1 шаг, ~13с)
```bash
./scripts/agent_loop.sh "What is the page title?" "https://example.com"
# Результат: done → "Example Domain"
```

### Навигация + отчёт (2 шага, ~16с)
```bash
./scripts/agent_loop.sh "Go to google.com and report the title" ""
# Шаг 1: goto https://google.com
# Шаг 2: done → "Google"
```

### Многошаговая задача (3 шага, ~26с)
```bash
./scripts/agent_loop.sh "Visit example.com, extract info, and report" ""
# Шаг 1: goto https://example.com
# Шаг 2: extract page info
# Шаг 3: done → результат
```

## Доступные действия

| Действие | Описание | Пример Input |
|----------|----------|--------------|
| goto | Навигация | https://example.com |
| click | Клик | button#submit |
| type | Ввод текста | input#search\|hello |
| scroll | Прокрутка | up / down |
| extract | Извлечение | main heading |
| done | Завершение | результат |
| fail | Ошибка | причина |

## Выбор модели

```bash
# По умолчанию (3b - надёжная)
./scripts/agent_loop.sh "task" "url"

# Быстрая (1.5b - для тестов)
VIBEE_MODEL="qwen2.5:1.5b" ./scripts/agent_loop.sh "task" "url"
```

## Метрики v21

| Метрика | Значение |
|---------|----------|
| Латенси на шаг | ~6-10с |
| Успешность простых задач | ~95% |
| Успешность многошаговых | ~80% |
| Модель по умолчанию | qwen2.5:3b |

## Архитектура

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Chrome    │────▶│   Agent     │────▶│   Ollama    │
│    CDP      │◀────│   Loop      │◀────│    LLM      │
└─────────────┘     └─────────────┘     └─────────────┘
     │                    │                    │
     │   OBSERVE          │    THINK           │
     │   (page state)     │    (next action)   │
     │                    │                    │
     └────────────────────┴────────────────────┘
                    ACT (execute)
```

---
φ² + 1/φ² = 3 | PHOENIX = 999 | VIBEE v21

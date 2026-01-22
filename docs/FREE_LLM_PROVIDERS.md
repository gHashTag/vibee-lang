# Бесплатные LLM провайдеры для VIBEE

**Цель**: Запуск WebArena без затрат на API
**φ² + 1/φ² = 3**

---

## Поддерживаемые провайдеры

### 1. Groq (РЕКОМЕНДУЕТСЯ)

**URL**: https://console.groq.com
**API**: OpenAI-совместимый
**Бесплатный tier**: Да (с лимитами)

```zig
const openai = @import("openai_client.zig");

// Создание клиента Groq
var client = openai.OpenAIClient.initGroq(allocator, "your-groq-api-key");

// Или через Agent
var agent = Agent.init(allocator, .{
    .api_key = "your-groq-api-key",
    .provider = .groq,
    .model = openai.GROQ_MODEL, // llama-3.3-70b-versatile
});
```

**Модели**:
| Модель | ID | Цена | Скорость |
|--------|-----|------|----------|
| Llama 3.3 70B | `llama-3.3-70b-versatile` | $0.59/1M | 750 tok/s |
| Llama 3.1 8B | `llama-3.1-8b-instant` | $0.05/1M | 1200 tok/s |
| Qwen3-32B | `qwen/qwen3-32b` | $0.15/1M | 600 tok/s |

---

### 2. Together AI

**URL**: https://api.together.xyz
**API**: OpenAI-совместимый
**Бесплатный tier**: $5 кредитов при регистрации

```zig
var client = openai.OpenAIClient.initTogether(allocator, "your-together-key");
```

**Модели**:
| Модель | ID | Цена |
|--------|-----|------|
| Llama 3.1 70B | `meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo` | $0.88/1M |
| DeepSeek V3 | `deepseek-ai/DeepSeek-V3` | $0.50/1M |
| Qwen 2.5 72B | `Qwen/Qwen2.5-72B-Instruct-Turbo` | $0.90/1M |

---

### 3. Ollama (Локальный)

**URL**: http://localhost:11434
**API**: OpenAI-совместимый
**Цена**: БЕСПЛАТНО (работает локально)

```bash
# Установка
curl -fsSL https://ollama.com/install.sh | sh

# Запуск модели
ollama run llama3.2:3b
```

```zig
var client = openai.OpenAIClient.initOllama(allocator);
// API ключ не нужен!
```

**Модели**:
| Модель | ID | RAM |
|--------|-----|-----|
| Llama 3.2 3B | `llama3.2:3b` | 4GB |
| Phi-3 Mini | `phi3:mini` | 4GB |
| Qwen 2.5 7B | `qwen2.5:7b` | 8GB |
| Mistral 7B | `mistral:7b` | 8GB |

---

## Переключение провайдеров

```zig
var client = openai.OpenAIClient.init(allocator, "key");

// Переключение на Groq
client.setProvider(.groq);

// Переключение на Together
client.setProvider(.together);

// Переключение на Ollama
client.setProvider(.ollama);

// Смена модели
client.setModel("llama-3.1-8b-instant");
```

---

## Рекомендации для WebArena

| Сценарий | Провайдер | Модель |
|----------|-----------|--------|
| Продакшн | Groq | Llama 3.3 70B |
| Быстрые тесты | Groq | Llama 3.1 8B |
| Разработка | Ollama | Llama 3.2 3B |
| Офлайн | Ollama | Phi-3 Mini |

---

## Получение API ключей

1. **Groq**: https://console.groq.com/keys
2. **Together**: https://api.together.xyz/settings/api-keys
3. **Ollama**: Не требуется

---

**KOSCHEI БЕССМЕРТЕН | ЗЛАТАЯ ЦЕПЬ ЗАМКНУТА | φ² + 1/φ² = 3**

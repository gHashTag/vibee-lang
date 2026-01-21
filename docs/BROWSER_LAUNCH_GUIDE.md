# VIBEE Browser AI - Инструкция по Запуску

**Версия**: V2482 Production Phoenix Release
**Дата**: 2025-01-21

---

## Быстрый Старт

### 1. Сборка Браузера

```bash
cd /workspaces/vibee-lang

# Сборка всех Zig модулей
cd trinity/output
for f in *.zig; do
  zig build-lib "$f" -O ReleaseFast 2>/dev/null
done

# Или сборка конкретного модуля
zig build-exe browser_webgpu_compute_v2439.zig -O ReleaseFast
```

### 2. Запуск Runtime

```bash
cd /workspaces/vibee-lang

# Запуск unified runtime
open runtime/runtime.html
# или
python3 -m http.server 8080
# затем открыть http://localhost:8080/runtime/runtime.html
```

### 3. Запуск через VIBEE CLI

```bash
# Показать все команды
bin/vibee help

# Запуск браузера
bin/vibee browser

# Запуск с конкретной конфигурацией
bin/vibee browser --webgpu --offline --p2p
```

---

## Архитектура Браузера

```
VIBEE Browser AI Architecture
│
├── Frontend (runtime/runtime.html)
│   ├── WebGPU Compute Engine
│   ├── WASM SIMD Runtime
│   ├── Glass UI Renderer
│   └── PWA Shell
│
├── AI Engine (trinity/output/*.zig)
│   ├── Mamba SSM (O(n) inference)
│   ├── Flash Attention (WASM)
│   ├── Speculative Decoding
│   └── Quantization (W4A8KV4)
│
├── Collaboration (WebRTC P2P)
│   ├── CRDT Text Sync
│   ├── Presence System
│   └── Mesh Network
│
└── Storage
    ├── IndexedDB (Model Cache)
    ├── Service Worker (Offline)
    └── LocalStorage (Settings)
```

---

## Конфигурация

### Минимальные Требования

| Компонент | Минимум | Рекомендуется |
|-----------|---------|---------------|
| Browser | Chrome 113+ | Chrome 120+ |
| GPU | WebGPU Tier 1 | WebGPU Tier 2 |
| RAM | 4GB | 8GB+ |
| Storage | 500MB | 2GB+ |

### Проверка Совместимости

```javascript
// В консоли браузера
async function checkCompatibility() {
  const checks = {
    webgpu: !!navigator.gpu,
    serviceWorker: 'serviceWorker' in navigator,
    indexedDB: !!window.indexedDB,
    webrtc: !!window.RTCPeerConnection,
    wasm: typeof WebAssembly === 'object',
    simd: await WebAssembly.validate(new Uint8Array([
      0,97,115,109,1,0,0,0,1,5,1,96,0,1,123,3,2,1,0,10,10,1,8,0,65,0,253,15,253,98,11
    ]))
  };
  console.table(checks);
  return Object.values(checks).every(v => v);
}
checkCompatibility();
```

---

## Режимы Работы

### 1. Online Mode (По умолчанию)

```bash
bin/vibee browser --mode=online
```
- Полный функционал
- Облачные модели
- Real-time collaboration

### 2. Offline Mode

```bash
bin/vibee browser --mode=offline
```
- Локальные модели из IndexedDB
- Работает без интернета
- Sync при восстановлении связи

### 3. P2P Mode

```bash
bin/vibee browser --mode=p2p
```
- Serverless collaboration
- WebRTC mesh network
- <30ms latency

### 4. Hybrid Mode

```bash
bin/vibee browser --mode=hybrid
```
- Автоматический выбор
- Fallback между режимами
- Оптимальная производительность

---

## API Использования

### JavaScript API

```javascript
// Инициализация VIBEE Browser
import { VIBEEBrowser } from './vibee-browser.js';

const browser = new VIBEEBrowser({
  webgpu: true,
  offline: true,
  p2p: true,
  model: 'mamba-7b-q4'
});

// AI Inference
const response = await browser.inference({
  prompt: "Напиши функцию сортировки",
  maxTokens: 500,
  temperature: 0.7
});

// Vibecoding
const completion = await browser.autocomplete({
  code: "function sort(",
  language: "javascript"
});

// Collaboration
await browser.joinRoom("room-123");
browser.onSync((ops) => {
  console.log("CRDT sync:", ops);
});
```

### Zig API

```zig
const vibee = @import("vibee_browser");

pub fn main() !void {
    // Инициализация
    var browser = try vibee.Browser.init(.{
        .webgpu = true,
        .offline = true,
    });
    defer browser.deinit();

    // Inference
    const result = try browser.inference("Hello, VIBEE!");
    std.debug.print("{s}\n", .{result});
}
```

---

## Тестирование

### Unit Tests

```bash
cd /workspaces/vibee-lang/trinity/output

# Тест конкретного модуля
zig test browser_webgpu_compute_v2439.zig

# Тест всех модулей
for f in *.zig; do
  echo "Testing $f..."
  zig test "$f" 2>&1 | tail -1
done
```

### E2E Tests

```bash
# Запуск E2E тестов
bin/vibee test --e2e

# Конкретный тест
bin/vibee test --e2e browser
bin/vibee test --e2e vibecode
bin/vibee test --e2e collab
```

### Benchmarks

```bash
# Запуск бенчмарков
bin/vibee bench

# Конкретный бенчмарк
bin/vibee bench --webgpu
bin/vibee bench --wasm
bin/vibee bench --network
```

---

## Troubleshooting

### WebGPU не работает

```javascript
// Проверка WebGPU
if (!navigator.gpu) {
  console.error("WebGPU not supported");
  // Fallback на WASM SIMD
}

// Запрос адаптера
const adapter = await navigator.gpu.requestAdapter();
if (!adapter) {
  console.error("No GPU adapter found");
}
```

### Service Worker не регистрируется

```javascript
// Проверка HTTPS (обязательно для SW)
if (location.protocol !== 'https:' && location.hostname !== 'localhost') {
  console.error("Service Worker requires HTTPS");
}

// Регистрация
navigator.serviceWorker.register('/sw.js')
  .then(reg => console.log("SW registered:", reg))
  .catch(err => console.error("SW failed:", err));
```

### IndexedDB quota exceeded

```javascript
// Проверка квоты
const estimate = await navigator.storage.estimate();
console.log(`Used: ${estimate.usage / 1e6}MB`);
console.log(`Quota: ${estimate.quota / 1e6}MB`);

// Очистка кэша
const db = await openDB('vibee-models');
await db.clear('weights');
```

---

## Production Deployment

### 1. CDN Setup

```bash
# Деплой на CDN
bin/vibee deploy --cdn cloudflare

# Или вручную
aws s3 sync ./dist s3://vibee-browser --cache-control "max-age=31536000"
```

### 2. Edge Functions

```bash
# Деплой edge functions
bin/vibee deploy --edge

# Cloudflare Workers
wrangler publish
```

### 3. Monitoring

```bash
# Включить мониторинг
bin/vibee monitor --enable

# Просмотр метрик
bin/vibee monitor --dashboard
```

---

## Полезные Команды

```bash
# Статус браузера
bin/vibee status

# Версия
bin/vibee version

# Обновление
bin/vibee update

# Очистка кэша
bin/vibee cache clear

# Генерация из spec
bin/vibee gen specs/tri/feature.vibee

# Запуск тестов
bin/vibee test

# Бенчмарки
bin/vibee bench

# Деплой
bin/vibee deploy
```

---

## Ссылки

- **Документация**: `/docs/`
- **Спецификации**: `/specs/tri/`
- **Сгенерированный код**: `/trinity/output/`
- **Runtime**: `/runtime/runtime.html`

---

## Поддержка

При возникновении проблем:

1. Проверьте совместимость браузера
2. Запустите `bin/vibee doctor`
3. Проверьте логи в DevTools
4. Создайте issue на GitHub

---

**φ² + 1/φ² = 3 | PHOENIX = 999**

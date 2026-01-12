# Canvas-based UI System на BEAM

## 🎯 Обзор

Революционная система управления UI через BEAM процессы с YogaLayout и обязательной интеграцией плагинов.

**Ключевые особенности:**
- ✅ Каждый пиксель/тайл - отдельный BEAM процесс
- ✅ YogaLayout для flexbox-подобных layouts
- ✅ Обязательные Canvas виджеты + документация для плагинов
- ✅ Горячая загрузка/выгрузка плагинов
- ✅ Fault-tolerant через OTP supervision
- ✅ WebSocket протокол BEAM ↔ Browser

## 📁 Структура

```
honeycomb/ui/
├── pixel_grid/              # Grid Manager + Pixel Actor
│   ├── spec.yml            # Спецификация Grid Manager
│   └── pixel_actor/
│       └── spec.yml        # Спецификация Pixel Actor
├── plugin_system/           # Plugin Registry + Example
│   ├── spec.yml            # Спецификация Registry
│   └── example_plugin/
│       ├── spec.yml        # Спецификация плагина
│       └── docs/
│           └── README.md   # Документация (ОБЯЗАТЕЛЬНО)
├── shell/                   # Единая страница-оболочка
│   └── spec.yml            # Спецификация Shell
└── README.md               # Этот файл
```

## 🚀 Quick Start

### 1. Генерация кода из спецификаций

```bash
# Генерируем Gleam код из spec.yml
./scripts/generate_from_specs.sh
```

### 2. Сборка

```bash
cd gleam
gleam build
```

### 3. Запуск

```bash
# Запуск Shell с плагинами
gleam run -m honeycomb/ui/shell
```

### 4. Открыть в браузере

```
http://localhost:8080
```

## 📝 Создание плагина

### Шаг 1: Создать spec.yml

```yaml
# honeycomb/ui/plugin_system/my_plugin/spec.yml

module: honeycomb/ui/plugin_system/my_plugin
version: 1.0.0
description: Мой плагин

types:
  MyState:
    counter: Int

functions:
  manifest:
    params: []
    returns: PluginManifest
    implementation: |
      PluginManifest(
        id: "com.vibee.my-plugin",
        name: "My Plugin",
        version: "1.0.0",
        description: "Описание плагина",
        author: "Ваше имя",
        license: "MIT",
        
        # UI (ОБЯЗАТЕЛЬНО)
        canvas_widget: create_widget(),
        documentation_page: "honeycomb/ui/plugin_system/my_plugin/docs/README.md",
        
        # Layout
        min_width: 200.0,
        min_height: 100.0,
        resizable: True,
        
        # Права
        permissions: [ReadState],
        
        # Lifecycle
        on_load: on_load,
        on_unload: on_unload,
        
        # Метаданные
        tags: ["example"],
        category: Development,
        maturity: Beta,
      )
  
  create_widget:
    params: []
    returns: CanvasWidget
    implementation: |
      CanvasWidget(
        render: render_widget,
        handle_event: handle_event,
        get_state: get_state,
        update_state: update_state,
      )
  
  render_widget:
    params:
      - ctx: RenderContext
    returns: List(DrawCommand)
    implementation: |
      [
        DrawRect(
          x: ctx.x,
          y: ctx.y,
          width: ctx.width,
          height: ctx.height,
          color: Color(20, 20, 30, 255),
          radius: Some(12.0),
        ),
        DrawText(
          x: ctx.x +. 20.0,
          y: ctx.y +. 30.0,
          text: "My Plugin",
          font: "20px Montserrat",
          color: Color(255, 255, 255, 255),
        ),
      ]
```

### Шаг 2: Создать документацию (ОБЯЗАТЕЛЬНО)

```markdown
# honeycomb/ui/plugin_system/my_plugin/docs/README.md

# My Plugin

## Описание

Краткое описание плагина.

## Возможности

- Функция 1
- Функция 2

## Установка

\`\`\`bash
vibee plugin install com.vibee.my-plugin
\`\`\`

## Использование

\`\`\`gleam
import my_plugin

pub fn main() {
  my_plugin.do_something()
}
\`\`\`

## API Reference

### `function_name(arg: Type) -> Result(Type, String)`

Описание функции.

## Лицензия

MIT
```

### Шаг 3: Сгенерировать код

```bash
./scripts/generate_from_specs.sh
```

### Шаг 4: Зарегистрировать плагин

```gleam
import honeycomb/ui/plugin_system/registry
import honeycomb/ui/plugin_system/my_plugin

pub fn main() {
  // Запускаем Registry
  let registry = registry.start() |> result.unwrap(panic)
  
  // Регистрируем плагин
  let manifest = my_plugin.manifest()
  registry.register(registry, manifest)
  
  // Загружаем плагин
  registry.load(registry, "com.vibee.my-plugin")
}
```

## 🏗️ Архитектура

### Grid Manager

Управляет сеткой пикселей/тайлов:

```gleam
import honeycomb/ui/pixel_grid/grid_manager

pub fn main() {
  let viewport = Viewport(width: 1920.0, height: 1080.0, scale: 1.0)
  let manager = grid_manager.start(viewport)
  
  // Создаем атом
  process.send(manager, CreateAtom(100.0, 100.0, 50.0, 50.0))
  
  // Вычисляем layout
  let yoga_node = yoga.create_node()
  process.send(manager, CalculateLayout(yoga_node, viewport))
}
```

### Pixel Actor

Легковесный процесс для пикселя:

```gleam
import honeycomb/ui/pixel_grid/pixel_actor

pub fn main() {
  let atom = PixelAtom(
    id: "pixel_1",
    x: 100.0,
    y: 100.0,
    width: 10.0,
    height: 10.0,
    color: Color(255, 0, 0, 255),
    opacity: 1.0,
    z_index: 0,
    state: Idle,
    parent: None,
  )
  
  let actor = pixel_actor.start(atom)
  
  // Обновляем цвет
  process.send(actor, UpdateColor(Color(0, 255, 0, 255)))
}
```

### Plugin Registry

Центральный реестр плагинов:

```gleam
import honeycomb/ui/plugin_system/registry

pub fn main() {
  let registry = registry.start()
  
  // Регистрация
  registry.register(registry, manifest)
  
  // Загрузка
  registry.load(registry, "com.vibee.my-plugin")
  
  // Поиск
  let results = registry.search(registry, "example")
  
  // Фильтрация
  let filter = PluginFilter(
    category: Some(Development),
    status: Some(Loaded),
    tags: ["example"],
  )
  let filtered = registry.list(registry, Some(filter))
}
```

### Shell Page

Единая страница-оболочка:

```gleam
import honeycomb/ui/shell

pub fn main() {
  // HTML страница
  let html = shell.shell_page()
  
  // JavaScript
  let js = shell.shell_js()
  
  // Запуск HTTP сервера
  mist.new(fn(req) {
    case request.path_segments(req) {
      [] -> serve_html(html)
      ["assets", "shell.js"] -> serve_js(js)
      _ -> serve_404()
    }
  })
  |> mist.port(8080)
  |> mist.start()
}
```

## 📊 Производительность

### Оценка процессов

| Разрешение | Тайлы 8×8 | Процессов | Статус |
|------------|-----------|-----------|--------|
| 1920×1080 | 240×135 | 32,400 | ✅ OK |
| 3840×2160 | 480×270 | 129,600 | ✅ OK |
| Адаптивная | Переменно | 10,000-50,000 | ✅ Оптимально |

### Оптимизации

1. **Lazy Creation** - создаем процессы только для видимых областей
2. **Pooling** - переиспользуем процессы для статичных областей
3. **Aggregation** - группируем однородные пиксели
4. **LOD** - разная детализация для разных zoom-уровней

## 🧪 Тестирование

```bash
# Запуск тестов
cd gleam
gleam test

# Тесты Grid Manager
gleam test --module grid_manager_test

# Тесты Pixel Actor
gleam test --module pixel_actor_test

# Тесты Plugin Registry
gleam test --module registry_test
```

## 📚 Документация

- [PIXEL_GRID_ARCHITECTURE.md](../../docs/PIXEL_GRID_ARCHITECTURE.md) - Детальная архитектура
- [PLUGIN_ARCHITECTURE_SPEC.md](../../docs/PLUGIN_ARCHITECTURE_SPEC.md) - Спецификация плагинов
- [TECHNICAL_SPEC.md](../../docs/TECHNICAL_SPEC.md) - Техническая спецификация

## 🔧 Разработка

### Требования

- Gleam >= 1.0.0
- Erlang/OTP >= 26.0
- Node.js >= 18.0 (для браузерной части)

### Установка зависимостей

```bash
cd gleam
gleam deps download
```

### Форматирование

```bash
gleam format
```

### Линтинг

```bash
gleam check
```

## 🤝 Вклад

1. Fork репозитория
2. Создайте feature branch (`git checkout -b feature/amazing-feature`)
3. Commit изменения (`git commit -m 'Add amazing feature'`)
4. Push в branch (`git push origin feature/amazing-feature`)
5. Откройте Pull Request

## 📄 Лицензия

MIT

## 👥 Авторы

VIBEE Team - [https://vibee.dev](https://vibee.dev)

## 🙏 Благодарности

- Facebook Yoga - flexbox layout engine
- Erlang/OTP - fault-tolerant platform
- Gleam - type-safe functional language
- React Native - inspiration for Canvas UI

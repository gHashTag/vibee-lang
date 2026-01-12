# Example Plugin

## Описание

Демонстрационный плагин показывающий как создавать Canvas-based UI плагины для VIBEE с обязательной документацией и интеграцией.

## Возможности

- Canvas рендеринг с immediate-mode UI
- Обработка событий (клик, клавиатура, фокус)
- Анимация (пульсация цвета)
- Управление состоянием через process dictionary
- Lifecycle hooks (load, unload, resize, focus, blur)

## Установка

```bash
vibee plugin install com.vibee.example-plugin
```

## Использование

### Базовое использование

```gleam
import honeycomb/ui/plugin_system/example_plugin

pub fn main() {
  // Получаем манифест
  let manifest = example_plugin.manifest()
  
  // Регистрируем в Registry
  let registry = plugin_registry.start()
  plugin_registry.register(registry, manifest)
  
  // Загружаем плагин
  plugin_registry.load(registry, "com.vibee.example-plugin")
}
```

### Интеграция в Shell

Плагин автоматически появится в sidebar после регистрации:

```javascript
// В браузере
fetch('/api/plugins')
  .then(r => r.json())
  .then(plugins => {
    // Example Plugin будет в списке
    console.log(plugins);
  });
```

## Конфигурация

Плагин не требует конфигурации, но поддерживает сохранение состояния:

```json
{
  "counter": 42,
  "color": {
    "r": 99,
    "g": 102,
    "b": 241,
    "a": 255
  },
  "text": "Hello, VIBEE!"
}
```

## API Reference

### Функции

#### `manifest() -> PluginManifest`

Возвращает манифест плагина со всеми метаданными.

**Возвращает:**
- `PluginManifest` - полный манифест плагина

**Пример:**
```gleam
let manifest = example_plugin.manifest()
io.println(manifest.name)  // "Example Plugin"
```

#### `create_widget() -> CanvasWidget`

Создает Canvas виджет для рендеринга.

**Возвращает:**
- `CanvasWidget` - виджет с функциями render, handle_event, get_state

**Пример:**
```gleam
let widget = example_plugin.create_widget()
let commands = widget.render(ctx)
```

#### `render_widget(ctx: RenderContext) -> List(DrawCommand)`

Рендерит виджет на Canvas.

**Параметры:**
- `ctx` - контекст рендеринга (позиция, размер, тема, состояние)

**Возвращает:**
- `List(DrawCommand)` - список команд рисования

**Пример:**
```gleam
let ctx = RenderContext(
  x: 0.0,
  y: 0.0,
  width: 200.0,
  height: 100.0,
  scale: 1.0,
  time: 0.0,
  viewport: viewport,
  theme: theme,
  focused: False,
  hovered: False,
)

let commands = render_widget(ctx)
// [DrawRect(...), DrawText(...), ...]
```

#### `handle_event(event: UIEvent) -> Result(EventResponse, String)`

Обрабатывает UI события.

**Параметры:**
- `event` - событие (Click, MouseMove, KeyDown, etc.)

**Возвращает:**
- `Ok(EventResponse)` - ответ (Handled, Propagate, Update, Command)
- `Error(String)` - ошибка обработки

**Пример:**
```gleam
let event = Click(150.0, 70.0)
case handle_event(event) {
  Ok(Update(state)) -> io.println("State updated")
  Ok(Handled) -> io.println("Event handled")
  Error(err) -> io.println("Error: " <> err)
}
```

## События

### Click

Клик по кнопке увеличивает счетчик.

**Payload:**
```json
{
  "x": 150.0,
  "y": 70.0
}
```

### KeyDown

- `Space` - увеличить счетчик
- `R` - сбросить счетчик

**Payload:**
```json
{
  "key": "Space"
}
```

## Разрешения

Плагин требует следующие разрешения:
- `ReadState` - для чтения глобального состояния
- `WriteState` - для записи состояния

## Зависимости

Нет внешних зависимостей.

## Примеры

### Пример 1: Базовый рендеринг

```gleam
import honeycomb/ui/plugin_system/example_plugin

pub fn main() {
  let manifest = example_plugin.manifest()
  let widget = manifest.canvas_widget
  
  let ctx = create_render_context()
  let commands = widget.render(ctx)
  
  // Рендерим команды на Canvas
  list.each(commands, render_command)
}
```

### Пример 2: Обработка событий

```gleam
import honeycomb/ui/plugin_system/example_plugin

pub fn main() {
  let manifest = example_plugin.manifest()
  let widget = manifest.canvas_widget
  
  // Симулируем клик
  let event = Click(150.0, 70.0)
  
  case widget.handle_event(event) {
    Ok(Update(new_state)) -> {
      io.println("Counter increased!")
      widget.update_state(new_state)
    }
    _ -> Nil
  }
}
```

### Пример 3: Анимация

```gleam
import honeycomb/ui/plugin_system/example_plugin

pub fn main() {
  let manifest = example_plugin.manifest()
  let widget = manifest.canvas_widget
  
  case widget.animate {
    Some(animate_fn) -> {
      let time = 1.5  // 1.5 секунды
      let commands = animate_fn(time)
      
      // Рендерим анимацию
      list.each(commands, render_command)
    }
    None -> Nil
  }
}
```

## FAQ

### Как изменить цвет счетчика?

Измените поле `color` в `ExampleState`:

```gleam
let state = ExampleState(
  counter: 0,
  color: Color(255, 0, 0, 255),  // Красный
  text: "Hello!",
)
```

### Как добавить свою кнопку?

Добавьте новый `DrawRect` и обработку клика в `handle_event`:

```gleam
// В render_widget
DrawRect(
  x: ctx.x +. 20.0,
  y: ctx.y +. ctx.height -. 50.0,
  width: 80.0,
  height: 30.0,
  color: Color(0, 255, 0, 255),
  radius: Some(6.0),
)

// В handle_event
Click(x, y) -> {
  let button_x = x -. 20.0
  let button_y = y -. (ctx.height -. 50.0)
  
  case button_x >=. 0.0 && button_x <=. 80.0 && button_y >=. 0.0 && button_y <=. 30.0 {
    True -> {
      io.println("Custom button clicked!")
      Ok(Handled)
    }
    False -> Ok(Propagate)
  }
}
```

### Как сохранить состояние между перезагрузками?

Используйте ETS или файловую систему:

```gleam
// Сохранение
pub fn save_state(state: ExampleState) {
  let json = json.object([
    #("counter", json.int(state.counter)),
    // ...
  ])
  |> json.to_string
  
  file.write("state.json", json)
}

// Загрузка
pub fn load_state() -> Result(ExampleState, String) {
  case file.read("state.json") {
    Ok(json_str) -> json.decode(json_str, example_state_decoder)
    Error(err) -> Error("Failed to load state")
  }
}
```

## Troubleshooting

### Плагин не отображается в sidebar

**Проблема**: Плагин зарегистрирован, но не виден в UI.

**Решение**: Проверьте что:
1. Манифест валиден (`validate_plugin` возвращает `Ok`)
2. Плагин загружен (`plugin_registry.load`)
3. Canvas виджет не возвращает пустой список команд

### Клики не обрабатываются

**Проблема**: Клики по кнопке не работают.

**Решение**: Проверьте координаты в `handle_event`:
```gleam
io.println("Click at: " <> float.to_string(x) <> ", " <> float.to_string(y))
```

### Анимация не работает

**Проблема**: Анимация не отображается.

**Решение**: Убедитесь что:
1. `animate` возвращает `Some(fn)`
2. Функция анимации вызывается с правильным `time`
3. Команды рисования не пустые

## Changelog

### v1.0.0 (2026-01-10)

- Initial release
- Canvas рендеринг
- Обработка событий (клик, клавиатура)
- Анимация пульсации
- Lifecycle hooks

## Лицензия

MIT

## Автор

VIBEE Team - [https://vibee.dev](https://vibee.dev)

## Ссылки

- [VIBEE Documentation](https://vibee.dev/docs)
- [Plugin Architecture](https://vibee.dev/docs/plugin-architecture)
- [Canvas UI Guide](https://vibee.dev/docs/canvas-ui)
- [GitHub Repository](https://github.com/vibee/example-plugin)

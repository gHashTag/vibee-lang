# VIBEE Browser - Установка на macOS

## Быстрый Запуск (без установки)

```bash
cd vibee-lang
python3 -m http.server 8080
```
Затем открой: **http://localhost:8080/runtime/runtime.html**

---

## Установка .app Bundle

### Вариант 1: Скачать готовый .app

```bash
# Скачай папку dist/macos/VIBEE Browser.app
# Перемести в /Applications
mv "dist/macos/VIBEE Browser.app" /Applications/

# Запусти
open "/Applications/VIBEE Browser.app"
```

### Вариант 2: Собрать локально

```bash
cd vibee-lang
./build-macos.sh
mv "dist/macos/VIBEE Browser.app" /Applications/
open "/Applications/VIBEE Browser.app"
```

---

## Создание .dmg (опционально)

```bash
cd vibee-lang
hdiutil create -volname "VIBEE Browser" \
  -srcfolder "dist/macos/VIBEE Browser.app" \
  -ov -format UDZO \
  "dist/VIBEE-Browser-2482.dmg"
```

---

## Сборка CLI для Apple Silicon

```bash
# Установи Zig
brew install zig

# Собери CLI
cd vibee-lang/generated/crush/zig
zig build-exe main.zig -O ReleaseFast
mv main ../../../bin/vibee

# Проверь
../../../bin/vibee help
```

---

## Troubleshooting

### "App is damaged and can't be opened"

```bash
xattr -cr "/Applications/VIBEE Browser.app"
```

### "Developer cannot be verified"

```bash
# Разреши в System Preferences > Security & Privacy
# Или:
sudo spctl --master-disable
open "/Applications/VIBEE Browser.app"
sudo spctl --master-enable
```

### Порт 8080 занят

```bash
# Используй другой порт
python3 -m http.server 9999
# Открой http://localhost:9999/runtime/runtime.html
```

---

## Минимальные Требования

- macOS 11.0+ (Big Sur)
- Safari 15+ / Chrome 113+ / Firefox 115+
- 4GB RAM
- WebGPU поддержка (для GPU ускорения)

---

## Проверка WebGPU

Открой консоль браузера (Cmd+Option+J) и выполни:

```javascript
if (navigator.gpu) {
  const adapter = await navigator.gpu.requestAdapter();
  console.log("WebGPU:", adapter ? "✅ Supported" : "❌ No adapter");
} else {
  console.log("WebGPU: ❌ Not supported");
}
```

---

**φ² + 1/φ² = 3 | PHOENIX = 999**

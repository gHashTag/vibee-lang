# Chromium → VIBEE → Zig Transpilation Plan

## φ² + 1/φ² = 3 | PHOENIX = 999

## Overview

Пакетная транспиляция всего Chromium из C++ в Zig через VIBEE спецификации.

## Comparison: All Browser Options

| Option | Base | Size | Build Time | Performance | Complexity |
|--------|------|------|------------|-------------|------------|
| **vibee-electron** | Electron | ~200MB | 30 sec | Standard | Low |
| **vibee-browser-chromium** | Thorium/Chromium | ~100GB | 3-6 hours | +15% | Very High |
| **vibee-tauri** | Tauri (Rust) | ~600KB | 5 min | +10% | Medium |
| **vibee-browser-zig** | Zig (transpiled) | ~50MB | 30 min | +30% | High |

## Recommended: Tauri

**Tauri** - лучший баланс для VIBEE Browser:

```
┌─────────────────────────────────────────────────────────────────┐
│                    TAURI ADVANTAGES                             │
├─────────────────────────────────────────────────────────────────┤
│  ✓ Minimal size: 600KB vs 200MB (Electron)                      │
│  ✓ Native webview (no bundled Chromium)                         │
│  ✓ Rust backend (memory safe, fast)                             │
│  ✓ Cross-platform: Windows, macOS, Linux, iOS, Android          │
│  ✓ Easy to customize                                            │
│  ✓ Active development                                           │
└─────────────────────────────────────────────────────────────────┘
```

## Transpilation Strategy

### Phase 1: Clay UI (DONE)
```bash
# 4,454 lines C → 7 .vibee specs
./scripts/cpp_to_vibee.sh /tmp/clay specs/generated/clay
```

### Phase 2: Tauri Core (Next)
```bash
# ~50,000 lines Rust → .vibee → Zig
# Requires rust_to_vibee transpiler
```

### Phase 3: Chromium Components (Future)
```
Priority order:
1. base/          - Foundation (~500 files)
2. ui/gfx/        - Graphics primitives (~200 files)
3. ui/views/      - UI framework (~800 files)
4. chrome/browser/ui/ - Browser UI (~2000 files)
```

### Phase 4: Full Chromium (Long-term)
```
Total: ~35 million lines C++
Estimated: 6-12 months with team
Result: Native Zig browser
```

## Immediate Recommendation

**Use Tauri for VIBEE Browser:**

```bash
# Install Tauri
npm create tauri-app@latest vibee-browser-tauri

# Add VIBEE features
# - φ-layout UI
# - AI sidebar
# - Vibecoding panel
```

### Tauri vs Electron

| Feature | Electron | Tauri |
|---------|----------|-------|
| Bundle size | 150-200MB | 0.6-3MB |
| Memory usage | 150-300MB | 30-50MB |
| Startup time | 2-5 sec | 0.5-1 sec |
| Backend | Node.js | Rust |
| Security | Medium | High |
| Mobile | ❌ | ✅ |

## Commands

```bash
# Option 1: Tauri (RECOMMENDED)
npm create tauri-app@latest vibee-browser-tauri
cd vibee-browser-tauri
npm run tauri dev

# Option 2: Continue with Electron
cd vibee-electron
npm start  # Requires X11/display

# Option 3: Full Chromium transpilation (long-term)
./scripts/cpp_to_vibee.sh chromium/src specs/chromium 16
for f in specs/chromium/*.vibee; do vibee gen "$f"; done
```

## Architecture: VIBEE Browser (Tauri)

```
┌─────────────────────────────────────────────────────────────────┐
│                    VIBEE Browser (Tauri)                        │
├─────────────────────────────────────────────────────────────────┤
│  Frontend (WebView)                                             │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  HTML/CSS/JS                                            │    │
│  │  - φ-layout CSS (golden ratio)                          │    │
│  │  - AI Sidebar component                                 │    │
│  │  - Vibecoding panel                                     │    │
│  └─────────────────────────────────────────────────────────┘    │
│                           │                                     │
│                           ▼                                     │
│  Backend (Rust)                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Tauri Commands                                         │    │
│  │  - AI API calls (OpenAI/Claude/Ollama)                  │    │
│  │  - File system access                                   │    │
│  │  - .vibee compilation                                   │    │
│  │  - System integration                                   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                           │                                     │
│                           ▼                                     │
│  Native WebView (OS-provided)                                   │
│  - Windows: WebView2 (Edge/Chromium)                            │
│  - macOS: WKWebView (Safari/WebKit)                             │
│  - Linux: WebKitGTK                                             │
└─────────────────────────────────────────────────────────────────┘
```

## Next Steps

1. **Create vibee-browser-tauri** - Tauri-based browser
2. **Port UI from vibee-electron** - Same features, smaller size
3. **Add mobile support** - iOS/Android via Tauri
4. **Long-term: Zig transpilation** - For maximum performance

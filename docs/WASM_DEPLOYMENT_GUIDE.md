# VIBEE WASM Deployment Guide

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                    VIBEE WASM RUNTIME DEPLOYMENT                              ║
║                         φ² + 1/φ² = 3                                         ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

## Overview

VIBEE compiles to WebAssembly for browser execution. This guide covers deployment of browser_v3 WASM modules.

## Module Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      BROWSER APPLICATION                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   LOADER    │  │   RUNTIME   │  │   INTEROP   │             │
│  │   .wasm     │──│    .wasm    │──│    .wasm    │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│         │                │                │                     │
│         ▼                ▼                ▼                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   MEMORY    │  │  COMPILER   │  │  BINDINGS   │             │
│  │   .wasm     │  │    .wasm    │  │    .wasm    │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Modules

| Module | Size | Purpose |
|--------|------|---------|
| `vibee_wasm_runtime.wasm` | ~4KB | Core runtime, module lifecycle |
| `vibee_wasm_memory.wasm` | ~4KB | Linear memory management |
| `vibee_wasm_bindings.wasm` | ~4KB | JS/DOM/Canvas bindings |
| `vibee_wasm_compiler.wasm` | ~4KB | Zig→WASM compilation |
| `vibee_wasm_loader.wasm` | ~4KB | Module loading, caching |
| `vibee_wasm_interop.wasm` | ~4KB | Host function calls |

## Quick Start

### 1. Build WASM Modules

```bash
cd trinity/wasm
zig build -Doptimize=ReleaseSmall --build-file build_browser_v3.zig
```

### 2. Load in Browser

```javascript
// Load WASM module
const response = await fetch('/wasm/vibee_wasm_runtime.wasm');
const bytes = await response.arrayBuffer();
const module = await WebAssembly.compile(bytes);

// Create instance with imports
const instance = await WebAssembly.instantiate(module, {
  env: {
    console_log: (ptr, len) => {
      const memory = instance.exports.memory;
      const bytes = new Uint8Array(memory.buffer, ptr, len);
      console.log(new TextDecoder().decode(bytes));
    }
  }
});

// Call exported function
const result = instance.exports.init_runtime();
```

### 3. Streaming Compilation

```javascript
const { instance } = await WebAssembly.instantiateStreaming(
  fetch('/wasm/vibee_wasm_runtime.wasm'),
  importObject
);
```

## Build Options

| Option | Description |
|--------|-------------|
| `-Doptimize=ReleaseSmall` | Smallest binary size |
| `-Doptimize=ReleaseFast` | Maximum performance |
| `-Dsimd=true` | Enable SIMD128 (default) |
| `-Dsimd=false` | Disable SIMD for compatibility |

## SIMD Support

WASM SIMD128 is enabled by default for:
- Vector operations (4x f32, 2x f64)
- φ-spiral calculations
- Layout computations

Check browser support:
```javascript
const simdSupported = WebAssembly.validate(new Uint8Array([
  0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
  0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7b, 0x03,
  0x02, 0x01, 0x00, 0x0a, 0x0a, 0x01, 0x08, 0x00,
  0x41, 0x00, 0xfd, 0x0f, 0x0b
]));
```

## Memory Management

```javascript
// Get memory from instance
const memory = instance.exports.memory;

// Grow memory (returns previous page count or -1)
const prevPages = instance.exports.grow_memory(2);

// Read/write memory
const view = new DataView(memory.buffer);
view.setInt32(0, 42, true);  // little-endian
const value = view.getInt32(0, true);
```

## Caching with Service Worker

```javascript
// sw.js
const CACHE_NAME = 'vibee-wasm-v1';
const WASM_MODULES = [
  '/wasm/vibee_wasm_runtime.wasm',
  '/wasm/vibee_wasm_memory.wasm',
  '/wasm/vibee_wasm_bindings.wasm',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(WASM_MODULES))
  );
});
```

## Performance Tips

1. **Use streaming compilation** - `instantiateStreaming` is faster
2. **Cache compiled modules** - Store in IndexedDB
3. **Lazy load** - Only load modules when needed
4. **Enable SIMD** - 2-4x speedup for vector ops
5. **Use SharedArrayBuffer** - For multi-threaded WASM

## File Locations

```
vibee-lang/
├── specs/wasm/              # .vibee specifications
│   ├── vibee_wasm_runtime.vibee
│   ├── vibee_wasm_memory.vibee
│   ├── vibee_wasm_bindings.vibee
│   ├── vibee_wasm_compiler.vibee
│   ├── vibee_wasm_loader.vibee
│   └── vibee_wasm_interop.vibee
├── trinity/output/          # Generated .zig
│   └── vibee_wasm_*.zig
└── trinity/wasm/            # Compiled .wasm
    ├── build_browser_v3.zig
    └── vibee_wasm_*.wasm
```

## Testing

```bash
# Run Zig tests
cd trinity/output
for f in vibee_wasm_*.zig; do zig test "$f"; done

# Build WASM
cd ../wasm
zig build -Doptimize=ReleaseSmall --build-file build_browser_v3.zig
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| SIMD not supported | Build with `-Dsimd=false` |
| Memory limit exceeded | Increase `max_pages` in config |
| Import not found | Check importObject matches exports |
| Slow compilation | Use streaming + caching |

---

*φ² + 1/φ² = 3 | PHOENIX = 999*

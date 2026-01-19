# TRINITY Code Splitting Architecture v20.φ

## Current State

```
runtime.html: 612KB (15,590 lines)
├── CSS: ~15KB
├── HTML: ~5KB
└── JavaScript: ~592KB
    ├── Core (φ-ADS, Layout): ~50KB
    ├── Renderers: ~100KB
    ├── Visualizations: ~400KB
    └── Utilities: ~42KB
```

## Target Architecture

```
Initial Bundle: <100KB
├── core.js: ~30KB
│   ├── φ constants
│   ├── Canvas setup
│   └── Navigation
├── layout.js: ~20KB
│   ├── ArticleLayout
│   └── Dirty regions
└── article.js: ~40KB
    └── Article renderer

Lazy Loaded:
├── renderers/
│   ├── table.js: ~5KB
│   ├── diagram.js: ~10KB
│   └── 3dgs.js: ~50KB
├── visualizations/
│   ├── modules.js: ~30KB
│   ├── tsp.js: ~20KB
│   ├── pas.js: ~25KB
│   └── ... (40+ modules)
└── wasm/
    └── phi_compute.wasm: ~10KB
```

## Implementation Plan

### Phase 1: Extract Modules

```javascript
// src/core.js
export const Φ = { PHI, PHI_INV, PHI_SQ, ... };
export const φADS = { ... };

// src/layout.js
export const ArticleLayout = { ... };
export const ArticleState = { ... };

// src/renderers/table.js
export function renderTable(ctx, x, y, data, options) { ... }

// src/renderers/diagram.js
export function renderFlowchart(ctx, x, y, nodes, edges, options) { ... }
```

### Phase 2: Dynamic Imports

```javascript
// Lazy load visualizations
async function loadVisualization(name) {
  const module = await import(`./visualizations/${name}.js`);
  return module.default;
}

// Usage
if (tab === 'tsp') {
  const TSP = await loadVisualization('tsp');
  TSP.render(ctx);
}
```

### Phase 3: Build System

```javascript
// vite.config.js
export default {
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          core: ['./src/core.js', './src/layout.js'],
          article: ['./src/article.js'],
          renderers: ['./src/renderers/table.js', './src/renderers/diagram.js'],
          '3dgs': ['./src/renderers/3dgs.js']
        }
      }
    }
  }
};
```

## Module Dependency Graph

```
core.js
├── layout.js
│   └── article.js
│       ├── table.js
│       └── diagram.js
├── φ-ADS.js
│   └── webgpu.js
└── visualizations/
    ├── modules.js (depends: core)
    ├── tsp.js (depends: core)
    ├── pas.js (depends: core)
    ├── 3dgs.js (depends: core, φ-ADS)
    └── ...
```

## Loading Strategy

```javascript
// 1. Critical path (blocking)
<script src="core.js"></script>
<script src="layout.js"></script>
<script src="article.js"></script>

// 2. Preload likely modules
<link rel="modulepreload" href="renderers/table.js">
<link rel="modulepreload" href="renderers/diagram.js">

// 3. Lazy load on demand
const loadModule = async (name) => {
  const cache = loadModule.cache || (loadModule.cache = {});
  if (!cache[name]) {
    cache[name] = import(`./visualizations/${name}.js`);
  }
  return cache[name];
};
```

## Size Budget

| Module | Budget | Current | Status |
|--------|--------|---------|--------|
| core.js | 30KB | - | Planned |
| layout.js | 20KB | - | Planned |
| article.js | 40KB | - | Planned |
| table.js | 5KB | ~3KB | ✓ |
| diagram.js | 10KB | ~8KB | ✓ |
| 3dgs.js | 50KB | - | Planned |
| Total Initial | <100KB | 612KB | ❌ |

## Migration Steps

1. **Extract φ constants** → `src/phi.js` ✓
2. **Extract table renderer** → `src/table.js` ✓
3. **Extract diagram renderer** → `src/diagram.js` ✓
4. **Extract WASM loader** → `src/wasm-loader.js` ✓
5. **Extract core** → `src/core.js` (TODO)
6. **Extract layout** → `src/layout.js` (TODO)
7. **Extract article** → `src/article.js` (TODO)
8. **Extract visualizations** → `src/visualizations/*.js` (TODO)
9. **Add build system** → Vite (TODO)
10. **Implement lazy loading** (TODO)

## Temporary Solution

Until full code splitting is implemented, use compression:

```nginx
# nginx.conf
gzip on;
gzip_types text/html application/javascript;
gzip_min_length 1000;

# Result: 612KB → ~120KB gzipped
```

---

*φ² + 1/φ² = 3*

# WASM Integration Guide

**Using VIBEE WASM modules in your projects**

---

## Module Overview

| Module | Size | Description |
|--------|------|-------------|
| phi_core.wasm | 14 KB | Core φ-computations |
| phi_structures.wasm | 18 KB | φ-Tree, Fibonacci Heap |
| phi_layout.wasm | 18 KB | Force-directed layouts |
| phi_crypto.wasm | 24 KB | SHA-256, Merkle Tree |

---

## Browser Usage

### Basic Loading

```javascript
async function loadVibee() {
    const response = await fetch('phi_core.wasm');
    const bytes = await response.arrayBuffer();
    const { instance } = await WebAssembly.instantiate(bytes);
    return instance.exports;
}

// Usage
const vibee = await loadVibee();
console.log(vibee.phi_power(10));      // 122.99...
console.log(vibee.fibonacci(20));       // 6765
console.log(vibee.verify_trinity());    // 3.0
```

### With Memory Access

```javascript
async function loadVibeeWithMemory() {
    const response = await fetch('phi_core.wasm');
    const bytes = await response.arrayBuffer();
    const { instance } = await WebAssembly.instantiate(bytes);
    
    const exports = instance.exports;
    const memory = exports.memory;
    
    // Get buffer pointer and size
    const bufferPtr = exports.get_f64_buffer_ptr();
    const bufferSize = exports.get_f64_buffer_size();
    
    // Create typed array view
    const f64View = new Float64Array(memory.buffer, bufferPtr, bufferSize);
    
    return { exports, f64View };
}

// Generate spiral and read points
const { exports, f64View } = await loadVibeeWithMemory();
const count = exports.generate_phi_spiral(100, 10.0, 0.0, 0.0);

for (let i = 0; i < count; i++) {
    const x = f64View[i * 2];
    const y = f64View[i * 2 + 1];
    console.log(`Point ${i}: (${x}, ${y})`);
}
```

### ES Module Wrapper

```javascript
// vibee.js
let instance = null;
let f64Buffer = null;

export async function init(wasmPath = 'phi_core.wasm') {
    const response = await fetch(wasmPath);
    const bytes = await response.arrayBuffer();
    const result = await WebAssembly.instantiate(bytes);
    instance = result.instance;
    
    const memory = instance.exports.memory;
    const ptr = instance.exports.get_f64_buffer_ptr();
    const size = instance.exports.get_f64_buffer_size();
    f64Buffer = new Float64Array(memory.buffer, ptr, size);
    
    return true;
}

export function phiPower(n) {
    return instance.exports.phi_power(n);
}

export function fibonacci(n) {
    return instance.exports.fibonacci(n);
}

export function verifyTrinity() {
    return instance.exports.verify_trinity();
}

export function generateSpiral(n, scale, cx, cy) {
    const count = instance.exports.generate_phi_spiral(n, scale, cx, cy);
    const points = [];
    for (let i = 0; i < count; i++) {
        points.push({
            x: f64Buffer[i * 2],
            y: f64Buffer[i * 2 + 1]
        });
    }
    return points;
}

// SIMD functions
export function simdVerifyTrinityBatch(iterations) {
    return instance.exports.simd_verify_trinity_batch(iterations);
}

export function simdDotProduct(n) {
    return instance.exports.simd_dot_product(n);
}

export { f64Buffer };
```

**Usage:**
```javascript
import { init, phiPower, fibonacci, generateSpiral } from './vibee.js';

await init();

console.log(phiPower(10));
console.log(fibonacci(20));

const spiral = generateSpiral(100, 10, 0, 0);
spiral.forEach((p, i) => console.log(`${i}: (${p.x}, ${p.y})`));
```

---

## Node.js Usage

### CommonJS

```javascript
const fs = require('fs');
const path = require('path');

async function loadVibee() {
    const wasmPath = path.join(__dirname, 'phi_core.wasm');
    const bytes = fs.readFileSync(wasmPath);
    const { instance } = await WebAssembly.instantiate(bytes);
    return instance.exports;
}

(async () => {
    const vibee = await loadVibee();
    console.log('φ^10 =', vibee.phi_power(10));
    console.log('F(20) =', vibee.fibonacci(20));
    console.log('TRINITY =', vibee.verify_trinity());
})();
```

### ES Modules

```javascript
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));

const bytes = readFileSync(join(__dirname, 'phi_core.wasm'));
const { instance } = await WebAssembly.instantiate(bytes);
const vibee = instance.exports;

console.log('φ^10 =', vibee.phi_power(10));
```

---

## Canvas Visualization

### Golden Spiral

```html
<!DOCTYPE html>
<html>
<head>
    <title>φ-Spiral Visualization</title>
    <style>
        canvas { border: 1px solid #333; }
    </style>
</head>
<body>
    <canvas id="canvas" width="800" height="800"></canvas>
    <script>
        async function main() {
            // Load WASM
            const response = await fetch('phi_core.wasm');
            const bytes = await response.arrayBuffer();
            const { instance } = await WebAssembly.instantiate(bytes);
            const exports = instance.exports;
            
            // Get buffer
            const memory = exports.memory;
            const ptr = exports.get_f64_buffer_ptr();
            const size = exports.get_f64_buffer_size();
            const buffer = new Float64Array(memory.buffer, ptr, size);
            
            // Generate spiral
            const count = exports.generate_phi_spiral(500, 1.0, 400, 400);
            
            // Draw
            const canvas = document.getElementById('canvas');
            const ctx = canvas.getContext('2d');
            
            ctx.fillStyle = '#000';
            ctx.fillRect(0, 0, 800, 800);
            
            ctx.strokeStyle = '#FFD700';
            ctx.lineWidth = 2;
            ctx.beginPath();
            
            for (let i = 0; i < count; i++) {
                const x = buffer[i * 2];
                const y = buffer[i * 2 + 1];
                
                if (i === 0) {
                    ctx.moveTo(x, y);
                } else {
                    ctx.lineTo(x, y);
                }
                
                // Draw point
                ctx.fillStyle = `hsl(${i * 137.5 % 360}, 70%, 50%)`;
                ctx.beginPath();
                ctx.arc(x, y, 3, 0, Math.PI * 2);
                ctx.fill();
            }
            
            ctx.stroke();
        }
        main();
    </script>
</body>
</html>
```

---

## Performance Tips

### 1. Batch Operations

```javascript
// ❌ Slow: Many small calls
for (let i = 0; i < 1000; i++) {
    results[i] = vibee.phi_power(i);
}

// ✅ Fast: Use SIMD batch
const sum = vibee.simd_verify_trinity_batch(1000);
```

### 2. Reuse Memory Buffer

```javascript
// ❌ Slow: Create new view each time
function getPoints() {
    return new Float64Array(memory.buffer, ptr, size);
}

// ✅ Fast: Reuse view
const f64View = new Float64Array(memory.buffer, ptr, size);
function getPoints() {
    return f64View;
}
```

### 3. Minimize JS-WASM Boundary Crossings

```javascript
// ❌ Slow: Many boundary crossings
for (let i = 0; i < 1000; i++) {
    vibee.some_function(i);
}

// ✅ Fast: Single call with batch
vibee.batch_function(1000);
```

---

## SIMD Support

VIBEE WASM modules include SIMD128 optimizations:

```javascript
// Check SIMD support
const simdSupported = WebAssembly.validate(new Uint8Array([
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7b, 0x03,
    0x02, 0x01, 0x00, 0x0a, 0x0a, 0x01, 0x08, 0x00,
    0x41, 0x00, 0xfd, 0x0f, 0xfd, 0x62, 0x0b
]));

if (simdSupported) {
    // Use SIMD functions
    const result = vibee.simd_verify_trinity_batch(1000000);
    console.log('SIMD result:', result);
} else {
    // Fallback to scalar
    let sum = 0;
    for (let i = 0; i < 1000000; i++) {
        sum += vibee.verify_trinity();
    }
    console.log('Scalar result:', sum);
}
```

---

## Error Handling

```javascript
async function safeLoadVibee(wasmPath) {
    try {
        const response = await fetch(wasmPath);
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        
        const bytes = await response.arrayBuffer();
        const { instance } = await WebAssembly.instantiate(bytes);
        
        // Verify module
        if (typeof instance.exports.verify_trinity !== 'function') {
            throw new Error('Invalid VIBEE module');
        }
        
        // Verify TRINITY identity
        const trinity = instance.exports.verify_trinity();
        if (Math.abs(trinity - 3.0) > 1e-10) {
            throw new Error('TRINITY verification failed');
        }
        
        return instance.exports;
    } catch (error) {
        console.error('Failed to load VIBEE:', error);
        throw error;
    }
}
```

---

## TypeScript Definitions

```typescript
// vibee.d.ts
declare module 'vibee' {
    export interface VibeeExports {
        // Constants
        memory: WebAssembly.Memory;
        
        // Core functions
        phi_power(n: number): number;
        fibonacci(n: number): bigint;
        lucas(n: number): bigint;
        verify_trinity(): number;
        phi_lerp(a: number, b: number, t: number): number;
        
        // Spiral
        generate_phi_spiral(n: number, scale: number, cx: number, cy: number): number;
        
        // SIMD
        simd_verify_trinity_batch(iterations: number): number;
        simd_dot_product(n: number): number;
        simd_sum_squares(n: number): number;
        simd_phi_weighted_sum(n: number): number;
        
        // Buffer access
        get_f64_buffer_ptr(): number;
        get_f64_buffer_size(): number;
    }
    
    export function init(wasmPath?: string): Promise<VibeeExports>;
}
```

---

*φ² + 1/φ² = 3*

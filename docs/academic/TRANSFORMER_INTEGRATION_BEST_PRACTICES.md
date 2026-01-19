# Transformer Integration Best Practices

**Автор**: Dmitrii Vasilev  
**Дата**: 2026-01-20  
**Версия**: v44 Planning  

---

## 1. Архитектура Интеграции

### 1.1 Общая Схема

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        VIBEE TRANSFORMER STACK                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      APPLICATION LAYER                               │   │
│  │  WeDLM Decoder → Streaming Parallel Decoding → Output                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      ABSTRACTION LAYER                               │   │
│  │  TransformerBackend (trait/interface)                                │   │
│  │  ├── forward(tokens, kv_cache) → logits                              │   │
│  │  ├── get_kv_cache() → KVCache                                        │   │
│  │  └── update_kv_cache(new_tokens)                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│          ┌─────────────────────────┼─────────────────────────┐              │
│          │                         │                         │              │
│          ▼                         ▼                         ▼              │
│  ┌───────────────┐       ┌───────────────┐       ┌───────────────┐         │
│  │ ONNX Runtime  │       │  llama.cpp    │       │   vLLM API    │         │
│  │   Backend     │       │   Backend     │       │   Backend     │         │
│  │               │       │               │       │               │         │
│  │ • C API       │       │ • Native Zig  │       │ • HTTP/gRPC   │         │
│  │ • CPU/CUDA    │       │ • GGUF models │       │ • PagedAttn   │         │
│  │ • DirectML    │       │ • Quantized   │       │ • Batching    │         │
│  └───────────────┘       └───────────────┘       └───────────────┘         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Backend Interface

```zig
// Абстракция для любого transformer backend
pub const TransformerBackend = struct {
    // Virtual table for polymorphism
    vtable: *const VTable,
    
    const VTable = struct {
        forward: *const fn (self: *anyopaque, tokens: []const u32, kv_cache: ?*KVCache) anyerror![]f32,
        get_kv_cache: *const fn (self: *anyopaque) ?*KVCache,
        update_kv_cache: *const fn (self: *anyopaque, new_tokens: []const u32) anyerror!void,
        deinit: *const fn (self: *anyopaque) void,
    };
    
    pub fn forward(self: *TransformerBackend, tokens: []const u32, kv_cache: ?*KVCache) ![]f32 {
        return self.vtable.forward(self, tokens, kv_cache);
    }
    
    pub fn getKVCache(self: *TransformerBackend) ?*KVCache {
        return self.vtable.get_kv_cache(self);
    }
};
```

---

## 2. ONNX Runtime Integration

### 2.1 Почему ONNX Runtime

| Преимущество | Описание |
|--------------|----------|
| **Cross-platform** | Windows, Linux, macOS, iOS, Android |
| **Multiple backends** | CPU, CUDA, TensorRT, DirectML, CoreML |
| **C API** | Легко интегрируется с Zig через @cImport |
| **Optimized** | Graph optimizations, quantization |
| **Production-ready** | Используется в Microsoft, Meta, etc. |

### 2.2 Zig + ONNX Runtime C API

```zig
const c = @cImport({
    @cInclude("onnxruntime_c_api.h");
});

pub const ONNXBackend = struct {
    env: *c.OrtEnv,
    session: *c.OrtSession,
    allocator: *c.OrtAllocator,
    
    pub fn init(model_path: [*:0]const u8) !ONNXBackend {
        var env: *c.OrtEnv = undefined;
        const api = c.OrtGetApiBase().*.GetApi(c.ORT_API_VERSION);
        
        // Create environment
        _ = api.*.CreateEnv(c.ORT_LOGGING_LEVEL_WARNING, "vibee", &env);
        
        // Create session options
        var session_options: *c.OrtSessionOptions = undefined;
        _ = api.*.CreateSessionOptions(&session_options);
        
        // Enable CUDA if available
        _ = api.*.SessionOptionsAppendExecutionProvider_CUDA(session_options, 0);
        
        // Create session
        var session: *c.OrtSession = undefined;
        _ = api.*.CreateSession(env, model_path, session_options, &session);
        
        return ONNXBackend{
            .env = env,
            .session = session,
            .allocator = undefined, // Get default allocator
        };
    }
    
    pub fn forward(self: *ONNXBackend, input_ids: []const i64) ![]f32 {
        // Create input tensor
        // Run inference
        // Return logits
    }
};
```

### 2.3 Model Conversion Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      MODEL CONVERSION PIPELINE                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. Source Model (HuggingFace)                                              │
│     └── transformers.AutoModelForCausalLM.from_pretrained("model")          │
│                                    │                                        │
│                                    ▼                                        │
│  2. Export to ONNX                                                          │
│     └── optimum-cli export onnx --model model --task causal-lm output/      │
│                                    │                                        │
│                                    ▼                                        │
│  3. Optimize ONNX                                                           │
│     └── python -m onnxruntime.transformers.optimizer                        │
│         --input model.onnx                                                  │
│         --output model_optimized.onnx                                       │
│         --model_type gpt2                                                   │
│         --use_gpu                                                           │
│                                    │                                        │
│                                    ▼                                        │
│  4. Quantize (optional)                                                     │
│     └── python -m onnxruntime.quantization.quantize                         │
│         --input model_optimized.onnx                                        │
│         --output model_int8.onnx                                            │
│         --quant_format QDQ                                                  │
│                                    │                                        │
│                                    ▼                                        │
│  5. Load in VIBEE                                                           │
│     └── ONNXBackend.init("model_int8.onnx")                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. KV Cache Best Practices

### 3.1 PagedAttention (vLLM)

```
PAGED ATTENTION CONCEPT:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  ПРОБЛЕМА: Contiguous KV Cache                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ Sequence 1: [████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] │   │
│  │ Sequence 2: [████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] │   │
│  │ Sequence 3: [████████████████████████████░░░░░░░░░░░░░░░░░░░░░░░░] │   │
│  │                                                                     │   │
│  │ ░ = Wasted memory (pre-allocated for max_seq_len)                   │   │
│  │ Memory waste: 60-80% typical                                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  РЕШЕНИЕ: Paged Attention                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ Physical Blocks:  [B0][B1][B2][B3][B4][B5][B6][B7][B8][B9]...       │   │
│  │                                                                     │   │
│  │ Sequence 1 → Block Table: [0, 3, 7]                                 │   │
│  │ Sequence 2 → Block Table: [1, 5]                                    │   │
│  │ Sequence 3 → Block Table: [2, 4, 6, 8]                              │   │
│  │                                                                     │   │
│  │ Memory waste: <4% (only last block partially filled)                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 KV Cache для WeDLM

```
WeDLM KV CACHE STRATEGY:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  ОСОБЕННОСТЬ WeDLM: Topological Reordering                                  │
│                                                                             │
│  Физический порядок меняется, но KV cache должен соответствовать            │
│  ЛОГИЧЕСКИМ позициям (RoPE position ids)                                    │
│                                                                             │
│  РЕШЕНИЕ: Position-indexed KV Cache                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                                                     │   │
│  │  KV Cache Structure:                                                │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │ Position │ Key Vector (d_k) │ Value Vector (d_v) │ Valid   │   │   │
│  │  ├─────────────────────────────────────────────────────────────┤   │   │
│  │  │    0     │ [k0_0...k0_dk]   │ [v0_0...v0_dv]     │  true   │   │   │
│  │  │    1     │ [k1_0...k1_dk]   │ [v1_0...v1_dv]     │  true   │   │   │
│  │  │    2     │ [k2_0...k2_dk]   │ [v2_0...v2_dv]     │  false  │   │   │
│  │  │    3     │ [k3_0...k3_dk]   │ [v3_0...v3_dv]     │  true   │   │   │
│  │  │   ...    │       ...        │       ...          │   ...   │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                                                                     │   │
│  │  При Topological Reorder:                                           │   │
│  │  - Физический порядок: [0, 3, 1, 2] (committed first)               │   │
│  │  - KV lookup по ЛОГИЧЕСКОЙ позиции, не физической                   │   │
│  │  - Committed positions (0, 3) → cache hit                           │   │
│  │  - Masked positions (1, 2) → recompute                              │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Zig Implementation

```zig
pub const PagedKVCache = struct {
    const BLOCK_SIZE: u32 = 16; // Tokens per block
    
    blocks: std.ArrayList(KVBlock),
    block_tables: std.AutoHashMap(u32, std.ArrayList(u32)), // seq_id → block_ids
    free_blocks: std.ArrayList(u32),
    allocator: std.mem.Allocator,
    
    pub const KVBlock = struct {
        keys: [BLOCK_SIZE][HEAD_DIM]f32,
        values: [BLOCK_SIZE][HEAD_DIM]f32,
        num_tokens: u32,
    };
    
    pub fn init(allocator: std.mem.Allocator, num_blocks: u32) !PagedKVCache {
        var cache = PagedKVCache{
            .blocks = std.ArrayList(KVBlock).init(allocator),
            .block_tables = std.AutoHashMap(u32, std.ArrayList(u32)).init(allocator),
            .free_blocks = std.ArrayList(u32).init(allocator),
            .allocator = allocator,
        };
        
        // Pre-allocate blocks
        for (0..num_blocks) |i| {
            try cache.blocks.append(KVBlock{
                .keys = undefined,
                .values = undefined,
                .num_tokens = 0,
            });
            try cache.free_blocks.append(@intCast(i));
        }
        
        return cache;
    }
    
    pub fn allocateBlock(self: *PagedKVCache, seq_id: u32) !u32 {
        if (self.free_blocks.items.len == 0) {
            return error.OutOfMemory;
        }
        
        const block_id = self.free_blocks.pop();
        
        var table = self.block_tables.getPtr(seq_id) orelse {
            try self.block_tables.put(seq_id, std.ArrayList(u32).init(self.allocator));
            return self.block_tables.getPtr(seq_id).?;
        };
        
        try table.append(block_id);
        return block_id;
    }
    
    pub fn appendKV(self: *PagedKVCache, seq_id: u32, position: u32, key: []f32, value: []f32) !void {
        const table = self.block_tables.get(seq_id) orelse return error.SequenceNotFound;
        
        const block_idx = position / BLOCK_SIZE;
        const slot_idx = position % BLOCK_SIZE;
        
        // Allocate new block if needed
        while (table.items.len <= block_idx) {
            _ = try self.allocateBlock(seq_id);
        }
        
        const block_id = table.items[block_idx];
        var block = &self.blocks.items[block_id];
        
        @memcpy(&block.keys[slot_idx], key);
        @memcpy(&block.values[slot_idx], value);
        block.num_tokens = @max(block.num_tokens, slot_idx + 1);
    }
    
    pub fn getKV(self: *PagedKVCache, seq_id: u32, position: u32) ?struct { key: []f32, value: []f32 } {
        const table = self.block_tables.get(seq_id) orelse return null;
        
        const block_idx = position / BLOCK_SIZE;
        const slot_idx = position % BLOCK_SIZE;
        
        if (block_idx >= table.items.len) return null;
        
        const block_id = table.items[block_idx];
        const block = &self.blocks.items[block_id];
        
        if (slot_idx >= block.num_tokens) return null;
        
        return .{
            .key = &block.keys[slot_idx],
            .value = &block.values[slot_idx],
        };
    }
};
```

---

## 4. GPU Acceleration

### 4.1 Варианты для Zig

| Backend | Pros | Cons |
|---------|------|------|
| **CUDA via C** | Fastest, full control | NVIDIA only, complex |
| **OpenCL** | Cross-platform | Slower than CUDA |
| **Vulkan Compute** | Cross-platform, modern | Complex API |
| **ONNX Runtime CUDA** | Easy integration | Less control |
| **llama.cpp CUDA** | Optimized for LLMs | Limited to GGUF |

### 4.2 Рекомендуемый Подход

```
RECOMMENDED GPU STRATEGY:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  Phase 1: ONNX Runtime with CUDA EP (Immediate)                             │
│  ├── Minimal code changes                                                   │
│  ├── Automatic GPU utilization                                              │
│  └── 5-10x speedup expected                                                 │
│                                                                             │
│  Phase 2: Custom CUDA Kernels (Future)                                      │
│  ├── PagedAttention kernel                                                  │
│  ├── Fused softmax + attention                                              │
│  └── 2-3x additional speedup                                                │
│                                                                             │
│  Phase 3: TensorRT Integration (Production)                                 │
│  ├── Maximum optimization                                                   │
│  ├── INT8/FP16 quantization                                                 │
│  └── 1.5-2x additional speedup                                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. vLLM Benchmark Strategy

### 5.1 Fair Comparison Setup

```
BENCHMARK SETUP:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  Hardware: Same GPU (e.g., A100 40GB)                                       │
│  Model: Same model (e.g., Llama-2-7B)                                       │
│  Batch size: Same (e.g., 1 for latency, 32 for throughput)                  │
│  Sequence length: Same (e.g., 512 input, 128 output)                        │
│                                                                             │
│  Metrics:                                                                   │
│  ├── Time to First Token (TTFT)                                             │
│  ├── Tokens per Second (TPS)                                                │
│  ├── Memory Usage (GB)                                                      │
│  └── Quality (perplexity, accuracy)                                         │
│                                                                             │
│  Baselines:                                                                 │
│  ├── vLLM (PagedAttention, continuous batching)                             │
│  ├── HuggingFace Transformers (naive)                                       │
│  └── TensorRT-LLM (NVIDIA optimized)                                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Expected Results

| System | TTFT | TPS | Memory | Notes |
|--------|------|-----|--------|-------|
| HF Transformers | 100ms | 30 | 14GB | Baseline |
| vLLM | 50ms | 100 | 10GB | PagedAttention |
| TensorRT-LLM | 30ms | 150 | 8GB | Maximum opt |
| **VIBEE WeDLM** | **40ms** | **120** | **9GB** | **Target** |

---

## 6. Implementation Roadmap

### Phase 1: ONNX Backend (Week 1-2)

```
Tasks:
├── [ ] Create ONNXBackend struct
├── [ ] Implement C API bindings
├── [ ] Model loading and session creation
├── [ ] Forward pass with KV cache
├── [ ] Basic tests with small model
└── [ ] Benchmark vs simulated backend
```

### Phase 2: PagedKVCache (Week 2-3)

```
Tasks:
├── [ ] Implement PagedKVCache struct
├── [ ] Block allocation/deallocation
├── [ ] Position-indexed lookup
├── [ ] Integration with WeDLM decoder
├── [ ] Memory efficiency tests
└── [ ] Benchmark cache hit rate
```

### Phase 3: GPU Acceleration (Week 3-4)

```
Tasks:
├── [ ] Enable CUDA EP in ONNX Runtime
├── [ ] GPU memory management
├── [ ] Async execution
├── [ ] Multi-GPU support (optional)
└── [ ] Benchmark GPU vs CPU
```

### Phase 4: vLLM Comparison (Week 4-5)

```
Tasks:
├── [ ] Setup vLLM baseline
├── [ ] Implement benchmark suite
├── [ ] Run comparative tests
├── [ ] Analyze results
└── [ ] Document findings
```

---

## 7. Научные Ссылки

1. **PagedAttention** (Kwon et al., 2023)
   - vLLM: Efficient Memory Management for LLM Serving
   - https://arxiv.org/abs/2309.06180

2. **FlashAttention** (Dao et al., 2022)
   - Fast and Memory-Efficient Exact Attention
   - https://arxiv.org/abs/2205.14135

3. **ONNX Runtime** (Microsoft)
   - Cross-platform ML inference
   - https://onnxruntime.ai/

4. **TensorRT-LLM** (NVIDIA)
   - Optimized LLM inference
   - https://github.com/NVIDIA/TensorRT-LLM

5. **llama.cpp** (Gerganov)
   - Efficient LLM inference in C/C++
   - https://github.com/ggerganov/llama.cpp

---

**φ² + 1/φ² = 3 | PHOENIX = 999 = 3³ × 37**

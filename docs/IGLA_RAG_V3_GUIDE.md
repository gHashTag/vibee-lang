# IGLA RAG v3 Guide

**Author**: Dmitrii Vasilev  
**Version**: 3.0.0  
**Date**: 2026-01-21

---

## Overview

IGLA RAG v3 extends v2 with real embeddings, persistent storage, streaming generation, multi-modal support, and evaluation benchmarks.

## What's New in v3

| Feature | Description |
|---------|-------------|
| **ONNX Runtime** | ML inference engine for embeddings |
| **MiniLM Embeddings** | Real 384-dim dense vectors |
| **Persistent Store** | SQLite/RocksDB backend |
| **Streaming Gen** | SSE token streaming |
| **CLIP Embeddings** | Image embeddings (512-dim) |
| **Multi-Modal Index** | Text + Image search |
| **RAGAS Evaluation** | Quality metrics |
| **BEIR Benchmark** | IR benchmarks |

## Module Statistics

| Version | Modules | Tests |
|---------|---------|-------|
| RAG v1 | 5 | 25 |
| RAG v2 | 55 | 495 |
| **RAG v3** | **8** | **91** |
| **TOTAL** | **68** | **611** |

## v3 Modules

| Module | Tests | Description |
|--------|-------|-------------|
| `igla_onnx_runtime` | 11 | ONNX Runtime integration |
| `igla_minilm_embeddings` | 11 | MiniLM-L6-v2 embeddings |
| `igla_persistent_store` | 13 | SQLite/RocksDB storage |
| `igla_streaming_gen` | 11 | SSE streaming |
| `igla_clip_embeddings` | 11 | CLIP image embeddings |
| `igla_multimodal_index` | 11 | Multi-modal search |
| `igla_ragas_eval` | 11 | RAGAS metrics |
| `igla_beir_benchmark` | 12 | BEIR benchmarks |

## Embedding Models

| Model | Dimension | Use Case |
|-------|-----------|----------|
| MiniLM-L6-v2 | 384 | Text (default) |
| CLIP | 512 | Multi-modal |
| BGE | 768 | Text (high quality) |
| E5 | 1024 | Text (best quality) |

## Storage Backends

| Backend | Description | Use Case |
|---------|-------------|----------|
| Memory | In-memory | Development, small datasets |
| SQLite | Persistent, portable | Production, medium datasets |
| RocksDB | High-performance | Production, large datasets |

## CLI Commands

### v3 Options

```bash
# Use MiniLM embeddings
vibee rag query "What is VIBEE?" --embed minilm

# Use CLIP for multi-modal
vibee rag query "cat image" --embed clip --multimodal

# Use SQLite storage
vibee rag index ./docs --storage sqlite

# Enable streaming
vibee rag query "Explain RAG" --stream

# Run evaluation
vibee rag query "test" --eval
```

## API Endpoints

### GET /v1/rag/info

Returns v3 system information.

```json
{
  "version": "3.0.0",
  "embedding_models": ["minilm", "clip", "bge", "e5"],
  "storage_backends": ["memory", "sqlite", "rocksdb"],
  "features": {
    "streaming": true,
    "multimodal": true,
    "evaluation": true
  },
  "v3_extensions": {
    "onnx_runtime": true,
    "minilm_embeddings": true,
    "persistent_store": true,
    "streaming_gen": true,
    "clip_embeddings": true,
    "multimodal_index": true,
    "ragas_eval": true,
    "beir_benchmark": true
  }
}
```

### POST /v1/rag/stream

Streaming generation with SSE.

```
data: {"chunk":"VIBEE","index":0}

data: {"chunk":" is","index":1}

data: {"chunk":" a","index":2}

data: {"finish_reason":"stop"}
```

### POST /v1/rag/eval

RAGAS and BEIR evaluation.

```json
{
  "ragas": {
    "faithfulness": 0.92,
    "answer_relevancy": 0.88,
    "context_precision": 0.85,
    "context_recall": 0.90,
    "overall": 0.89
  },
  "beir": {
    "ndcg_at_10": 0.78,
    "recall_at_100": 0.92,
    "mrr": 0.82
  }
}
```

## RAGAS Metrics

| Metric | Description |
|--------|-------------|
| Faithfulness | Answer grounded in context |
| Answer Relevancy | Answer addresses question |
| Context Precision | Relevant contexts ranked higher |
| Context Recall | Ground truth covered by contexts |

## BEIR Metrics

| Metric | Description |
|--------|-------------|
| NDCG@10 | Normalized DCG at rank 10 |
| Recall@100 | Recall at rank 100 |
| MRR | Mean Reciprocal Rank |

## Configuration

```zig
pub const RAGConfigV3 = struct {
    // v2 config
    search_mode: SearchMode = .hybrid,
    index_type: IndexType = .flat,
    
    // v3 extensions
    embedding_model: EmbeddingModel = .minilm,
    storage_backend: StorageBackend = .memory,
    storage_path: []const u8 = "rag_index.db",
    enable_streaming: bool = true,
    enable_multimodal: bool = false,
    enable_evaluation: bool = false,
};
```

## Specifications

All v3 modules generated from `.vibee` specs:

```
specs/tri/igla_onnx_runtime.vibee
specs/tri/igla_minilm_embeddings.vibee
specs/tri/igla_persistent_store.vibee
specs/tri/igla_streaming_gen.vibee
specs/tri/igla_clip_embeddings.vibee
specs/tri/igla_multimodal_index.vibee
specs/tri/igla_ragas_eval.vibee
specs/tri/igla_beir_benchmark.vibee
```

## Testing

```bash
# Test all v3 modules
cd trinity/output
zig test igla_onnx_runtime.zig
zig test igla_minilm_embeddings.zig
zig test igla_persistent_store.zig
zig test igla_streaming_gen.zig
zig test igla_clip_embeddings.zig
zig test igla_multimodal_index.zig
zig test igla_ragas_eval.zig
zig test igla_beir_benchmark.zig
```

## Sacred Constants

```
φ (phi)       = 1.618033988749895
φ²            = 2.618033988749895
1/φ²          = 0.381966011250105
φ² + 1/φ² = 3 ✓ VERIFIED

PHOENIX = 999 = 27 × 37 = 3³ × 37
```

---

**φ² + 1/φ² = 3 | PHOENIX = 999**

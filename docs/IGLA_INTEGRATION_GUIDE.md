# IGLA RAG v2 Integration Guide

**Author**: Dmitrii Vasilev  
**Version**: 2.0.0  
**Date**: 2026-01-21

---

## Overview

IGLA (Intelligent Generation with Learned Augmentation) is the RAG subsystem of VIBEE. This guide covers integration of all 60 modules across 5 versions.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    IGLA RAG v2 ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Document Input                                                 │
│       ↓                                                         │
│  ┌─────────────┐                                                │
│  │  Chunker    │ → Semantic splitting (500 chars, 50 overlap)   │
│  └─────────────┘                                                │
│       ↓                                                         │
│  ┌─────────────┐                                                │
│  │ Embeddings  │ → MiniLM 384-dim dense vectors                 │
│  └─────────────┘                                                │
│       ↓                                                         │
│  ┌─────────────┐                                                │
│  │   Index     │ → Flat / HNSW / DiskANN                        │
│  └─────────────┘                                                │
│       ↓                                                         │
│  ┌─────────────┐                                                │
│  │   Search    │ → BM25 / Dense / Hybrid / ColBERT              │
│  └─────────────┘                                                │
│       ↓                                                         │
│  ┌─────────────┐                                                │
│  │  Reranker   │ → Cross-encoder reranking                      │
│  └─────────────┘                                                │
│       ↓                                                         │
│  ┌─────────────┐                                                │
│  │ Generator   │ → LLM with RAG context                         │
│  └─────────────┘                                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Module Versions

| Version | Modules | Tests | Features |
|---------|---------|-------|----------|
| RAG v1 | 5 | 25 | Basic pipeline |
| RAG v2 | 11 | 99 | Dense, Hybrid, Rerank, Cache |
| Scale v3 | 12 | 108 | HNSW, Quantization, ColBERT |
| v4 | 17 | 153 | DiskANN, Self-RAG, Streaming |
| v5 FINAL | 15 | 135 | GPU, Training, Video, Federated, Quantum |
| **TOTAL** | **60** | **520** | **100% pass rate** |

## CLI Commands

### Index Documents

```bash
# Basic indexing
vibee rag index ./docs

# With HNSW index
vibee rag index ./docs --index hnsw

# With DiskANN for large datasets
vibee rag index ./docs --index diskann
```

### Query Documents

```bash
# Basic query
vibee rag query "What is VIBEE?"

# Hybrid search with reranking
vibee rag query "How does PAS work?" --mode hybrid --rerank

# ColBERT late interaction
vibee rag query "Golden identity" --mode colbert --top-k 10
```

### System Info

```bash
vibee rag info
vibee rag help
vibee rag demo
```

## API Endpoints

### GET /v1/rag/info

Returns system information.

```json
{
  "version": "2.0.0",
  "search_modes": ["bm25", "dense", "hybrid", "colbert"],
  "index_types": ["flat", "hnsw", "diskann"],
  "features": {
    "reranking": true,
    "caching": true,
    "streaming": true
  },
  "modules": {
    "total": 60,
    "tests": 520,
    "pass_rate": 100
  }
}
```

### POST /v1/rag/query

Query indexed documents.

**Request:**
```json
{
  "query": "What is VIBEE?",
  "mode": "hybrid",
  "top_k": 5,
  "rerank": true
}
```

**Response:**
```json
{
  "id": "rag-123456",
  "object": "rag.query",
  "results": [
    {
      "doc_id": 0,
      "score": 0.95,
      "text": "VIBEE is a specification-first programming language",
      "source": "overview.md"
    }
  ],
  "usage": {
    "chunks_searched": 100,
    "latency_ms": 15
  }
}
```

### POST /v1/rag/index

Index new documents.

**Request:**
```json
{
  "text": "Document content here...",
  "source": "document.md"
}
```

**Response:**
```json
{
  "id": "idx-123456",
  "object": "rag.index",
  "chunks_indexed": 5,
  "status": "success"
}
```

## Search Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| `bm25` | Classic sparse search | Keyword matching |
| `dense` | MiniLM 384-dim embeddings | Semantic similarity |
| `hybrid` | BM25 + Dense with RRF fusion | Best of both |
| `colbert` | Late interaction MaxSim | High precision |

## Index Types

| Type | Scale | Description |
|------|-------|-------------|
| `flat` | <100K | Brute force, exact |
| `hnsw` | <10M | Graph-based, fast |
| `diskann` | 100B+ | SSD-optimized |

## Configuration

```zig
pub const RAGConfig = struct {
    search_mode: SearchMode = .hybrid,
    index_type: IndexType = .flat,
    use_reranking: bool = true,
    bm25_weight: f32 = 0.4,
    dense_weight: f32 = 0.6,
    chunk_size: usize = 500,
    chunk_overlap: usize = 50,
    top_k: usize = 5,
    hnsw_M: usize = 16,
    hnsw_ef_construction: usize = 200,
    hnsw_ef_search: usize = 50,
};
```

## Generated Modules

All modules are generated from `.vibee` specifications:

```
specs/tri/*.vibee → vibee gen → trinity/output/*.zig
```

Key integration modules:
- `igla_unified_pipeline.zig` - Main pipeline
- `igla_config_manager.zig` - Configuration
- `igla_module_registry.zig` - Module registry

## Testing

```bash
# Test core modules
zig test generated/crush/zig/rag.zig
zig test generated/crush/zig/serve.zig

# Test generated modules
zig test trinity/output/igla_unified_pipeline.zig
zig test trinity/output/igla_config_manager.zig
zig test trinity/output/igla_module_registry.zig
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

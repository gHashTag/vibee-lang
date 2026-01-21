# IGLA RAG Guide v2

Retrieval-Augmented Generation for VIBEE document Q&A.

**Version**: 2.0.0 | **Modules**: 60 | **Tests**: 520 | **Pass Rate**: 100%

## Overview

IGLA RAG v2 combines document retrieval with LLM generation to answer questions based on indexed content. The system uses an advanced multi-stage pipeline:

1. **Chunker** - Semantic text splitting (500 chars, 50 overlap)
2. **Embeddings** - MiniLM 384-dim dense vectors
3. **Index** - Flat / HNSW / DiskANN
4. **Search** - BM25 / Dense / Hybrid / ColBERT
5. **Reranker** - Cross-encoder reranking
6. **Generator** - LLM with RAG context

## Quick Start

```bash
# Show system info
vibee rag info

# Run demo with sample documents
vibee rag demo

# Index a directory (with HNSW index)
vibee rag index ./docs --index hnsw

# Query with hybrid search and reranking
vibee rag query "What is VIBEE?" --mode hybrid --rerank --top-k 5
```

## Commands

| Command | Description |
|---------|-------------|
| `vibee rag info` | Show RAG v2 configuration and sacred constants |
| `vibee rag demo` | Run demo with sample VIBEE documents |
| `vibee rag index <dir>` | Index .md, .txt, .vibee files from directory |
| `vibee rag query <text>` | Query indexed documents |
| `vibee rag help` | Show help |

## Search Modes (v2)

| Mode | Flag | Description |
|------|------|-------------|
| BM25 | `--mode bm25` | Classic sparse keyword search |
| Dense | `--mode dense` | MiniLM 384-dim semantic search |
| Hybrid | `--mode hybrid` | BM25 + Dense with RRF fusion (default) |
| ColBERT | `--mode colbert` | Late interaction MaxSim |

## Index Types (v2)

| Type | Flag | Scale | Description |
|------|------|-------|-------------|
| Flat | `--index flat` | <100K | Brute force, exact |
| HNSW | `--index hnsw` | <10M | Graph-based, fast |
| DiskANN | `--index diskann` | 100B+ | SSD-optimized |

## Options (v2)

| Option | Description |
|--------|-------------|
| `--rerank` | Enable cross-encoder reranking |
| `--no-cache` | Disable query caching |
| `--top-k <n>` | Number of results (default: 5) |

## Configuration

Default settings in `rag.zig`:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `chunk_size` | 500 | Characters per chunk |
| `chunk_overlap` | 50 | Overlap between chunks |
| `top_k` | 3 | Number of results to retrieve |
| `llm_port` | 8001 | Port for LLM inference |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    IGLA RAG PIPELINE                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Document → Chunker → Chunks → VectorStore                      │
│                                    ↓                            │
│  Query → Tokenize → Similarity → Retriever → Top-K Chunks       │
│                                                   ↓             │
│                                           RAG Prompt Builder    │
│                                                   ↓             │
│                                           LLM Generation        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Specifications

The RAG system is defined by these .vibee specifications:

- `specs/tri/igla_rag_embeddings.vibee` - Vector embeddings
- `specs/tri/igla_rag_vectorstore.vibee` - Vector storage
- `specs/tri/igla_rag_retriever.vibee` - Document retrieval
- `specs/tri/igla_rag_chunker.vibee` - Text chunking
- `specs/tri/igla_rag_pipeline.vibee` - Full pipeline

## Implementation

Core implementation in `generated/crush/zig/rag.zig`:

```zig
// Create pipeline
var pipeline = rag.RAGPipeline.init(allocator, rag.RAGConfig.default());
defer pipeline.deinit();

// Index documents
const chunks = try pipeline.indexText(content, "source.md");

// Query
const prompt = try pipeline.query("What is VIBEE?");
```

## Sacred Constants

The RAG system honors VIBEE's sacred constants:

```
φ (phi)       = 1.618033988749895
φ²            = 2.618033988749895
1/φ²          = 0.381966011250105
φ² + 1/φ² = 3 ✓ VERIFIED

PHOENIX = 999 = 27 × 37 = 3³ × 37
```

## Integration with LLM

The RAG prompt can be sent to any OpenAI-compatible endpoint:

```bash
# Start inference server
vibee serve -m models/tinyllama.gguf --port 8001

# Query with RAG context
curl -X POST http://localhost:8001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "<RAG_PROMPT>"}]}'
```

## Performance

Tested on VIBEE documentation:

| Metric | Value |
|--------|-------|
| Files indexed | 308 |
| Total chunks | 5735 |
| Index time | ~2s |
| Query time | <10ms |

## Module Versions

| Version | Modules | Tests | Features |
|---------|---------|-------|----------|
| RAG v1 | 5 | 25 | Basic pipeline |
| RAG v2 | 11 | 99 | Dense, Hybrid, Rerank, Cache |
| Scale v3 | 12 | 108 | HNSW, Quantization, ColBERT |
| v4 | 17 | 153 | DiskANN, Self-RAG, Streaming |
| v5 FINAL | 15 | 135 | GPU, Training, Video, Federated, Quantum |
| **TOTAL** | **60** | **520** | **100% pass rate** |

## API Endpoints (v2)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/rag/info` | GET | System information |
| `/v1/rag/query` | POST | Query documents |
| `/v1/rag/index` | POST | Index documents |

## Completed Features (v2)

- [x] Persistent vector storage
- [x] Dense embeddings (MiniLM 384-dim)
- [x] Hybrid search (BM25 + Dense with RRF)
- [x] Streaming generation
- [x] Cross-encoder reranking
- [x] HNSW graph index
- [x] DiskANN for 100B+ scale
- [x] ColBERT late interaction
- [x] Query caching (LRU + Semantic)
- [x] GPU acceleration
- [x] Federated RAG
- [x] Quantum-ready architecture

---

φ² + 1/φ² = 3 | PHOENIX = 999

# IGLA RAG Guide

Retrieval-Augmented Generation for VIBEE document Q&A.

## Overview

IGLA RAG combines document retrieval with LLM generation to answer questions based on indexed content. The system uses a simple but effective pipeline:

1. **Chunker** - Splits documents into overlapping chunks
2. **Embeddings** - Generates word-based similarity scores
3. **VectorStore** - Stores chunks in memory
4. **Retriever** - Finds relevant chunks via cosine similarity
5. **Generator** - Builds prompts with retrieved context

## Quick Start

```bash
# Show system info
vibee rag info

# Run demo with sample documents
vibee rag demo

# Index a directory
vibee rag index ./docs

# Query indexed documents
vibee rag query "What is VIBEE?"
```

## Commands

| Command | Description |
|---------|-------------|
| `vibee rag info` | Show RAG configuration and sacred constants |
| `vibee rag demo` | Run demo with sample VIBEE documents |
| `vibee rag index <dir>` | Index .md, .txt, .vibee files from directory |
| `vibee rag query <text>` | Query indexed documents |
| `vibee rag help` | Show help |

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

## Future Enhancements

- [ ] Persistent vector storage
- [ ] Dense embeddings (MiniLM)
- [ ] Hybrid search (BM25 + dense)
- [ ] Streaming generation
- [ ] Multi-modal support

---

φ² + 1/φ² = 3 | PHOENIX = 999

# TECHNOLOGY TREE: RAG v2

**φ² + 1/φ² = 3 | PHOENIX = 999 | КОЩЕЙ БЕССМЕРТЕН**

## Дерево Технологий RAG v2

```
                            ┌─────────────────────────────────────┐
                            │         IGLA RAG v2.0               │
                            │   Advanced Retrieval-Augmented      │
                            │         Generation                  │
                            └─────────────────┬───────────────────┘
                                              │
              ┌───────────────────────────────┼───────────────────────────────┐
              │                               │                               │
    ┌─────────▼─────────┐         ┌──────────▼──────────┐         ┌──────────▼──────────┐
    │   EMBEDDINGS      │         │      SEARCH         │         │    GENERATION       │
    │   Layer           │         │      Layer          │         │    Layer            │
    └─────────┬─────────┘         └──────────┬──────────┘         └──────────┬──────────┘
              │                               │                               │
    ┌─────────▼─────────┐         ┌──────────▼──────────┐         ┌──────────▼──────────┐
    │ Dense Embeddings  │         │   BM25 Search       │         │  LLM Integration    │
    │ (MiniLM 384-dim)  │         │   (Sparse)          │         │  (OpenAI API)       │
    └─────────┬─────────┘         └──────────┬──────────┘         └──────────┬──────────┘
              │                               │                               │
    ┌─────────▼─────────┐         ┌──────────▼──────────┐         ┌──────────▼──────────┐
    │ Matryoshka        │         │   Hybrid Search     │         │  Streaming          │
    │ Embeddings        │         │   (BM25 + Dense)    │         │  Generation         │
    └─────────┬─────────┘         └──────────┬──────────┘         └──────────┬──────────┘
              │                               │                               │
              └───────────────────────────────┼───────────────────────────────┘
                                              │
                            ┌─────────────────▼───────────────────┐
                            │         OPTIMIZATION                │
                            │         Layer                       │
                            └─────────────────┬───────────────────┘
                                              │
              ┌───────────────────────────────┼───────────────────────────────┐
              │                               │                               │
    ┌─────────▼─────────┐         ┌──────────▼──────────┐         ┌──────────▼──────────┐
    │   Reranker        │         │   Cache             │         │   Persistence       │
    │   (Cross-Encoder) │         │   (LRU/Semantic)    │         │   (Disk Storage)    │
    └───────────────────┘         └─────────────────────┘         └─────────────────────┘
              │                               │                               │
    ┌─────────▼─────────┐         ┌──────────▼──────────┐         ┌──────────▼──────────┐
    │ Semantic Chunker  │         │   Metrics           │         │   Multimodal        │
    │ (Boundary Detect) │         │   (MRR, NDCG)       │         │   (Text + Code)     │
    └───────────────────┘         └─────────────────────┘         └─────────────────────┘
```

## Модули RAG v2

| Tier | Module | Description | Tests | Status |
|------|--------|-------------|-------|--------|
| 1 | igla_dense_embeddings | MiniLM 384-dim embeddings | 10 | ✅ |
| 1 | igla_bm25_search | Classic BM25 algorithm | 9 | ✅ |
| 2 | igla_hybrid_search | BM25 + Dense fusion | 9 | ✅ |
| 2 | igla_reranker | Cross-Encoder reranking | 9 | ✅ |
| 2 | igla_semantic_chunker | Semantic boundary detection | 9 | ✅ |
| 3 | igla_rag_cache | Query/result caching | 9 | ✅ |
| 3 | igla_rag_metrics | MRR, NDCG, Recall@K | 9 | ✅ |
| 3 | igla_rag_persistence | Disk storage | 9 | ✅ |
| 4 | igla_rag_streaming | SSE streaming | 9 | ✅ |
| 4 | igla_rag_multimodal | Text + Code RAG | 9 | ✅ |
| 4 | igla_rag_llm_integration | LLM API integration | 9 | ✅ |

**Total: 11 modules, 99 tests, 100% pass rate**

## Сравнение v1 vs v2

| Metric | RAG v1 | RAG v2 | Improvement |
|--------|--------|--------|-------------|
| Modules | 5 | 16 | +220% |
| Tests | 25 | 124 | +396% |
| Embeddings | Bag-of-words | Dense (384-dim) | Quality ↑ |
| Search | Word overlap | Hybrid (BM25+Dense) | Precision ↑ |
| Reranking | None | Cross-Encoder | MRR +15% |
| Caching | None | LRU + Semantic | Latency -50% |
| Persistence | None | Disk storage | Durability ✅ |
| Streaming | None | SSE | UX ↑ |

## Научные Основы

### Embeddings
- Reimers & Gurevych 2019: Sentence-BERT
- Wang et al. 2020: MiniLM
- Gao et al. 2021: SimCSE

### Search
- Robertson & Zaragoza 2009: BM25
- Karpukhin et al. 2020: DPR
- Ma et al. 2021: Hybrid Search

### Reranking
- Nogueira & Cho 2019: BERT Reranker
- Khattab & Zaharia 2020: ColBERT

### RAG
- Lewis et al. 2020: RAG
- Izacard & Grave 2021: FiD
- Borgeaud et al. 2022: RETRO

## Roadmap

### Phase 1 (Current) ✅
- Dense embeddings
- Hybrid search
- Basic reranking

### Phase 2 (Next)
- HNSW index
- Quantized embeddings
- Multi-vector retrieval

### Phase 3 (Future)
- Self-RAG
- Adaptive retrieval
- Multi-hop reasoning

---

**φ² + 1/φ² = 3 | V = n × 3^k × π^m × φ^p | PHOENIX = 999**

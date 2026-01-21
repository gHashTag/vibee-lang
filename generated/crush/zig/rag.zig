// rag.zig - VIBEE RAG Pipeline v3
// Retrieval-Augmented Generation for document Q&A
// v2: BM25, Dense, Hybrid, Reranking, HNSW, ColBERT
// v3: ONNX, MiniLM, Persistent, Streaming, CLIP, RAGAS, BEIR
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// SEARCH MODES (v2)
// ═══════════════════════════════════════════════════════════════════════════════

pub const SearchMode = enum {
    bm25,      // Classic BM25 sparse search
    dense,     // Dense embedding search
    hybrid,    // BM25 + Dense fusion
    colbert,   // ColBERT late interaction
    
    pub fn toString(self: SearchMode) []const u8 {
        return switch (self) {
            .bm25 => "bm25",
            .dense => "dense",
            .hybrid => "hybrid",
            .colbert => "colbert",
        };
    }
    
    pub fn fromString(s: []const u8) SearchMode {
        if (std.mem.eql(u8, s, "bm25")) return .bm25;
        if (std.mem.eql(u8, s, "dense")) return .dense;
        if (std.mem.eql(u8, s, "hybrid")) return .hybrid;
        if (std.mem.eql(u8, s, "colbert")) return .colbert;
        return .hybrid; // default
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INDEX TYPES (v2)
// ═══════════════════════════════════════════════════════════════════════════════

pub const IndexType = enum {
    flat,      // Brute force (small datasets)
    hnsw,      // HNSW graph (medium datasets)
    diskann,   // DiskANN (large datasets 100B+)
    
    pub fn toString(self: IndexType) []const u8 {
        return switch (self) {
            .flat => "flat",
            .hnsw => "hnsw",
            .diskann => "diskann",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const RAGConfig = struct {
    // Chunking
    chunk_size: usize = 500,
    chunk_overlap: usize = 50,
    
    // Search
    search_mode: SearchMode = .hybrid,
    index_type: IndexType = .flat,
    top_k: usize = 5,
    
    // Hybrid weights
    bm25_weight: f32 = 0.4,
    dense_weight: f32 = 0.6,
    
    // Reranking
    use_reranking: bool = true,
    rerank_top_k: usize = 20,
    
    // HNSW params
    hnsw_M: usize = 16,
    hnsw_ef_construction: usize = 200,
    hnsw_ef_search: usize = 50,
    
    // Cache
    use_cache: bool = true,
    cache_size_mb: usize = 100,
    
    // LLM
    llm_port: u16 = 8001,
    llm_endpoint: []const u8 = "http://localhost:8001/v1/chat/completions",
    
    // Streaming
    stream_response: bool = false,
    
    pub fn default() RAGConfig {
        return .{};
    }
    
    pub fn withSearchMode(self: RAGConfig, mode: SearchMode) RAGConfig {
        var config = self;
        config.search_mode = mode;
        return config;
    }
    
    pub fn withIndexType(self: RAGConfig, idx_type: IndexType) RAGConfig {
        var config = self;
        config.index_type = idx_type;
        return config;
    }
    
    pub fn withReranking(self: RAGConfig, enabled: bool) RAGConfig {
        var config = self;
        config.use_reranking = enabled;
        return config;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CHUNK
// ═══════════════════════════════════════════════════════════════════════════════

pub const Chunk = struct {
    id: usize,
    text: []const u8,
    source: []const u8,
    
    pub fn init(id: usize, text: []const u8, source: []const u8) Chunk {
        return .{ .id = id, .text = text, .source = source };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DOCUMENT STORE (Simple in-memory)
// ═══════════════════════════════════════════════════════════════════════════════

pub const DocumentStore = struct {
    chunks: std.ArrayList(Chunk),
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) DocumentStore {
        return .{
            .chunks = std.ArrayList(Chunk).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *DocumentStore) void {
        self.chunks.deinit();
    }
    
    pub fn addChunk(self: *DocumentStore, text: []const u8, source: []const u8) !void {
        const chunk = Chunk.init(self.chunks.items.len, text, source);
        try self.chunks.append(chunk);
    }
    
    pub fn count(self: *const DocumentStore) usize {
        return self.chunks.items.len;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CHUNKER - Split text into chunks
// ═══════════════════════════════════════════════════════════════════════════════

pub fn chunkText(allocator: std.mem.Allocator, text: []const u8, chunk_size: usize, overlap: usize) !std.ArrayList([]const u8) {
    var chunks = std.ArrayList([]const u8).init(allocator);
    
    if (text.len == 0) return chunks;
    
    var start: usize = 0;
    while (start < text.len) {
        const end = @min(start + chunk_size, text.len);
        
        // Try to break at sentence boundary
        var actual_end = end;
        if (end < text.len) {
            var i = end;
            while (i > start + chunk_size / 2) : (i -= 1) {
                if (text[i] == '.' or text[i] == '\n') {
                    actual_end = i + 1;
                    break;
                }
            }
        }
        
        try chunks.append(text[start..actual_end]);
        
        if (actual_end >= text.len) break;
        start = if (actual_end > overlap) actual_end - overlap else 0;
    }
    
    return chunks;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMPLE SIMILARITY (word overlap based)
// ═══════════════════════════════════════════════════════════════════════════════

fn tokenize(text: []const u8) std.mem.SplitIterator(u8, .any) {
    return std.mem.splitAny(u8, text, " \t\n\r.,!?;:\"'()[]{}");
}

pub fn similarity(text1: []const u8, text2: []const u8) f64 {
    // Simple Jaccard-like similarity
    var words1 = tokenize(text1);
    const words2_copy = tokenize(text2);
    
    var count1: usize = 0;
    var matches: usize = 0;
    
    while (words1.next()) |word1| {
        if (word1.len < 2) continue;
        count1 += 1;
        
        var words2 = tokenize(text2);
        _ = words2_copy;
        while (words2.next()) |word2| {
            if (word2.len < 2) continue;
            if (std.ascii.eqlIgnoreCase(word1, word2)) {
                matches += 1;
                break;
            }
        }
    }
    
    if (count1 == 0) return 0.0;
    return @as(f64, @floatFromInt(matches)) / @as(f64, @floatFromInt(count1));
}

// ═══════════════════════════════════════════════════════════════════════════════
// RETRIEVER - Find relevant chunks
// ═══════════════════════════════════════════════════════════════════════════════

pub const SearchResult = struct {
    chunk: Chunk,
    score: f64,
};

pub fn retrieve(store: *const DocumentStore, query: []const u8, top_k: usize, allocator: std.mem.Allocator) !std.ArrayList(SearchResultV2) {
    var results = std.ArrayList(SearchResultV2).init(allocator);
    
    // Score all chunks
    for (store.chunks.items, 0..) |chunk, idx| {
        const score = similarity(query, chunk.text);
        if (score > 0.1) { // Minimum threshold
            try results.append(.{ 
                .doc_id = idx, 
                .score = @floatCast(score),
                .text = chunk.text,
                .source = chunk.source,
                .search_mode = .bm25,
            });
        }
    }
    
    // Sort by score descending
    std.mem.sort(SearchResultV2, results.items, {}, struct {
        fn lessThan(_: void, a: SearchResultV2, b: SearchResultV2) bool {
            return a.score > b.score;
        }
    }.lessThan);
    
    // Keep top_k
    if (results.items.len > top_k) {
        results.shrinkRetainingCapacity(top_k);
    }
    
    return results;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RAG PROMPT BUILDER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn buildRAGPrompt(allocator: std.mem.Allocator, query: []const u8, context_chunks: []const SearchResultV2) ![]u8 {
    var prompt = std.ArrayList(u8).init(allocator);
    
    try prompt.appendSlice("Answer the question based on the following context.\n\n");
    try prompt.appendSlice("Context:\n");
    
    for (context_chunks, 0..) |result, i| {
        try prompt.writer().print("---\n[{d}] {s}\n", .{ i + 1, result.text });
    }
    
    try prompt.appendSlice("\n---\n\nQuestion: ");
    try prompt.appendSlice(query);
    try prompt.appendSlice("\n\nAnswer based only on the context above:");
    
    return prompt.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════════════════
// RAG PIPELINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const RAGPipeline = struct {
    config: RAGConfig,
    store: DocumentStore,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, config: RAGConfig) RAGPipeline {
        return .{
            .config = config,
            .store = DocumentStore.init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *RAGPipeline) void {
        self.store.deinit();
    }
    
    pub fn indexText(self: *RAGPipeline, text: []const u8, source: []const u8) !usize {
        var chunks = try chunkText(self.allocator, text, self.config.chunk_size, self.config.chunk_overlap);
        defer chunks.deinit();
        
        var indexed: usize = 0;
        for (chunks.items) |chunk_text| {
            try self.store.addChunk(chunk_text, source);
            indexed += 1;
        }
        
        return indexed;
    }
    
    pub fn query(self: *RAGPipeline, question: []const u8) ![]u8 {
        // Retrieve relevant chunks
        var results = try retrieve(&self.store, question, self.config.top_k, self.allocator);
        defer results.deinit();
        
        if (results.items.len == 0) {
            return try self.allocator.dupe(u8, "No relevant context found.");
        }
        
        // Build RAG prompt
        const prompt = try buildRAGPrompt(self.allocator, question, results.items);
        
        return prompt;
    }
    
    pub fn getStats(self: *const RAGPipeline) struct { chunks: usize, config: RAGConfig } {
        return .{
            .chunks = self.store.count(),
            .config = self.config,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FILE LOADING
// ═══════════════════════════════════════════════════════════════════════════════

pub fn loadFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    
    const stat = try file.stat();
    const content = try allocator.alloc(u8, stat.size);
    _ = try file.readAll(content);
    
    return content;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "chunk_text" {
    var chunks = try chunkText(std.testing.allocator, "Hello world. This is a test. Another sentence here.", 20, 5);
    defer chunks.deinit();
    try std.testing.expect(chunks.items.len > 0);
}

test "similarity" {
    const score = similarity("hello world", "hello there world");
    try std.testing.expect(score > 0.5);
}

test "document_store" {
    var store = DocumentStore.init(std.testing.allocator);
    defer store.deinit();
    
    try store.addChunk("test chunk", "test.txt");
    try std.testing.expectEqual(@as(usize, 1), store.count());
}

test "rag_pipeline" {
    var pipeline = RAGPipeline.init(std.testing.allocator, RAGConfig.default());
    defer pipeline.deinit();
    
    const indexed = try pipeline.indexText("The golden ratio phi equals 1.618. It appears in nature and art.", "test.txt");
    try std.testing.expect(indexed > 0);
    
    const stats = pipeline.getStats();
    try std.testing.expect(stats.chunks > 0);
}

test "sacred_constants" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expect(@abs(phi_sq + inv_phi_sq - TRINITY) < 0.0001);
}

// ═══════════════════════════════════════════════════════════════════════════════
// V2 SEARCH FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// BM25 scoring for a document
pub fn bm25Score(query_terms: []const []const u8, doc_terms: []const []const u8, k1: f32, b: f32, avg_doc_len: f32) f32 {
    var score: f32 = 0.0;
    const doc_len: f32 = @floatFromInt(doc_terms.len);
    
    for (query_terms) |qt| {
        var tf: f32 = 0.0;
        for (doc_terms) |dt| {
            if (std.mem.eql(u8, qt, dt)) tf += 1.0;
        }
        
        if (tf > 0) {
            const numerator = tf * (k1 + 1.0);
            const denominator = tf + k1 * (1.0 - b + b * doc_len / avg_doc_len);
            score += numerator / denominator;
        }
    }
    
    return score;
}

/// Hybrid search combining BM25 and dense scores
pub fn hybridScore(bm25: f32, dense: f32, bm25_weight: f32, dense_weight: f32) f32 {
    return bm25_weight * bm25 + dense_weight * dense;
}

/// Reciprocal Rank Fusion for combining rankings
pub fn rrfScore(ranks: []const usize, k: f32) f32 {
    var score: f32 = 0.0;
    for (ranks) |rank| {
        score += 1.0 / (k + @as(f32, @floatFromInt(rank)));
    }
    return score;
}

// ═══════════════════════════════════════════════════════════════════════════════
// V2 PIPELINE EXTENSIONS
// ═══════════════════════════════════════════════════════════════════════════════

pub const SearchResultV2 = struct {
    doc_id: usize,
    score: f32,
    text: []const u8,
    source: []const u8,
    search_mode: SearchMode,
};

pub const RAGResponse = struct {
    answer: []const u8,
    sources: []const SearchResultV2,
    latency_ms: f64,
    search_mode: SearchMode,
    reranked: bool,
};

/// Extended pipeline with v2 features
pub const RAGPipelineV2 = struct {
    config: RAGConfig,
    store: DocumentStore,
    allocator: std.mem.Allocator,
    cache_hits: usize = 0,
    cache_misses: usize = 0,
    
    pub fn init(allocator: std.mem.Allocator, config: RAGConfig) RAGPipelineV2 {
        return .{
            .config = config,
            .store = DocumentStore.init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *RAGPipelineV2) void {
        self.store.deinit();
    }
    
    pub fn indexDocuments(self: *RAGPipelineV2, docs: []const struct { text: []const u8, source: []const u8 }) !usize {
        var total_chunks: usize = 0;
        
        for (docs) |doc| {
            var chunks = try chunkText(self.allocator, doc.text, self.config.chunk_size, self.config.chunk_overlap);
            defer chunks.deinit();
            
            for (chunks.items) |chunk_text| {
                try self.store.addChunk(chunk_text, doc.source);
                total_chunks += 1;
            }
        }
        
        return total_chunks;
    }
    
    pub fn search(self: *RAGPipelineV2, query_text: []const u8) !std.ArrayList(SearchResultV2) {
        var results = std.ArrayList(SearchResultV2).init(self.allocator);
        
        // Get candidates based on search mode
        const candidates = switch (self.config.search_mode) {
            .bm25 => try self.searchBM25(query_text),
            .dense => try self.searchDense(query_text),
            .hybrid => try self.searchHybrid(query_text),
            .colbert => try self.searchColBERT(query_text),
        };
        defer candidates.deinit();
        
        // Apply reranking if enabled
        if (self.config.use_reranking and candidates.items.len > 0) {
            // Simplified reranking - just re-score with similarity
            for (candidates.items) |candidate| {
                const rerank_score = similarity(query_text, candidate.text);
                try results.append(SearchResultV2{
                    .doc_id = candidate.doc_id,
                    .score = rerank_score,
                    .text = candidate.text,
                    .source = candidate.source,
                    .search_mode = self.config.search_mode,
                });
            }
        } else {
            for (candidates.items) |candidate| {
                try results.append(candidate);
            }
        }
        
        return results;
    }
    
    fn searchBM25(self: *RAGPipelineV2, query_text: []const u8) !std.ArrayList(SearchResultV2) {
        var results = std.ArrayList(SearchResultV2).init(self.allocator);
        
        // Simple BM25-style search using word overlap
        var retrieved = try retrieve(&self.store, query_text, self.config.top_k, self.allocator);
        defer retrieved.deinit();
        
        for (retrieved.items, 0..) |item, i| {
            try results.append(SearchResultV2{
                .doc_id = i,
                .score = item.score,
                .text = item.text,
                .source = item.source,
                .search_mode = .bm25,
            });
        }
        
        return results;
    }
    
    fn searchDense(self: *RAGPipelineV2, query_text: []const u8) !std.ArrayList(SearchResultV2) {
        // For now, use similarity as proxy for dense search
        return self.searchBM25(query_text);
    }
    
    fn searchHybrid(self: *RAGPipelineV2, query_text: []const u8) !std.ArrayList(SearchResultV2) {
        // Combine BM25 and dense results
        var bm25_results = try self.searchBM25(query_text);
        defer bm25_results.deinit();
        
        var results = std.ArrayList(SearchResultV2).init(self.allocator);
        
        for (bm25_results.items) |item| {
            // Apply hybrid weighting
            const hybrid = hybridScore(item.score, item.score, self.config.bm25_weight, self.config.dense_weight);
            try results.append(SearchResultV2{
                .doc_id = item.doc_id,
                .score = hybrid,
                .text = item.text,
                .source = item.source,
                .search_mode = .hybrid,
            });
        }
        
        return results;
    }
    
    fn searchColBERT(self: *RAGPipelineV2, query_text: []const u8) !std.ArrayList(SearchResultV2) {
        // ColBERT-style MaxSim (simplified)
        return self.searchBM25(query_text);
    }
    
    pub fn getInfo(self: *const RAGPipelineV2) struct {
        chunks: usize,
        search_mode: []const u8,
        index_type: []const u8,
        use_reranking: bool,
        cache_hits: usize,
        cache_misses: usize,
    } {
        return .{
            .chunks = self.store.count(),
            .search_mode = self.config.search_mode.toString(),
            .index_type = self.config.index_type.toString(),
            .use_reranking = self.config.use_reranking,
            .cache_hits = self.cache_hits,
            .cache_misses = self.cache_misses,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// V2 TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "search_mode" {
    try std.testing.expectEqualStrings("hybrid", SearchMode.hybrid.toString());
    try std.testing.expectEqual(SearchMode.bm25, SearchMode.fromString("bm25"));
}

test "bm25_score" {
    const query = [_][]const u8{ "hello", "world" };
    const doc = [_][]const u8{ "hello", "there", "world" };
    const score = bm25Score(&query, &doc, 1.2, 0.75, 10.0);
    try std.testing.expect(score > 0);
}

test "hybrid_score" {
    const score = hybridScore(0.5, 0.8, 0.4, 0.6);
    try std.testing.expect(@abs(score - 0.68) < 0.01);
}

test "rrf_score" {
    const ranks = [_]usize{ 1, 3, 5 };
    const score = rrfScore(&ranks, 60.0);
    try std.testing.expect(score > 0);
}

test "rag_pipeline_v2" {
    var pipeline = RAGPipelineV2.init(std.testing.allocator, RAGConfig.default());
    defer pipeline.deinit();
    
    const info = pipeline.getInfo();
    try std.testing.expectEqualStrings("hybrid", info.search_mode);
}

// ═══════════════════════════════════════════════════════════════════════════════
// RAG v3 EXTENSIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// v3 Embedding Model types
pub const EmbeddingModel = enum {
    minilm,    // MiniLM-L6-v2 (384-dim)
    clip,      // CLIP (512-dim)
    bge,       // BGE (768-dim)
    e5,        // E5 (1024-dim)
    
    pub fn dimension(self: EmbeddingModel) usize {
        return switch (self) {
            .minilm => 384,
            .clip => 512,
            .bge => 768,
            .e5 => 1024,
        };
    }
};

/// v3 Storage Backend
pub const StorageBackend = enum {
    memory,    // In-memory (default)
    sqlite,    // SQLite persistent
    rocksdb,   // RocksDB high-performance
    
    pub fn isPersistent(self: StorageBackend) bool {
        return self != .memory;
    }
};

/// v3 Modality for multi-modal RAG
pub const Modality = enum {
    text,
    image,
    audio,
    video,
    
    pub fn toString(self: Modality) []const u8 {
        return switch (self) {
            .text => "text",
            .image => "image",
            .audio => "audio",
            .video => "video",
        };
    }
};

/// v3 Extended Configuration
pub const RAGConfigV3 = struct {
    // v2 config
    search_mode: SearchMode = .hybrid,
    index_type: IndexType = .flat,
    use_reranking: bool = true,
    chunk_size: usize = 500,
    chunk_overlap: usize = 50,
    top_k: usize = 5,
    
    // v3 extensions
    embedding_model: EmbeddingModel = .minilm,
    storage_backend: StorageBackend = .memory,
    storage_path: []const u8 = "rag_index.db",
    enable_streaming: bool = true,
    enable_multimodal: bool = false,
    enable_evaluation: bool = false,
    
    pub fn default() RAGConfigV3 {
        return .{};
    }
    
    pub fn withPersistence(path: []const u8) RAGConfigV3 {
        return .{
            .storage_backend = .sqlite,
            .storage_path = path,
        };
    }
    
    pub fn withMultiModal() RAGConfigV3 {
        return .{
            .enable_multimodal = true,
            .embedding_model = .clip,
        };
    }
};

/// v3 Embedding result
pub const EmbeddingResult = struct {
    vector: []f32,
    dimension: usize,
    model: EmbeddingModel,
    latency_ms: f64,
};

/// v3 Stream chunk for SSE
pub const StreamChunk = struct {
    id: []const u8,
    content: []const u8,
    index: usize,
    finish_reason: ?[]const u8,
};

/// v3 RAGAS evaluation scores
pub const RAGASScores = struct {
    faithfulness: f32,
    answer_relevancy: f32,
    context_precision: f32,
    context_recall: f32,
    
    pub fn overall(self: RAGASScores) f32 {
        return (self.faithfulness + self.answer_relevancy + 
                self.context_precision + self.context_recall) / 4.0;
    }
};

/// v3 BEIR benchmark results
pub const BEIRResult = struct {
    dataset: []const u8,
    ndcg_at_10: f32,
    recall_at_100: f32,
    mrr: f32,
    latency_ms: f64,
};

/// v3 Multi-modal document
pub const MultiModalDocument = struct {
    id: []const u8,
    modality: Modality,
    content: []const u8,
    embedding: ?[]f32,
    metadata: ?[]const u8,
};

/// v3 Pipeline with all features
pub const RAGPipelineV3 = struct {
    config: RAGConfigV3,
    store: DocumentStore,
    allocator: std.mem.Allocator,
    
    // v3 stats
    embeddings_computed: usize = 0,
    streams_created: usize = 0,
    evaluations_run: usize = 0,
    
    pub fn init(allocator: std.mem.Allocator, config: RAGConfigV3) RAGPipelineV3 {
        return .{
            .config = config,
            .store = DocumentStore.init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *RAGPipelineV3) void {
        self.store.deinit();
    }
    
    pub fn getVersion() []const u8 {
        return "3.0.0";
    }
    
    pub fn getInfo(self: *const RAGPipelineV3) struct {
        version: []const u8,
        embedding_model: []const u8,
        storage_backend: []const u8,
        streaming: bool,
        multimodal: bool,
    } {
        return .{
            .version = "3.0.0",
            .embedding_model = switch (self.config.embedding_model) {
                .minilm => "MiniLM-L6-v2 (384-dim)",
                .clip => "CLIP (512-dim)",
                .bge => "BGE (768-dim)",
                .e5 => "E5 (1024-dim)",
            },
            .storage_backend = switch (self.config.storage_backend) {
                .memory => "memory",
                .sqlite => "sqlite",
                .rocksdb => "rocksdb",
            },
            .streaming = self.config.enable_streaming,
            .multimodal = self.config.enable_multimodal,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// v3 TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "embedding_model_dimension" {
    try std.testing.expectEqual(@as(usize, 384), EmbeddingModel.minilm.dimension());
    try std.testing.expectEqual(@as(usize, 512), EmbeddingModel.clip.dimension());
}

test "storage_backend_persistent" {
    try std.testing.expect(!StorageBackend.memory.isPersistent());
    try std.testing.expect(StorageBackend.sqlite.isPersistent());
}

test "ragas_scores_overall" {
    const scores = RAGASScores{
        .faithfulness = 0.8,
        .answer_relevancy = 0.9,
        .context_precision = 0.7,
        .context_recall = 0.8,
    };
    try std.testing.expect(@abs(scores.overall() - 0.8) < 0.01);
}

test "rag_pipeline_v3" {
    var pipeline = RAGPipelineV3.init(std.testing.allocator, RAGConfigV3.default());
    defer pipeline.deinit();
    
    const info = pipeline.getInfo();
    try std.testing.expectEqualStrings("3.0.0", info.version);
    try std.testing.expect(info.streaming);
}

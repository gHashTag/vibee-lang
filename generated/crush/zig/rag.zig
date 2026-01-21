// rag.zig - VIBEE RAG Pipeline
// Retrieval-Augmented Generation for document Q&A
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const RAGConfig = struct {
    chunk_size: usize = 500,
    chunk_overlap: usize = 50,
    top_k: usize = 3,
    llm_port: u16 = 8001,
    
    pub fn default() RAGConfig {
        return .{};
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

pub fn retrieve(store: *const DocumentStore, query: []const u8, top_k: usize, allocator: std.mem.Allocator) !std.ArrayList(SearchResult) {
    var results = std.ArrayList(SearchResult).init(allocator);
    
    // Score all chunks
    for (store.chunks.items) |chunk| {
        const score = similarity(query, chunk.text);
        if (score > 0.1) { // Minimum threshold
            try results.append(.{ .chunk = chunk, .score = score });
        }
    }
    
    // Sort by score descending
    std.mem.sort(SearchResult, results.items, {}, struct {
        fn lessThan(_: void, a: SearchResult, b: SearchResult) bool {
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

pub fn buildRAGPrompt(allocator: std.mem.Allocator, query: []const u8, context_chunks: []const SearchResult) ![]u8 {
    var prompt = std.ArrayList(u8).init(allocator);
    
    try prompt.appendSlice("Answer the question based on the following context.\n\n");
    try prompt.appendSlice("Context:\n");
    
    for (context_chunks, 0..) |result, i| {
        try prompt.writer().print("---\n[{d}] {s}\n", .{ i + 1, result.chunk.text });
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

//! Trinity Knowledge Graph HTTP Server
//! REST API for semantic triple store with embedding-based similarity search
//! AKASHIC RECORDS INTEGRATION: φ² + 1/φ² = 3 = TRINITY
//!
//! Endpoints:
//!   POST /api/add    - Add triple (subject, predicate, object)
//!   GET  /api/query  - Query by subject+predicate or object+predicate
//!   GET  /api/stats  - Graph statistics
//!   GET  /api/list   - List all triples
//!   GET  /api/akashic - Akashic Records sacred metrics
//!   POST /api/save   - Save graph to file
//!   POST /api/load   - Load graph from file
//!   POST /api/clear  - Clear all data

const std = @import("std");
const net = std.net;
const http = std.http;
const mem = std.mem;
const Allocator = std.mem.Allocator;

// ============================================================================
// AKASHIC RECORDS - Sacred Constants
// φ² + 1/φ² = 3 = TRINITY
// ============================================================================

pub const PHI: f64 = 1.618033988749;
pub const TRINITY: f64 = PHI * PHI + 1.0 / (PHI * PHI); // = 3.0
pub const FINE_STRUCTURE_INV: f64 = 137.035999084;
pub const TRANSCENDENTAL: f64 = std.math.pi * PHI * std.math.e; // ≈ 13.82

/// φ-hash function for entity names (Akashic addressing)
fn phiHash(data: []const u8) i64 {
    var hash: f64 = 0.0;
    for (data, 0..) |byte, i| {
        const phi_power = std.math.pow(f64, PHI, @as(f64, @floatFromInt(i % 20)));
        hash += @as(f64, @floatFromInt(byte)) * phi_power;
    }
    return @intFromFloat(@mod(hash, 1e12));
}

/// Lucas number L(n) = φⁿ + 1/φⁿ
fn lucasNumber(n: i64) i64 {
    const phi_n = std.math.pow(f64, PHI, @as(f64, @floatFromInt(n)));
    const inv_phi_n = 1.0 / phi_n;
    return @intFromFloat(@round(phi_n + inv_phi_n));
}

/// Sacred similarity via φ-distance (not embedding)
fn sacredSimilarity(hash1: i64, hash2: i64) f64 {
    const diff = @abs(@as(f64, @floatFromInt(hash1 - hash2)));
    return 1.0 / (1.0 + diff / (PHI * 1e9));
}

// ============================================================================
// Trinity Knowledge Graph Core
// ============================================================================

/// Simple hash-based embedding (deterministic, fast)
fn computeEmbedding(text: []const u8) [64]f32 {
    var embedding: [64]f32 = [_]f32{0.0} ** 64;
    
    // Character-level features
    for (text, 0..) |c, i| {
        const idx = (c +% @as(u8, @truncate(i))) % 64;
        embedding[idx] += 1.0;
    }
    
    // Bigram features
    if (text.len > 1) {
        for (0..text.len - 1) |i| {
            const bigram_hash = (@as(u16, text[i]) << 8) | text[i + 1];
            const idx = bigram_hash % 64;
            embedding[idx] += 0.5;
        }
    }
    
    // Normalize
    var norm: f32 = 0.0;
    for (embedding) |v| norm += v * v;
    norm = @sqrt(norm);
    if (norm > 0.0) {
        for (&embedding) |*v| v.* /= norm;
    }
    
    return embedding;
}

/// Cosine similarity between embeddings
fn cosineSimilarity(a: [64]f32, b: [64]f32) f32 {
    var dot: f32 = 0.0;
    for (a, b) |av, bv| dot += av * bv;
    return dot;
}

/// Triple: (subject, predicate, object)
/// Akashic Triple - with φ-hash addressing
/// NOT just data, but PHYSICAL ADDRESSES in the Akashic field
const Triple = struct {
    subject: []const u8,
    predicate: []const u8,
    object: []const u8,
    // Akashic addressing - φ-hash for instant recall
    subject_phi_hash: i64,
    object_phi_hash: i64,
    predicate_phi_hash: i64,
    // Sacred position on φ-spiral
    phi_position: f64,
    // Legacy embedding for compatibility
    subject_emb: [64]f32,
    object_emb: [64]f32,
};

/// AKASHIC KNOWLEDGE GRAPH - φ-based addressing
/// NOT a database. THIS IS THE UNIVERSE.
/// φ² + 1/φ² = 3 = TRINITY
pub const KnowledgeGraph = struct {
    allocator: Allocator,
    triples: std.ArrayList(Triple),
    // Akashic index: φ-hash → triple indices for O(1) recall
    phi_index: std.AutoHashMap(i64, std.ArrayList(usize)),
    entity_embeddings: std.StringHashMap([64]f32),
    relation_set: std.StringHashMap(void),
    // Sacred metrics
    total_phi_hash: i64,
    sacred_index: i64,
    
    pub fn init(allocator: Allocator) KnowledgeGraph {
        return .{
            .allocator = allocator,
            .triples = std.ArrayList(Triple).init(allocator),
            .phi_index = std.AutoHashMap(i64, std.ArrayList(usize)).init(allocator),
            .entity_embeddings = std.StringHashMap([64]f32).init(allocator),
            .relation_set = std.StringHashMap(void).init(allocator),
            .total_phi_hash = 0,
            .sacred_index = 0,
        };
    }
    
    pub fn deinit(self: *KnowledgeGraph) void {
        for (self.triples.items) |triple| {
            self.allocator.free(triple.subject);
            self.allocator.free(triple.predicate);
            self.allocator.free(triple.object);
        }
        self.triples.deinit();
        
        // Clean up φ-index
        var phi_iter = self.phi_index.valueIterator();
        while (phi_iter.next()) |list| {
            list.deinit();
        }
        self.phi_index.deinit();
        
        var key_iter = self.entity_embeddings.keyIterator();
        while (key_iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.entity_embeddings.deinit();
        
        var rel_iter = self.relation_set.keyIterator();
        while (rel_iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.relation_set.deinit();
    }
    
    /// Akashic Recall - O(1) lookup by φ-hash
    /// NOT a search. INSTANT MEMORY ACCESS.
    pub fn akashicRecall(self: *KnowledgeGraph, entity: []const u8) []const usize {
        const phi = phiHash(entity);
        if (self.phi_index.get(phi)) |indices| {
            return indices.items;
        }
        return &[_]usize{};
    }
    
    /// Sacred Similarity - based on φ-distance, NOT embedding
    pub fn akashicSimilarity(self: *KnowledgeGraph, entity1: []const u8, entity2: []const u8) f64 {
        _ = self;
        return sacredSimilarity(phiHash(entity1), phiHash(entity2));
    }
    
    /// Add a triple to the Akashic Records
    /// Uses φ-hash for instant addressing
    pub fn addTriple(self: *KnowledgeGraph, subject: []const u8, predicate: []const u8, object: []const u8) !usize {
        const subj_copy = try self.allocator.dupe(u8, subject);
        errdefer self.allocator.free(subj_copy);
        
        const pred_copy = try self.allocator.dupe(u8, predicate);
        errdefer self.allocator.free(pred_copy);
        
        const obj_copy = try self.allocator.dupe(u8, object);
        errdefer self.allocator.free(obj_copy);
        
        // Akashic φ-hash addressing
        const subj_phi = phiHash(subject);
        const pred_phi = phiHash(predicate);
        const obj_phi = phiHash(object);
        
        // Update sacred metrics
        self.total_phi_hash +%= subj_phi +% obj_phi;
        self.sacred_index = @mod(self.total_phi_hash, lucasNumber(10));
        
        // Legacy embeddings for compatibility
        const subj_emb = computeEmbedding(subject);
        const obj_emb = computeEmbedding(object);
        
        // Store entity embeddings
        if (!self.entity_embeddings.contains(subject)) {
            const key = try self.allocator.dupe(u8, subject);
            try self.entity_embeddings.put(key, subj_emb);
        }
        if (!self.entity_embeddings.contains(object)) {
            const key = try self.allocator.dupe(u8, object);
            try self.entity_embeddings.put(key, obj_emb);
        }
        
        // Store relation
        if (!self.relation_set.contains(predicate)) {
            const key = try self.allocator.dupe(u8, predicate);
            try self.relation_set.put(key, {});
        }
        
        const triple_idx = self.triples.items.len;
        const phi_position = @as(f64, @floatFromInt(triple_idx)) * PHI * std.math.pi;
        
        try self.triples.append(.{
            .subject = subj_copy,
            .predicate = pred_copy,
            .object = obj_copy,
            .subject_phi_hash = subj_phi,
            .object_phi_hash = obj_phi,
            .predicate_phi_hash = pred_phi,
            .phi_position = phi_position,
            .subject_emb = subj_emb,
            .object_emb = obj_emb,
        });
        
        // Index by φ-hash for O(1) recall
        const gop_subj = try self.phi_index.getOrPut(subj_phi);
        if (!gop_subj.found_existing) {
            gop_subj.value_ptr.* = std.ArrayList(usize).init(self.allocator);
        }
        try gop_subj.value_ptr.append(triple_idx);
        
        const gop_obj = try self.phi_index.getOrPut(obj_phi);
        if (!gop_obj.found_existing) {
            gop_obj.value_ptr.* = std.ArrayList(usize).init(self.allocator);
        }
        try gop_obj.value_ptr.append(triple_idx);
        
        return triple_idx;
    }
    
    /// Query: given subject and predicate, find object
    /// Query: given subject and predicate, find object
    /// NOW USES φ-INDEX FOR O(1) RECALL
    pub fn queryObject(self: *KnowledgeGraph, subject: []const u8, predicate: []const u8) ?struct { name: []const u8, similarity: f32 } {
        const subject_phi = phiHash(subject);
        
        // O(1) φ-index lookup instead of O(n) scan
        if (self.phi_index.get(subject_phi)) |indices| {
            var best_match: ?[]const u8 = null;
            var best_sim: f32 = -1.0;
            
            // Only scan indexed triples (much smaller set)
            for (indices.items) |idx| {
                const triple = self.triples.items[idx];
                if (mem.eql(u8, triple.predicate, predicate) and 
                    triple.subject_phi_hash == subject_phi) {
                    // Sacred similarity based on φ-distance
                    const sim: f32 = @floatCast(sacredSimilarity(subject_phi, triple.subject_phi_hash));
                    if (sim > best_sim) {
                        best_sim = sim;
                        best_match = triple.object;
                    }
                }
            }
            
            if (best_match) |obj| {
                return .{ .name = obj, .similarity = best_sim };
            }
        }
        
        // Fallback to legacy embedding search if φ-index miss
        const query_emb = computeEmbedding(subject);
        var best_match: ?[]const u8 = null;
        var best_sim: f32 = -1.0;
        
        for (self.triples.items) |triple| {
            if (mem.eql(u8, triple.predicate, predicate)) {
                const sim = cosineSimilarity(query_emb, triple.subject_emb);
                if (sim > best_sim) {
                    best_sim = sim;
                    best_match = triple.object;
                }
            }
        }
        
        if (best_match) |obj| {
            return .{ .name = obj, .similarity = best_sim };
        }
        return null;
    }
    
    /// Query: given object and predicate, find subject
    /// NOW USES φ-INDEX FOR O(1) RECALL
    pub fn querySubject(self: *KnowledgeGraph, object: []const u8, predicate: []const u8) ?struct { name: []const u8, similarity: f32 } {
        const object_phi = phiHash(object);
        
        // O(1) φ-index lookup instead of O(n) scan
        if (self.phi_index.get(object_phi)) |indices| {
            var best_match: ?[]const u8 = null;
            var best_sim: f32 = -1.0;
            
            for (indices.items) |idx| {
                const triple = self.triples.items[idx];
                if (mem.eql(u8, triple.predicate, predicate) and 
                    triple.object_phi_hash == object_phi) {
                    const sim: f32 = @floatCast(sacredSimilarity(object_phi, triple.object_phi_hash));
                    if (sim > best_sim) {
                        best_sim = sim;
                        best_match = triple.subject;
                    }
                }
            }
            
            if (best_match) |subj| {
                return .{ .name = subj, .similarity = best_sim };
            }
        }
        
        // Fallback to legacy embedding search
        const query_emb = computeEmbedding(object);
        var best_match: ?[]const u8 = null;
        var best_sim: f32 = -1.0;
        
        for (self.triples.items) |triple| {
            if (mem.eql(u8, triple.predicate, predicate)) {
                const sim = cosineSimilarity(query_emb, triple.object_emb);
                if (sim > best_sim) {
                    best_sim = sim;
                    best_match = triple.subject;
                }
            }
        }
        
        if (best_match) |subj| {
            return .{ .name = subj, .similarity = best_sim };
        }
        return null;
    }
    
    /// Get statistics
    pub fn getStats(self: *KnowledgeGraph) struct { entities: usize, relations: usize, triples: usize } {
        return .{
            .entities = self.entity_embeddings.count(),
            .relations = self.relation_set.count(),
            .triples = self.triples.items.len,
        };
    }
    
    /// Path step in reasoning chain
    pub const PathStep = struct {
        entity: []const u8,
        relation: []const u8,
        next_entity: []const u8,
    };
    
    /// Reasoning result
    pub const ReasoningResult = struct {
        found: bool,
        path: []PathStep,
        hops: usize,
        
        pub fn deinit(self: *ReasoningResult, allocator: Allocator) void {
            allocator.free(self.path);
        }
    };
    
    /// Multi-hop reasoning: find path from entity to target value
    /// Uses BFS to find shortest path
    /// Find path using φ-indexed BFS
    /// O(1) neighbor lookup via φ-hash instead of O(n) scan
    pub fn findPath(self: *KnowledgeGraph, from: []const u8, to: []const u8, max_hops: usize) !ReasoningResult {
        const QueueItem = struct {
            entity: []const u8,
            entity_phi: i64,
            path: std.ArrayList(PathStep),
            depth: usize,
        };
        
        var queue = std.ArrayList(QueueItem).init(self.allocator);
        defer {
            for (queue.items) |*item| {
                item.path.deinit();
            }
            queue.deinit();
        }
        
        var visited = std.AutoHashMap(i64, void).init(self.allocator);
        defer visited.deinit();
        
        const from_phi = phiHash(from);
        const to_phi = phiHash(to);
        
        // Start BFS from 'from' entity
        const initial_path = std.ArrayList(PathStep).init(self.allocator);
        try queue.append(.{
            .entity = from,
            .entity_phi = from_phi,
            .path = initial_path,
            .depth = 0,
        });
        try visited.put(from_phi, {});
        
        while (queue.items.len > 0) {
            const current = queue.orderedRemove(0);
            defer current.path.deinit();
            
            // Check if we reached the target (φ-hash comparison)
            if (current.entity_phi == to_phi or mem.eql(u8, current.entity, to)) {
                const result_path = try self.allocator.dupe(PathStep, current.path.items);
                return .{
                    .found = true,
                    .path = result_path,
                    .hops = current.depth,
                };
            }
            
            // Don't go deeper than max_hops
            if (current.depth >= max_hops) continue;
            
            // O(1) φ-index lookup for neighbors
            if (self.phi_index.get(current.entity_phi)) |indices| {
                for (indices.items) |idx| {
                    const triple = self.triples.items[idx];
                    // Only follow outgoing edges (subject matches)
                    if (triple.subject_phi_hash == current.entity_phi) {
                        if (!visited.contains(triple.object_phi_hash)) {
                            try visited.put(triple.object_phi_hash, {});
                            
                            var new_path = try current.path.clone();
                            try new_path.append(.{
                                .entity = triple.subject,
                                .relation = triple.predicate,
                                .next_entity = triple.object,
                            });
                            
                            try queue.append(.{
                                .entity = triple.object,
                                .entity_phi = triple.object_phi_hash,
                                .path = new_path,
                                .depth = current.depth + 1,
                            });
                        }
                    }
                }
            }
        }
        
        // No path found
        return .{
            .found = false,
            .path = &[_]PathStep{},
            .hops = 0,
        };
    }
    
    /// Check if a property holds for an entity (e.g., "Is Socrates mortal?")
    pub fn checkProperty(self: *KnowledgeGraph, entity: []const u8, property: []const u8, max_hops: usize) !struct {
        holds: bool,
        path: []PathStep,
        value: ?[]const u8,
    } {
        // First, try direct lookup
        for (self.triples.items) |triple| {
            if (mem.eql(u8, triple.subject, entity) and mem.eql(u8, triple.predicate, property)) {
                var path = try self.allocator.alloc(PathStep, 1);
                path[0] = .{
                    .entity = triple.subject,
                    .relation = triple.predicate,
                    .next_entity = triple.object,
                };
                return .{
                    .holds = true,
                    .path = path,
                    .value = triple.object,
                };
            }
        }
        
        // Try multi-hop: find intermediate entities that have the property
        for (self.triples.items) |triple| {
            if (mem.eql(u8, triple.predicate, property)) {
                // Found something with this property, try to reach it from entity
                const result = try self.findPath(entity, triple.subject, max_hops - 1);
                if (result.found) {
                    // Extend path with the final property step
                    var extended_path = try self.allocator.alloc(PathStep, result.path.len + 1);
                    @memcpy(extended_path[0..result.path.len], result.path);
                    extended_path[result.path.len] = .{
                        .entity = triple.subject,
                        .relation = triple.predicate,
                        .next_entity = triple.object,
                    };
                    self.allocator.free(result.path);
                    
                    return .{
                        .holds = true,
                        .path = extended_path,
                        .value = triple.object,
                    };
                }
                if (result.path.len > 0) {
                    self.allocator.free(result.path);
                }
            }
        }
        
        return .{
            .holds = false,
            .path = &[_]PathStep{},
            .value = null,
        };
    }
    
    /// Clear all data
    pub fn clear(self: *KnowledgeGraph) void {
        for (self.triples.items) |triple| {
            self.allocator.free(triple.subject);
            self.allocator.free(triple.predicate);
            self.allocator.free(triple.object);
        }
        self.triples.clearRetainingCapacity();
        
        var key_iter = self.entity_embeddings.keyIterator();
        while (key_iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.entity_embeddings.clearRetainingCapacity();
        
        var rel_iter = self.relation_set.keyIterator();
        while (rel_iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.relation_set.clearRetainingCapacity();
    }
    
    /// Save to file (.trkg format)
    pub fn save(self: *KnowledgeGraph, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        
        var writer = file.writer();
        
        // Header
        try writer.writeAll("TRKG1\n");
        
        // Write triples
        for (self.triples.items) |triple| {
            try writer.print("{s}\t{s}\t{s}\n", .{ triple.subject, triple.predicate, triple.object });
        }
    }
    
    /// Load from file
    pub fn load(self: *KnowledgeGraph, path: []const u8) !usize {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        
        var reader = file.reader();
        var buf: [4096]u8 = undefined;
        
        // Check header
        const header = reader.readUntilDelimiter(&buf, '\n') catch return error.InvalidFormat;
        if (!mem.eql(u8, header, "TRKG1")) return error.InvalidFormat;
        
        var count: usize = 0;
        while (reader.readUntilDelimiter(&buf, '\n')) |line| {
            var parts = mem.splitScalar(u8, line, '\t');
            const subject = parts.next() orelse continue;
            const predicate = parts.next() orelse continue;
            const object = parts.next() orelse continue;
            
            _ = try self.addTriple(subject, predicate, object);
            count += 1;
        } else |_| {}
        
        return count;
    }
};

// ============================================================================
// HTTP Server
// ============================================================================

/// JSON response builder
fn jsonResponse(allocator: Allocator, comptime fmt: []const u8, args: anytype) ![]u8 {
    return try std.fmt.allocPrint(allocator, fmt, args);
}

/// Parse JSON field from body
fn parseJsonField(body: []const u8, field: []const u8) ?[]const u8 {
    // Simple JSON parser for {"field": "value"} format
    const search = std.fmt.allocPrint(std.heap.page_allocator, "\"{s}\":", .{field}) catch return null;
    defer std.heap.page_allocator.free(search);
    
    const start_idx = mem.indexOf(u8, body, search) orelse return null;
    const value_start = start_idx + search.len;
    
    // Skip whitespace and opening quote
    var i = value_start;
    while (i < body.len and (body[i] == ' ' or body[i] == '"')) : (i += 1) {}
    
    if (i >= body.len) return null;
    
    // Find closing quote
    const end_idx = mem.indexOfScalarPos(u8, body, i, '"') orelse return null;
    
    return body[i..end_idx];
}

/// Parse query parameter from URL
fn parseQueryParam(target: []const u8, param: []const u8) ?[]const u8 {
    const query_start = mem.indexOf(u8, target, "?") orelse return null;
    const query = target[query_start + 1 ..];
    
    var params = mem.splitScalar(u8, query, '&');
    while (params.next()) |p| {
        var kv = mem.splitScalar(u8, p, '=');
        const key = kv.next() orelse continue;
        const value = kv.next() orelse continue;
        if (mem.eql(u8, key, param)) {
            return value;
        }
    }
    return null;
}

/// URL decode
fn urlDecode(allocator: Allocator, input: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();
    
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            const hex = input[i + 1 .. i + 3];
            const byte = std.fmt.parseInt(u8, hex, 16) catch {
                try result.append(input[i]);
                i += 1;
                continue;
            };
            try result.append(byte);
            i += 3;
        } else if (input[i] == '+') {
            try result.append(' ');
            i += 1;
        } else {
            try result.append(input[i]);
            i += 1;
        }
    }
    
    return result.toOwnedSlice();
}

/// HTTP Server for Knowledge Graph
pub const KGServer = struct {
    allocator: Allocator,
    kg: KnowledgeGraph,
    server: net.Server,
    running: bool,
    
    pub fn init(allocator: Allocator, port: u16) !KGServer {
        const address = net.Address.initIp4(.{ 0, 0, 0, 0 }, port);
        const server = try address.listen(.{
            .reuse_address = true,
        });
        
        return .{
            .allocator = allocator,
            .kg = KnowledgeGraph.init(allocator),
            .server = server,
            .running = true,
        };
    }
    
    pub fn deinit(self: *KGServer) void {
        self.kg.deinit();
        self.server.deinit();
    }
    
    /// Handle single request
    fn handleRequest(self: *KGServer, request: *http.Server.Request) !void {
        const target = request.head.target;
        const method = request.head.method;
        
        // Read body for POST requests
        var body_buf: [4096]u8 = undefined;
        var body: []const u8 = "";
        if (method == .POST) {
            if (request.head.content_length) |len| {
                const read_len = @min(len, body_buf.len);
                var reader = request.reader() catch {
                    try self.sendError(request, "Failed to read body");
                    return;
                };
                const n = reader.read(body_buf[0..read_len]) catch 0;
                body = body_buf[0..n];
            }
        }
        
        // Route requests
        if (mem.startsWith(u8, target, "/api/add") and method == .POST) {
            try self.handleAdd(request, body);
        } else if (mem.startsWith(u8, target, "/api/reason")) {
            try self.handleReason(request, target);
        } else if (mem.startsWith(u8, target, "/api/query")) {
            try self.handleQuery(request, target);
        } else if (mem.startsWith(u8, target, "/api/graph")) {
            try self.handleGraph(request);
        } else if (mem.startsWith(u8, target, "/api/stats")) {
            try self.handleStats(request);
        } else if (mem.startsWith(u8, target, "/api/akashic")) {
            try self.handleAkashic(request);
        } else if (mem.startsWith(u8, target, "/api/list")) {
            try self.handleList(request);
        } else if (mem.startsWith(u8, target, "/api/save") and method == .POST) {
            try self.handleSave(request, body);
        } else if (mem.startsWith(u8, target, "/api/load") and method == .POST) {
            try self.handleLoad(request, body);
        } else if (mem.startsWith(u8, target, "/api/clear") and method == .POST) {
            try self.handleClear(request);
        } else if (mem.eql(u8, target, "/") or mem.eql(u8, target, "/ui")) {
            try self.handleNewUI(request);
        } else if (mem.eql(u8, target, "/stars")) {
            try self.handleStarsUI(request);
        } else if (mem.eql(u8, target, "/old")) {
            try self.handleVisualization(request);
        } else if (mem.eql(u8, target, "/health")) {
            try self.sendJson(request, "{\"status\":\"ok\",\"service\":\"trinity-kg\"}");
        } else {
            try self.sendError(request, "Not found");
        }
    }
    
    fn handleAdd(self: *KGServer, request: *http.Server.Request, body: []const u8) !void {
        const subject = parseJsonField(body, "subject") orelse {
            try self.sendError(request, "Missing subject");
            return;
        };
        const predicate = parseJsonField(body, "predicate") orelse {
            try self.sendError(request, "Missing predicate");
            return;
        };
        const object = parseJsonField(body, "object") orelse {
            try self.sendError(request, "Missing object");
            return;
        };
        
        const id = self.kg.addTriple(subject, predicate, object) catch {
            try self.sendError(request, "Failed to add triple");
            return;
        };
        
        const response = try jsonResponse(self.allocator, "{{\"status\":\"ok\",\"triple_id\":{d}}}", .{id});
        defer self.allocator.free(response);
        try self.sendJson(request, response);
    }
    
    fn handleQuery(self: *KGServer, request: *http.Server.Request, target: []const u8) !void {
        const predicate_raw = parseQueryParam(target, "predicate") orelse {
            try self.sendError(request, "Missing predicate parameter");
            return;
        };
        const predicate = try urlDecode(self.allocator, predicate_raw);
        defer self.allocator.free(predicate);
        
        // Check if querying by subject or object
        if (parseQueryParam(target, "subject")) |subject_raw| {
            const subject = try urlDecode(self.allocator, subject_raw);
            defer self.allocator.free(subject);
            
            if (self.kg.queryObject(subject, predicate)) |result| {
                const response = try jsonResponse(self.allocator, 
                    "{{\"status\":\"ok\",\"result\":\"{s}\",\"similarity\":{d:.4}}}", 
                    .{ result.name, result.similarity });
                defer self.allocator.free(response);
                try self.sendJson(request, response);
            } else {
                try self.sendJson(request, "{\"status\":\"ok\",\"result\":null}");
            }
        } else if (parseQueryParam(target, "object")) |object_raw| {
            const object = try urlDecode(self.allocator, object_raw);
            defer self.allocator.free(object);
            
            if (self.kg.querySubject(object, predicate)) |result| {
                const response = try jsonResponse(self.allocator, 
                    "{{\"status\":\"ok\",\"result\":\"{s}\",\"similarity\":{d:.4}}}", 
                    .{ result.name, result.similarity });
                defer self.allocator.free(response);
                try self.sendJson(request, response);
            } else {
                try self.sendJson(request, "{\"status\":\"ok\",\"result\":null}");
            }
        } else {
            try self.sendError(request, "Missing subject or object parameter");
        }
    }
    
    /// Handle /api/reason - Multi-hop reasoning
    /// Params: 
    ///   - from, to, max_hops: Find path from entity to value
    ///   - entity, property, max_hops: Check if property holds for entity
    fn handleReason(self: *KGServer, request: *http.Server.Request, target: []const u8) !void {
        // Parse max_hops (default 5)
        var max_hops: usize = 5;
        if (parseQueryParam(target, "max_hops")) |hops_str| {
            max_hops = std.fmt.parseInt(usize, hops_str, 10) catch 5;
        }
        
        // Mode 1: Find path from -> to
        if (parseQueryParam(target, "from")) |from_raw| {
            const from = try urlDecode(self.allocator, from_raw);
            defer self.allocator.free(from);
            
            const to_raw = parseQueryParam(target, "to") orelse {
                try self.sendError(request, "Missing 'to' parameter");
                return;
            };
            const to = try urlDecode(self.allocator, to_raw);
            defer self.allocator.free(to);
            
            const result = self.kg.findPath(from, to, max_hops) catch {
                try self.sendError(request, "Reasoning failed");
                return;
            };
            defer if (result.path.len > 0) self.allocator.free(result.path);
            
            if (result.found) {
                // Build path JSON
                var path_json = std.ArrayList(u8).init(self.allocator);
                defer path_json.deinit();
                
                try path_json.appendSlice("[");
                for (result.path, 0..) |step, i| {
                    if (i > 0) try path_json.appendSlice(",");
                    const step_json = try std.fmt.allocPrint(self.allocator,
                        "{{\"entity\":\"{s}\",\"relation\":\"{s}\",\"next\":\"{s}\"}}",
                        .{ step.entity, step.relation, step.next_entity });
                    defer self.allocator.free(step_json);
                    try path_json.appendSlice(step_json);
                }
                try path_json.appendSlice("]");
                
                // Build conclusion string
                var conclusion = std.ArrayList(u8).init(self.allocator);
                defer conclusion.deinit();
                try conclusion.appendSlice(from);
                for (result.path) |step| {
                    try conclusion.appendSlice(" -> ");
                    try conclusion.appendSlice(step.relation);
                    try conclusion.appendSlice(" -> ");
                    try conclusion.appendSlice(step.next_entity);
                }
                
                const response = try std.fmt.allocPrint(self.allocator,
                    "{{\"status\":\"ok\",\"found\":true,\"hops\":{d},\"path\":{s},\"conclusion\":\"{s}\"}}",
                    .{ result.hops, path_json.items, conclusion.items });
                defer self.allocator.free(response);
                try self.sendJson(request, response);
            } else {
                const response = try std.fmt.allocPrint(self.allocator,
                    "{{\"status\":\"ok\",\"found\":false,\"message\":\"No path from '{s}' to '{s}' within {d} hops\"}}",
                    .{ from, to, max_hops });
                defer self.allocator.free(response);
                try self.sendJson(request, response);
            }
            return;
        }
        
        // Mode 2: Check property (e.g., "Is Socrates mortal?")
        if (parseQueryParam(target, "entity")) |entity_raw| {
            const entity = try urlDecode(self.allocator, entity_raw);
            defer self.allocator.free(entity);
            
            const property_raw = parseQueryParam(target, "property") orelse {
                try self.sendError(request, "Missing 'property' parameter");
                return;
            };
            const property = try urlDecode(self.allocator, property_raw);
            defer self.allocator.free(property);
            
            const result = self.kg.checkProperty(entity, property, max_hops) catch {
                try self.sendError(request, "Reasoning failed");
                return;
            };
            defer if (result.path.len > 0) self.allocator.free(result.path);
            
            if (result.holds) {
                // Build path JSON
                var path_json = std.ArrayList(u8).init(self.allocator);
                defer path_json.deinit();
                
                try path_json.appendSlice("[");
                for (result.path, 0..) |step, i| {
                    if (i > 0) try path_json.appendSlice(",");
                    const step_json = try std.fmt.allocPrint(self.allocator,
                        "{{\"entity\":\"{s}\",\"relation\":\"{s}\",\"next\":\"{s}\"}}",
                        .{ step.entity, step.relation, step.next_entity });
                    defer self.allocator.free(step_json);
                    try path_json.appendSlice(step_json);
                }
                try path_json.appendSlice("]");
                
                // Build explanation
                var explanation = std.ArrayList(u8).init(self.allocator);
                defer explanation.deinit();
                try explanation.appendSlice(entity);
                for (result.path) |step| {
                    try explanation.appendSlice(" -> ");
                    try explanation.appendSlice(step.relation);
                    try explanation.appendSlice(" -> ");
                    try explanation.appendSlice(step.next_entity);
                }
                
                const response = try std.fmt.allocPrint(self.allocator,
                    "{{\"status\":\"ok\",\"holds\":true,\"value\":\"{s}\",\"hops\":{d},\"path\":{s},\"explanation\":\"{s}\"}}",
                    .{ result.value.?, result.path.len, path_json.items, explanation.items });
                defer self.allocator.free(response);
                try self.sendJson(request, response);
            } else {
                const response = try std.fmt.allocPrint(self.allocator,
                    "{{\"status\":\"ok\",\"holds\":false,\"message\":\"Cannot determine if '{s}' has property '{s}'\"}}",
                    .{ entity, property });
                defer self.allocator.free(response);
                try self.sendJson(request, response);
            }
            return;
        }
        
        try self.sendError(request, "Missing parameters. Use: from+to or entity+property");
    }
    
    fn handleStats(self: *KGServer, request: *http.Server.Request) !void {
        const stats = self.kg.getStats();
        const response = try jsonResponse(self.allocator, 
            "{{\"status\":\"ok\",\"entities\":{d},\"relations\":{d},\"triples\":{d}}}", 
            .{ stats.entities, stats.relations, stats.triples });
        defer self.allocator.free(response);
        try self.sendJson(request, response);
    }
    
    /// Handle /api/akashic - Sacred Akashic Records metrics
    /// Handle /api/akashic - Sacred Akashic Records metrics
    /// NOW using REAL φ-indexed data from KnowledgeGraph
    fn handleAkashic(self: *KGServer, request: *http.Server.Request) !void {
        const stats = self.kg.getStats();
        const lucas_10 = lucasNumber(10);
        
        // Use REAL Akashic metrics from the graph (not recomputed)
        const phi_index_size = self.kg.phi_index.count();
        
        const response = try jsonResponse(self.allocator, 
            "{{\"status\":\"ok\"," ++
            "\"phi\":{d:.6}," ++
            "\"trinity\":{d:.6}," ++
            "\"fine_structure_inv\":{d:.6}," ++
            "\"transcendental\":{d:.6}," ++
            "\"lucas_10\":{d}," ++
            "\"entities\":{d}," ++
            "\"relations\":{d}," ++
            "\"triples\":{d}," ++
            "\"total_phi_hash\":{d}," ++
            "\"sacred_index\":{d}," ++
            "\"phi_index_size\":{d}," ++
            "\"backend\":\"AkashicKnowledgeGraph\"," ++
            "\"formula\":\"phi^2 + 1/phi^2 = 3\"}}", 
            .{ PHI, TRINITY, FINE_STRUCTURE_INV, TRANSCENDENTAL, lucas_10,
               stats.entities, stats.relations, stats.triples, 
               self.kg.total_phi_hash, self.kg.sacred_index, phi_index_size });
        defer self.allocator.free(response);
        try self.sendJson(request, response);
    }
    
    fn handleList(self: *KGServer, request: *http.Server.Request) !void {
        var response = std.ArrayList(u8).init(self.allocator);
        defer response.deinit();
        
        try response.appendSlice("{\"status\":\"ok\",\"triples\":[");
        
        for (self.kg.triples.items, 0..) |triple, i| {
            if (i > 0) try response.appendSlice(",");
            const triple_json = try std.fmt.allocPrint(self.allocator, 
                "[\"{s}\",\"{s}\",\"{s}\"]", 
                .{ triple.subject, triple.predicate, triple.object });
            defer self.allocator.free(triple_json);
            try response.appendSlice(triple_json);
        }
        
        try response.appendSlice("]}");
        try self.sendJson(request, response.items);
    }
    
    fn handleSave(self: *KGServer, request: *http.Server.Request, body: []const u8) !void {
        const path = parseJsonField(body, "path") orelse "graph.trkg";
        
        self.kg.save(path) catch {
            try self.sendError(request, "Failed to save graph");
            return;
        };
        
        try self.sendJson(request, "{\"status\":\"ok\"}");
    }
    
    fn handleLoad(self: *KGServer, request: *http.Server.Request, body: []const u8) !void {
        const path = parseJsonField(body, "path") orelse "graph.trkg";
        
        const count = self.kg.load(path) catch {
            try self.sendError(request, "Failed to load graph");
            return;
        };
        
        const response = try jsonResponse(self.allocator, "{{\"status\":\"ok\",\"triples\":{d}}}", .{count});
        defer self.allocator.free(response);
        try self.sendJson(request, response);
    }
    
    fn handleClear(self: *KGServer, request: *http.Server.Request) !void {
        self.kg.clear();
        try self.sendJson(request, "{\"status\":\"ok\"}");
    }
    
    /// Handle /api/graph - Return D3.js compatible graph format
    fn handleGraph(self: *KGServer, request: *http.Server.Request) !void {
        var response = std.ArrayList(u8).init(self.allocator);
        defer response.deinit();
        
        // Collect unique entities
        var entities = std.StringHashMap(usize).init(self.allocator);
        defer entities.deinit();
        
        const group_counter: usize = 1;
        for (self.kg.triples.items) |triple| {
            if (!entities.contains(triple.subject)) {
                try entities.put(triple.subject, group_counter);
            }
            if (!entities.contains(triple.object)) {
                // Values get group 2, entities get group 1
                const is_value = mem.eql(u8, triple.object, "true") or 
                                 mem.eql(u8, triple.object, "false") or
                                 (triple.object.len > 0 and (triple.object[0] >= '0' and triple.object[0] <= '9'));
                try entities.put(triple.object, if (is_value) 2 else 1);
            }
        }
        
        // Build nodes array
        try response.appendSlice("{\"nodes\":[");
        var first_node = true;
        var entity_iter = entities.iterator();
        while (entity_iter.next()) |entry| {
            if (!first_node) try response.appendSlice(",");
            first_node = false;
            
            const node_json = try std.fmt.allocPrint(self.allocator,
                "{{\"id\":\"{s}\",\"group\":{d}}}",
                .{ entry.key_ptr.*, entry.value_ptr.* });
            defer self.allocator.free(node_json);
            try response.appendSlice(node_json);
        }
        try response.appendSlice("],");
        
        // Build links array
        try response.appendSlice("\"links\":[");
        for (self.kg.triples.items, 0..) |triple, i| {
            if (i > 0) try response.appendSlice(",");
            const link_json = try std.fmt.allocPrint(self.allocator,
                "{{\"source\":\"{s}\",\"target\":\"{s}\",\"label\":\"{s}\"}}",
                .{ triple.subject, triple.object, triple.predicate });
            defer self.allocator.free(link_json);
            try response.appendSlice(link_json);
        }
        try response.appendSlice("]}");
        
        try self.sendJson(request, response.items);
    }
    
    /// Handle / and /ui - Serve new visualization HTML
    fn handleNewUI(self: *KGServer, request: *http.Server.Request) !void {
        _ = self;
        // Read HTML file
        const file = std.fs.cwd().openFile("trinity-kg-ui.html", .{}) catch {
            // Fallback to embedded HTML if file not found
            try request.respond("<html><body><h1>trinity-kg-ui.html not found</h1><p>Please ensure the file exists in the current directory.</p></body></html>", .{
                .status = .not_found,
                .extra_headers = &.{
                    .{ .name = "Content-Type", .value = "text/html; charset=utf-8" },
                },
            });
            return;
        };
        defer file.close();
        
        var buf: [65536]u8 = undefined;
        const len = file.readAll(&buf) catch 0;
        
        try request.respond(buf[0..len], .{
            .status = .ok,
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "text/html; charset=utf-8" },
            },
        });
    }
    
    /// Handle /stars - Serve 3D star map visualization
    fn handleStarsUI(self: *KGServer, request: *http.Server.Request) !void {
        _ = self;
        const file = std.fs.cwd().openFile("trinity-stars-ui.html", .{}) catch {
            try request.respond("<html><body><h1>trinity-stars-ui.html not found</h1></body></html>", .{
                .status = .not_found,
                .extra_headers = &.{
                    .{ .name = "Content-Type", .value = "text/html; charset=utf-8" },
                },
            });
            return;
        };
        defer file.close();
        
        var buf: [131072]u8 = undefined;  // 128KB for stars page
        const len = file.readAll(&buf) catch 0;
        
        try request.respond(buf[0..len], .{
            .status = .ok,
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "text/html; charset=utf-8" },
            },
        });
    }

    /// Handle /old - Serve old visualization HTML page
    fn handleVisualization(self: *KGServer, request: *http.Server.Request) !void {
        _ = self;
        const html = 
            \\<!DOCTYPE html>
            \\<html>
            \\<head>
            \\  <meta charset="utf-8">
            \\  <title>Trinity Knowledge Graph</title>
            \\  <script src="https://d3js.org/d3.v7.min.js"></script>
            \\  <style>
            \\    body { margin: 0; font-family: Arial, sans-serif; background: #1a1a2e; color: #eee; }
            \\    #controls { position: fixed; top: 10px; left: 10px; z-index: 100; background: #16213e; padding: 15px; border-radius: 8px; max-width: 200px; }
            \\    #controls input, #controls button { margin: 5px 0; padding: 8px; border-radius: 4px; border: 1px solid #0f3460; }
            \\    #controls input { background: #1a1a2e; color: #eee; width: 150px; }
            \\    #controls button { background: #e94560; color: white; cursor: pointer; border: none; margin-right: 5px; }
            \\    #controls button:hover { background: #ff6b6b; }
            \\    #stats { position: fixed; top: 10px; right: 10px; background: #16213e; padding: 15px; border-radius: 8px; }
            \\    #tooltip { position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%); background: #16213e; padding: 15px 25px; border-radius: 8px; display: none; border: 2px solid #e94560; max-width: 600px; }
            \\    #tooltip.show { display: block; }
            \\    #tooltip .path { color: #4ade80; font-family: monospace; margin: 10px 0; }
            \\    svg { width: 100vw; height: 100vh; }
            \\    .node { cursor: pointer; }
            \\    .node circle { stroke: #fff; stroke-width: 2px; transition: all 0.3s; }
            \\    .node text { font-size: 12px; fill: #eee; }
            \\    .node.highlighted circle { stroke: #4ade80; stroke-width: 4px; filter: drop-shadow(0 0 10px #4ade80); }
            \\    .node.dimmed circle { opacity: 0.3; }
            \\    .node.dimmed text { opacity: 0.3; }
            \\    .link { stroke: #0f3460; stroke-width: 2px; transition: all 0.3s; }
            \\    .link.highlighted { stroke: #4ade80; stroke-width: 4px; filter: drop-shadow(0 0 5px #4ade80); }
            \\    .link.dimmed { opacity: 0.2; }
            \\    .link-label { font-size: 10px; fill: #888; transition: all 0.3s; }
            \\    .link-label.highlighted { fill: #4ade80; font-weight: bold; }
            \\    .link-label.dimmed { opacity: 0.2; }
            \\    .group-1 { fill: #e94560; }
            \\    .group-2 { fill: #0f3460; }
            \\    h4 { margin: 15px 0 5px 0; color: #888; font-size: 12px; }
            \\  </style>
            \\</head>
            \\<body>
            \\  <div id="controls">
            \\    <h3 style="margin-top:0">Trinity KG</h3>
            \\    <h4>Add Triple</h4>
            \\    <input id="subject" placeholder="Subject"><br>
            \\    <input id="predicate" placeholder="Predicate"><br>
            \\    <input id="object" placeholder="Object"><br>
            \\    <button onclick="addTriple()">Add</button><br>
            \\    <h4>Actions</h4>
            \\    <button onclick="clearGraph()">Clear</button>
            \\    <button onclick="loadGraph()">Refresh</button><br>
            \\    <h4>Reasoning</h4>
            \\    <input id="reasonFrom" placeholder="From entity"><br>
            \\    <input id="reasonTo" placeholder="To entity"><br>
            \\    <button onclick="findPath()">Find Path</button><br>
            \\    <h4>Try Examples</h4>
            \\    <button onclick="example1()" style="font-size:11px;padding:5px;margin:2px 0;width:100%">Is Socrates mortal?</button><br>
            \\    <button onclick="example2()" style="font-size:11px;padding:5px;margin:2px 0;width:100%">Socrates → Aristotle</button><br>
            \\    <button onclick="example3()" style="font-size:11px;padding:5px;margin:2px 0;width:100%">Athens → place</button><br>
            \\    <p style="font-size:10px;color:#888;margin-top:8px">Click examples above or any node on graph</p>
            \\  </div>
            \\  <div id="stats"></div>
            \\  <div id="tooltip"><span id="tooltipText"></span><div class="path" id="tooltipPath"></div></div>
            \\  <svg></svg>
            \\  <script>
            \\    const width = window.innerWidth, height = window.innerHeight;
            \\    const svg = d3.select("svg");
            \\    let graphData = {nodes: [], links: []};
            \\    let simulation, link, node, linkLabel;
            \\    
            \\    function loadGraph() {
            \\      Promise.all([
            \\        fetch('/api/graph').then(r => r.json()),
            \\        fetch('/api/stats').then(r => r.json())
            \\      ]).then(([graph, stats]) => {
            \\        graphData = graph;
            \\        document.getElementById('stats').innerHTML = 
            \\          `<b>Entities:</b> ${stats.entities}<br><b>Relations:</b> ${stats.relations}<br><b>Triples:</b> ${stats.triples}`;
            \\        svg.selectAll("*").remove();
            \\        hideTooltip();
            \\        if (graph.nodes.length === 0) return;
            \\        simulation = d3.forceSimulation(graph.nodes)
            \\          .force("link", d3.forceLink(graph.links).id(d => d.id).distance(150))
            \\          .force("charge", d3.forceManyBody().strength(-400))
            \\          .force("center", d3.forceCenter(width / 2, height / 2));
            \\        link = svg.append("g").selectAll("line")
            \\          .data(graph.links).enter().append("line").attr("class", "link");
            \\        linkLabel = svg.append("g").selectAll("text")
            \\          .data(graph.links).enter().append("text")
            \\          .attr("class", "link-label").text(d => d.label);
            \\        node = svg.append("g").selectAll("g")
            \\          .data(graph.nodes).enter().append("g").attr("class", "node")
            \\          .on("click", (e, d) => highlightConnections(d.id))
            \\          .call(d3.drag().on("start", dragstarted).on("drag", dragged).on("end", dragended));
            \\        node.append("circle").attr("r", 20).attr("class", d => "group-" + d.group);
            \\        node.append("text").attr("dy", 35).attr("text-anchor", "middle").text(d => d.id);
            \\        simulation.on("tick", () => {
            \\          link.attr("x1", d => d.source.x).attr("y1", d => d.source.y)
            \\              .attr("x2", d => d.target.x).attr("y2", d => d.target.y);
            \\          linkLabel.attr("x", d => (d.source.x + d.target.x) / 2)
            \\                   .attr("y", d => (d.source.y + d.target.y) / 2);
            \\          node.attr("transform", d => `translate(${d.x},${d.y})`);
            \\        });
            \\      });
            \\    }
            \\    function highlightConnections(nodeId) {
            \\      clearHighlight();
            \\      const connected = new Set([nodeId]);
            \\      const connectedLinks = [];
            \\      graphData.links.forEach((l, i) => {
            \\        const src = typeof l.source === 'object' ? l.source.id : l.source;
            \\        const tgt = typeof l.target === 'object' ? l.target.id : l.target;
            \\        if (src === nodeId || tgt === nodeId) {
            \\          connected.add(src); connected.add(tgt);
            \\          connectedLinks.push({src, tgt, label: l.label, idx: i});
            \\        }
            \\      });
            \\      node.classed("highlighted", d => d.id === nodeId);
            \\      node.classed("dimmed", d => !connected.has(d.id));
            \\      link.classed("highlighted", (d, i) => connectedLinks.some(c => c.idx === i));
            \\      link.classed("dimmed", (d, i) => !connectedLinks.some(c => c.idx === i));
            \\      linkLabel.classed("highlighted", (d, i) => connectedLinks.some(c => c.idx === i));
            \\      linkLabel.classed("dimmed", (d, i) => !connectedLinks.some(c => c.idx === i));
            \\      const outgoing = connectedLinks.filter(c => c.src === nodeId).map(c => `${c.label} -> ${c.tgt}`);
            \\      const incoming = connectedLinks.filter(c => c.tgt === nodeId).map(c => `${c.src} -> ${c.label}`);
            \\      showTooltip(`<b>${nodeId}</b>`, outgoing.length ? `Out: ${outgoing.join(', ')}` : incoming.length ? `In: ${incoming.join(', ')}` : 'No connections');
            \\    }
            \\    function clearHighlight() {
            \\      node.classed("highlighted", false).classed("dimmed", false);
            \\      link.classed("highlighted", false).classed("dimmed", false);
            \\      linkLabel.classed("highlighted", false).classed("dimmed", false);
            \\    }
            \\    function showTooltip(title, path) {
            \\      document.getElementById('tooltipText').innerHTML = title;
            \\      document.getElementById('tooltipPath').innerHTML = path;
            \\      document.getElementById('tooltip').classList.add('show');
            \\    }
            \\    function hideTooltip() { document.getElementById('tooltip').classList.remove('show'); }
            \\    function findPath() {
            \\      const from = document.getElementById('reasonFrom').value;
            \\      const to = document.getElementById('reasonTo').value;
            \\      if (!from || !to) return alert('Enter From and To entities');
            \\      fetch(`/api/reason?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`)
            \\        .then(r => r.json()).then(data => {
            \\          if (!data.found) { showTooltip('No path found', `Cannot reach "${to}" from "${from}"`); return; }
            \\          const pathNodes = new Set([from]);
            \\          const pathLinks = [];
            \\          data.path.forEach(step => { pathNodes.add(step.entity); pathNodes.add(step.next); });
            \\          graphData.links.forEach((l, i) => {
            \\            const src = typeof l.source === 'object' ? l.source.id : l.source;
            \\            const tgt = typeof l.target === 'object' ? l.target.id : l.target;
            \\            data.path.forEach(step => { if (src === step.entity && tgt === step.next) pathLinks.push(i); });
            \\          });
            \\          clearHighlight();
            \\          node.classed("highlighted", d => pathNodes.has(d.id));
            \\          node.classed("dimmed", d => !pathNodes.has(d.id));
            \\          link.classed("highlighted", (d, i) => pathLinks.includes(i));
            \\          link.classed("dimmed", (d, i) => !pathLinks.includes(i));
            \\          linkLabel.classed("highlighted", (d, i) => pathLinks.includes(i));
            \\          linkLabel.classed("dimmed", (d, i) => !pathLinks.includes(i));
            \\          showTooltip(`Path found (${data.hops} hops)`, data.conclusion);
            \\        });
            \\    }
            \\    svg.on("click", (e) => { if (e.target.tagName === 'svg') { clearHighlight(); hideTooltip(); } });
            \\    function dragstarted(event) { if (!event.active) simulation.alphaTarget(0.3).restart(); event.subject.fx = event.subject.x; event.subject.fy = event.subject.y; }
            \\    function dragged(event) { event.subject.fx = event.x; event.subject.fy = event.y; }
            \\    function dragended(event) { if (!event.active) simulation.alphaTarget(0); event.subject.fx = null; event.subject.fy = null; }
            \\    function addTriple() {
            \\      const s = document.getElementById('subject').value;
            \\      const p = document.getElementById('predicate').value;
            \\      const o = document.getElementById('object').value;
            \\      if (!s || !p || !o) return alert('Fill all fields');
            \\      fetch('/api/add', {
            \\        method: 'POST', headers: {'Content-Type': 'application/json'},
            \\        body: JSON.stringify({subject: s, predicate: p, object: o})
            \\      }).then(() => { loadGraph(); ['subject','predicate','object'].forEach(id => document.getElementById(id).value = ''); });
            \\    }
            \\    function clearGraph() { if (confirm('Clear all data?')) fetch('/api/clear', {method: 'POST'}).then(loadGraph); }
            \\    function example1() { document.getElementById('reasonFrom').value = 'Socrates'; document.getElementById('reasonTo').value = 'true'; findPath(); }
            \\    function example2() { document.getElementById('reasonFrom').value = 'Socrates'; document.getElementById('reasonTo').value = 'Aristotle'; findPath(); }
            \\    function example3() { document.getElementById('reasonFrom').value = 'Athens'; document.getElementById('reasonTo').value = 'place'; findPath(); }
            \\    loadGraph();
            \\  </script>
            \\</body>
            \\</html>
        ;
        
        try request.respond(html, .{
            .status = .ok,
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "text/html; charset=utf-8" },
            },
        });
    }
    
    fn sendJson(self: *KGServer, request: *http.Server.Request, content: []const u8) !void {
        _ = self;
        try request.respond(content, .{
            .status = .ok,
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "Access-Control-Allow-Origin", .value = "*" },
            },
        });
    }
    
    fn sendError(self: *KGServer, request: *http.Server.Request, message: []const u8) !void {
        const response = try jsonResponse(self.allocator, "{{\"status\":\"error\",\"message\":\"{s}\"}}", .{message});
        defer self.allocator.free(response);
        try request.respond(response, .{
            .status = .bad_request,
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "Access-Control-Allow-Origin", .value = "*" },
            },
        });
    }
    
    /// Load example data for demonstration
    fn loadDefaultData(self: *KGServer) void {
        // Greek philosophers knowledge graph
        _ = self.kg.addTriple("Socrates", "is_a", "human") catch {};
        _ = self.kg.addTriple("Plato", "is_a", "human") catch {};
        _ = self.kg.addTriple("Aristotle", "is_a", "human") catch {};
        _ = self.kg.addTriple("human", "is_mortal", "true") catch {};
        _ = self.kg.addTriple("Socrates", "teacher_of", "Plato") catch {};
        _ = self.kg.addTriple("Plato", "teacher_of", "Aristotle") catch {};
        _ = self.kg.addTriple("Plato", "founded", "Academy") catch {};
        _ = self.kg.addTriple("Aristotle", "founded", "Lyceum") catch {};
        _ = self.kg.addTriple("Socrates", "born_in", "Athens") catch {};
        _ = self.kg.addTriple("Plato", "born_in", "Athens") catch {};
        _ = self.kg.addTriple("Athens", "is_a", "city") catch {};
        _ = self.kg.addTriple("city", "is_a", "place") catch {};
        
        std.debug.print("Loaded 12 default triples (Greek philosophers)\n", .{});
    }
    
    /// Run server loop
    pub fn run(self: *KGServer) !void {
        // Load default data for demonstration
        self.loadDefaultData();
        
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║         Trinity Knowledge Graph Server                       ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  http://0.0.0.0:{d:<5}                                       ║\n", .{self.server.listen_address.getPort()});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  GET  /           - Interactive visualization               ║\n", .{});
        std.debug.print("║  GET  /api/graph  - D3.js graph format                      ║\n", .{});
        std.debug.print("║  GET  /api/reason - Multi-hop reasoning                     ║\n", .{});
        std.debug.print("║  POST /api/add    - Add triple                              ║\n", .{});
        std.debug.print("║  GET  /api/query  - Query graph                             ║\n", .{});
        std.debug.print("║  GET  /api/stats  - Statistics                              ║\n", .{});
        std.debug.print("║  GET  /api/list   - List triples                            ║\n", .{});
        std.debug.print("║  POST /api/save   - Save to file                            ║\n", .{});
        std.debug.print("║  POST /api/load   - Load from file                          ║\n", .{});
        std.debug.print("║  POST /api/clear  - Clear graph                             ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
        std.debug.print("\n", .{});
        
        var read_buffer: [8192]u8 = undefined;
        
        while (self.running) {
            const connection = self.server.accept() catch |err| {
                std.debug.print("Accept error: {}\n", .{err});
                continue;
            };
            
            var server = http.Server.init(connection, &read_buffer);
            defer connection.stream.close();
            
            var request = server.receiveHead() catch |err| {
                std.debug.print("Receive error: {}\n", .{err});
                continue;
            };
            
            self.handleRequest(&request) catch |err| {
                std.debug.print("Handle error: {}\n", .{err});
            };
        }
    }
};

// ============================================================================
// Main Entry Point
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    var port: u16 = 8080;
    if (args.len > 1) {
        port = std.fmt.parseInt(u16, args[1], 10) catch 8080;
    }
    
    var server = try KGServer.init(allocator, port);
    defer server.deinit();
    
    try server.run();
}

// ============================================================================
// Tests
// ============================================================================

test "KnowledgeGraph basic operations" {
    const allocator = std.testing.allocator;
    var kg = KnowledgeGraph.init(allocator);
    defer kg.deinit();
    
    // Add triples
    _ = try kg.addTriple("Socrates", "is_a", "human");
    _ = try kg.addTriple("human", "is_mortal", "true");
    _ = try kg.addTriple("Plato", "is_a", "human");
    
    // Check stats
    const stats = kg.getStats();
    try std.testing.expectEqual(@as(usize, 4), stats.entities); // Socrates, human, true, Plato
    try std.testing.expectEqual(@as(usize, 2), stats.relations); // is_a, is_mortal
    try std.testing.expectEqual(@as(usize, 3), stats.triples);
    
    // Query: What is Socrates?
    if (kg.queryObject("Socrates", "is_a")) |result| {
        try std.testing.expectEqualStrings("human", result.name);
        try std.testing.expect(result.similarity > 0.9);
    } else {
        return error.QueryFailed;
    }
    
    // Query: Who is human?
    if (kg.querySubject("human", "is_a")) |result| {
        // Should find Socrates or Plato
        try std.testing.expect(mem.eql(u8, result.name, "Socrates") or mem.eql(u8, result.name, "Plato"));
    } else {
        return error.QueryFailed;
    }
}

test "embedding similarity" {
    const emb1 = computeEmbedding("hello");
    const emb2 = computeEmbedding("hello");
    const emb3 = computeEmbedding("world");
    
    // Same text should have similarity 1.0
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), cosineSimilarity(emb1, emb2), 0.001);
    
    // Different text should have lower similarity
    const sim = cosineSimilarity(emb1, emb3);
    try std.testing.expect(sim < 1.0);
    try std.testing.expect(sim > 0.0);
}

test "URL decode" {
    const allocator = std.testing.allocator;
    
    const decoded = try urlDecode(allocator, "hello%20world");
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("hello world", decoded);
    
    const decoded2 = try urlDecode(allocator, "test+value");
    defer allocator.free(decoded2);
    try std.testing.expectEqualStrings("test value", decoded2);
}

test "parse query param" {
    const target = "/api/query?subject=Socrates&predicate=is_a";
    
    try std.testing.expectEqualStrings("Socrates", parseQueryParam(target, "subject").?);
    try std.testing.expectEqualStrings("is_a", parseQueryParam(target, "predicate").?);
    try std.testing.expect(parseQueryParam(target, "object") == null);
}

test "parse JSON field" {
    const json = "{\"subject\":\"Socrates\",\"predicate\":\"is_a\",\"object\":\"human\"}";
    
    try std.testing.expectEqualStrings("Socrates", parseJsonField(json, "subject").?);
    try std.testing.expectEqualStrings("is_a", parseJsonField(json, "predicate").?);
    try std.testing.expectEqualStrings("human", parseJsonField(json, "object").?);
}

test "multi-hop reasoning: find path" {
    const allocator = std.testing.allocator;
    var kg = KnowledgeGraph.init(allocator);
    defer kg.deinit();
    
    // Build knowledge graph:
    // Socrates -> is_a -> human -> is_mortal -> true
    _ = try kg.addTriple("Socrates", "is_a", "human");
    _ = try kg.addTriple("human", "is_mortal", "true");
    _ = try kg.addTriple("Plato", "is_a", "human");
    _ = try kg.addTriple("Aristotle", "is_a", "human");
    
    // Find path from Socrates to true
    const result = try kg.findPath("Socrates", "true", 5);
    defer if (result.path.len > 0) allocator.free(result.path);
    
    try std.testing.expect(result.found);
    try std.testing.expectEqual(@as(usize, 2), result.hops);
    try std.testing.expectEqual(@as(usize, 2), result.path.len);
    
    // First step: Socrates -> is_a -> human
    try std.testing.expectEqualStrings("Socrates", result.path[0].entity);
    try std.testing.expectEqualStrings("is_a", result.path[0].relation);
    try std.testing.expectEqualStrings("human", result.path[0].next_entity);
    
    // Second step: human -> is_mortal -> true
    try std.testing.expectEqualStrings("human", result.path[1].entity);
    try std.testing.expectEqualStrings("is_mortal", result.path[1].relation);
    try std.testing.expectEqualStrings("true", result.path[1].next_entity);
}

test "multi-hop reasoning: check property" {
    const allocator = std.testing.allocator;
    var kg = KnowledgeGraph.init(allocator);
    defer kg.deinit();
    
    // Socrates -> is_a -> human -> is_mortal -> true
    _ = try kg.addTriple("Socrates", "is_a", "human");
    _ = try kg.addTriple("human", "is_mortal", "true");
    
    // Check: Is Socrates mortal?
    const result = try kg.checkProperty("Socrates", "is_mortal", 5);
    defer if (result.path.len > 0) allocator.free(result.path);
    
    try std.testing.expect(result.holds);
    try std.testing.expectEqualStrings("true", result.value.?);
    try std.testing.expectEqual(@as(usize, 2), result.path.len);
}

test "multi-hop reasoning: no path" {
    const allocator = std.testing.allocator;
    var kg = KnowledgeGraph.init(allocator);
    defer kg.deinit();
    
    _ = try kg.addTriple("Socrates", "is_a", "human");
    _ = try kg.addTriple("cat", "is_a", "animal");
    
    // No path from Socrates to animal
    const result = try kg.findPath("Socrates", "animal", 5);
    defer if (result.path.len > 0) allocator.free(result.path);
    
    try std.testing.expect(!result.found);
}

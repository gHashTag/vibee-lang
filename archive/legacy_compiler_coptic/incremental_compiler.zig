// ═══════════════════════════════════════════════════════════════
// INCREMENTAL COMPILER for VIBEE
// Based on: Salsa (Matsakis, 2018) - demand-driven incremental computation
// Expected speedup: 10-100x for small changes
// ═══════════════════════════════════════════════════════════════

const std = @import("std");
const parser = @import("parser.zig");
const codegen = @import("codegen.zig");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════
// REVISION TRACKING
// ═══════════════════════════════════════════════════════════════

pub const Revision = u64;

pub const RevisionTracker = struct {
    current: Revision,
    
    pub fn init() RevisionTracker {
        return .{ .current = 0 };
    }
    
    pub fn next(self: *RevisionTracker) Revision {
        self.current += 1;
        return self.current;
    }
};

// ═══════════════════════════════════════════════════════════════
// QUERY CACHE (Salsa-style)
// ═══════════════════════════════════════════════════════════════

pub fn QueryCache(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();
        
        entries: std.AutoHashMap(K, CacheEntry),
        allocator: Allocator,
        hits: u64,
        misses: u64,
        
        const CacheEntry = struct {
            value: V,
            computed_at: Revision,
            dependencies: std.ArrayList(K),
        };
        
        pub fn init(allocator: Allocator) Self {
            return .{
                .entries = std.AutoHashMap(K, CacheEntry).init(allocator),
                .allocator = allocator,
                .hits = 0,
                .misses = 0,
            };
        }
        
        pub fn deinit(self: *Self) void {
            var iter = self.entries.iterator();
            while (iter.next()) |entry| {
                entry.value_ptr.dependencies.deinit();
            }
            self.entries.deinit();
        }
        
        pub fn get(self: *Self, key: K, current_rev: Revision) ?V {
            if (self.entries.get(key)) |entry| {
                // Check if still valid
                if (entry.computed_at == current_rev) {
                    self.hits += 1;
                    return entry.value;
                }
            }
            self.misses += 1;
            return null;
        }
        
        pub fn put(self: *Self, key: K, value: V, revision: Revision, deps: []const K) !void {
            var dep_list = std.ArrayList(K).init(self.allocator);
            try dep_list.appendSlice(deps);
            
            try self.entries.put(key, .{
                .value = value,
                .computed_at = revision,
                .dependencies = dep_list,
            });
        }
        
        pub fn invalidate(self: *Self, key: K) void {
            if (self.entries.getPtr(key)) |entry| {
                entry.computed_at = 0; // Mark as stale
            }
        }
        
        pub fn hitRate(self: *Self) f64 {
            const total = self.hits + self.misses;
            if (total == 0) return 0;
            return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
        }
    };
}

// ═══════════════════════════════════════════════════════════════
// FILE FINGERPRINT
// ═══════════════════════════════════════════════════════════════

pub const FileFingerprint = struct {
    path: []const u8,
    hash: u64,
    mtime: i128,
    size: u64,
    
    pub fn compute(allocator: Allocator, path: []const u8) !FileFingerprint {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        
        const stat = try file.stat();
        const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
        defer allocator.free(content);
        
        return .{
            .path = path,
            .hash = std.hash.Wyhash.hash(0, content),
            .mtime = stat.mtime,
            .size = stat.size,
        };
    }
    
    pub fn hasChanged(self: FileFingerprint, other: FileFingerprint) bool {
        return self.hash != other.hash or self.size != other.size;
    }
};

// ═══════════════════════════════════════════════════════════════
// COMPILATION UNIT
// ═══════════════════════════════════════════════════════════════

pub const CompilationUnit = struct {
    path: []const u8,
    fingerprint: FileFingerprint,
    spec: ?parser.Spec,
    generated_code: ?[]const u8,
    dependencies: std.ArrayList([]const u8),
    errors: std.ArrayList(CompileError),
    
    pub const CompileError = struct {
        line: u32,
        column: u32,
        message: []const u8,
    };
};

// ═══════════════════════════════════════════════════════════════
// INCREMENTAL COMPILER
// ═══════════════════════════════════════════════════════════════

pub const IncrementalCompiler = struct {
    allocator: Allocator,
    revision: RevisionTracker,
    
    // Caches
    parse_cache: QueryCache(u64, parser.Spec),      // hash -> Spec
    codegen_cache: QueryCache(u64, []const u8),     // hash -> generated code
    
    // File tracking
    file_fingerprints: std.StringHashMap(FileFingerprint),
    compilation_units: std.StringHashMap(CompilationUnit),
    
    // Statistics
    full_compiles: u64,
    incremental_compiles: u64,
    cache_hits: u64,
    
    pub fn init(allocator: Allocator) IncrementalCompiler {
        return .{
            .allocator = allocator,
            .revision = RevisionTracker.init(),
            .parse_cache = QueryCache(u64, parser.Spec).init(allocator),
            .codegen_cache = QueryCache(u64, []const u8).init(allocator),
            .file_fingerprints = std.StringHashMap(FileFingerprint).init(allocator),
            .compilation_units = std.StringHashMap(CompilationUnit).init(allocator),
            .full_compiles = 0,
            .incremental_compiles = 0,
            .cache_hits = 0,
        };
    }
    
    pub fn deinit(self: *IncrementalCompiler) void {
        self.parse_cache.deinit();
        self.codegen_cache.deinit();
        self.file_fingerprints.deinit();
        
        var iter = self.compilation_units.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.dependencies.deinit();
            entry.value_ptr.errors.deinit();
        }
        self.compilation_units.deinit();
    }
    
    /// Compile a file (incremental if possible)
    pub fn compile(self: *IncrementalCompiler, path: []const u8) !CompilationResult {
        const start_time = std.time.nanoTimestamp();
        
        // Compute current fingerprint
        const current_fp = try FileFingerprint.compute(self.allocator, path);
        
        // Check if file has changed
        if (self.file_fingerprints.get(path)) |old_fp| {
            if (!current_fp.hasChanged(old_fp)) {
                // File unchanged - return cached result
                if (self.compilation_units.get(path)) |unit| {
                    self.cache_hits += 1;
                    self.incremental_compiles += 1;
                    
                    const end_time = std.time.nanoTimestamp();
                    return .{
                        .path = path,
                        .spec = unit.spec,
                        .generated_code = unit.generated_code,
                        .was_cached = true,
                        .compile_time_ns = @intCast(end_time - start_time),
                    };
                }
            }
        }
        
        // File changed or new - full compile
        self.full_compiles += 1;
        
        // Read file
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        const content = try file.readToEndAlloc(self.allocator, 10 * 1024 * 1024);
        defer self.allocator.free(content);
        
        // Parse
        const rev = self.revision.next();
        const content_hash = std.hash.Wyhash.hash(0, content);
        
        var spec: ?parser.Spec = null;
        if (self.parse_cache.get(content_hash, rev)) |cached_spec| {
            spec = cached_spec;
        } else {
            spec = parser.parse(self.allocator, content) catch null;
            if (spec) |s| {
                try self.parse_cache.put(content_hash, s, rev, &[_]u64{});
            }
        }
        
        // Generate code
        var generated: ?[]const u8 = null;
        if (spec) |s| {
            if (self.codegen_cache.get(content_hash, rev)) |cached_code| {
                generated = cached_code;
            } else {
                // Generate code (simplified)
                generated = try self.generateCode(s);
                if (generated) |g| {
                    try self.codegen_cache.put(content_hash, g, rev, &[_]u64{});
                }
            }
        }
        
        // Update fingerprint
        try self.file_fingerprints.put(path, current_fp);
        
        // Update compilation unit
        const unit = CompilationUnit{
            .path = path,
            .fingerprint = current_fp,
            .spec = spec,
            .generated_code = generated,
            .dependencies = std.ArrayList([]const u8).init(self.allocator),
            .errors = std.ArrayList(CompilationUnit.CompileError).init(self.allocator),
        };
        try self.compilation_units.put(path, unit);
        
        const end_time = std.time.nanoTimestamp();
        
        return .{
            .path = path,
            .spec = spec,
            .generated_code = generated,
            .was_cached = false,
            .compile_time_ns = @intCast(end_time - start_time),
        };
    }
    
    /// Generate code from spec
    fn generateCode(self: *IncrementalCompiler, spec: parser.Spec) ![]const u8 {
        // Simplified code generation
        var output = std.ArrayList(u8).init(self.allocator);
        const writer = output.writer();
        
        try writer.print("// Generated from: {s}\n", .{spec.name});
        try writer.print("// Version: {s}\n", .{spec.version});
        try writer.print("// Module: {s}\n\n", .{spec.module});
        
        for (spec.behaviors) |behavior| {
            try writer.print("// Behavior: {s}\n", .{behavior.name});
            try writer.print("//   Given: {s}\n", .{behavior.given});
            try writer.print("//   When: {s}\n", .{behavior.when});
            try writer.print("//   Then: {s}\n\n", .{behavior.then});
        }
        
        return try output.toOwnedSlice();
    }
    
    /// Invalidate a file (force recompile)
    pub fn invalidate(self: *IncrementalCompiler, path: []const u8) void {
        _ = self.file_fingerprints.remove(path);
        _ = self.compilation_units.remove(path);
    }
    
    /// Get statistics
    pub fn getStats(self: *IncrementalCompiler) CompilerStats {
        return .{
            .full_compiles = self.full_compiles,
            .incremental_compiles = self.incremental_compiles,
            .cache_hits = self.cache_hits,
            .parse_cache_hit_rate = self.parse_cache.hitRate(),
            .codegen_cache_hit_rate = self.codegen_cache.hitRate(),
        };
    }
};

// ═══════════════════════════════════════════════════════════════
// RESULT TYPES
// ═══════════════════════════════════════════════════════════════

pub const CompilationResult = struct {
    path: []const u8,
    spec: ?parser.Spec,
    generated_code: ?[]const u8,
    was_cached: bool,
    compile_time_ns: u64,
    
    pub fn speedupVsFull(self: CompilationResult, full_time_ns: u64) f64 {
        if (self.compile_time_ns == 0) return 0;
        return @as(f64, @floatFromInt(full_time_ns)) / @as(f64, @floatFromInt(self.compile_time_ns));
    }
};

pub const CompilerStats = struct {
    full_compiles: u64,
    incremental_compiles: u64,
    cache_hits: u64,
    parse_cache_hit_rate: f64,
    codegen_cache_hit_rate: f64,
    
    pub fn format(self: CompilerStats, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print(
            \\Compiler Statistics:
            \\  Full compiles: {}
            \\  Incremental compiles: {}
            \\  Cache hits: {}
            \\  Parse cache hit rate: {d:.1}%
            \\  Codegen cache hit rate: {d:.1}%
        , .{
            self.full_compiles,
            self.incremental_compiles,
            self.cache_hits,
            self.parse_cache_hit_rate * 100,
            self.codegen_cache_hit_rate * 100,
        });
    }
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

test "revision tracker" {
    var tracker = RevisionTracker.init();
    try std.testing.expectEqual(@as(Revision, 0), tracker.current);
    
    const r1 = tracker.next();
    try std.testing.expectEqual(@as(Revision, 1), r1);
    
    const r2 = tracker.next();
    try std.testing.expectEqual(@as(Revision, 2), r2);
}

test "query cache" {
    var cache = QueryCache(u64, i32).init(std.testing.allocator);
    defer cache.deinit();
    
    try cache.put(42, 100, 1, &[_]u64{});
    
    // Same revision - should hit
    const v1 = cache.get(42, 1);
    try std.testing.expectEqual(@as(i32, 100), v1.?);
    
    // Different revision - should miss
    const v2 = cache.get(42, 2);
    try std.testing.expect(v2 == null);
}

test "incremental compiler initialization" {
    var compiler = IncrementalCompiler.init(std.testing.allocator);
    defer compiler.deinit();
    
    const stats = compiler.getStats();
    try std.testing.expectEqual(@as(u64, 0), stats.full_compiles);
}

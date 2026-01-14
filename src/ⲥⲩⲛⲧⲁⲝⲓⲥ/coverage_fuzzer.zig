// Coverage-Guided Fuzzing for VIBEE
// Based on AFL (Zalewski, 2014) and libFuzzer
// Part of PAS Phase 3 implementation

const std = @import("std");
const parser = @import("parser.zig");

// ============================================================================
// COVERAGE MAP
// ============================================================================

pub const COVERAGE_MAP_SIZE: usize = 65536;

pub const CoverageMap = struct {
    edges: [COVERAGE_MAP_SIZE]u8,
    total_edges: u32,
    new_edges_found: u32,

    pub fn init() CoverageMap {
        return .{
            .edges = [_]u8{0} ** COVERAGE_MAP_SIZE,
            .total_edges = 0,
            .new_edges_found = 0,
        };
    }

    pub fn clear(self: *CoverageMap) void {
        @memset(&self.edges, 0);
    }

    pub fn recordEdge(self: *CoverageMap, from: u32, to: u32) void {
        const hash = (from ^ to) % COVERAGE_MAP_SIZE;
        if (self.edges[hash] < 255) {
            self.edges[hash] += 1;
        }
    }

    pub fn merge(self: *CoverageMap, other: *const CoverageMap) bool {
        var found_new = false;

        for (0..COVERAGE_MAP_SIZE) |i| {
            if (other.edges[i] > 0 and self.edges[i] == 0) {
                self.edges[i] = other.edges[i];
                self.new_edges_found += 1;
                found_new = true;
            }
        }

        return found_new;
    }

    pub fn countEdges(self: *const CoverageMap) u32 {
        var count: u32 = 0;
        for (self.edges) |e| {
            if (e > 0) count += 1;
        }
        return count;
    }
};

// ============================================================================
// INPUT CORPUS
// ============================================================================

pub const CorpusEntry = struct {
    data: []const u8,
    coverage: u32,
    depth: u32,
    found_at: u64,
    is_crash: bool,
};

pub const Corpus = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(CorpusEntry),
    total_coverage: CoverageMap,
    max_size: usize,

    pub fn init(allocator: std.mem.Allocator) Corpus {
        return .{
            .allocator = allocator,
            .entries = std.ArrayList(CorpusEntry).init(allocator),
            .total_coverage = CoverageMap.init(),
            .max_size = 10000,
        };
    }

    pub fn deinit(self: *Corpus) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry.data);
        }
        self.entries.deinit();
    }

    pub fn add(self: *Corpus, data: []const u8, coverage: *const CoverageMap, is_crash: bool) !bool {
        // Check if this input provides new coverage
        if (!self.total_coverage.merge(coverage) and !is_crash) {
            return false;
        }

        // Add to corpus
        const data_copy = try self.allocator.dupe(u8, data);
        try self.entries.append(.{
            .data = data_copy,
            .coverage = coverage.countEdges(),
            .depth = 0,
            .found_at = @intCast(std.time.milliTimestamp()),
            .is_crash = is_crash,
        });

        // Trim if too large
        if (self.entries.items.len > self.max_size) {
            self.trim();
        }

        return true;
    }

    pub fn selectRandom(self: *Corpus, random: std.Random) ?[]const u8 {
        if (self.entries.items.len == 0) return null;

        // Favor inputs with higher coverage
        var total_weight: u64 = 0;
        for (self.entries.items) |entry| {
            total_weight += entry.coverage + 1;
        }

        var target = random.intRangeAtMost(u64, 0, total_weight);
        for (self.entries.items) |entry| {
            const weight = entry.coverage + 1;
            if (target <= weight) {
                return entry.data;
            }
            target -= weight;
        }

        return self.entries.items[0].data;
    }

    fn trim(self: *Corpus) void {
        // Remove entries with lowest coverage
        std.sort.pdq(CorpusEntry, self.entries.items, {}, struct {
            fn lessThan(_: void, a: CorpusEntry, b: CorpusEntry) bool {
                return a.coverage > b.coverage; // Higher coverage first
            }
        }.lessThan);

        // Remove bottom half
        const keep = self.max_size / 2;
        while (self.entries.items.len > keep) {
            const entry = self.entries.pop();
            self.allocator.free(entry.data);
        }
    }
};

// ============================================================================
// MUTATION STRATEGIES
// ============================================================================

pub const MutationStrategy = enum {
    bit_flip,
    byte_flip,
    byte_insert,
    byte_delete,
    byte_replace,
    chunk_insert,
    chunk_delete,
    chunk_duplicate,
    arithmetic,
    interesting_values,
    dictionary,
    splice,
    havoc,
};

pub const Mutator = struct {
    allocator: std.mem.Allocator,
    random: std.Random,
    dictionary: std.ArrayList([]const u8),

    // Interesting values for fuzzing
    const INTERESTING_8: []const u8 = &[_]u8{ 0, 1, 16, 32, 64, 100, 127, 128, 255 };
    const INTERESTING_16: []const u16 = &[_]u16{ 0, 1, 128, 255, 256, 512, 1000, 1024, 4096, 32767, 32768, 65535 };

    pub fn init(allocator: std.mem.Allocator, seed: u64) Mutator {
        var prng = std.Random.DefaultPrng.init(seed);
        var dict = std.ArrayList([]const u8).init(allocator);

        // Add YAML-specific dictionary entries
        dict.append("name:") catch {};
        dict.append("version:") catch {};
        dict.append("behaviors:") catch {};
        dict.append("types:") catch {};
        dict.append("functions:") catch {};
        dict.append("given:") catch {};
        dict.append("when:") catch {};
        dict.append("then:") catch {};
        dict.append("test_cases:") catch {};
        dict.append("creation_pattern:") catch {};
        dict.append("source:") catch {};
        dict.append("transformer:") catch {};
        dict.append("result:") catch {};

        return .{
            .allocator = allocator,
            .random = prng.random(),
            .dictionary = dict,
        };
    }

    pub fn deinit(self: *Mutator) void {
        self.dictionary.deinit();
    }

    pub fn mutate(self: *Mutator, input: []const u8) ![]u8 {
        if (input.len == 0) {
            // Generate minimal valid input
            return try self.allocator.dupe(u8, "name: x\n");
        }

        const strategy = self.random.enumValue(MutationStrategy);

        return switch (strategy) {
            .bit_flip => try self.bitFlip(input),
            .byte_flip => try self.byteFlip(input),
            .byte_insert => try self.byteInsert(input),
            .byte_delete => try self.byteDelete(input),
            .byte_replace => try self.byteReplace(input),
            .chunk_insert => try self.chunkInsert(input),
            .chunk_delete => try self.chunkDelete(input),
            .chunk_duplicate => try self.chunkDuplicate(input),
            .arithmetic => try self.arithmetic(input),
            .interesting_values => try self.interestingValues(input),
            .dictionary => try self.dictionaryInsert(input),
            .splice => try self.splice(input, input), // Self-splice for now
            .havoc => try self.havoc(input),
        };
    }

    fn bitFlip(self: *Mutator, input: []const u8) ![]u8 {
        var output = try self.allocator.dupe(u8, input);
        if (output.len == 0) return output;

        const pos = self.random.intRangeAtMost(usize, 0, output.len - 1);
        const bit = @as(u8, 1) << @intCast(self.random.intRangeAtMost(u3, 0, 7));
        output[pos] ^= bit;

        return output;
    }

    fn byteFlip(self: *Mutator, input: []const u8) ![]u8 {
        var output = try self.allocator.dupe(u8, input);
        if (output.len == 0) return output;

        const pos = self.random.intRangeAtMost(usize, 0, output.len - 1);
        output[pos] = self.random.int(u8);

        return output;
    }

    fn byteInsert(self: *Mutator, input: []const u8) ![]u8 {
        const pos = if (input.len == 0) 0 else self.random.intRangeAtMost(usize, 0, input.len);
        const byte = self.random.int(u8);

        var output = try self.allocator.alloc(u8, input.len + 1);
        @memcpy(output[0..pos], input[0..pos]);
        output[pos] = byte;
        @memcpy(output[pos + 1 ..], input[pos..]);

        return output;
    }

    fn byteDelete(self: *Mutator, input: []const u8) ![]u8 {
        if (input.len <= 1) return try self.allocator.dupe(u8, input);

        const pos = self.random.intRangeAtMost(usize, 0, input.len - 1);

        var output = try self.allocator.alloc(u8, input.len - 1);
        @memcpy(output[0..pos], input[0..pos]);
        @memcpy(output[pos..], input[pos + 1 ..]);

        return output;
    }

    fn byteReplace(self: *Mutator, input: []const u8) ![]u8 {
        var output = try self.allocator.dupe(u8, input);
        if (output.len == 0) return output;

        const pos = self.random.intRangeAtMost(usize, 0, output.len - 1);
        output[pos] = INTERESTING_8[self.random.intRangeAtMost(usize, 0, INTERESTING_8.len - 1)];

        return output;
    }

    fn chunkInsert(self: *Mutator, input: []const u8) ![]u8 {
        const chunk_size = self.random.intRangeAtMost(usize, 1, 32);
        const pos = if (input.len == 0) 0 else self.random.intRangeAtMost(usize, 0, input.len);

        var output = try self.allocator.alloc(u8, input.len + chunk_size);
        @memcpy(output[0..pos], input[0..pos]);

        // Fill chunk with random or interesting data
        for (output[pos .. pos + chunk_size]) |*b| {
            b.* = self.random.int(u8);
        }

        @memcpy(output[pos + chunk_size ..], input[pos..]);

        return output;
    }

    fn chunkDelete(self: *Mutator, input: []const u8) ![]u8 {
        if (input.len <= 1) return try self.allocator.dupe(u8, input);

        const max_chunk = @min(32, input.len - 1);
        const chunk_size = self.random.intRangeAtMost(usize, 1, max_chunk);
        const pos = self.random.intRangeAtMost(usize, 0, input.len - chunk_size);

        var output = try self.allocator.alloc(u8, input.len - chunk_size);
        @memcpy(output[0..pos], input[0..pos]);
        @memcpy(output[pos..], input[pos + chunk_size ..]);

        return output;
    }

    fn chunkDuplicate(self: *Mutator, input: []const u8) ![]u8 {
        if (input.len == 0) return try self.allocator.dupe(u8, input);

        const max_chunk = @min(32, input.len);
        const chunk_size = self.random.intRangeAtMost(usize, 1, max_chunk);
        const src_pos = self.random.intRangeAtMost(usize, 0, input.len - chunk_size);
        const dst_pos = self.random.intRangeAtMost(usize, 0, input.len);

        var output = try self.allocator.alloc(u8, input.len + chunk_size);
        @memcpy(output[0..dst_pos], input[0..dst_pos]);
        @memcpy(output[dst_pos .. dst_pos + chunk_size], input[src_pos .. src_pos + chunk_size]);
        @memcpy(output[dst_pos + chunk_size ..], input[dst_pos..]);

        return output;
    }

    fn arithmetic(self: *Mutator, input: []const u8) ![]u8 {
        var output = try self.allocator.dupe(u8, input);
        if (output.len == 0) return output;

        const pos = self.random.intRangeAtMost(usize, 0, output.len - 1);
        const delta = self.random.intRangeAtMost(i8, -35, 35);

        if (delta >= 0) {
            output[pos] +%= @intCast(delta);
        } else {
            output[pos] -%= @intCast(-delta);
        }

        return output;
    }

    fn interestingValues(self: *Mutator, input: []const u8) ![]u8 {
        var output = try self.allocator.dupe(u8, input);
        if (output.len == 0) return output;

        const pos = self.random.intRangeAtMost(usize, 0, output.len - 1);
        output[pos] = INTERESTING_8[self.random.intRangeAtMost(usize, 0, INTERESTING_8.len - 1)];

        return output;
    }

    fn dictionaryInsert(self: *Mutator, input: []const u8) ![]u8 {
        if (self.dictionary.items.len == 0) {
            return try self.allocator.dupe(u8, input);
        }

        const word = self.dictionary.items[self.random.intRangeAtMost(usize, 0, self.dictionary.items.len - 1)];
        const pos = if (input.len == 0) 0 else self.random.intRangeAtMost(usize, 0, input.len);

        var output = try self.allocator.alloc(u8, input.len + word.len);
        @memcpy(output[0..pos], input[0..pos]);
        @memcpy(output[pos .. pos + word.len], word);
        @memcpy(output[pos + word.len ..], input[pos..]);

        return output;
    }

    fn splice(self: *Mutator, input1: []const u8, input2: []const u8) ![]u8 {
        if (input1.len == 0) return try self.allocator.dupe(u8, input2);
        if (input2.len == 0) return try self.allocator.dupe(u8, input1);

        const split1 = self.random.intRangeAtMost(usize, 0, input1.len);
        const split2 = self.random.intRangeAtMost(usize, 0, input2.len);

        var output = try self.allocator.alloc(u8, split1 + (input2.len - split2));
        @memcpy(output[0..split1], input1[0..split1]);
        @memcpy(output[split1..], input2[split2..]);

        return output;
    }

    fn havoc(self: *Mutator, input: []const u8) ![]u8 {
        var output = try self.allocator.dupe(u8, input);

        // Apply multiple random mutations
        const num_mutations = self.random.intRangeAtMost(usize, 1, 16);

        for (0..num_mutations) |_| {
            const new_output = try self.mutate(output);
            self.allocator.free(output);
            output = new_output;
        }

        return output;
    }
};

// ============================================================================
// FUZZER ENGINE
// ============================================================================

pub const FuzzerStats = struct {
    executions: u64,
    crashes: u64,
    unique_crashes: u64,
    coverage_edges: u32,
    corpus_size: usize,
    exec_per_sec: f64,
    start_time: i64,
    last_new_coverage: i64,
};

pub const CoverageFuzzer = struct {
    allocator: std.mem.Allocator,
    corpus: Corpus,
    mutator: Mutator,
    local_coverage: CoverageMap,
    stats: FuzzerStats,
    max_input_size: usize,

    pub fn init(allocator: std.mem.Allocator, seed: u64) CoverageFuzzer {
        return .{
            .allocator = allocator,
            .corpus = Corpus.init(allocator),
            .mutator = Mutator.init(allocator, seed),
            .local_coverage = CoverageMap.init(),
            .stats = .{
                .executions = 0,
                .crashes = 0,
                .unique_crashes = 0,
                .coverage_edges = 0,
                .corpus_size = 0,
                .exec_per_sec = 0,
                .start_time = std.time.milliTimestamp(),
                .last_new_coverage = std.time.milliTimestamp(),
            },
            .max_input_size = 64 * 1024, // 64KB max
        };
    }

    pub fn deinit(self: *CoverageFuzzer) void {
        self.corpus.deinit();
        self.mutator.deinit();
    }

    /// Add seed inputs to corpus
    pub fn addSeed(self: *CoverageFuzzer, input: []const u8) !void {
        self.local_coverage.clear();

        // Execute to get coverage
        const is_crash = !self.executeTarget(input);

        _ = try self.corpus.add(input, &self.local_coverage, is_crash);
        self.stats.corpus_size = self.corpus.entries.items.len;
    }

    /// Run fuzzing for specified duration
    pub fn fuzz(self: *CoverageFuzzer, duration_ms: u64) !void {
        const end_time = std.time.milliTimestamp() + @as(i64, @intCast(duration_ms));

        while (std.time.milliTimestamp() < end_time) {
            try self.fuzzOne();
        }

        self.updateStats();
    }

    /// Run one fuzzing iteration
    pub fn fuzzOne(self: *CoverageFuzzer) !void {
        // Select input from corpus
        const base_input = self.corpus.selectRandom(self.mutator.random) orelse "name: x\n";

        // Mutate
        const mutated = try self.mutator.mutate(base_input);
        defer self.allocator.free(mutated);

        // Limit size
        const input = if (mutated.len > self.max_input_size) mutated[0..self.max_input_size] else mutated;

        // Clear local coverage
        self.local_coverage.clear();

        // Execute
        const is_crash = !self.executeTarget(input);

        self.stats.executions += 1;
        if (is_crash) {
            self.stats.crashes += 1;
        }

        // Add to corpus if interesting
        if (try self.corpus.add(input, &self.local_coverage, is_crash)) {
            self.stats.last_new_coverage = std.time.milliTimestamp();
            if (is_crash) {
                self.stats.unique_crashes += 1;
            }
        }

        self.stats.corpus_size = self.corpus.entries.items.len;
        self.stats.coverage_edges = self.corpus.total_coverage.countEdges();
    }

    fn executeTarget(self: *CoverageFuzzer, input: []const u8) bool {
        // Try to parse the input
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        const spec = parser.parse(arena.allocator(), input) catch {
            // Parse error is not a crash
            return true;
        };

        // Record some coverage based on what was parsed
        self.recordCoverage(&spec);

        return true;
    }

    fn recordCoverage(self: *CoverageFuzzer, spec: *const parser.Spec) void {
        // Record coverage based on spec structure
        var prev_hash: u32 = 0;

        // Name
        if (spec.name.len > 0) {
            const hash: u32 = @truncate(std.hash.Wyhash.hash(0, spec.name));
            self.local_coverage.recordEdge(prev_hash, hash);
            prev_hash = hash;
        }

        // Behaviors
        for (spec.behaviors) |b| {
            const hash: u32 = @truncate(std.hash.Wyhash.hash(0, b.name));
            self.local_coverage.recordEdge(prev_hash, hash);
            prev_hash = hash;

            // Test cases
            for (b.test_cases) |tc| {
                const tc_hash: u32 = @truncate(std.hash.Wyhash.hash(0, tc.name));
                self.local_coverage.recordEdge(prev_hash, tc_hash);
            }
        }

        // Types
        for (spec.types) |t| {
            const hash: u32 = @truncate(std.hash.Wyhash.hash(0, t.name));
            self.local_coverage.recordEdge(prev_hash, hash);
            prev_hash = hash;
        }

        // Functions
        for (spec.functions) |f| {
            const hash: u32 = @truncate(std.hash.Wyhash.hash(0, f.name));
            self.local_coverage.recordEdge(prev_hash, hash);
            prev_hash = hash;
        }
    }

    fn updateStats(self: *CoverageFuzzer) void {
        const elapsed = std.time.milliTimestamp() - self.stats.start_time;
        if (elapsed > 0) {
            self.stats.exec_per_sec = @as(f64, @floatFromInt(self.stats.executions)) * 1000.0 / @as(f64, @floatFromInt(elapsed));
        }
    }

    pub fn getStats(self: *CoverageFuzzer) FuzzerStats {
        self.updateStats();
        return self.stats;
    }

    /// Get crash inputs
    pub fn getCrashes(self: *CoverageFuzzer) []const CorpusEntry {
        var crashes = std.ArrayList(CorpusEntry).init(self.allocator);
        for (self.corpus.entries.items) |entry| {
            if (entry.is_crash) {
                crashes.append(entry) catch {};
            }
        }
        return crashes.items;
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "coverage map" {
    var map = CoverageMap.init();

    map.recordEdge(0, 1);
    map.recordEdge(1, 2);
    map.recordEdge(2, 3);

    try std.testing.expect(map.countEdges() == 3);
}

test "coverage map merge" {
    var map1 = CoverageMap.init();
    var map2 = CoverageMap.init();

    map1.recordEdge(0, 1);
    map2.recordEdge(1, 2);

    const found_new = map1.merge(&map2);
    try std.testing.expect(found_new);
    try std.testing.expect(map1.countEdges() == 2);
}

test "corpus" {
    const allocator = std.testing.allocator;
    var corpus = Corpus.init(allocator);
    defer corpus.deinit();

    var coverage = CoverageMap.init();
    coverage.recordEdge(0, 1);

    const added = try corpus.add("test input", &coverage, false);
    try std.testing.expect(added);
    try std.testing.expect(corpus.entries.items.len == 1);
}

test "mutator bit flip" {
    const allocator = std.testing.allocator;
    var mutator = Mutator.init(allocator, 12345);
    defer mutator.deinit();

    const input = "hello";
    const output = try mutator.bitFlip(input);
    defer allocator.free(output);

    try std.testing.expect(output.len == input.len);
}

test "mutator byte insert" {
    const allocator = std.testing.allocator;
    var mutator = Mutator.init(allocator, 12345);
    defer mutator.deinit();

    const input = "hello";
    const output = try mutator.byteInsert(input);
    defer allocator.free(output);

    try std.testing.expect(output.len == input.len + 1);
}

test "mutator byte delete" {
    const allocator = std.testing.allocator;
    var mutator = Mutator.init(allocator, 12345);
    defer mutator.deinit();

    const input = "hello";
    const output = try mutator.byteDelete(input);
    defer allocator.free(output);

    try std.testing.expect(output.len == input.len - 1);
}

test "fuzzer init" {
    const allocator = std.testing.allocator;
    var fuzzer = CoverageFuzzer.init(allocator, 12345);
    defer fuzzer.deinit();

    const stats = fuzzer.getStats();
    try std.testing.expect(stats.executions == 0);
}

test "fuzzer add seed" {
    const allocator = std.testing.allocator;
    var fuzzer = CoverageFuzzer.init(allocator, 12345);
    defer fuzzer.deinit();

    try fuzzer.addSeed("name: test\nversion: \"1.0.0\"\n");
    try std.testing.expect(fuzzer.stats.corpus_size >= 1);
}

test "fuzzer one iteration" {
    const allocator = std.testing.allocator;
    var fuzzer = CoverageFuzzer.init(allocator, 12345);
    defer fuzzer.deinit();

    try fuzzer.addSeed("name: test\nversion: \"1.0.0\"\nlanguage: zig\nmodule: test\n");
    try fuzzer.fuzzOne();

    try std.testing.expect(fuzzer.stats.executions == 1);
}

// SIMD-Accelerated YAML Parser for VIBEE
// Based on simdjson techniques (Langdale & Lemire, 2019)
// Part of PAS Phase 1 implementation

const std = @import("std");
const parser = @import("parser.zig");

// ============================================================================
// SIMD CONSTANTS AND TYPES
// ============================================================================

pub const CHUNK_SIZE = 32;
pub const ChunkVector = @Vector(CHUNK_SIZE, u8);

/// Structural characters in YAML
pub const StructuralChar = enum(u8) {
    colon = ':',
    dash = '-',
    newline = '\n',
    space = ' ',
    hash = '#',
    quote_single = '\'',
    quote_double = '"',
    bracket_open = '[',
    bracket_close = ']',
    brace_open = '{',
    brace_close = '}',
};

/// Structural index entry
pub const StructuralIndex = struct {
    position: u32,
    char_type: StructuralChar,
    indent: u8,
};

// ============================================================================
// SIMD OPERATIONS
// ============================================================================

/// Create a vector filled with a single byte
fn splat(byte: u8) ChunkVector {
    return @splat(byte);
}

/// Compare vector with byte, return bitmask
fn cmpEq(vec: ChunkVector, byte: u8) u32 {
    const cmp_vec = splat(byte);
    const result: @Vector(CHUNK_SIZE, bool) = vec == cmp_vec;
    return @bitCast(result);
}

/// Find all occurrences of a character in chunk
pub fn findChar(chunk: ChunkVector, char: u8) u32 {
    return cmpEq(chunk, char);
}

/// Find YAML key separators (colon followed by space or newline)
pub fn findKeysSIMD(chunk: ChunkVector) u32 {
    const colon_mask = cmpEq(chunk, ':');
    
    // Shift chunk left by 1 to check next character
    var shifted: ChunkVector = undefined;
    inline for (0..CHUNK_SIZE - 1) |i| {
        shifted[i] = chunk[i + 1];
    }
    shifted[CHUNK_SIZE - 1] = 0;
    
    const space_mask = cmpEq(shifted, ' ');
    const newline_mask = cmpEq(shifted, '\n');
    
    // Key separator is colon followed by space or newline
    return colon_mask & (space_mask | newline_mask);
}

/// Find all newlines in chunk
pub fn findNewlines(chunk: ChunkVector) u32 {
    return cmpEq(chunk, '\n');
}

/// Find all list item markers (dash followed by space)
pub fn findListItems(chunk: ChunkVector) u32 {
    const dash_mask = cmpEq(chunk, '-');
    
    var shifted: ChunkVector = undefined;
    inline for (0..CHUNK_SIZE - 1) |i| {
        shifted[i] = chunk[i + 1];
    }
    shifted[CHUNK_SIZE - 1] = 0;
    
    const space_mask = cmpEq(shifted, ' ');
    
    return dash_mask & space_mask;
}

/// Find comment starts
pub fn findComments(chunk: ChunkVector) u32 {
    return cmpEq(chunk, '#');
}

/// Count leading spaces (for indent calculation)
pub fn countLeadingSpaces(line: []const u8) u8 {
    var count: u8 = 0;
    for (line) |c| {
        if (c == ' ') {
            count += 1;
        } else {
            break;
        }
    }
    return count;
}

// ============================================================================
// STRUCTURAL INDEX BUILDER
// ============================================================================

pub const StructuralIndexBuilder = struct {
    allocator: std.mem.Allocator,
    indices: std.ArrayList(StructuralIndex),
    current_position: u32,
    current_indent: u8,

    pub fn init(allocator: std.mem.Allocator) StructuralIndexBuilder {
        return .{
            .allocator = allocator,
            .indices = std.ArrayList(StructuralIndex).init(allocator),
            .current_position = 0,
            .current_indent = 0,
        };
    }

    pub fn deinit(self: *StructuralIndexBuilder) void {
        self.indices.deinit();
    }

    /// Process input and build structural index using SIMD
    pub fn build(self: *StructuralIndexBuilder, input: []const u8) ![]StructuralIndex {
        var pos: usize = 0;
        var line_start: usize = 0;

        while (pos + CHUNK_SIZE <= input.len) {
            // Load chunk
            var chunk: ChunkVector = undefined;
            inline for (0..CHUNK_SIZE) |i| {
                chunk[i] = input[pos + i];
            }

            // Find structural characters
            const keys = findKeysSIMD(chunk);
            const newlines = findNewlines(chunk);
            const list_items = findListItems(chunk);
            const comments = findComments(chunk);

            // Process found positions
            try self.processChunk(pos, keys, .colon);
            try self.processChunk(pos, newlines, .newline);
            try self.processChunk(pos, list_items, .dash);
            
            // Update line tracking for newlines
            var nl_mask = newlines;
            while (nl_mask != 0) {
                const bit_pos = @ctz(nl_mask);
                line_start = pos + bit_pos + 1;
                nl_mask &= nl_mask - 1;
            }

            pos += CHUNK_SIZE;
        }

        // Process remaining bytes (non-SIMD)
        while (pos < input.len) {
            const c = input[pos];
            switch (c) {
                ':' => {
                    if (pos + 1 < input.len and (input[pos + 1] == ' ' or input[pos + 1] == '\n')) {
                        try self.addIndex(pos, .colon, self.current_indent);
                    }
                },
                '\n' => {
                    try self.addIndex(pos, .newline, self.current_indent);
                    line_start = pos + 1;
                    if (pos + 1 < input.len) {
                        self.current_indent = countLeadingSpaces(input[pos + 1 ..]);
                    }
                },
                '-' => {
                    if (pos + 1 < input.len and input[pos + 1] == ' ') {
                        try self.addIndex(pos, .dash, self.current_indent);
                    }
                },
                else => {},
            }
            pos += 1;
        }

        return self.indices.toOwnedSlice();
    }

    fn processChunk(self: *StructuralIndexBuilder, base_pos: usize, mask: u32, char_type: StructuralChar) !void {
        var m = mask;
        while (m != 0) {
            const bit_pos = @ctz(m);
            try self.addIndex(base_pos + bit_pos, char_type, self.current_indent);
            m &= m - 1; // Clear lowest set bit
        }
    }

    fn addIndex(self: *StructuralIndexBuilder, pos: usize, char_type: StructuralChar, indent: u8) !void {
        try self.indices.append(.{
            .position = @intCast(pos),
            .char_type = char_type,
            .indent = indent,
        });
    }
};

// ============================================================================
// INCREMENTAL PARSER STATE
// ============================================================================

pub const IncrementalState = struct {
    allocator: std.mem.Allocator,
    spec: ?parser.Spec,
    structural_index: []StructuralIndex,
    source_hash: u64,
    dirty_ranges: std.ArrayList(Range),

    pub const Range = struct {
        start: u32,
        end: u32,
    };

    pub fn init(allocator: std.mem.Allocator) IncrementalState {
        return .{
            .allocator = allocator,
            .spec = null,
            .structural_index = &[_]StructuralIndex{},
            .source_hash = 0,
            .dirty_ranges = std.ArrayList(Range).init(allocator),
        };
    }

    pub fn deinit(self: *IncrementalState) void {
        if (self.spec) |*s| {
            s.deinit();
        }
        self.allocator.free(self.structural_index);
        self.dirty_ranges.deinit();
    }

    /// Check if full reparse is needed
    pub fn needsFullReparse(self: *IncrementalState, new_hash: u64) bool {
        return self.spec == null or self.source_hash != new_hash;
    }

    /// Mark range as dirty (needs reparse)
    pub fn markDirty(self: *IncrementalState, start: u32, end: u32) !void {
        try self.dirty_ranges.append(.{ .start = start, .end = end });
    }

    /// Clear dirty ranges after reparse
    pub fn clearDirty(self: *IncrementalState) void {
        self.dirty_ranges.clearRetainingCapacity();
    }
};

// ============================================================================
// FAST YAML PARSER (SIMD-accelerated)
// ============================================================================

pub const FastYamlParser = struct {
    allocator: std.mem.Allocator,
    index_builder: StructuralIndexBuilder,
    incremental_state: IncrementalState,

    pub fn init(allocator: std.mem.Allocator) FastYamlParser {
        return .{
            .allocator = allocator,
            .index_builder = StructuralIndexBuilder.init(allocator),
            .incremental_state = IncrementalState.init(allocator),
        };
    }

    pub fn deinit(self: *FastYamlParser) void {
        self.index_builder.deinit();
        self.incremental_state.deinit();
    }

    /// Parse YAML content with SIMD acceleration
    pub fn parse(self: *FastYamlParser, content: []const u8) !parser.Spec {
        // Build structural index using SIMD
        const index = try self.index_builder.build(content);
        defer self.allocator.free(index);

        // Parse using structural index
        return try self.parseFromIndex(content, index);
    }

    /// Parse incrementally (reuse previous parse state)
    pub fn parseIncremental(self: *FastYamlParser, content: []const u8, edit_start: u32, edit_end: u32) !parser.Spec {
        const new_hash = std.hash.Wyhash.hash(0, content);

        if (self.incremental_state.needsFullReparse(new_hash)) {
            // Full reparse needed
            const spec = try self.parse(content);
            self.incremental_state.spec = spec;
            self.incremental_state.source_hash = new_hash;
            return spec;
        }

        // Mark affected range as dirty
        try self.incremental_state.markDirty(edit_start, edit_end);

        // Reparse only dirty sections
        // For now, fall back to full reparse (incremental optimization TODO)
        const spec = try self.parse(content);
        self.incremental_state.spec = spec;
        self.incremental_state.source_hash = new_hash;
        self.incremental_state.clearDirty();

        return spec;
    }

    fn parseFromIndex(self: *FastYamlParser, content: []const u8, index: []StructuralIndex) !parser.Spec {
        _ = index; // Will be used for optimized parsing
        
        // For now, delegate to standard parser
        // Full SIMD-based parsing will be implemented in Phase 1
        return try parser.parse(self.allocator, content);
    }
};

// ============================================================================
// BENCHMARKING UTILITIES
// ============================================================================

pub const ParseMetrics = struct {
    parse_time_ns: u64,
    tokens_found: u32,
    structural_indices: u32,
    simd_chunks_processed: u32,
    bytes_processed: u64,

    pub fn throughputMBps(self: ParseMetrics) f64 {
        if (self.parse_time_ns == 0) return 0;
        const bytes_per_sec = @as(f64, @floatFromInt(self.bytes_processed)) * 1_000_000_000.0 / @as(f64, @floatFromInt(self.parse_time_ns));
        return bytes_per_sec / (1024.0 * 1024.0);
    }
};

pub fn benchmarkParse(allocator: std.mem.Allocator, content: []const u8, iterations: u32) !ParseMetrics {
    var total_time: u64 = 0;
    var fast_parser = FastYamlParser.init(allocator);
    defer fast_parser.deinit();

    for (0..iterations) |_| {
        const start = std.time.nanoTimestamp();
        const spec = try fast_parser.parse(content);
        const end = std.time.nanoTimestamp();
        
        spec.deinit();
        total_time += @intCast(end - start);
    }

    return .{
        .parse_time_ns = total_time / iterations,
        .tokens_found = 0, // TODO: count tokens
        .structural_indices = 0, // TODO: count indices
        .simd_chunks_processed = @intCast(content.len / CHUNK_SIZE),
        .bytes_processed = content.len,
    };
}

// ============================================================================
// TESTS
// ============================================================================

test "SIMD find keys" {
    const chunk: ChunkVector = "name: test                      ".*;
    const keys = findKeysSIMD(chunk);
    
    // Should find colon at position 4
    try std.testing.expect((keys & (1 << 4)) != 0);
}

test "SIMD find newlines" {
    var chunk: ChunkVector = undefined;
    @memset(&chunk, ' ');
    chunk[10] = '\n';
    chunk[20] = '\n';
    
    const newlines = findNewlines(chunk);
    
    try std.testing.expect((newlines & (1 << 10)) != 0);
    try std.testing.expect((newlines & (1 << 20)) != 0);
}

test "SIMD find list items" {
    const chunk: ChunkVector = "  - item1                       ".*;
    const items = findListItems(chunk);
    
    // Should find dash at position 2
    try std.testing.expect((items & (1 << 2)) != 0);
}

test "structural index builder" {
    const allocator = std.testing.allocator;
    var builder = StructuralIndexBuilder.init(allocator);
    defer builder.deinit();

    const input = "name: test\nversion: 1.0\n";
    const index = try builder.build(input);
    defer allocator.free(index);

    // Should find structural characters
    try std.testing.expect(index.len > 0);
}

test "fast yaml parser" {
    const allocator = std.testing.allocator;
    var fast_parser = FastYamlParser.init(allocator);
    defer fast_parser.deinit();

    const content =
        \\name: test_spec
        \\version: "1.0.0"
        \\language: zig
        \\module: test
        \\
        \\behaviors:
        \\  - name: test_behavior
        \\    given: A test condition
        \\    when: Action is taken
        \\    then: Expected result
    ;

    const spec = try fast_parser.parse(content);
    defer spec.deinit();

    try std.testing.expectEqualStrings("test_spec", spec.name);
}

test "incremental state" {
    const allocator = std.testing.allocator;
    var state = IncrementalState.init(allocator);
    defer state.deinit();

    try std.testing.expect(state.needsFullReparse(12345));
    
    try state.markDirty(0, 100);
    try std.testing.expect(state.dirty_ranges.items.len == 1);
    
    state.clearDirty();
    try std.testing.expect(state.dirty_ranges.items.len == 0);
}

test "count leading spaces" {
    try std.testing.expect(countLeadingSpaces("    test") == 4);
    try std.testing.expect(countLeadingSpaces("test") == 0);
    try std.testing.expect(countLeadingSpaces("  - item") == 2);
}

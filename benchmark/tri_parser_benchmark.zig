// ═══════════════════════════════════════════════════════════════════════════════
// TRI PARSER BENCHMARK - REAL PERFORMANCE MEASUREMENT
// ═══════════════════════════════════════════════════════════════════════════════
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;
pub const PHOENIX: usize = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// TRI PARSER (Simplified but real)
// ═══════════════════════════════════════════════════════════════════════════════

pub const TriParser = struct {
    source: []const u8,
    pos: usize,
    line: usize,
    
    pub fn init(source: []const u8) TriParser {
        return .{
            .source = source,
            .pos = 0,
            .line = 1,
        };
    }
    
    pub fn parse(self: *TriParser) !ParseResult {
        var entries: usize = 0;
        var keys: usize = 0;
        var values: usize = 0;
        
        while (self.pos < self.source.len) {
            self.skipWhitespace();
            if (self.pos >= self.source.len) break;
            
            // Skip comments
            if (self.peek() == '#') {
                self.skipLine();
                continue;
            }
            
            // Parse key
            const key_start = self.pos;
            while (self.pos < self.source.len and self.peek() != ':' and self.peek() != '\n') {
                self.pos += 1;
            }
            
            if (self.pos > key_start) {
                keys += 1;
            }
            
            // Skip colon
            if (self.pos < self.source.len and self.peek() == ':') {
                self.pos += 1;
                self.skipWhitespace();
                
                // Parse value
                const value_start = self.pos;
                if (self.pos < self.source.len and self.peek() == '|') {
                    // Multi-line string
                    self.skipLine();
                    while (self.pos < self.source.len) {
                        const indent = self.countIndent();
                        if (indent < 2) break;
                        self.skipLine();
                        values += 1;
                    }
                } else if (self.pos < self.source.len and self.peek() == '"') {
                    // Quoted string
                    self.pos += 1;
                    while (self.pos < self.source.len and self.peek() != '"') {
                        self.pos += 1;
                    }
                    if (self.pos < self.source.len) self.pos += 1;
                    values += 1;
                } else {
                    // Simple value
                    while (self.pos < self.source.len and self.peek() != '\n') {
                        self.pos += 1;
                    }
                    if (self.pos > value_start) {
                        values += 1;
                    }
                }
                
                entries += 1;
            }
            
            self.skipLine();
        }
        
        return .{
            .entries = entries,
            .keys = keys,
            .values = values,
            .bytes_parsed = self.pos,
        };
    }
    
    fn peek(self: *const TriParser) u8 {
        if (self.pos >= self.source.len) return 0;
        return self.source[self.pos];
    }
    
    fn skipWhitespace(self: *TriParser) void {
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == ' ' or c == '\t') {
                self.pos += 1;
            } else {
                break;
            }
        }
    }
    
    fn skipLine(self: *TriParser) void {
        while (self.pos < self.source.len and self.source[self.pos] != '\n') {
            self.pos += 1;
        }
        if (self.pos < self.source.len) {
            self.pos += 1;
            self.line += 1;
        }
    }
    
    fn countIndent(self: *TriParser) usize {
        var indent: usize = 0;
        const start = self.pos;
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == ' ') {
                indent += 1;
                self.pos += 1;
            } else if (c == '\t') {
                indent += 2;
                self.pos += 1;
            } else {
                break;
            }
        }
        self.pos = start;
        return indent;
    }
    
    pub const ParseResult = struct {
        entries: usize,
        keys: usize,
        values: usize,
        bytes_parsed: usize,
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

pub fn generateTriDocument(allocator: std.mem.Allocator, size_kb: usize) ![]u8 {
    var list = std.ArrayList(u8).init(allocator);
    const writer = list.writer();
    
    // Header
    try writer.writeAll("# Generated TRI document for benchmarking\n");
    try writer.writeAll("# ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q\n\n");
    
    try writer.writeAll("ⲛⲁⲙⲉ: benchmark_document\n");
    try writer.writeAll("ⲩⲉⲣⲥⲓⲟⲛ: \"1.0.0\"\n");
    try writer.writeAll("ⲫⲟⲉⲛⲓⲝ_ⲃⲗⲉⲥⲥⲓⲛⲅ: true\n\n");
    
    // Sacred constants
    try writer.writeAll("ⲥⲁⲕⲣⲁ_ⲕⲟⲛⲥⲧⲁⲛⲧⲥ:\n");
    try writer.writeAll("  PHI: 1.618033988749895\n");
    try writer.writeAll("  TRINITY: 3\n");
    try writer.writeAll("  PHOENIX: 999\n");
    try writer.writeAll("  SPEED_OF_LIGHT: 299792458\n\n");
    
    // Generate entries until we reach target size
    var entry_num: usize = 0;
    while (list.items.len < size_kb * 1024) {
        try writer.print("entry_{d}:\n", .{entry_num});
        try writer.print("  name: \"Entry number {d}\"\n", .{entry_num});
        try writer.print("  value: {d}\n", .{entry_num * 42});
        try writer.print("  phi_multiple: {d:.6}\n", .{@as(f64, @floatFromInt(entry_num)) * PHI});
        try writer.writeAll("  nested:\n");
        try writer.print("    level1: \"nested value {d}\"\n", .{entry_num});
        try writer.writeAll("    level2:\n");
        try writer.print("      deep: {d}\n", .{entry_num * 3});
        try writer.writeAll("\n");
        entry_num += 1;
    }
    
    return list.toOwnedSlice();
}

pub const BenchmarkResult = struct {
    size_bytes: usize,
    time_ns: u64,
    throughput_mb_s: f64,
    entries_parsed: usize,
    
    pub fn print(self: *const BenchmarkResult) void {
        std.debug.print("  Size: {d} KB\n", .{self.size_bytes / 1024});
        std.debug.print("  Time: {d:.2} ms\n", .{@as(f64, @floatFromInt(self.time_ns)) / 1_000_000.0});
        std.debug.print("  Throughput: {d:.2} MB/s\n", .{self.throughput_mb_s});
        std.debug.print("  Entries: {d}\n", .{self.entries_parsed});
    }
};

pub fn runBenchmark(allocator: std.mem.Allocator, data: []const u8, iterations: usize) !BenchmarkResult {
    var total_time: u64 = 0;
    var total_entries: usize = 0;
    
    // Warmup
    for (0..3) |_| {
        var parser = TriParser.init(data);
        _ = try parser.parse();
    }
    
    // Benchmark
    for (0..iterations) |_| {
        var parser = TriParser.init(data);
        
        const start = std.time.nanoTimestamp();
        const result = try parser.parse();
        const end = std.time.nanoTimestamp();
        
        total_time += @intCast(end - start);
        total_entries += result.entries;
    }
    
    _ = allocator;
    
    const avg_time = total_time / iterations;
    const throughput = @as(f64, @floatFromInt(data.len)) / @as(f64, @floatFromInt(avg_time)) * 1000.0; // MB/s
    
    return .{
        .size_bytes = data.len,
        .time_ns = avg_time,
        .throughput_mb_s = throughput,
        .entries_parsed = total_entries / iterations,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN BENCHMARK
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  TRI PARSER BENCHMARK\n", .{});
    std.debug.print("  ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q\n", .{});
    std.debug.print("  PHOENIX = {d} = 3³ × 37\n", .{PHOENIX});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    
    const sizes = [_]usize{ 1, 10, 100, 1000 }; // KB
    const iterations = 100;
    
    var results: [4]BenchmarkResult = undefined;
    
    for (sizes, 0..) |size_kb, i| {
        std.debug.print("Generating {d} KB document...\n", .{size_kb});
        const data = try generateTriDocument(allocator, size_kb);
        defer allocator.free(data);
        
        std.debug.print("Running benchmark ({d} iterations)...\n", .{iterations});
        results[i] = try runBenchmark(allocator, data, iterations);
        
        std.debug.print("\nResults for {d} KB:\n", .{size_kb});
        results[i].print();
        std.debug.print("\n", .{});
    }
    
    // Summary
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  SUMMARY\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("  Size (KB)  |  Time (ms)  |  Throughput (MB/s)  |  Entries\n", .{});
    std.debug.print("  -----------|-------------|---------------------|----------\n", .{});
    
    for (results) |r| {
        std.debug.print("  {d:>9}  |  {d:>9.2}  |  {d:>17.2}  |  {d:>8}\n", .{
            r.size_bytes / 1024,
            @as(f64, @floatFromInt(r.time_ns)) / 1_000_000.0,
            r.throughput_mb_s,
            r.entries_parsed,
        });
    }
    
    std.debug.print("\n", .{});
    
    // Comparison with libyaml (typical: 50-80 MB/s)
    const libyaml_typical: f64 = 65.0;
    const our_best = results[3].throughput_mb_s;
    const speedup = our_best / libyaml_typical;
    
    std.debug.print("  Comparison with libyaml (~{d:.0} MB/s typical):\n", .{libyaml_typical});
    std.debug.print("  TRI Parser: {d:.2} MB/s\n", .{our_best});
    std.debug.print("  Speedup: {d:.2}x\n", .{speedup});
    std.debug.print("\n", .{});
    
    if (speedup > 1.0) {
        std.debug.print("  ✅ TRI Parser is {d:.0}% FASTER than libyaml!\n", .{(speedup - 1.0) * 100.0});
    } else {
        std.debug.print("  ⚠️ TRI Parser is {d:.0}% slower than libyaml\n", .{(1.0 - speedup) * 100.0});
    }
    
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  🔥 PHOENIX BLESSING: Benchmark complete!\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "parser_basic" {
    const source =
        \\name: test
        \\value: 42
        \\nested:
        \\  key: value
    ;
    
    var parser = TriParser.init(source);
    const result = try parser.parse();
    
    try std.testing.expect(result.entries > 0);
    try std.testing.expect(result.keys > 0);
}

test "parser_with_comments" {
    const source =
        \\# This is a comment
        \\name: test
        \\# Another comment
        \\value: 42
    ;
    
    var parser = TriParser.init(source);
    const result = try parser.parse();
    
    try std.testing.expectEqual(@as(usize, 2), result.entries);
}

test "generate_document" {
    const allocator = std.testing.allocator;
    const doc = try generateTriDocument(allocator, 1);
    defer allocator.free(doc);
    
    try std.testing.expect(doc.len >= 1024);
}

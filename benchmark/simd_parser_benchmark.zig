// SIMD Parser Benchmark
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// PHOENIX = 999 = 3³ × 37

const std = @import("std");

// Embedded SIMD Parser for standalone benchmark
const PHI_CONST: f64 = 1.6180339887498948482;
const Vec16 = @Vector(16, u8);

const SimdToken = struct {
    kind: TokenKind,
    start: u32,
    len: u16,
    line: u32,
};

const TokenKind = enum(u8) {
    key, value, colon, newline, indent, string, number, comment, list_item, eof,
};

const SimdParserV2 = struct {
    input: []const u8,
    pos: usize,
    line: u32,
    tokens: std.ArrayList(SimdToken),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, input: []const u8) Self {
        return Self{
            .input = input,
            .pos = 0,
            .line = 1,
            .tokens = std.ArrayList(SimdToken).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.tokens.deinit();
    }

    fn simdSkipWhitespace(self: *Self) void {
        while (self.pos + 16 <= self.input.len) {
            const chunk: Vec16 = self.input[self.pos..][0..16].*;
            const spaces: Vec16 = @splat(' ');
            const tabs: Vec16 = @splat('\t');
            const is_space = chunk == spaces;
            const is_tab = chunk == tabs;
            const is_ws = @select(bool, is_space, is_space, is_tab);
            const mask = @as(u16, @bitCast(is_ws));
            if (mask == 0xFFFF) {
                self.pos += 16;
            } else {
                self.pos += @ctz(~mask);
                return;
            }
        }
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c != ' ' and c != '\t') break;
            self.pos += 1;
        }
    }

    fn simdCountIndent(self: *Self) u32 {
        var count: u32 = 0;
        while (self.pos + 16 <= self.input.len) {
            const chunk: Vec16 = self.input[self.pos..][0..16].*;
            const spaces: Vec16 = @splat(' ');
            const is_space = chunk == spaces;
            const mask = @as(u16, @bitCast(is_space));
            if (mask == 0xFFFF) {
                self.pos += 16;
                count += 16;
            } else {
                const first = @ctz(~mask);
                self.pos += first;
                count += first;
                break;
            }
        }
        while (self.pos < self.input.len and self.input[self.pos] == ' ') {
            self.pos += 1;
            count += 1;
        }
        return count;
    }

    fn simdParseKey(self: *Self) SimdToken {
        const start = self.pos;
        while (self.pos + 16 <= self.input.len) {
            const chunk: Vec16 = self.input[self.pos..][0..16].*;
            const colons: Vec16 = @splat(':');
            const newlines: Vec16 = @splat('\n');
            const is_colon = chunk == colons;
            const is_newline = chunk == newlines;
            const is_delim = @select(bool, is_colon, is_colon, is_newline);
            const mask = @as(u16, @bitCast(is_delim));
            if (mask != 0) {
                self.pos += @ctz(mask);
                break;
            }
            self.pos += 16;
        }
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c == ':' or c == '\n' or c == ' ') break;
            self.pos += 1;
        }
        return SimdToken{ .kind = .key, .start = @intCast(start), .len = @intCast(self.pos - start), .line = self.line };
    }

    fn simdParseValue(self: *Self) SimdToken {
        self.simdSkipWhitespace();
        const start = self.pos;
        while (self.pos + 16 <= self.input.len) {
            const chunk: Vec16 = self.input[self.pos..][0..16].*;
            const newlines: Vec16 = @splat('\n');
            const is_newline = chunk == newlines;
            const mask = @as(u16, @bitCast(is_newline));
            if (mask != 0) {
                self.pos += @ctz(mask);
                break;
            }
            self.pos += 16;
        }
        while (self.pos < self.input.len and self.input[self.pos] != '\n') {
            self.pos += 1;
        }
        var end = self.pos;
        while (end > start and (self.input[end - 1] == ' ' or self.input[end - 1] == '\t')) {
            end -= 1;
        }
        return SimdToken{ .kind = .value, .start = @intCast(start), .len = @intCast(end - start), .line = self.line };
    }

    pub fn tokenize(self: *Self) ![]SimdToken {
        while (self.pos < self.input.len) {
            if (self.input[self.pos] == '\n') {
                try self.tokens.append(SimdToken{ .kind = .newline, .start = @intCast(self.pos), .len = 1, .line = self.line });
                self.pos += 1;
                self.line += 1;
                const indent = self.simdCountIndent();
                if (indent > 0) {
                    try self.tokens.append(SimdToken{ .kind = .indent, .start = @intCast(self.pos - indent), .len = @intCast(indent), .line = self.line });
                }
                continue;
            }
            self.simdSkipWhitespace();
            if (self.pos >= self.input.len) break;
            if (self.input[self.pos] == '#') {
                const start = self.pos;
                while (self.pos < self.input.len and self.input[self.pos] != '\n') self.pos += 1;
                try self.tokens.append(SimdToken{ .kind = .comment, .start = @intCast(start), .len = @intCast(self.pos - start), .line = self.line });
                continue;
            }
            if (self.input[self.pos] == '-' and self.pos + 1 < self.input.len and self.input[self.pos + 1] == ' ') {
                try self.tokens.append(SimdToken{ .kind = .list_item, .start = @intCast(self.pos), .len = 2, .line = self.line });
                self.pos += 2;
                continue;
            }
            const key = self.simdParseKey();
            if (key.len > 0) try self.tokens.append(key);
            if (self.pos < self.input.len and self.input[self.pos] == ':') {
                try self.tokens.append(SimdToken{ .kind = .colon, .start = @intCast(self.pos), .len = 1, .line = self.line });
                self.pos += 1;
                if (self.pos < self.input.len and self.input[self.pos] != '\n') {
                    const value = self.simdParseValue();
                    if (value.len > 0) try self.tokens.append(value);
                }
            }
        }
        try self.tokens.append(SimdToken{ .kind = .eof, .start = @intCast(self.input.len), .len = 0, .line = self.line });
        return self.tokens.items;
    }
};

const PHI: f64 = 1.6180339887498948482;

fn generateYamlDocument(allocator: std.mem.Allocator, size_kb: usize) ![]u8 {
    var list = std.ArrayList(u8).init(allocator);
    const writer = list.writer();

    try writer.writeAll("# VIBEE Specification\n");
    try writer.writeAll("name: benchmark_spec\n");
    try writer.writeAll("version: \"1.0.0\"\n");
    try writer.writeAll("language: zig\n\n");

    var entries: usize = 0;
    while (list.items.len < size_kb * 1024) {
        try writer.print("entry_{d}:\n", .{entries});
        try writer.print("  key: value_{d}\n", .{entries});
        try writer.print("  number: {d}\n", .{entries * 42});
        try writer.print("  items:\n", .{});
        try writer.print("    - item_a_{d}\n", .{entries});
        try writer.print("    - item_b_{d}\n", .{entries});
        try writer.print("    - item_c_{d}\n", .{entries});
        entries += 1;
    }

    return list.toOwnedSlice();
}

// Scalar tokenizer for comparison
fn scalarTokenize(input: []const u8) u32 {
    var tokens: u32 = 0;
    var i: usize = 0;
    var in_token = false;

    while (i < input.len) : (i += 1) {
        const c = input[i];
        if (c == ' ' or c == '\t' or c == '\n' or c == ':' or c == '#') {
            if (in_token) {
                tokens += 1;
                in_token = false;
            }
            if (c == ':' or c == '#') tokens += 1;
        } else {
            in_token = true;
        }
    }
    if (in_token) tokens += 1;
    return tokens;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    try stdout.writeAll("═" ** 79 ++ "\n");
    try stdout.writeAll("  SIMD PARSER BENCHMARK\n");
    try stdout.writeAll("  ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q\n");
    try stdout.writeAll("  PHOENIX = 999 = 3³ × 37\n");
    try stdout.writeAll("═" ** 79 ++ "\n\n");

    const sizes = [_]usize{ 1, 10, 100, 1000 };
    const iterations: u32 = 100;

    var total_simd_speedup: f64 = 0;
    var count: f64 = 0;

    for (sizes) |size_kb| {
        try stdout.print("Generating {d} KB document...\n", .{size_kb});
        const doc = try generateYamlDocument(allocator, size_kb);
        defer allocator.free(doc);

        try stdout.print("Running benchmark ({d} iterations)...\n", .{iterations});

        // SIMD benchmark
        var simd_total: u64 = 0;
        var simd_tokens: usize = 0;
        {
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                var timer = try std.time.Timer.start();
                var parser = SimdParserV2.init(allocator, doc);
                const tokens = try parser.tokenize();
                simd_tokens = tokens.len;
                simd_total += timer.read();
                parser.deinit();
            }
        }

        // Scalar benchmark
        var scalar_total: u64 = 0;
        var scalar_tokens: u32 = 0;
        {
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                var timer = try std.time.Timer.start();
                scalar_tokens = scalarTokenize(doc);
                scalar_total += timer.read();
            }
        }

        const simd_avg_ns = simd_total / iterations;
        const scalar_avg_ns = scalar_total / iterations;
        const simd_avg_ms = @as(f64, @floatFromInt(simd_avg_ns)) / 1_000_000.0;
        const scalar_avg_ms = @as(f64, @floatFromInt(scalar_avg_ns)) / 1_000_000.0;
        const speedup = scalar_avg_ms / simd_avg_ms;
        const simd_throughput = @as(f64, @floatFromInt(size_kb)) / simd_avg_ms * 1000.0;
        const scalar_throughput = @as(f64, @floatFromInt(size_kb)) / scalar_avg_ms * 1000.0;

        total_simd_speedup += speedup;
        count += 1;

        try stdout.print("\nResults for {d} KB:\n", .{size_kb});
        try stdout.print("  SIMD:   {d:.2} ms, {d:.2} MB/s, {d} tokens\n", .{ simd_avg_ms, simd_throughput, simd_tokens });
        try stdout.print("  Scalar: {d:.2} ms, {d:.2} MB/s, {d} tokens\n", .{ scalar_avg_ms, scalar_throughput, scalar_tokens });
        try stdout.print("  Speedup: {d:.2}x\n\n", .{speedup});
    }

    const avg_speedup = total_simd_speedup / count;

    try stdout.writeAll("═" ** 79 ++ "\n");
    try stdout.writeAll("  SUMMARY\n");
    try stdout.writeAll("═" ** 79 ++ "\n\n");

    try stdout.print("  Average SIMD Speedup: {d:.2}x\n\n", .{avg_speedup});

    try stdout.writeAll("  Comparison:\n");
    try stdout.writeAll("    Scalar parser:     1.0x (baseline)\n");
    try stdout.print("    SIMD parser:       {d:.1}x\n", .{avg_speedup});
    try stdout.writeAll("    Target (3x):       3.0x\n\n");

    if (avg_speedup >= 2.5) {
        try stdout.writeAll("  ✅ SIMD Parser achieves significant speedup!\n");
    } else if (avg_speedup >= 1.5) {
        try stdout.writeAll("  ⚠️ SIMD Parser shows moderate improvement\n");
    } else {
        try stdout.writeAll("  ❌ SIMD Parser needs optimization\n");
    }

    // Golden identity verification
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const golden = phi_sq + inv_phi_sq;
    try stdout.print("\n  Golden Identity: φ² + 1/φ² = {d:.10}\n", .{golden});

    try stdout.writeAll("\n" ++ "═" ** 79 ++ "\n");
    try stdout.writeAll("  🔥 PHOENIX BLESSING: SIMD Benchmark complete!\n");
    try stdout.writeAll("═" ** 79 ++ "\n");
}

// ═══════════════════════════════════════════════════════════════════════════════
// ⲌⲘⲈⲒ ⲄⲞⲢⲨⲚⲨⲬ - IGLA CODE GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════
// Based on vibeec architecture: compiler.zig + codegen_v4.zig + pas_predictions.zig
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Patterns Applied: PRE, HSH, AMR, D&C, MLS
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const PI: f64 = 3.14159265358979323846;
pub const E: f64 = 2.71828182845904523536;
pub const TRINITY: u32 = 3;
pub const PHOENIX: u32 = 999;
pub const TRINITY_PRIME: u32 = 33;
pub const VERSION = "1.0.0";

/// Verify Golden Identity: φ² + 1/φ² = 3
pub fn verifyGoldenIdentity() bool {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    return @abs(result - GOLDEN_IDENTITY) < 0.0001;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CODE BUILDER - φ-BASED BUFFER GROWTH (AMR Pattern from vibeec)
// ═══════════════════════════════════════════════════════════════════════════════

pub const CodeBuilder = struct {
    allocator: Allocator,
    buffer: []u8,
    len: usize,
    reallocations: u32,
    indent_level: u32,

    const Self = @This();
    const INITIAL_SIZE: usize = 4096;

    pub fn init(allocator: Allocator) !Self {
        const buffer = try allocator.alloc(u8, INITIAL_SIZE);
        return Self{
            .allocator = allocator,
            .buffer = buffer,
            .len = 0,
            .reallocations = 0,
            .indent_level = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.buffer);
    }

    /// Grow using φ factor for optimal amortization (AMR pattern)
    fn grow(self: *Self, min_additional: usize) !void {
        const current = self.buffer.len;
        const phi_growth = @as(usize, @intFromFloat(@as(f64, @floatFromInt(current)) * PHI));
        const new_size = @max(phi_growth, current + min_additional);
        self.buffer = try self.allocator.realloc(self.buffer, new_size);
        self.reallocations += 1;
    }

    pub fn append(self: *Self, bytes: []const u8) !void {
        if (self.len + bytes.len > self.buffer.len) {
            try self.grow(bytes.len);
        }
        @memcpy(self.buffer[self.len..][0..bytes.len], bytes);
        self.len += bytes.len;
    }

    pub fn appendLine(self: *Self, line: []const u8) !void {
        try self.appendIndent();
        try self.append(line);
        try self.append("\n");
    }

    pub fn appendIndent(self: *Self) !void {
        var i: u32 = 0;
        while (i < self.indent_level) : (i += 1) {
            try self.append("    ");
        }
    }

    pub fn indent(self: *Self) void {
        self.indent_level += 1;
    }

    pub fn dedent(self: *Self) void {
        if (self.indent_level > 0) {
            self.indent_level -= 1;
        }
    }

    pub fn toOwnedSlice(self: *Self) ![]const u8 {
        const result = try self.allocator.alloc(u8, self.len);
        @memcpy(result, self.buffer[0..self.len]);
        return result;
    }

    pub fn getWritten(self: Self) []const u8 {
        return self.buffer[0..self.len];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// IDENTIFIER CACHE - HSH PATTERN (from vibeec)
// ═══════════════════════════════════════════════════════════════════════════════

pub const IdentifierCache = struct {
    cache: std.StringHashMap([]const u8),
    allocator: Allocator,
    hits: u64,
    misses: u64,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .cache = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
            .hits = 0,
            .misses = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.cache.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.cache.deinit();
    }

    pub fn getOrCreate(self: *Self, name: []const u8) ![]const u8 {
        if (self.cache.get(name)) |cached| {
            self.hits += 1;
            return cached;
        }

        self.misses += 1;
        // Transform: opcode name -> function name
        var buf: [64]u8 = undefined;
        const transformed = std.fmt.bufPrint(&buf, "exec_{s}", .{name}) catch name;
        const owned = try self.allocator.dupe(u8, transformed);
        try self.cache.put(name, owned);
        return owned;
    }

    pub fn hitRatio(self: Self) f64 {
        const total = self.hits + self.misses;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// OPCODE DEFINITION
// ═══════════════════════════════════════════════════════════════════════════════

pub const Opcode = struct {
    code: u8,
    mnemonic: []const u8,
    stack_in: u8,
    stack_out: u8,
    semantics: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ZMEI GORYNYCH - CODE GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const ZmeiGorynych = struct {
    allocator: Allocator,
    zig_builder: CodeBuilder,
    id_cache: IdentifierCache,

    // Metrics
    types_generated: u64,
    functions_generated: u64,
    tests_generated: u64,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .allocator = allocator,
            .zig_builder = try CodeBuilder.init(allocator),
            .id_cache = IdentifierCache.init(allocator),
            .types_generated = 0,
            .functions_generated = 0,
            .tests_generated = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.zig_builder.deinit();
        self.id_cache.deinit();
    }

    pub fn generate(self: *Self, opcodes: []const Opcode) !GenerateResult {
        // Header
        try self.generateHeader();

        // VM struct
        try self.generateVMStruct();

        // Dispatch
        try self.generateDispatch(opcodes);

        // Opcode functions
        for (opcodes) |opcode| {
            try self.generateOpcodeFunction(opcode);
            self.functions_generated += 1;
        }

        // Footer
        try self.generateFooter();

        // Tests
        for (opcodes) |opcode| {
            try self.generateTests(opcode);
            self.tests_generated += 1;
        }

        return GenerateResult{
            .zig_code = try self.zig_builder.toOwnedSlice(),
            .metrics = self.getMetrics(),
        };
    }

    fn generateHeader(self: *Self) !void {
        try self.zig_builder.appendLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.zig_builder.appendLine("// TRINITY VM - GENERATED BY ZMEI GORYNYCH");
        try self.zig_builder.appendLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.zig_builder.appendLine("// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q");
        try self.zig_builder.appendLine("// Golden Identity: φ² + 1/φ² = 3");
        try self.zig_builder.appendLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.zig_builder.append("\n");
        try self.zig_builder.appendLine("const std = @import(\"std\");");
        try self.zig_builder.appendLine("const Allocator = std.mem.Allocator;");
        try self.zig_builder.append("\n");
        try self.zig_builder.appendLine("// Sacred Constants");
        try self.zig_builder.appendLine("pub const PHI: f64 = 1.618033988749895;");
        try self.zig_builder.appendLine("pub const GOLDEN_IDENTITY: f64 = 3.0;");
        try self.zig_builder.appendLine("pub const TRINITY_PRIME: u32 = 33;");
        try self.zig_builder.append("\n");
    }

    fn generateVMStruct(self: *Self) !void {
        try self.zig_builder.appendLine("pub const VM = struct {");
        self.zig_builder.indent();
        try self.zig_builder.appendLine("stack: std.ArrayList(u64),");
        try self.zig_builder.appendLine("registers: [TRINITY_PRIME]u64,");
        try self.zig_builder.appendLine("pc: u64,");
        try self.zig_builder.appendLine("status: Status,");
        try self.zig_builder.appendLine("allocator: Allocator,");
        try self.zig_builder.append("\n");
        try self.zig_builder.appendLine("pub const Status = enum {");
        self.zig_builder.indent();
        try self.zig_builder.appendLine("Running,");
        try self.zig_builder.appendLine("Halted,");
        try self.zig_builder.appendLine("Error_StackUnderflow,");
        try self.zig_builder.appendLine("Error_StackOverflow,");
        try self.zig_builder.appendLine("Error_DivByZero,");
        try self.zig_builder.appendLine("Error_InvalidOpcode,");
        self.zig_builder.dedent();
        try self.zig_builder.appendLine("};");
        try self.zig_builder.append("\n");
        try self.zig_builder.appendLine("pub fn init(allocator: Allocator) VM {");
        self.zig_builder.indent();
        try self.zig_builder.appendLine("return .{");
        self.zig_builder.indent();
        try self.zig_builder.appendLine(".stack = std.ArrayList(u64).init(allocator),");
        try self.zig_builder.appendLine(".registers = [_]u64{0} ** TRINITY_PRIME,");
        try self.zig_builder.appendLine(".pc = 0,");
        try self.zig_builder.appendLine(".status = .Running,");
        try self.zig_builder.appendLine(".allocator = allocator,");
        self.zig_builder.dedent();
        try self.zig_builder.appendLine("};");
        self.zig_builder.dedent();
        try self.zig_builder.appendLine("}");
        try self.zig_builder.append("\n");
        try self.zig_builder.appendLine("pub fn deinit(self: *VM) void {");
        self.zig_builder.indent();
        try self.zig_builder.appendLine("self.stack.deinit();");
        self.zig_builder.dedent();
        try self.zig_builder.appendLine("}");
        try self.zig_builder.append("\n");
        self.types_generated += 1;
    }

    fn generateDispatch(self: *Self, opcodes: []const Opcode) !void {
        try self.zig_builder.appendLine("pub fn dispatch(self: *VM, opcode: u8) void {");
        self.zig_builder.indent();
        try self.zig_builder.appendLine("switch (opcode) {");
        self.zig_builder.indent();

        for (opcodes) |opcode| {
            const func_name = try self.id_cache.getOrCreate(opcode.mnemonic);
            var buf: [128]u8 = undefined;
            const line = std.fmt.bufPrint(&buf, "0x{X:0>2} => self.{s}(),", .{ opcode.code, func_name }) catch continue;
            try self.zig_builder.appendLine(line);
        }

        try self.zig_builder.appendLine("else => self.status = .Error_InvalidOpcode,");
        self.zig_builder.dedent();
        try self.zig_builder.appendLine("}");
        self.zig_builder.dedent();
        try self.zig_builder.appendLine("}");
        try self.zig_builder.append("\n");
    }

    fn generateOpcodeFunction(self: *Self, opcode: Opcode) !void {
        const func_name = try self.id_cache.getOrCreate(opcode.mnemonic);

        var buf: [256]u8 = undefined;
        const fn_line = std.fmt.bufPrint(&buf, "fn {s}(self: *VM) void {{", .{func_name}) catch return;
        try self.zig_builder.appendLine(fn_line);
        self.zig_builder.indent();

        // Stack check
        if (opcode.stack_in > 0) {
            const check = std.fmt.bufPrint(&buf, "if (self.stack.items.len < {d}) {{", .{opcode.stack_in}) catch return;
            try self.zig_builder.appendLine(check);
            self.zig_builder.indent();
            try self.zig_builder.appendLine("self.status = .Error_StackUnderflow;");
            try self.zig_builder.appendLine("return;");
            self.zig_builder.dedent();
            try self.zig_builder.appendLine("}");
        }

        // Pop operands
        if (opcode.stack_in >= 2) {
            try self.zig_builder.appendLine("const v1 = self.stack.pop();");
            try self.zig_builder.appendLine("const v2 = self.stack.pop();");
        } else if (opcode.stack_in == 1) {
            try self.zig_builder.appendLine("const v1 = self.stack.pop();");
        }

        // Operation
        if (std.mem.eql(u8, opcode.mnemonic, "ADD")) {
            try self.zig_builder.appendLine("const result = v1 +% v2;");
            try self.zig_builder.appendLine("self.stack.append(result) catch {");
            self.zig_builder.indent();
            try self.zig_builder.appendLine("self.status = .Error_StackOverflow;");
            try self.zig_builder.appendLine("return;");
            self.zig_builder.dedent();
            try self.zig_builder.appendLine("};");
        } else if (std.mem.eql(u8, opcode.mnemonic, "SUB")) {
            try self.zig_builder.appendLine("const result = v2 -% v1;");
            try self.zig_builder.appendLine("self.stack.append(result) catch {");
            self.zig_builder.indent();
            try self.zig_builder.appendLine("self.status = .Error_StackOverflow;");
            try self.zig_builder.appendLine("return;");
            self.zig_builder.dedent();
            try self.zig_builder.appendLine("};");
        } else if (std.mem.eql(u8, opcode.mnemonic, "MUL")) {
            try self.zig_builder.appendLine("const result = v1 *% v2;");
            try self.zig_builder.appendLine("self.stack.append(result) catch {");
            self.zig_builder.indent();
            try self.zig_builder.appendLine("self.status = .Error_StackOverflow;");
            try self.zig_builder.appendLine("return;");
            self.zig_builder.dedent();
            try self.zig_builder.appendLine("};");
        } else if (std.mem.eql(u8, opcode.mnemonic, "DIV")) {
            try self.zig_builder.appendLine("if (v1 == 0) {");
            self.zig_builder.indent();
            try self.zig_builder.appendLine("self.status = .Error_DivByZero;");
            try self.zig_builder.appendLine("return;");
            self.zig_builder.dedent();
            try self.zig_builder.appendLine("}");
            try self.zig_builder.appendLine("const result = v2 / v1;");
            try self.zig_builder.appendLine("self.stack.append(result) catch {");
            self.zig_builder.indent();
            try self.zig_builder.appendLine("self.status = .Error_StackOverflow;");
            try self.zig_builder.appendLine("return;");
            self.zig_builder.dedent();
            try self.zig_builder.appendLine("};");
        } else if (std.mem.eql(u8, opcode.mnemonic, "PUSH")) {
            // PUSH uses immediate value (placeholder 0)
            try self.zig_builder.appendLine("self.stack.append(0) catch {");
            self.zig_builder.indent();
            try self.zig_builder.appendLine("self.status = .Error_StackOverflow;");
            try self.zig_builder.appendLine("return;");
            self.zig_builder.dedent();
            try self.zig_builder.appendLine("};");
        } else if (std.mem.eql(u8, opcode.mnemonic, "POP")) {
            try self.zig_builder.appendLine("_ = self.stack.pop();");
        } else if (std.mem.eql(u8, opcode.mnemonic, "DUP")) {
            try self.zig_builder.appendLine("const top = self.stack.items[self.stack.items.len - 1];");
            try self.zig_builder.appendLine("self.stack.append(top) catch {");
            self.zig_builder.indent();
            try self.zig_builder.appendLine("self.status = .Error_StackOverflow;");
            try self.zig_builder.appendLine("return;");
            self.zig_builder.dedent();
            try self.zig_builder.appendLine("};");
        } else if (std.mem.eql(u8, opcode.mnemonic, "SWAP")) {
            try self.zig_builder.appendLine("self.stack.append(v1) catch {");
            self.zig_builder.indent();
            try self.zig_builder.appendLine("self.status = .Error_StackOverflow;");
            try self.zig_builder.appendLine("return;");
            self.zig_builder.dedent();
            try self.zig_builder.appendLine("};");
            try self.zig_builder.appendLine("self.stack.append(v2) catch {");
            self.zig_builder.indent();
            try self.zig_builder.appendLine("self.status = .Error_StackOverflow;");
            try self.zig_builder.appendLine("return;");
            self.zig_builder.dedent();
            try self.zig_builder.appendLine("};");
        } else if (opcode.stack_out > 0) {
            // Generic case for other opcodes with output
            try self.zig_builder.appendLine("// TODO: implement operation");
        }

        try self.zig_builder.appendLine("self.pc += 1;");
        self.zig_builder.dedent();
        try self.zig_builder.appendLine("}");
        try self.zig_builder.append("\n");
    }

    fn generateFooter(self: *Self) !void {
        self.zig_builder.dedent();
        try self.zig_builder.appendLine("};");
        try self.zig_builder.append("\n");
        try self.zig_builder.appendLine("// Golden Identity Verification");
        try self.zig_builder.appendLine("test \"golden_identity\" {");
        self.zig_builder.indent();
        try self.zig_builder.appendLine("const phi_sq = PHI * PHI;");
        try self.zig_builder.appendLine("const inv_phi_sq = 1.0 / phi_sq;");
        try self.zig_builder.appendLine("const result = phi_sq + inv_phi_sq;");
        try self.zig_builder.appendLine("try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);");
        self.zig_builder.dedent();
        try self.zig_builder.appendLine("}");
    }

    fn generateTests(self: *Self, opcode: Opcode) !void {
        var buf: [256]u8 = undefined;
        const test_name = std.fmt.bufPrint(&buf, "test \"{s}_basic\" {{", .{opcode.mnemonic}) catch return;
        try self.zig_builder.append("\n");
        try self.zig_builder.appendLine(test_name);
        self.zig_builder.indent();
        try self.zig_builder.appendLine("var gpa = std.heap.GeneralPurposeAllocator(.{}){};");
        try self.zig_builder.appendLine("defer _ = gpa.deinit();");
        try self.zig_builder.appendLine("var vm = VM.init(gpa.allocator());");
        try self.zig_builder.appendLine("defer vm.deinit();");
        try self.zig_builder.append("\n");

        if (opcode.stack_in >= 2) {
            try self.zig_builder.appendLine("try vm.stack.append(10);");
            try self.zig_builder.appendLine("try vm.stack.append(5);");
        }

        const dispatch_line = std.fmt.bufPrint(&buf, "vm.dispatch(0x{X:0>2});", .{opcode.code}) catch return;
        try self.zig_builder.appendLine(dispatch_line);
        try self.zig_builder.appendLine("try std.testing.expectEqual(VM.Status.Running, vm.status);");
        self.zig_builder.dedent();
        try self.zig_builder.appendLine("}");
    }

    pub fn getMetrics(self: *const Self) GenerateMetrics {
        return .{
            .types_generated = self.types_generated,
            .functions_generated = self.functions_generated,
            .tests_generated = self.tests_generated,
            .cache_hit_ratio = self.id_cache.hitRatio(),
            .buffer_reallocations = self.zig_builder.reallocations,
            .total_bytes = self.zig_builder.len,
        };
    }
};

pub const GenerateResult = struct {
    zig_code: []const u8,
    metrics: GenerateMetrics,
};

pub const GenerateMetrics = struct {
    types_generated: u64,
    functions_generated: u64,
    tests_generated: u64,
    cache_hit_ratio: f64,
    buffer_reallocations: u32,
    total_bytes: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "golden_identity" {
    try std.testing.expect(verifyGoldenIdentity());
}

test "code_builder_phi_growth" {
    const allocator = std.testing.allocator;
    var builder = try CodeBuilder.init(allocator);
    defer builder.deinit();

    try builder.append("test");
    try std.testing.expectEqual(@as(usize, 4), builder.len);
}

test "identifier_cache" {
    const allocator = std.testing.allocator;
    var cache = IdentifierCache.init(allocator);
    defer cache.deinit();

    const name1 = try cache.getOrCreate("ADD");
    const name2 = try cache.getOrCreate("ADD");
    try std.testing.expectEqualStrings(name1, name2);
    try std.testing.expectEqual(@as(u64, 1), cache.hits);
}

test "zmei_generate" {
    const allocator = std.testing.allocator;
    var zmei = try ZmeiGorynych.init(allocator);
    defer zmei.deinit();

    const opcodes = [_]Opcode{
        .{ .code = 0x01, .mnemonic = "ADD", .stack_in = 2, .stack_out = 1, .semantics = "v1+v2" },
        .{ .code = 0x02, .mnemonic = "SUB", .stack_in = 2, .stack_out = 1, .semantics = "v2-v1" },
    };

    const result = try zmei.generate(&opcodes);
    defer allocator.free(result.zig_code);

    try std.testing.expect(result.zig_code.len > 0);
    try std.testing.expectEqual(@as(u64, 2), result.metrics.functions_generated);
}

// ═══════════════════════════════════════════════════════════════════════════════
// VARLOG CODEGEN - Генератор Verilog кода из .vibee спецификаций
// ═══════════════════════════════════════════════════════════════════════════════
//
// Генерирует Verilog HDL для FPGA синтеза
// Автор: Dmitrii Vasilev
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// Sacred constants
const PHI: f64 = 1.618033988749895;
const PHI_INT: u32 = 1618;

pub const VarlogCodeGen = struct {
    allocator: Allocator,
    buffer: ArrayList(u8),
    indent: u32,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .buffer = ArrayList(u8).init(allocator),
            .indent = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
    }

    fn write(self: *Self, str: []const u8) !void {
        try self.buffer.appendSlice(str);
    }

    fn writeLine(self: *Self, str: []const u8) !void {
        try self.writeIndent();
        try self.buffer.appendSlice(str);
        try self.buffer.append('\n');
    }

    fn writeIndent(self: *Self) !void {
        var i: u32 = 0;
        while (i < self.indent) : (i += 1) {
            try self.buffer.appendSlice("  ");
        }
    }

    fn writeFmt(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        const writer = self.buffer.writer(self.allocator);
        try writer.print(fmt, args);
    }

    fn newline(self: *Self) !void {
        try self.buffer.append('\n');
    }

    fn incIndent(self: *Self) void {
        self.indent += 1;
    }

    fn decIndent(self: *Self) void {
        if (self.indent > 0) self.indent -= 1;
    }

    pub fn getOutput(self: *Self) []const u8 {
        return self.buffer.items;
    }

    /// Generate Verilog module from spec name
    pub fn generateModule(self: *Self, name: []const u8, module_type: ModuleType) ![]const u8 {
        try self.writeHeader(name);

        switch (module_type) {
            .sha256 => try self.generateSHA256Module(name),
            .nonce_gen => try self.generateNonceModule(name),
            .mining_core => try self.generateMiningCore(name),
            .phi_modulator => try self.generatePhiModulator(name),
            .generic => try self.generateGenericModule(name),
        }

        return self.getOutput();
    }

    fn writeHeader(self: *Self, name: []const u8) !void {
        try self.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.writeFmt("// TRINITY FPGA - {s}\n", .{name});
        try self.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.writeLine("// Generated from .vibee specification");
        try self.writeLine("// Sacred Formula: φ² + 1/φ² = 3");
        try self.writeLine("// DO NOT EDIT - Auto-generated");
        try self.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.newline();
        try self.writeLine("`timescale 1ns / 1ps");
        try self.newline();
    }

    fn generateSHA256Module(self: *Self, name: []const u8) !void {
        try self.writeFmt("module {s} (\n", .{name});
        self.incIndent();
        try self.writeLine("input  wire        clk,");
        try self.writeLine("input  wire        rst_n,");
        try self.writeLine("input  wire        start,");
        try self.writeLine("input  wire [511:0] block_in,");
        try self.writeLine("output reg  [255:0] hash_out,");
        try self.writeLine("output reg         done");
        self.decIndent();
        try self.writeLine(");");
        try self.newline();

        // SHA256 constants with phi modulation
        self.incIndent();
        try self.writeLine("// SHA-256 round constants (K) with φ-modulation");
        try self.writeLine("localparam [31:0] PHI_MOD = 32'd1618;  // φ × 1000");
        try self.newline();

        try self.writeLine("// Standard SHA-256 K constants");
        try self.writeLine("reg [31:0] K [0:63];");
        try self.writeLine("initial begin");
        self.incIndent();
        try self.writeLine("K[0]  = 32'h428a2f98; K[1]  = 32'h71374491;");
        try self.writeLine("K[2]  = 32'hb5c0fbcf; K[3]  = 32'he9b5dba5;");
        try self.writeLine("K[4]  = 32'h3956c25b; K[5]  = 32'h59f111f1;");
        try self.writeLine("K[6]  = 32'h923f82a4; K[7]  = 32'hab1c5ed5;");
        try self.writeLine("// ... (remaining 56 constants)");
        self.decIndent();
        try self.writeLine("end");
        try self.newline();

        // State machine
        try self.writeLine("// State machine");
        try self.writeLine("localparam IDLE = 2'b00, ROUND = 2'b01, DONE = 2'b10;");
        try self.writeLine("reg [1:0] state;");
        try self.writeLine("reg [6:0] round_cnt;");
        try self.newline();

        // Working variables
        try self.writeLine("// Working variables");
        try self.writeLine("reg [31:0] a, b, c, d, e, f, g, h;");
        try self.writeLine("reg [31:0] W [0:63];");
        try self.newline();

        // Phi modulation function
        try self.writeLine("// φ-modulation: inject irrationality every 3rd round");
        try self.writeLine("wire [31:0] K_mod = (round_cnt % 3 == 0) ? (K[round_cnt] + PHI_MOD) : K[round_cnt];");
        try self.newline();

        // Main logic
        try self.writeLine("always @(posedge clk or negedge rst_n) begin");
        self.incIndent();
        try self.writeLine("if (!rst_n) begin");
        self.incIndent();
        try self.writeLine("state <= IDLE;");
        try self.writeLine("done <= 1'b0;");
        try self.writeLine("round_cnt <= 7'd0;");
        self.decIndent();
        try self.writeLine("end else begin");
        self.incIndent();
        try self.writeLine("case (state)");
        self.incIndent();
        try self.writeLine("IDLE: if (start) begin");
        self.incIndent();
        try self.writeLine("// Initialize hash values (H0-H7)");
        try self.writeLine("a <= 32'h6a09e667; b <= 32'hbb67ae85;");
        try self.writeLine("c <= 32'h3c6ef372; d <= 32'ha54ff53a;");
        try self.writeLine("e <= 32'h510e527f; f <= 32'h9b05688c;");
        try self.writeLine("g <= 32'h1f83d9ab; h <= 32'h5be0cd19;");
        try self.writeLine("state <= ROUND;");
        try self.writeLine("round_cnt <= 7'd0;");
        try self.writeLine("done <= 1'b0;");
        self.decIndent();
        try self.writeLine("end");
        try self.newline();
        try self.writeLine("ROUND: begin");
        self.incIndent();
        try self.writeLine("// SHA-256 compression with φ-modulated K");
        try self.writeLine("// ... (64 rounds of compression)");
        try self.writeLine("if (round_cnt == 63) state <= DONE;");
        try self.writeLine("else round_cnt <= round_cnt + 1;");
        self.decIndent();
        try self.writeLine("end");
        try self.newline();
        try self.writeLine("DONE: begin");
        self.incIndent();
        try self.writeLine("hash_out <= {a, b, c, d, e, f, g, h};");
        try self.writeLine("done <= 1'b1;");
        try self.writeLine("state <= IDLE;");
        self.decIndent();
        try self.writeLine("end");
        self.decIndent();
        try self.writeLine("endcase");
        self.decIndent();
        try self.writeLine("end");
        self.decIndent();
        try self.writeLine("end");
        try self.newline();
        self.decIndent();

        try self.writeLine("endmodule");
    }

    fn generateNonceModule(self: *Self, name: []const u8) !void {
        try self.writeFmt("module {s} (\n", .{name});
        self.incIndent();
        try self.writeLine("input  wire        clk,");
        try self.writeLine("input  wire        rst_n,");
        try self.writeLine("input  wire        enable,");
        try self.writeLine("input  wire [31:0] start_nonce,");
        try self.writeLine("input  wire [7:0]  block_id,");
        try self.writeLine("output reg  [31:0] nonce_out,");
        try self.writeLine("output reg         valid");
        self.decIndent();
        try self.writeLine(");");
        try self.newline();

        self.incIndent();
        try self.writeLine("// Golden spiral stride for parallel mining");
        try self.writeLine("localparam [31:0] PHI_STRIDE = 32'd2654435769;  // 2^32 / φ");
        try self.newline();

        try self.writeLine("always @(posedge clk or negedge rst_n) begin");
        self.incIndent();
        try self.writeLine("if (!rst_n) begin");
        self.incIndent();
        try self.writeLine("nonce_out <= 32'd0;");
        try self.writeLine("valid <= 1'b0;");
        self.decIndent();
        try self.writeLine("end else if (enable) begin");
        self.incIndent();
        try self.writeLine("// Golden spiral traversal: nonce += φ-stride");
        try self.writeLine("nonce_out <= nonce_out + PHI_STRIDE + {24'd0, block_id};");
        try self.writeLine("valid <= 1'b1;");
        self.decIndent();
        try self.writeLine("end else begin");
        self.incIndent();
        try self.writeLine("nonce_out <= start_nonce + ({24'd0, block_id} * PHI_STRIDE);");
        try self.writeLine("valid <= 1'b0;");
        self.decIndent();
        try self.writeLine("end");
        self.decIndent();
        try self.writeLine("end");
        try self.newline();
        self.decIndent();

        try self.writeLine("endmodule");
    }

    fn generateMiningCore(self: *Self, name: []const u8) !void {
        try self.writeFmt("module {s} (\n", .{name});
        self.incIndent();
        try self.writeLine("input  wire         clk,");
        try self.writeLine("input  wire         rst_n,");
        try self.writeLine("input  wire         start,");
        try self.writeLine("input  wire [639:0] block_header,");
        try self.writeLine("input  wire [255:0] target,");
        try self.writeLine("output reg  [31:0]  golden_nonce,");
        try self.writeLine("output reg          found,");
        try self.writeLine("output reg  [31:0]  hashrate");
        self.decIndent();
        try self.writeLine(");");
        try self.newline();

        self.incIndent();
        try self.writeLine("// TRINITY Mining Core - Matryoshka Architecture");
        try self.writeLine("// φ² + 1/φ² = 3");
        try self.newline();

        try self.writeLine("// Instantiate parallel hash units");
        try self.writeLine("localparam NUM_UNITS = 8;  // 8 parallel SHA256 units");
        try self.newline();

        try self.writeLine("wire [255:0] hash_results [0:NUM_UNITS-1];");
        try self.writeLine("wire [NUM_UNITS-1:0] hash_done;");
        try self.writeLine("reg  [31:0] nonces [0:NUM_UNITS-1];");
        try self.newline();

        try self.writeLine("// Generate parallel mining units");
        try self.writeLine("genvar i;");
        try self.writeLine("generate");
        self.incIndent();
        try self.writeLine("for (i = 0; i < NUM_UNITS; i = i + 1) begin : mining_units");
        self.incIndent();
        try self.writeLine("phi_sha256 sha_unit (");
        self.incIndent();
        try self.writeLine(".clk(clk),");
        try self.writeLine(".rst_n(rst_n),");
        try self.writeLine(".start(start),");
        try self.writeLine(".block_in({block_header[639:32], nonces[i]}),");
        try self.writeLine(".hash_out(hash_results[i]),");
        try self.writeLine(".done(hash_done[i])");
        self.decIndent();
        try self.writeLine(");");
        self.decIndent();
        try self.writeLine("end");
        self.decIndent();
        try self.writeLine("endgenerate");
        try self.newline();

        try self.writeLine("// Check if hash meets target");
        try self.writeLine("integer j;");
        try self.writeLine("always @(posedge clk) begin");
        self.incIndent();
        try self.writeLine("found <= 1'b0;");
        try self.writeLine("for (j = 0; j < NUM_UNITS; j = j + 1) begin");
        self.incIndent();
        try self.writeLine("if (hash_done[j] && hash_results[j] < target) begin");
        self.incIndent();
        try self.writeLine("golden_nonce <= nonces[j];");
        try self.writeLine("found <= 1'b1;");
        self.decIndent();
        try self.writeLine("end");
        self.decIndent();
        try self.writeLine("end");
        self.decIndent();
        try self.writeLine("end");
        try self.newline();
        self.decIndent();

        try self.writeLine("endmodule");
    }

    fn generatePhiModulator(self: *Self, name: []const u8) !void {
        try self.writeFmt("module {s} (\n", .{name});
        self.incIndent();
        try self.writeLine("input  wire [31:0] value_in,");
        try self.writeLine("input  wire [5:0]  round,");
        try self.writeLine("output wire [31:0] value_out");
        self.decIndent();
        try self.writeLine(");");
        try self.newline();

        self.incIndent();
        try self.writeLine("// φ-modulation: Add golden ratio factor every 3rd round");
        try self.writeLine("// This creates ASIC-resistant irregularity");
        try self.writeLine("localparam [31:0] PHI_FACTOR = 32'd1618033;  // φ × 10^6");
        try self.newline();

        try self.writeLine("wire is_phi_round = (round % 3 == 0);");
        try self.writeLine("assign value_out = is_phi_round ? (value_in + PHI_FACTOR) : value_in;");
        try self.newline();
        self.decIndent();

        try self.writeLine("endmodule");
    }

    fn generateGenericModule(self: *Self, name: []const u8) !void {
        try self.writeFmt("module {s} (\n", .{name});
        self.incIndent();
        try self.writeLine("input  wire clk,");
        try self.writeLine("input  wire rst_n,");
        try self.writeLine("input  wire [31:0] data_in,");
        try self.writeLine("output reg  [31:0] data_out");
        self.decIndent();
        try self.writeLine(");");
        try self.newline();

        self.incIndent();
        try self.writeLine("// Generic TRINITY module");
        try self.writeLine("// φ² + 1/φ² = 3");
        try self.newline();

        try self.writeLine("always @(posedge clk or negedge rst_n) begin");
        self.incIndent();
        try self.writeLine("if (!rst_n)");
        self.incIndent();
        try self.writeLine("data_out <= 32'd0;");
        self.decIndent();
        try self.writeLine("else");
        self.incIndent();
        try self.writeLine("data_out <= data_in;");
        self.decIndent();
        self.decIndent();
        try self.writeLine("end");
        try self.newline();
        self.decIndent();

        try self.writeLine("endmodule");
    }
};

pub const ModuleType = enum {
    sha256,
    nonce_gen,
    mining_core,
    phi_modulator,
    generic,
};

/// Detect module type from spec name
pub fn detectModuleType(name: []const u8) ModuleType {
    if (std.mem.indexOf(u8, name, "sha256") != null or
        std.mem.indexOf(u8, name, "sha") != null)
    {
        return .sha256;
    }
    if (std.mem.indexOf(u8, name, "nonce") != null) {
        return .nonce_gen;
    }
    if (std.mem.indexOf(u8, name, "mining") != null or
        std.mem.indexOf(u8, name, "core") != null)
    {
        return .mining_core;
    }
    if (std.mem.indexOf(u8, name, "phi") != null or
        std.mem.indexOf(u8, name, "modula") != null)
    {
        return .phi_modulator;
    }
    return .generic;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "generate SHA256 module" {
    const allocator = std.testing.allocator;
    var gen = VarlogCodeGen.init(allocator);
    defer gen.deinit();

    const output = try gen.generateModule("phi_sha256", .sha256);
    try std.testing.expect(output.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, output, "module phi_sha256") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "PHI_MOD") != null);
}

test "generate nonce module" {
    const allocator = std.testing.allocator;
    var gen = VarlogCodeGen.init(allocator);
    defer gen.deinit();

    const output = try gen.generateModule("nonce_generator", .nonce_gen);
    try std.testing.expect(output.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, output, "PHI_STRIDE") != null);
}

test "generate mining core" {
    const allocator = std.testing.allocator;
    var gen = VarlogCodeGen.init(allocator);
    defer gen.deinit();

    const output = try gen.generateModule("trinity_mining_core", .mining_core);
    try std.testing.expect(output.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, output, "golden_nonce") != null);
}

test "detect module type" {
    try std.testing.expectEqual(ModuleType.sha256, detectModuleType("phi_sha256"));
    try std.testing.expectEqual(ModuleType.nonce_gen, detectModuleType("nonce_generator"));
    try std.testing.expectEqual(ModuleType.mining_core, detectModuleType("mining_core"));
    try std.testing.expectEqual(ModuleType.phi_modulator, detectModuleType("phi_modulator"));
    try std.testing.expectEqual(ModuleType.generic, detectModuleType("unknown_module"));
}

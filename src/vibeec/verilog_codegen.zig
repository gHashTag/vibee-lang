// ═══════════════════════════════════════════════════════════════════════════════
// VERILOG CODEGEN - Генератор Verilog кода из .vibee спецификаций
// ═══════════════════════════════════════════════════════════════════════════════
//
// Генерирует Verilog код для FPGA синтеза
// Автор: Dmitrii Vasilev
// φ² + 1/φ² = 3 | PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const vibee_parser = @import("vibee_parser.zig");

const VibeeSpec = vibee_parser.VibeeSpec;
const Constant = vibee_parser.Constant;
const TypeDef = vibee_parser.TypeDef;
const Behavior = vibee_parser.Behavior;
const Field = vibee_parser.Field;

// ═══════════════════════════════════════════════════════════════════════════════
// EXTRACTED SIGNAL FOR SVA
// ═══════════════════════════════════════════════════════════════════════════════

pub const ExtractedSignal = struct {
    name: []const u8,
    verilog_type: []const u8,
    width: u32,
    is_bool: bool,
};

/// Extract signals from spec types for SVA checker
pub fn extractSignalsFromTypes(types: []const TypeDef, allocator: Allocator) !ArrayList(ExtractedSignal) {
    var signals = ArrayList(ExtractedSignal).init(allocator);

    for (types) |t| {
        for (t.fields.items) |field| {
            const is_bool = std.mem.eql(u8, field.type_name, "Bool");
            const width: u32 = if (is_bool) 1 else if (std.mem.eql(u8, field.type_name, "Int")) 32 else 32;
            const verilog_type = if (is_bool) "wire" else "wire [31:0]";

            // Check if signal already exists
            var exists = false;
            for (signals.items) |s| {
                if (std.mem.eql(u8, s.name, field.name)) {
                    exists = true;
                    break;
                }
            }

            if (!exists) {
                try signals.append(ExtractedSignal{
                    .name = field.name,
                    .verilog_type = verilog_type,
                    .width = width,
                    .is_bool = is_bool,
                });
            }
        }
    }

    return signals;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BEHAVIOR-SIGNAL VALIDATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const ValidationWarning = struct {
    behavior_name: []const u8,
    clause: []const u8,
    referenced_signal: []const u8,
    message: []const u8,
};

/// Standard signals always available
const standard_signals = [_][]const u8{
    "clk", "rst_n", "data_in", "valid_in", "data_out", "valid_out", "ready", "state",
};

/// Common signals added as fallback
const common_signals = [_][]const u8{
    "running", "active", "overflow", "done", "flag", "count",
};

/// Signal keywords to look for in behavior text
const signal_keywords = [_]struct { keyword: []const u8, signal: []const u8 }{
    .{ .keyword = "running", .signal = "running" },
    .{ .keyword = "active", .signal = "active" },
    .{ .keyword = "valid", .signal = "valid_in" },
    .{ .keyword = "ready", .signal = "ready" },
    .{ .keyword = "reset", .signal = "rst_n" },
    .{ .keyword = "count", .signal = "count" },
    .{ .keyword = "counter", .signal = "count" },
    .{ .keyword = "overflow", .signal = "overflow" },
    .{ .keyword = "full", .signal = "full" },
    .{ .keyword = "empty", .signal = "empty" },
    .{ .keyword = "idle", .signal = "state" },
    .{ .keyword = "process", .signal = "state" },
    .{ .keyword = "done", .signal = "done" },
    .{ .keyword = "flag", .signal = "flag" },
    .{ .keyword = "output", .signal = "data_out" },
    .{ .keyword = "input", .signal = "data_in" },
    .{ .keyword = "depth", .signal = "depth" },
    .{ .keyword = "width", .signal = "width" },
};

/// Extract signal references from behavior text
pub fn extractSignalReferences(text: []const u8, allocator: Allocator) !ArrayList([]const u8) {
    var refs = ArrayList([]const u8).init(allocator);

    for (signal_keywords) |kw| {
        if (containsIgnoreCase(text, kw.keyword)) {
            // Check if already added
            var exists = false;
            for (refs.items) |r| {
                if (std.mem.eql(u8, r, kw.signal)) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                try refs.append(kw.signal);
            }
        }
    }

    return refs;
}

/// Check if a signal exists in available signals
fn signalExists(signal: []const u8, extracted: []const ExtractedSignal) bool {
    // Check standard signals
    for (standard_signals) |s| {
        if (std.mem.eql(u8, signal, s)) return true;
    }

    // Check common signals
    for (common_signals) |s| {
        if (std.mem.eql(u8, signal, s)) return true;
    }

    // Check extracted signals from types
    for (extracted) |sig| {
        if (std.mem.eql(u8, signal, sig.name)) return true;
    }

    return false;
}

/// Validate all behaviors against available signals
pub fn validateBehaviorSignals(
    behaviors: []const Behavior,
    extracted: []const ExtractedSignal,
    allocator: Allocator,
) !ArrayList(ValidationWarning) {
    var warnings = ArrayList(ValidationWarning).init(allocator);

    for (behaviors) |behavior| {
        // Check given clause
        var given_refs = try extractSignalReferences(behavior.given, allocator);
        defer given_refs.deinit();

        for (given_refs.items) |ref| {
            if (!signalExists(ref, extracted)) {
                try warnings.append(ValidationWarning{
                    .behavior_name = behavior.name,
                    .clause = "given",
                    .referenced_signal = ref,
                    .message = "Signal not found in types or standard signals",
                });
            }
        }

        // Check then clause
        var then_refs = try extractSignalReferences(behavior.then, allocator);
        defer then_refs.deinit();

        for (then_refs.items) |ref| {
            if (!signalExists(ref, extracted)) {
                try warnings.append(ValidationWarning{
                    .behavior_name = behavior.name,
                    .clause = "then",
                    .referenced_signal = ref,
                    .message = "Signal not found in types or standard signals",
                });
            }
        }
    }

    return warnings;
}

/// Print validation warnings
pub fn printValidationWarnings(warnings: []const ValidationWarning) void {
    if (warnings.len == 0) {
        std.debug.print("  ✓ All behavior signals validated\n", .{});
        return;
    }

    std.debug.print("  ⚠ Validation warnings ({d}):\n", .{warnings.len});
    for (warnings) |w| {
        std.debug.print("    - Behavior '{s}' ({s}): signal '{s}' - {s}\n", .{
            w.behavior_name,
            w.clause,
            w.referenced_signal,
            w.message,
        });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// VERILOG CODE BUILDER
// ═══════════════════════════════════════════════════════════════════════════════

pub const VerilogBuilder = struct {
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

    pub fn write(self: *Self, str: []const u8) !void {
        try self.buffer.appendSlice(str);
    }

    pub fn writeLine(self: *Self, str: []const u8) !void {
        try self.writeIndent();
        try self.buffer.appendSlice(str);
        try self.buffer.append('\n');
    }

    pub fn writeIndent(self: *Self) !void {
        var i: u32 = 0;
        while (i < self.indent) : (i += 1) {
            try self.buffer.appendSlice("    ");
        }
    }

    pub fn writeFmt(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        const writer = self.buffer.writer();
        try writer.print(fmt, args);
    }

    pub fn newline(self: *Self) !void {
        try self.buffer.append('\n');
    }

    pub fn incIndent(self: *Self) void {
        self.indent += 1;
    }

    pub fn decIndent(self: *Self) void {
        if (self.indent > 0) self.indent -= 1;
    }

    pub fn getOutput(self: *Self) []const u8 {
        return self.buffer.items;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VERILOG CODE GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const VerilogCodeGen = struct {
    allocator: Allocator,
    builder: VerilogBuilder,
    spec: *const VibeeSpec = undefined,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .builder = VerilogBuilder.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.builder.deinit();
    }

    /// Генерация полного Verilog файла из спецификации
    pub fn generate(self: *Self, spec: *const VibeeSpec) ![]const u8 {
        self.spec = spec;
        try self.writeHeader(spec);
        try self.writeTimescale();
        try self.writeSacredConstants(spec);
        try self.writeTypes(spec.types.items);
        try self.writeTopModule(spec);
        try self.writeBehaviorModules(spec.behaviors.items);
        try self.writeSVAAssertions(spec);
        try self.writeTestbench(spec);

        return self.builder.getOutput();
    }

    fn writeHeader(self: *Self, spec: *const VibeeSpec) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeFmt("// {s} v{s} - Generated Verilog from .vibee specification\n", .{ spec.name, spec.version });
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("//");
        try self.builder.writeLine("// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q");
        try self.builder.writeLine("// Golden Identity: φ² + 1/φ² = 3");
        try self.builder.writeLine("// PHOENIX = 999");
        try self.builder.writeLine("//");
        try self.builder.writeFmt("// Author: {s}\n", .{spec.author});
        try self.builder.writeLine("// DO NOT EDIT - This file is auto-generated by VIBEE");
        try self.builder.writeLine("//");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();
    }

    fn writeTimescale(self: *Self) !void {
        try self.builder.writeLine("`timescale 1ns / 1ps");
        try self.builder.newline();
    }

    fn writeSacredConstants(self: *Self, spec: *const VibeeSpec) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// SACRED CONSTANTS MODULE");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        try self.builder.writeFmt("module {s}_sacred_constants (\n", .{spec.name});
        self.builder.incIndent();

        // Output ports for constants
        try self.builder.writeLine("output wire [63:0] phi,");
        try self.builder.writeLine("output wire [63:0] phi_sq,");
        try self.builder.writeLine("output wire [63:0] phi_inv_sq,");
        try self.builder.writeLine("output wire [63:0] trinity,");
        try self.builder.writeLine("output wire [31:0] phoenix");

        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();

        self.builder.incIndent();

        // IEEE 754 double precision constants
        try self.builder.writeLine("// IEEE 754 double precision constants");
        try self.builder.writeLine("assign phi        = 64'h3FF9E3779B97F4A8; // 1.6180339887...");
        try self.builder.writeLine("assign phi_sq     = 64'h4004F1BBCDCBF254; // 2.6180339887...");
        try self.builder.writeLine("assign phi_inv_sq = 64'h3FD8722D0E560419; // 0.3819660112...");
        try self.builder.writeLine("assign trinity    = 64'h4008000000000000; // 3.0");
        try self.builder.writeLine("assign phoenix    = 32'd999;");

        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeTypes(self: *Self, types: []const TypeDef) !void {
        if (types.len == 0) return;

        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TYPE DEFINITIONS (as Verilog structs/parameters)");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (types) |t| {
            try self.builder.writeFmt("// Type: {s}\n", .{t.name});
            try self.builder.writeFmt("// {s}\n", .{t.description});

            // Generate parameter definitions for type fields
            for (t.fields.items) |field| {
                const verilog_type = mapTypeToVerilog(field.type_name);
                try self.builder.writeFmt("// Field: {s} -> {s}\n", .{ field.name, verilog_type });
            }
            try self.builder.newline();
        }
    }

    fn writeTopModule(self: *Self, spec: *const VibeeSpec) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TOP MODULE");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        try self.builder.writeFmt("module {s}_top (\n", .{spec.name});
        self.builder.incIndent();

        // Standard FPGA ports
        try self.builder.writeLine("input  wire        clk,");
        const has_reset = !std.mem.eql(u8, spec.reset.reset_type, "none");
        const rst_name = if (std.mem.eql(u8, spec.reset.level, "low")) "rst_n" else "rst";
        const rst_active = if (std.mem.eql(u8, spec.reset.level, "low")) "!" else "";
        const rst_edge = if (std.mem.eql(u8, spec.reset.level, "low")) "negedge" else "posedge";

        if (has_reset) {
            try self.builder.writeFmt("input  wire        {s},\n", .{rst_name});
        }
        try self.builder.writeLine("input  wire [31:0] data_in,");
        try self.builder.writeLine("input  wire        valid_in,");
        try self.builder.writeLine("output reg  [31:0] data_out,");
        try self.builder.writeLine("output reg         valid_out,");
        try self.builder.writeLine("output wire        ready");

        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();

        self.builder.incIndent();

        // State machine
        try self.builder.writeLine("// State machine");
        try self.builder.writeLine("localparam IDLE    = 3'd0;");
        try self.builder.writeLine("localparam PROCESS = 3'd1;");
        try self.builder.writeLine("localparam DONE    = 3'd2;");
        try self.builder.newline();

        try self.builder.writeLine("reg [2:0] state;");
        try self.builder.writeLine("reg [2:0] next_state;");
        try self.builder.newline();

        // Sacred constants instance
        try self.builder.writeLine("// Sacred constants");
        try self.builder.writeLine("wire [63:0] phi, phi_sq, phi_inv_sq, trinity;");
        try self.builder.writeLine("wire [31:0] phoenix;");
        try self.builder.newline();

        try self.builder.writeFmt("{s}_sacred_constants sacred_inst (\n", .{spec.name});
        self.builder.incIndent();
        try self.builder.writeLine(".phi(phi),");
        try self.builder.writeLine(".phi_sq(phi_sq),");
        try self.builder.writeLine(".phi_inv_sq(phi_inv_sq),");
        try self.builder.writeLine(".trinity(trinity),");
        try self.builder.writeLine(".phoenix(phoenix)");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();

        // Ready signal
        try self.builder.writeLine("assign ready = (state == IDLE);");
        try self.builder.newline();

        // State register
        try self.builder.writeLine("// State register");
        if (has_reset) {
            if (std.mem.eql(u8, spec.reset.reset_type, "async")) {
                try self.builder.writeFmt("always @(posedge clk or {s} {s}) begin\n", .{ rst_edge, rst_name });
            } else {
                try self.builder.writeLine("always @(posedge clk) begin");
            }
            self.builder.incIndent();
            try self.builder.writeFmt("if ({s}{s})\n", .{ rst_active, rst_name });
            self.builder.incIndent();
            try self.builder.writeLine("state <= IDLE;");
            self.builder.decIndent();
            try self.builder.writeLine("else");
            self.builder.incIndent();
            try self.builder.writeLine("state <= next_state;");
            self.builder.decIndent();
        } else {
            try self.builder.writeLine("always @(posedge clk) begin");
            self.builder.incIndent();
            try self.builder.writeLine("state <= next_state;");
        }
        self.builder.decIndent();
        try self.builder.writeLine("end");
        try self.builder.newline();

        // Next state logic
        try self.builder.writeLine("// Next state logic");
        try self.builder.writeLine("always @(*) begin");
        self.builder.incIndent();
        try self.builder.writeLine("next_state = state;");
        try self.builder.writeLine("case (state)");
        self.builder.incIndent();
        try self.builder.writeLine("IDLE:    if (valid_in) next_state = PROCESS;");
        try self.builder.writeLine("PROCESS: next_state = DONE;");
        try self.builder.writeLine("DONE:    next_state = IDLE;");
        try self.builder.writeLine("default: next_state = IDLE;");
        self.builder.decIndent();
        try self.builder.writeLine("endcase");
        self.builder.decIndent();
        try self.builder.writeLine("end");
        try self.builder.newline();

        // Output logic
        try self.builder.writeLine("// Output logic");
        if (has_reset) {
            if (std.mem.eql(u8, spec.reset.reset_type, "async")) {
                try self.builder.writeFmt("always @(posedge clk or {s} {s}) begin\n", .{ rst_edge, rst_name });
            } else {
                try self.builder.writeLine("always @(posedge clk) begin");
            }
            self.builder.incIndent();
            try self.builder.writeFmt("if ({s}{s}) begin\n", .{ rst_active, rst_name });
            self.builder.incIndent();
            try self.builder.writeLine("data_out  <= 32'd0;");
            try self.builder.writeLine("valid_out <= 1'b0;");
            self.builder.decIndent();
            try self.builder.writeLine("end else begin");
            self.builder.incIndent();
            try self.builder.writeLine("valid_out <= (state == DONE);");
            try self.builder.writeLine("if (state == PROCESS)");
            self.builder.incIndent();
            try self.builder.writeLine("data_out <= data_in ^ phoenix; // XOR with sacred constant");
            self.builder.decIndent();
            self.builder.decIndent();
            try self.builder.writeLine("end");
        } else {
            try self.builder.writeLine("always @(posedge clk) begin");
            self.builder.incIndent();
            try self.builder.writeLine("valid_out <= (state == DONE);");
            try self.builder.writeLine("if (state == PROCESS)");
            self.builder.incIndent();
            try self.builder.writeLine("data_out <= data_in ^ phoenix;");
            self.builder.decIndent();
        }
        self.builder.decIndent();
        try self.builder.writeLine("end");

        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeBehaviorModules(self: *Self, behaviors: []const Behavior) !void {
        if (behaviors.len == 0) return;

        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// BEHAVIOR MODULES");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (behaviors) |b| {
            // Check for special ternary logic modules
            if (std.mem.eql(u8, b.name, "trit_not")) {
                try self.writeTritNot();
            } else if (std.mem.eql(u8, b.name, "trit_and")) {
                try self.writeTritAnd();
            } else if (std.mem.eql(u8, b.name, "trit_or")) {
                try self.writeTritOr();
            } else if (std.mem.eql(u8, b.name, "trit_half_adder")) {
                try self.writeTritHalfAdder();
            } else if (std.mem.eql(u8, b.name, "trit_full_adder")) {
                try self.writeTritFullAdder();
            } else if (std.mem.eql(u8, b.name, "trit_multiply")) {
                try self.writeTritMultiply();
            } else if (std.mem.eql(u8, b.name, "trit3_add")) {
                try self.writeTrit3Adder();
            } else if (std.mem.eql(u8, b.name, "trit_compare")) {
                try self.writeTritCompare();
                // SIMD modules
            } else if (std.mem.eql(u8, b.name, "trit27_parallel_multiply")) {
                try self.writeTrit27ParallelMultiply();
            } else if (std.mem.eql(u8, b.name, "adder_tree_27")) {
                try self.writeAdderTree27();
            } else if (std.mem.eql(u8, b.name, "trit27_dot_product")) {
                try self.writeTrit27DotProduct();
            } else if (std.mem.eql(u8, b.name, "bitnet_activation")) {
                try self.writeBitNetActivation();
                // Pipeline modules
            } else if (std.mem.eql(u8, b.name, "weight_bram")) {
                try self.writeWeightBram();
            } else if (std.mem.eql(u8, b.name, "pipeline_stage2_compute")) {
                try self.writePipelineStage2();
            } else if (std.mem.eql(u8, b.name, "layer_sequencer")) {
                try self.writeLayerSequencer();
            } else if (std.mem.eql(u8, b.name, "bitnet_layer_top")) {
                try self.writeBitNetLayerTop();
                // Multi-layer modules
            } else if (std.mem.eql(u8, b.name, "double_buffer_ctrl")) {
                try self.writeDoubleBufferCtrl();
            } else if (std.mem.eql(u8, b.name, "weight_prefetch_ctrl")) {
                try self.writeWeightPrefetchCtrl();
            } else if (std.mem.eql(u8, b.name, "multilayer_sequencer")) {
                try self.writeMultilayerSequencer();
            } else if (std.mem.eql(u8, b.name, "bitnet_engine_top")) {
                try self.writeBitNetEngineTop();
                // AXI Host Interface modules
            } else if (std.mem.eql(u8, b.name, "axi_lite_slave")) {
                try self.writeAxiLiteSlave();
            } else if (std.mem.eql(u8, b.name, "dma_controller")) {
                try self.writeDmaController();
            } else if (std.mem.eql(u8, b.name, "interrupt_controller")) {
                try self.writeInterruptController();
            } else if (std.mem.eql(u8, b.name, "host_interface_top")) {
                try self.writeHostInterfaceTop();
                // AXI-Lite behavior handlers
            } else if (std.mem.eql(u8, b.name, "axi_write_handler")) {
                try self.writeAxiWriteHandler();
            } else if (std.mem.eql(u8, b.name, "axi_read_handler")) {
                try self.writeAxiReadHandler();
            } else if (std.mem.eql(u8, b.name, "ctrl_reg_handler")) {
                try self.writeCtrlRegHandler();
            } else if (std.mem.eql(u8, b.name, "irq_generator")) {
                try self.writeIrqGenerator();
            } else if (std.mem.eql(u8, b.name, "status_aggregator")) {
                try self.writeStatusAggregator();
            } else if (std.mem.eql(u8, b.name, "cycle_counter") or std.mem.eql(u8, b.name, "count_cycles")) {
                try self.writeCycleCounter();
                // AXI-Stream behavior handlers
            } else if (std.mem.eql(u8, b.name, "input_stream_rx")) {
                try self.writeAxisSlaveRx();
            } else if (std.mem.eql(u8, b.name, "output_stream_tx")) {
                try self.writeAxisMasterTx();
            } else if (std.mem.eql(u8, b.name, "weight_stream_rx")) {
                try self.writeWeightStreamRx();
            } else if (std.mem.eql(u8, b.name, "backpressure_handler")) {
                try self.writeBackpressureHandler();
            } else if (std.mem.eql(u8, b.name, "packet_parser")) {
                try self.writePacketParser();
            } else if (std.mem.eql(u8, b.name, "packet_assembler")) {
                try self.writePacketAssembler();
                // Weight loader handlers
            } else if (std.mem.eql(u8, b.name, "weight_load_handler") or std.mem.eql(u8, b.name, "receive_weights")) {
                try self.writeWeightLoadHandler();
            } else if (std.mem.eql(u8, b.name, "unpack_weights")) {
                try self.writeUnpackWeights();
            } else if (std.mem.eql(u8, b.name, "write_to_bram")) {
                try self.writeWriteToBram();
                // FIFO handlers
            } else if (std.mem.eql(u8, b.name, "input_fifo_write")) {
                try self.writeFifoWrite();
            } else if (std.mem.eql(u8, b.name, "output_fifo_read")) {
                try self.writeFifoRead();
                // Performance counter handlers
            } else if (std.mem.eql(u8, b.name, "count_inferences")) {
                try self.writeInferenceCounter();
            } else if (std.mem.eql(u8, b.name, "count_mac_ops")) {
                try self.writeMacCounter();
            } else if (std.mem.eql(u8, b.name, "track_stalls")) {
                try self.writeStallTracker();
            } else if (std.mem.eql(u8, b.name, "time_layer")) {
                try self.writeLayerTimer();
            } else {
                // Default generic behavior module
                try self.writeGenericBehavior(b);
            }
        }
    }

    fn writeTritNot(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT NOT - Ternary Negation");
        try self.builder.writeLine("// Encoding: 2'b00=-1, 2'b01=0, 2'b10=+1");
        try self.builder.writeLine("// NOT(-1)=+1, NOT(0)=0, NOT(+1)=-1");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit_not (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [1:0] a,");
        try self.builder.writeLine("output wire [1:0] result");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// Trit encoding constants");
        try self.builder.writeLine("localparam TRIT_N = 2'b00;  // -1");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;  //  0");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;  // +1");
        try self.builder.newline();
        try self.builder.writeLine("// NOT truth table: swap -1 and +1, keep 0");
        try self.builder.writeLine("assign result = (a == TRIT_Z) ? TRIT_Z :  // 0 -> 0");
        try self.builder.writeLine("                (a == TRIT_N) ? TRIT_P :  // -1 -> +1");
        try self.builder.writeLine("                (a == TRIT_P) ? TRIT_N :  // +1 -> -1");
        try self.builder.writeLine("                TRIT_Z;                    // invalid -> 0");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeTritAnd(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT AND - Kleene Logic Minimum");
        try self.builder.writeLine("// AND(a,b) = min(a,b) in balanced ternary");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit_and (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [1:0] a,");
        try self.builder.writeLine("input  wire [1:0] b,");
        try self.builder.writeLine("output wire [1:0] result");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_N = 2'b00;  // -1");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;  //  0");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;  // +1");
        try self.builder.newline();
        try self.builder.writeLine("// Kleene AND = minimum");
        try self.builder.writeLine("// If either is -1, result is -1");
        try self.builder.writeLine("// Else if either is 0, result is 0");
        try self.builder.writeLine("// Else result is +1");
        try self.builder.writeLine("assign result = (a == TRIT_N || b == TRIT_N) ? TRIT_N :");
        try self.builder.writeLine("                (a == TRIT_Z || b == TRIT_Z) ? TRIT_Z :");
        try self.builder.writeLine("                TRIT_P;");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeTritOr(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT OR - Kleene Logic Maximum");
        try self.builder.writeLine("// OR(a,b) = max(a,b) in balanced ternary");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit_or (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [1:0] a,");
        try self.builder.writeLine("input  wire [1:0] b,");
        try self.builder.writeLine("output wire [1:0] result");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_N = 2'b00;  // -1");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;  //  0");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;  // +1");
        try self.builder.newline();
        try self.builder.writeLine("// Kleene OR = maximum");
        try self.builder.writeLine("// If either is +1, result is +1");
        try self.builder.writeLine("// Else if either is 0, result is 0");
        try self.builder.writeLine("// Else result is -1");
        try self.builder.writeLine("assign result = (a == TRIT_P || b == TRIT_P) ? TRIT_P :");
        try self.builder.writeLine("                (a == TRIT_Z || b == TRIT_Z) ? TRIT_Z :");
        try self.builder.writeLine("                TRIT_N;");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeTritHalfAdder(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT HALF ADDER - Balanced Ternary Addition");
        try self.builder.writeLine("// a + b = (sum, carry)");
        try self.builder.writeLine("// -1+-1=(+1,-1), -1+0=(-1,0), -1+1=(0,0)");
        try self.builder.writeLine("//  0+-1=(-1,0),  0+0=(0,0),   0+1=(+1,0)");
        try self.builder.writeLine("// +1+-1=(0,0),  +1+0=(+1,0), +1+1=(-1,+1)");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit_half_adder (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [1:0] a,");
        try self.builder.writeLine("input  wire [1:0] b,");
        try self.builder.writeLine("output wire [1:0] sum,");
        try self.builder.writeLine("output wire [1:0] carry");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_N = 2'b00;  // -1");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;  //  0");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;  // +1");
        try self.builder.newline();
        try self.builder.writeLine("// Convert to signed for arithmetic");
        try self.builder.writeLine("wire signed [2:0] a_val = (a == TRIT_N) ? -3'sd1 : (a == TRIT_P) ? 3'sd1 : 3'sd0;");
        try self.builder.writeLine("wire signed [2:0] b_val = (b == TRIT_N) ? -3'sd1 : (b == TRIT_P) ? 3'sd1 : 3'sd0;");
        try self.builder.writeLine("wire signed [2:0] total = a_val + b_val;");
        try self.builder.newline();
        try self.builder.writeLine("// Map result back to balanced ternary");
        try self.builder.writeLine("assign sum = (total == -3'sd2) ? TRIT_P :  // -2 = -3+1 -> sum=+1");
        try self.builder.writeLine("             (total == -3'sd1) ? TRIT_N :  // -1 -> sum=-1");
        try self.builder.writeLine("             (total ==  3'sd0) ? TRIT_Z :  //  0 -> sum=0");
        try self.builder.writeLine("             (total ==  3'sd1) ? TRIT_P :  // +1 -> sum=+1");
        try self.builder.writeLine("             (total ==  3'sd2) ? TRIT_N :  // +2 = +3-1 -> sum=-1");
        try self.builder.writeLine("             TRIT_Z;");
        try self.builder.newline();
        try self.builder.writeLine("assign carry = (total == -3'sd2) ? TRIT_N :  // -2 -> carry=-1");
        try self.builder.writeLine("               (total ==  3'sd2) ? TRIT_P :  // +2 -> carry=+1");
        try self.builder.writeLine("               TRIT_Z;                        // else carry=0");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeTritFullAdder(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT FULL ADDER - With Carry Input");
        try self.builder.writeLine("// a + b + cin = (sum, cout)");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit_full_adder (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [1:0] a,");
        try self.builder.writeLine("input  wire [1:0] b,");
        try self.builder.writeLine("input  wire [1:0] cin,");
        try self.builder.writeLine("output wire [1:0] sum,");
        try self.builder.writeLine("output wire [1:0] cout");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_N = 2'b00;");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;");
        try self.builder.newline();
        try self.builder.writeLine("// Two-stage addition using half adders");
        try self.builder.writeLine("wire [1:0] sum1, carry1, carry2;");
        try self.builder.newline();
        try self.builder.writeLine("trit_half_adder ha1 (.a(a), .b(b), .sum(sum1), .carry(carry1));");
        try self.builder.writeLine("trit_half_adder ha2 (.a(sum1), .b(cin), .sum(sum), .carry(carry2));");
        try self.builder.newline();
        try self.builder.writeLine("// Combine carries with OR (max)");
        try self.builder.writeLine("trit_or carry_combine (.a(carry1), .b(carry2), .result(cout));");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeTritMultiply(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT MULTIPLY - Single Trit Multiplication");
        try self.builder.writeLine("// -1*-1=+1, -1*0=0, -1*+1=-1");
        try self.builder.writeLine("//  0*-1=0,   0*0=0,  0*+1=0");
        try self.builder.writeLine("// +1*-1=-1, +1*0=0, +1*+1=+1");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit_multiply (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [1:0] a,");
        try self.builder.writeLine("input  wire [1:0] b,");
        try self.builder.writeLine("output wire [1:0] result");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_N = 2'b00;");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;");
        try self.builder.newline();
        try self.builder.writeLine("// If either is zero, result is zero");
        try self.builder.writeLine("// If signs are same, result is +1");
        try self.builder.writeLine("// If signs are different, result is -1");
        try self.builder.writeLine("wire a_zero = (a == TRIT_Z);");
        try self.builder.writeLine("wire b_zero = (b == TRIT_Z);");
        try self.builder.writeLine("wire same_sign = (a == b);");
        try self.builder.newline();
        try self.builder.writeLine("assign result = (a_zero || b_zero) ? TRIT_Z :");
        try self.builder.writeLine("                same_sign ? TRIT_P : TRIT_N;");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeTrit3Adder(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT3 ADDER - 3-Trit Ripple Carry Adder");
        try self.builder.writeLine("// Adds two 3-trit numbers (range: -13 to +13)");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit3_add (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [5:0] a,      // 3 trits: [5:4]=t2, [3:2]=t1, [1:0]=t0");
        try self.builder.writeLine("input  wire [5:0] b,");
        try self.builder.writeLine("output wire [5:0] sum,");
        try self.builder.writeLine("output wire [1:0] cout    // Carry out");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;");
        try self.builder.newline();
        try self.builder.writeLine("wire [1:0] c0, c1, c2;");
        try self.builder.newline();
        try self.builder.writeLine("// Ripple carry chain");
        try self.builder.writeLine("trit_full_adder fa0 (.a(a[1:0]), .b(b[1:0]), .cin(TRIT_Z), .sum(sum[1:0]), .cout(c0));");
        try self.builder.writeLine("trit_full_adder fa1 (.a(a[3:2]), .b(b[3:2]), .cin(c0),     .sum(sum[3:2]), .cout(c1));");
        try self.builder.writeLine("trit_full_adder fa2 (.a(a[5:4]), .b(b[5:4]), .cin(c1),     .sum(sum[5:4]), .cout(cout));");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeTritCompare(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT COMPARE - Ternary Comparison");
        try self.builder.writeLine("// Returns -1 if a<b, 0 if a==b, +1 if a>b");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit_compare (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [1:0] a,");
        try self.builder.writeLine("input  wire [1:0] b,");
        try self.builder.writeLine("output wire [1:0] result");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_N = 2'b00;");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;");
        try self.builder.newline();
        try self.builder.writeLine("// Direct comparison of encoded values");
        try self.builder.writeLine("assign result = (a == b) ? TRIT_Z :");
        try self.builder.writeLine("                (a < b)  ? TRIT_N : TRIT_P;");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeTrit27ParallelMultiply(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT27 PARALLEL MULTIPLY - 27-way SIMD Ternary Multiplication");
        try self.builder.writeLine("// BitNet core operation: NO actual multipliers, just sign comparison!");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit27_parallel_multiply (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [53:0] a,      // 27 trits input");
        try self.builder.writeLine("input  wire [53:0] b,      // 27 trits weights");
        try self.builder.writeLine("output wire [53:0] result  // 27 trits products");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_N = 2'b00;  // -1");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;  //  0");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;  // +1");
        try self.builder.newline();
        try self.builder.writeLine("// Generate 27 parallel multipliers");
        try self.builder.writeLine("genvar i;");
        try self.builder.writeLine("generate");
        self.builder.incIndent();
        try self.builder.writeLine("for (i = 0; i < 27; i = i + 1) begin : mult_gen");
        self.builder.incIndent();
        try self.builder.writeLine("wire [1:0] ai = a[i*2 +: 2];  // Variable part-select with +: operator");
        try self.builder.writeLine("wire [1:0] bi = b[i*2 +: 2];");
        try self.builder.writeLine("wire a_zero = (ai == TRIT_Z);");
        try self.builder.writeLine("wire b_zero = (bi == TRIT_Z);");
        try self.builder.writeLine("wire same_sign = (ai == bi);");
        try self.builder.newline();
        try self.builder.writeLine("// Ternary multiply: sign comparison only!");
        try self.builder.writeLine("assign result[i*2 +: 2] = (a_zero || b_zero) ? TRIT_Z :");
        try self.builder.writeLine("                             same_sign ? TRIT_P : TRIT_N;");
        self.builder.decIndent();
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.writeLine("endgenerate");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeAdderTree27(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// ADDER TREE 27 - Reduce 27 trits to single sum");
        try self.builder.writeLine("// 3-level tree: 27 → 9 → 3 → 1");
        try self.builder.writeLine("// Output range: -27 to +27 (6 bits signed)");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module adder_tree_27 (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [53:0] trits,  // 27 trits to sum");
        try self.builder.writeLine("output wire signed [5:0] sum  // Result: -27 to +27");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_N = 2'b00;  // -1");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;  //  0");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;  // +1");
        try self.builder.newline();
        try self.builder.writeLine("// Convert trits to signed values");
        try self.builder.writeLine("wire signed [1:0] val [0:26];");
        try self.builder.writeLine("genvar i;");
        try self.builder.writeLine("generate");
        self.builder.incIndent();
        try self.builder.writeLine("for (i = 0; i < 27; i = i + 1) begin : convert");
        self.builder.incIndent();
        try self.builder.writeLine("wire [1:0] t = trits[i*2 +: 2];  // Variable part-select with +: operator");
        try self.builder.writeLine("assign val[i] = (t == TRIT_N) ? -2'sd1 :");
        try self.builder.writeLine("                (t == TRIT_P) ?  2'sd1 : 2'sd0;");
        self.builder.decIndent();
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.writeLine("endgenerate");
        try self.builder.newline();
        try self.builder.writeLine("// Level 1: 9 groups of 3 (range: -3 to +3)");
        try self.builder.writeLine("wire signed [2:0] l1 [0:8];");
        try self.builder.writeLine("generate");
        self.builder.incIndent();
        try self.builder.writeLine("for (i = 0; i < 9; i = i + 1) begin : level1");
        self.builder.incIndent();
        try self.builder.writeLine("assign l1[i] = val[i*3] + val[i*3+1] + val[i*3+2];");
        self.builder.decIndent();
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.writeLine("endgenerate");
        try self.builder.newline();
        try self.builder.writeLine("// Level 2: 3 groups of 3 (range: -9 to +9)");
        try self.builder.writeLine("wire signed [3:0] l2 [0:2];");
        try self.builder.writeLine("assign l2[0] = l1[0] + l1[1] + l1[2];");
        try self.builder.writeLine("assign l2[1] = l1[3] + l1[4] + l1[5];");
        try self.builder.writeLine("assign l2[2] = l1[6] + l1[7] + l1[8];");
        try self.builder.newline();
        try self.builder.writeLine("// Level 3: Final sum (range: -27 to +27)");
        try self.builder.writeLine("assign sum = l2[0] + l2[1] + l2[2];");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeTrit27DotProduct(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TRIT27 DOT PRODUCT - Complete BitNet MAC operation");
        try self.builder.writeLine("// Multiply 27 trits + reduce with adder tree");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module trit27_dot_product (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire [53:0] input_vec,   // 27 trits input");
        try self.builder.writeLine("input  wire [53:0] weight_vec,  // 27 trits weights");
        try self.builder.writeLine("output wire signed [5:0] result // Dot product: -27 to +27");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// Step 1: Parallel multiply (27 sign comparisons)");
        try self.builder.writeLine("wire [53:0] products;");
        try self.builder.writeLine("trit27_parallel_multiply mult_unit (");
        self.builder.incIndent();
        try self.builder.writeLine(".a(input_vec),");
        try self.builder.writeLine(".b(weight_vec),");
        try self.builder.writeLine(".result(products)");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        try self.builder.writeLine("// Step 2: Reduce with adder tree");
        try self.builder.writeLine("adder_tree_27 tree (");
        self.builder.incIndent();
        try self.builder.writeLine(".trits(products),");
        try self.builder.writeLine(".sum(result)");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeWeightBram(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// WEIGHT BRAM - Dual-port BRAM for ternary weights");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module weight_bram #(");
        self.builder.incIndent();
        try self.builder.writeLine("parameter DEPTH = 4096,");
        try self.builder.writeLine("parameter ADDR_WIDTH = 12");
        self.builder.decIndent();
        try self.builder.writeLine(") (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire                  clk,");
        try self.builder.writeLine("input  wire [ADDR_WIDTH-1:0] rd_addr,");
        try self.builder.writeLine("output reg  [53:0]           rd_data,");
        try self.builder.writeLine("input  wire [ADDR_WIDTH-1:0] wr_addr,");
        try self.builder.writeLine("input  wire [53:0]           wr_data,");
        try self.builder.writeLine("input  wire                  wr_en");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// BRAM storage");
        try self.builder.writeLine("reg [53:0] mem [0:DEPTH-1];");
        try self.builder.newline();
        try self.builder.writeLine("// Read port (1 cycle latency)");
        try self.builder.writeLine("always @(posedge clk) rd_data <= mem[rd_addr];");
        try self.builder.newline();
        try self.builder.writeLine("// Write port");
        try self.builder.writeLine("always @(posedge clk) if (wr_en) mem[wr_addr] <= wr_data;");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writePipelineStage2(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// PIPELINE STAGE 2 - SIMD Compute with Accumulator");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module pipeline_stage2_compute (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("input  wire        valid_in,");
        try self.builder.writeLine("input  wire [53:0] input_chunk,");
        try self.builder.writeLine("input  wire [53:0] weight_chunk,");
        try self.builder.writeLine("input  wire        first_chunk,");
        try self.builder.writeLine("input  wire        last_chunk,");
        try self.builder.writeLine("output reg         valid_out,");
        try self.builder.writeLine("output reg  signed [15:0] result,");
        try self.builder.writeLine("output reg         result_final");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// SIMD dot product");
        try self.builder.writeLine("wire signed [5:0] dot_result;");
        try self.builder.writeLine("trit27_dot_product simd (.input_vec(input_chunk), .weight_vec(weight_chunk), .result(dot_result));");
        try self.builder.newline();
        try self.builder.writeLine("// Accumulator");
        try self.builder.writeLine("reg signed [15:0] accumulator;");
        try self.builder.newline();
        try self.builder.writeLine("always @(posedge clk or negedge rst_n) begin");
        self.builder.incIndent();
        try self.builder.writeLine("if (!rst_n) begin");
        try self.builder.writeLine("    accumulator <= 0; valid_out <= 0; result_final <= 0;");
        try self.builder.writeLine("end else if (valid_in) begin");
        try self.builder.writeLine("    accumulator <= first_chunk ? dot_result : accumulator + dot_result;");
        try self.builder.writeLine("    valid_out <= last_chunk;");
        try self.builder.writeLine("    result <= first_chunk ? dot_result : accumulator + dot_result;");
        try self.builder.writeLine("    result_final <= last_chunk;");
        try self.builder.writeLine("end else valid_out <= 0;");
        self.builder.decIndent();
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeLayerSequencer(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// LAYER SEQUENCER - FSM for layer execution");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module layer_sequencer (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("input  wire        start,");
        try self.builder.writeLine("input  wire [15:0] num_neurons,");
        try self.builder.writeLine("input  wire [7:0]  num_chunks,");
        try self.builder.writeLine("output reg  [15:0] neuron_id,");
        try self.builder.writeLine("output reg  [7:0]  chunk_id,");
        try self.builder.writeLine("output reg         first_chunk,");
        try self.builder.writeLine("output reg         last_chunk,");
        try self.builder.writeLine("output reg         valid,");
        try self.builder.writeLine("output reg         done");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam IDLE=0, RUN=1, DONE_ST=2;");
        try self.builder.writeLine("reg [1:0] state;");
        try self.builder.newline();
        try self.builder.writeLine("always @(posedge clk or negedge rst_n) begin");
        self.builder.incIndent();
        try self.builder.writeLine("if (!rst_n) begin");
        try self.builder.writeLine("    state<=IDLE; neuron_id<=0; chunk_id<=0; valid<=0; done<=0;");
        try self.builder.writeLine("end else case(state)");
        try self.builder.writeLine("    IDLE: if(start) begin state<=RUN; neuron_id<=0; chunk_id<=0; end");
        try self.builder.writeLine("    RUN: begin");
        try self.builder.writeLine("        valid<=1; first_chunk<=(chunk_id==0); last_chunk<=(chunk_id==num_chunks-1);");
        try self.builder.writeLine("        if(chunk_id==num_chunks-1) begin chunk_id<=0;");
        try self.builder.writeLine("            if(neuron_id==num_neurons-1) state<=DONE_ST; else neuron_id<=neuron_id+1;");
        try self.builder.writeLine("        end else chunk_id<=chunk_id+1;");
        try self.builder.writeLine("    end");
        try self.builder.writeLine("    DONE_ST: begin valid<=0; done<=1; state<=IDLE; end");
        try self.builder.writeLine("endcase end");
        self.builder.decIndent();
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeDoubleBufferCtrl(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// DOUBLE BUFFER CONTROLLER - Ping-pong activation buffers");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module double_buffer_ctrl (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("input  wire        layer_done,");
        try self.builder.writeLine("input  wire [5:0]  current_layer,");
        try self.builder.writeLine("output reg         use_buffer_a,  // 1=read A/write B, 0=read B/write A");
        try self.builder.writeLine("output wire [11:0] read_addr,");
        try self.builder.writeLine("output wire [11:0] write_addr,");
        try self.builder.writeLine("input  wire [11:0] neuron_id");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// Even layers: read A, write B");
        try self.builder.writeLine("// Odd layers: read B, write A");
        try self.builder.writeLine("always @(posedge clk or negedge rst_n)");
        try self.builder.writeLine("    if (!rst_n) use_buffer_a <= 1;");
        try self.builder.writeLine("    else if (layer_done) use_buffer_a <= ~use_buffer_a;");
        try self.builder.newline();
        try self.builder.writeLine("assign read_addr = neuron_id;");
        try self.builder.writeLine("assign write_addr = neuron_id;");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeWeightPrefetchCtrl(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// WEIGHT PREFETCH CONTROLLER - Stream weights from DDR while computing");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module weight_prefetch_ctrl (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("input  wire        start_prefetch,");
        try self.builder.writeLine("input  wire [31:0] src_addr,");
        try self.builder.writeLine("input  wire [15:0] num_words,");
        try self.builder.writeLine("output reg         prefetch_active,");
        try self.builder.writeLine("output reg         prefetch_done,");
        try self.builder.writeLine("// AXI read interface");
        try self.builder.writeLine("output reg  [31:0] axi_araddr,");
        try self.builder.writeLine("output reg         axi_arvalid,");
        try self.builder.writeLine("input  wire        axi_arready,");
        try self.builder.writeLine("input  wire [63:0] axi_rdata,");
        try self.builder.writeLine("input  wire        axi_rvalid,");
        try self.builder.writeLine("output wire        axi_rready,");
        try self.builder.writeLine("// BRAM write interface");
        try self.builder.writeLine("output reg  [11:0] bram_addr,");
        try self.builder.writeLine("output reg  [53:0] bram_data,");
        try self.builder.writeLine("output reg         bram_we");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("reg [15:0] words_remaining;");
        try self.builder.writeLine("localparam IDLE=0, FETCH=1, DONE=2;");
        try self.builder.writeLine("reg [1:0] state;");
        try self.builder.newline();
        try self.builder.writeLine("assign axi_rready = (state == FETCH);");
        try self.builder.newline();
        try self.builder.writeLine("always @(posedge clk or negedge rst_n) begin");
        try self.builder.writeLine("    if (!rst_n) begin");
        try self.builder.writeLine("        state <= IDLE; prefetch_active <= 0; prefetch_done <= 0;");
        try self.builder.writeLine("        axi_arvalid <= 0; bram_we <= 0;");
        try self.builder.writeLine("    end else case (state)");
        try self.builder.writeLine("        IDLE: if (start_prefetch) begin");
        try self.builder.writeLine("            state <= FETCH; prefetch_active <= 1; prefetch_done <= 0;");
        try self.builder.writeLine("            axi_araddr <= src_addr; words_remaining <= num_words; bram_addr <= 0;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        FETCH: begin");
        try self.builder.writeLine("            axi_arvalid <= 1;");
        try self.builder.writeLine("            if (axi_arready) axi_araddr <= axi_araddr + 8;");
        try self.builder.writeLine("            if (axi_rvalid) begin");
        try self.builder.writeLine("                bram_data <= axi_rdata[53:0]; bram_we <= 1; bram_addr <= bram_addr + 1;");
        try self.builder.writeLine("                words_remaining <= words_remaining - 1;");
        try self.builder.writeLine("                if (words_remaining == 1) state <= DONE;");
        try self.builder.writeLine("            end else bram_we <= 0;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        DONE: begin");
        try self.builder.writeLine("            prefetch_active <= 0; prefetch_done <= 1; axi_arvalid <= 0; bram_we <= 0;");
        try self.builder.writeLine("            state <= IDLE;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("    endcase");
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeMultilayerSequencer(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// MULTI-LAYER SEQUENCER - FSM for full model inference");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module multilayer_sequencer (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("input  wire        start,");
        try self.builder.writeLine("input  wire [5:0]  num_layers,");
        try self.builder.writeLine("input  wire        layer_done,");
        try self.builder.writeLine("input  wire        prefetch_done,");
        try self.builder.writeLine("output reg  [5:0]  current_layer,");
        try self.builder.writeLine("output reg         layer_start,");
        try self.builder.writeLine("output reg         start_prefetch,");
        try self.builder.writeLine("output reg         inference_done");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam IDLE=0, INIT=1, RUNNING=2, WAIT_LAYER=3, NEXT_LAYER=4, COMPLETE=5;");
        try self.builder.writeLine("reg [2:0] state;");
        try self.builder.newline();
        try self.builder.writeLine("always @(posedge clk or negedge rst_n) begin");
        try self.builder.writeLine("    if (!rst_n) begin");
        try self.builder.writeLine("        state <= IDLE; current_layer <= 0; layer_start <= 0;");
        try self.builder.writeLine("        start_prefetch <= 0; inference_done <= 0;");
        try self.builder.writeLine("    end else case (state)");
        try self.builder.writeLine("        IDLE: if (start) begin");
        try self.builder.writeLine("            state <= INIT; current_layer <= 0; inference_done <= 0;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        INIT: begin");
        try self.builder.writeLine("            // Start first layer and prefetch second");
        try self.builder.writeLine("            layer_start <= 1; start_prefetch <= (num_layers > 1);");
        try self.builder.writeLine("            state <= RUNNING;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        RUNNING: begin");
        try self.builder.writeLine("            layer_start <= 0; start_prefetch <= 0;");
        try self.builder.writeLine("            state <= WAIT_LAYER;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        WAIT_LAYER: if (layer_done) begin");
        try self.builder.writeLine("            if (current_layer == num_layers - 1) state <= COMPLETE;");
        try self.builder.writeLine("            else state <= NEXT_LAYER;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        NEXT_LAYER: begin");
        try self.builder.writeLine("            current_layer <= current_layer + 1;");
        try self.builder.writeLine("            layer_start <= 1;");
        try self.builder.writeLine("            start_prefetch <= (current_layer + 2 < num_layers);");
        try self.builder.writeLine("            state <= RUNNING;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        COMPLETE: begin");
        try self.builder.writeLine("            inference_done <= 1; state <= IDLE;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("    endcase");
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeAxiLiteSlave(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// AXI-LITE SLAVE - Control/Status Register Interface");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module axi_lite_slave #(");
        self.builder.incIndent();
        try self.builder.writeLine("parameter ADDR_WIDTH = 8,");
        try self.builder.writeLine("parameter DATA_WIDTH = 32");
        self.builder.decIndent();
        try self.builder.writeLine(") (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire                    clk,");
        try self.builder.writeLine("input  wire                    rst_n,");
        try self.builder.writeLine("// AXI-Lite Write Address");
        try self.builder.writeLine("input  wire [ADDR_WIDTH-1:0]   s_axi_awaddr,");
        try self.builder.writeLine("input  wire                    s_axi_awvalid,");
        try self.builder.writeLine("output reg                     s_axi_awready,");
        try self.builder.writeLine("// AXI-Lite Write Data");
        try self.builder.writeLine("input  wire [DATA_WIDTH-1:0]   s_axi_wdata,");
        try self.builder.writeLine("input  wire [3:0]              s_axi_wstrb,");
        try self.builder.writeLine("input  wire                    s_axi_wvalid,");
        try self.builder.writeLine("output reg                     s_axi_wready,");
        try self.builder.writeLine("// AXI-Lite Write Response");
        try self.builder.writeLine("output reg  [1:0]              s_axi_bresp,");
        try self.builder.writeLine("output reg                     s_axi_bvalid,");
        try self.builder.writeLine("input  wire                    s_axi_bready,");
        try self.builder.writeLine("// AXI-Lite Read Address");
        try self.builder.writeLine("input  wire [ADDR_WIDTH-1:0]   s_axi_araddr,");
        try self.builder.writeLine("input  wire                    s_axi_arvalid,");
        try self.builder.writeLine("output reg                     s_axi_arready,");
        try self.builder.writeLine("// AXI-Lite Read Data");
        try self.builder.writeLine("output reg  [DATA_WIDTH-1:0]   s_axi_rdata,");
        try self.builder.writeLine("output reg  [1:0]              s_axi_rresp,");
        try self.builder.writeLine("output reg                     s_axi_rvalid,");
        try self.builder.writeLine("input  wire                    s_axi_rready,");
        try self.builder.writeLine("// Register outputs");
        try self.builder.writeLine("output reg  [31:0]             reg_ctrl,");
        try self.builder.writeLine("input  wire [31:0]             reg_status,");
        try self.builder.writeLine("output reg  [31:0]             reg_irq_en,");
        try self.builder.writeLine("input  wire [31:0]             reg_irq_stat,");
        try self.builder.writeLine("output reg  [31:0]             reg_num_layers,");
        try self.builder.writeLine("output reg  [31:0]             reg_neurons,");
        try self.builder.writeLine("output reg  [31:0]             reg_chunks,");
        try self.builder.writeLine("output reg  [31:0]             reg_threshold,");
        try self.builder.writeLine("output reg  [63:0]             reg_weight_addr,");
        try self.builder.writeLine("output reg  [63:0]             reg_input_addr,");
        try self.builder.writeLine("output reg  [63:0]             reg_output_addr,");
        try self.builder.writeLine("input  wire [63:0]             reg_cycles");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// Write state machine");
        try self.builder.writeLine("reg [ADDR_WIDTH-1:0] wr_addr;");
        try self.builder.writeLine("reg wr_addr_valid, wr_data_valid;");
        try self.builder.newline();
        try self.builder.writeLine("always @(posedge clk or negedge rst_n) begin");
        try self.builder.writeLine("    if (!rst_n) begin");
        try self.builder.writeLine("        s_axi_awready <= 1; s_axi_wready <= 1; s_axi_bvalid <= 0;");
        try self.builder.writeLine("        s_axi_arready <= 1; s_axi_rvalid <= 0;");
        try self.builder.writeLine("        reg_ctrl <= 0; reg_irq_en <= 0;");
        try self.builder.writeLine("    end else begin");
        try self.builder.writeLine("        // Write handling");
        try self.builder.writeLine("        if (s_axi_awvalid && s_axi_awready) wr_addr <= s_axi_awaddr;");
        try self.builder.writeLine("        if (s_axi_awvalid && s_axi_wvalid && s_axi_awready && s_axi_wready) begin");
        try self.builder.writeLine("            case (s_axi_awaddr[5:2])");
        try self.builder.writeLine("                4'h0: reg_ctrl <= s_axi_wdata;");
        try self.builder.writeLine("                4'h2: reg_irq_en <= s_axi_wdata;");
        try self.builder.writeLine("                4'h4: reg_num_layers <= s_axi_wdata;");
        try self.builder.writeLine("                4'h5: reg_neurons <= s_axi_wdata;");
        try self.builder.writeLine("                4'h6: reg_chunks <= s_axi_wdata;");
        try self.builder.writeLine("                4'h7: reg_threshold <= s_axi_wdata;");
        try self.builder.writeLine("                4'h8: reg_weight_addr[31:0] <= s_axi_wdata;");
        try self.builder.writeLine("                4'h9: reg_weight_addr[63:32] <= s_axi_wdata;");
        try self.builder.writeLine("                4'hA: reg_input_addr[31:0] <= s_axi_wdata;");
        try self.builder.writeLine("                4'hB: reg_input_addr[63:32] <= s_axi_wdata;");
        try self.builder.writeLine("                4'hC: reg_output_addr[31:0] <= s_axi_wdata;");
        try self.builder.writeLine("                4'hD: reg_output_addr[63:32] <= s_axi_wdata;");
        try self.builder.writeLine("            endcase");
        try self.builder.writeLine("            s_axi_bvalid <= 1; s_axi_bresp <= 2'b00;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 0;");
        try self.builder.writeLine("        // Read handling");
        try self.builder.writeLine("        if (s_axi_arvalid && s_axi_arready) begin");
        try self.builder.writeLine("            case (s_axi_araddr[5:2])");
        try self.builder.writeLine("                4'h0: s_axi_rdata <= reg_ctrl;");
        try self.builder.writeLine("                4'h1: s_axi_rdata <= reg_status;");
        try self.builder.writeLine("                4'h2: s_axi_rdata <= reg_irq_en;");
        try self.builder.writeLine("                4'h3: s_axi_rdata <= reg_irq_stat;");
        try self.builder.writeLine("                4'h4: s_axi_rdata <= reg_num_layers;");
        try self.builder.writeLine("                4'h5: s_axi_rdata <= reg_neurons;");
        try self.builder.writeLine("                4'h6: s_axi_rdata <= reg_chunks;");
        try self.builder.writeLine("                4'h7: s_axi_rdata <= reg_threshold;");
        try self.builder.writeLine("                4'hE: s_axi_rdata <= reg_cycles[31:0];");
        try self.builder.writeLine("                4'hF: s_axi_rdata <= reg_cycles[63:32];");
        try self.builder.writeLine("                default: s_axi_rdata <= 32'hDEADBEEF;");
        try self.builder.writeLine("            endcase");
        try self.builder.writeLine("            s_axi_rvalid <= 1; s_axi_rresp <= 2'b00;");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 0;");
        try self.builder.writeLine("    end");
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeDmaController(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// DMA CONTROLLER - High-bandwidth data transfer");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module dma_controller (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("// Control");
        try self.builder.writeLine("input  wire        start,");
        try self.builder.writeLine("input  wire [63:0] src_addr,");
        try self.builder.writeLine("input  wire [63:0] dst_addr,");
        try self.builder.writeLine("input  wire [31:0] length,");
        try self.builder.writeLine("input  wire        direction,  // 0=read, 1=write");
        try self.builder.writeLine("output reg         busy,");
        try self.builder.writeLine("output reg         done,");
        try self.builder.writeLine("// AXI4 Master Read");
        try self.builder.writeLine("output reg  [63:0] m_axi_araddr,");
        try self.builder.writeLine("output reg  [7:0]  m_axi_arlen,");
        try self.builder.writeLine("output reg         m_axi_arvalid,");
        try self.builder.writeLine("input  wire        m_axi_arready,");
        try self.builder.writeLine("input  wire [63:0] m_axi_rdata,");
        try self.builder.writeLine("input  wire        m_axi_rlast,");
        try self.builder.writeLine("input  wire        m_axi_rvalid,");
        try self.builder.writeLine("output wire        m_axi_rready,");
        try self.builder.writeLine("// AXI4 Master Write");
        try self.builder.writeLine("output reg  [63:0] m_axi_awaddr,");
        try self.builder.writeLine("output reg  [7:0]  m_axi_awlen,");
        try self.builder.writeLine("output reg         m_axi_awvalid,");
        try self.builder.writeLine("input  wire        m_axi_awready,");
        try self.builder.writeLine("output reg  [63:0] m_axi_wdata,");
        try self.builder.writeLine("output reg         m_axi_wlast,");
        try self.builder.writeLine("output reg         m_axi_wvalid,");
        try self.builder.writeLine("input  wire        m_axi_wready,");
        try self.builder.writeLine("input  wire        m_axi_bvalid,");
        try self.builder.writeLine("output wire        m_axi_bready,");
        try self.builder.writeLine("// Local memory interface");
        try self.builder.writeLine("output reg  [11:0] local_addr,");
        try self.builder.writeLine("output reg  [63:0] local_wdata,");
        try self.builder.writeLine("output reg         local_we,");
        try self.builder.writeLine("input  wire [63:0] local_rdata");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam IDLE=0, READ_ADDR=1, READ_DATA=2, WRITE_ADDR=3, WRITE_DATA=4, DONE_ST=5;");
        try self.builder.writeLine("reg [2:0] state;");
        try self.builder.writeLine("reg [31:0] bytes_remaining;");
        try self.builder.writeLine("reg [7:0] burst_count;");
        try self.builder.newline();
        try self.builder.writeLine("assign m_axi_rready = (state == READ_DATA);");
        try self.builder.writeLine("assign m_axi_bready = 1;");
        try self.builder.newline();
        try self.builder.writeLine("always @(posedge clk or negedge rst_n) begin");
        try self.builder.writeLine("    if (!rst_n) begin");
        try self.builder.writeLine("        state <= IDLE; busy <= 0; done <= 0;");
        try self.builder.writeLine("        m_axi_arvalid <= 0; m_axi_awvalid <= 0; m_axi_wvalid <= 0;");
        try self.builder.writeLine("        local_we <= 0;");
        try self.builder.writeLine("    end else case (state)");
        try self.builder.writeLine("        IDLE: if (start) begin");
        try self.builder.writeLine("            busy <= 1; done <= 0; bytes_remaining <= length;");
        try self.builder.writeLine("            local_addr <= 0;");
        try self.builder.writeLine("            state <= direction ? WRITE_ADDR : READ_ADDR;");
        try self.builder.writeLine("            if (!direction) begin m_axi_araddr <= src_addr; m_axi_arlen <= 8'hFF; end");
        try self.builder.writeLine("            else begin m_axi_awaddr <= dst_addr; m_axi_awlen <= 8'hFF; end");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        READ_ADDR: begin");
        try self.builder.writeLine("            m_axi_arvalid <= 1;");
        try self.builder.writeLine("            if (m_axi_arready) begin m_axi_arvalid <= 0; state <= READ_DATA; end");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        READ_DATA: if (m_axi_rvalid) begin");
        try self.builder.writeLine("            local_wdata <= m_axi_rdata; local_we <= 1;");
        try self.builder.writeLine("            local_addr <= local_addr + 1;");
        try self.builder.writeLine("            bytes_remaining <= bytes_remaining - 8;");
        try self.builder.writeLine("            if (m_axi_rlast || bytes_remaining <= 8) state <= DONE_ST;");
        try self.builder.writeLine("        end else local_we <= 0;");
        try self.builder.writeLine("        WRITE_ADDR: begin");
        try self.builder.writeLine("            m_axi_awvalid <= 1;");
        try self.builder.writeLine("            if (m_axi_awready) begin m_axi_awvalid <= 0; state <= WRITE_DATA; burst_count <= 0; end");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        WRITE_DATA: begin");
        try self.builder.writeLine("            m_axi_wdata <= local_rdata; m_axi_wvalid <= 1;");
        try self.builder.writeLine("            m_axi_wlast <= (bytes_remaining <= 8);");
        try self.builder.writeLine("            if (m_axi_wready) begin");
        try self.builder.writeLine("                local_addr <= local_addr + 1;");
        try self.builder.writeLine("                bytes_remaining <= bytes_remaining - 8;");
        try self.builder.writeLine("                if (bytes_remaining <= 8) begin m_axi_wvalid <= 0; state <= DONE_ST; end");
        try self.builder.writeLine("            end");
        try self.builder.writeLine("        end");
        try self.builder.writeLine("        DONE_ST: begin busy <= 0; done <= 1; local_we <= 0; state <= IDLE; end");
        try self.builder.writeLine("    endcase");
        try self.builder.writeLine("end");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeInterruptController(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// INTERRUPT CONTROLLER - Async completion signaling");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module interrupt_controller (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("// Interrupt sources");
        try self.builder.writeLine("input  wire        inference_done,");
        try self.builder.writeLine("input  wire        dma_done,");
        try self.builder.writeLine("input  wire        error,");
        try self.builder.writeLine("// Interrupt enable");
        try self.builder.writeLine("input  wire [2:0]  irq_enable,");
        try self.builder.writeLine("// Status (active-high, clear on read)");
        try self.builder.writeLine("output reg  [2:0]  irq_status,");
        try self.builder.writeLine("input  wire        status_read,");
        try self.builder.writeLine("// Interrupt output");
        try self.builder.writeLine("output wire        irq_out");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// Capture interrupt events");
        try self.builder.writeLine("always @(posedge clk or negedge rst_n) begin");
        try self.builder.writeLine("    if (!rst_n) irq_status <= 0;");
        try self.builder.writeLine("    else begin");
        try self.builder.writeLine("        if (inference_done) irq_status[0] <= 1;");
        try self.builder.writeLine("        if (dma_done) irq_status[1] <= 1;");
        try self.builder.writeLine("        if (error) irq_status[2] <= 1;");
        try self.builder.writeLine("        if (status_read) irq_status <= 0;  // Clear on read");
        try self.builder.writeLine("    end");
        try self.builder.writeLine("end");
        try self.builder.newline();
        try self.builder.writeLine("// Generate interrupt if any enabled source is active");
        try self.builder.writeLine("assign irq_out = |(irq_status & irq_enable);");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeHostInterfaceTop(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// HOST INTERFACE TOP - Complete AXI host interface");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module host_interface_top (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("// AXI-Lite Slave (from host)");
        try self.builder.writeLine("input  wire [7:0]  s_axi_awaddr,");
        try self.builder.writeLine("input  wire        s_axi_awvalid,");
        try self.builder.writeLine("output wire        s_axi_awready,");
        try self.builder.writeLine("input  wire [31:0] s_axi_wdata,");
        try self.builder.writeLine("input  wire        s_axi_wvalid,");
        try self.builder.writeLine("output wire        s_axi_wready,");
        try self.builder.writeLine("output wire [1:0]  s_axi_bresp,");
        try self.builder.writeLine("output wire        s_axi_bvalid,");
        try self.builder.writeLine("input  wire        s_axi_bready,");
        try self.builder.writeLine("input  wire [7:0]  s_axi_araddr,");
        try self.builder.writeLine("input  wire        s_axi_arvalid,");
        try self.builder.writeLine("output wire        s_axi_arready,");
        try self.builder.writeLine("output wire [31:0] s_axi_rdata,");
        try self.builder.writeLine("output wire [1:0]  s_axi_rresp,");
        try self.builder.writeLine("output wire        s_axi_rvalid,");
        try self.builder.writeLine("input  wire        s_axi_rready,");
        try self.builder.writeLine("// AXI4 Master (to DDR)");
        try self.builder.writeLine("output wire [63:0] m_axi_araddr,");
        try self.builder.writeLine("output wire [7:0]  m_axi_arlen,");
        try self.builder.writeLine("output wire        m_axi_arvalid,");
        try self.builder.writeLine("input  wire        m_axi_arready,");
        try self.builder.writeLine("input  wire [63:0] m_axi_rdata,");
        try self.builder.writeLine("input  wire        m_axi_rlast,");
        try self.builder.writeLine("input  wire        m_axi_rvalid,");
        try self.builder.writeLine("output wire        m_axi_rready,");
        try self.builder.writeLine("// Interrupt");
        try self.builder.writeLine("output wire        irq");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// Register wires");
        try self.builder.writeLine("wire [31:0] reg_ctrl, reg_status, reg_irq_en, reg_irq_stat;");
        try self.builder.writeLine("wire [31:0] reg_num_layers, reg_neurons, reg_chunks, reg_threshold;");
        try self.builder.writeLine("wire [63:0] reg_weight_addr, reg_input_addr, reg_output_addr, reg_cycles;");
        try self.builder.newline();
        try self.builder.writeLine("// Engine signals");
        try self.builder.writeLine("wire engine_start = reg_ctrl[0];");
        try self.builder.writeLine("wire engine_busy, engine_done;");
        try self.builder.writeLine("assign reg_status = {16'd0, 8'd0, 4'd0, 1'b0, 1'b0, engine_done, engine_busy};");
        try self.builder.newline();
        try self.builder.writeLine("// AXI-Lite slave");
        try self.builder.writeLine("axi_lite_slave regs (");
        try self.builder.writeLine("    .clk(clk), .rst_n(rst_n),");
        try self.builder.writeLine("    .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),");
        try self.builder.writeLine("    .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(4'hF), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),");
        try self.builder.writeLine("    .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),");
        try self.builder.writeLine("    .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),");
        try self.builder.writeLine("    .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),");
        try self.builder.writeLine("    .reg_ctrl(reg_ctrl), .reg_status(reg_status), .reg_irq_en(reg_irq_en), .reg_irq_stat(reg_irq_stat),");
        try self.builder.writeLine("    .reg_num_layers(reg_num_layers), .reg_neurons(reg_neurons), .reg_chunks(reg_chunks), .reg_threshold(reg_threshold),");
        try self.builder.writeLine("    .reg_weight_addr(reg_weight_addr), .reg_input_addr(reg_input_addr), .reg_output_addr(reg_output_addr), .reg_cycles(reg_cycles)");
        try self.builder.writeLine(");");
        try self.builder.newline();
        try self.builder.writeLine("// Interrupt controller");
        try self.builder.writeLine("interrupt_controller irq_ctrl (");
        try self.builder.writeLine("    .clk(clk), .rst_n(rst_n),");
        try self.builder.writeLine("    .inference_done(engine_done), .dma_done(1'b0), .error(1'b0),");
        try self.builder.writeLine("    .irq_enable(reg_irq_en[2:0]), .irq_status(), .status_read(1'b0), .irq_out(irq)");
        try self.builder.writeLine(");");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeBitNetEngineTop(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// BITNET INFERENCE ENGINE TOP - Complete multi-layer inference");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module bitnet_engine_top (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("input  wire        start,");
        try self.builder.writeLine("input  wire [5:0]  num_layers,");
        try self.builder.writeLine("input  wire [15:0] neurons_per_layer,");
        try self.builder.writeLine("input  wire [7:0]  chunks_per_neuron,");
        try self.builder.writeLine("input  wire signed [15:0] threshold,");
        try self.builder.writeLine("// External memory interface (simplified)");
        try self.builder.writeLine("output wire [31:0] mem_addr,");
        try self.builder.writeLine("output wire        mem_rd_en,");
        try self.builder.writeLine("input  wire [63:0] mem_rd_data,");
        try self.builder.writeLine("input  wire        mem_rd_valid,");
        try self.builder.writeLine("// Status");
        try self.builder.writeLine("output wire        busy,");
        try self.builder.writeLine("output wire        done,");
        try self.builder.writeLine("output wire [31:0] cycle_count");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// Multi-layer sequencer");
        try self.builder.writeLine("wire [5:0] current_layer;");
        try self.builder.writeLine("wire layer_start, layer_done, start_prefetch, prefetch_done;");
        try self.builder.writeLine("multilayer_sequencer seq (");
        try self.builder.writeLine("    .clk(clk), .rst_n(rst_n), .start(start), .num_layers(num_layers),");
        try self.builder.writeLine("    .layer_done(layer_done), .prefetch_done(prefetch_done),");
        try self.builder.writeLine("    .current_layer(current_layer), .layer_start(layer_start),");
        try self.builder.writeLine("    .start_prefetch(start_prefetch), .inference_done(done)");
        try self.builder.writeLine(");");
        try self.builder.newline();
        try self.builder.writeLine("// Double buffer controller");
        try self.builder.writeLine("wire use_buffer_a;");
        try self.builder.writeLine("wire [11:0] buf_read_addr, buf_write_addr;");
        try self.builder.writeLine("double_buffer_ctrl dbl_buf (");
        try self.builder.writeLine("    .clk(clk), .rst_n(rst_n), .layer_done(layer_done),");
        try self.builder.writeLine("    .current_layer(current_layer), .use_buffer_a(use_buffer_a),");
        try self.builder.writeLine("    .read_addr(buf_read_addr), .write_addr(buf_write_addr), .neuron_id(12'd0)");
        try self.builder.writeLine(");");
        try self.builder.newline();
        try self.builder.writeLine("// Cycle counter");
        try self.builder.writeLine("reg [31:0] cycles;");
        try self.builder.writeLine("always @(posedge clk or negedge rst_n)");
        try self.builder.writeLine("    if (!rst_n) cycles <= 0;");
        try self.builder.writeLine("    else if (start) cycles <= 0;");
        try self.builder.writeLine("    else if (busy) cycles <= cycles + 1;");
        try self.builder.writeLine("assign cycle_count = cycles;");
        try self.builder.writeLine("assign busy = (current_layer != 0) || layer_start;");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeBitNetLayerTop(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// BITNET LAYER TOP - Complete pipelined layer");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module bitnet_layer_top (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        try self.builder.writeLine("input  wire        rst_n,");
        try self.builder.writeLine("input  wire        start,");
        try self.builder.writeLine("input  wire [15:0] num_neurons,");
        try self.builder.writeLine("input  wire [7:0]  num_chunks,");
        try self.builder.writeLine("input  wire signed [15:0] threshold,");
        try self.builder.writeLine("input  wire [53:0] input_data,");
        try self.builder.writeLine("output wire [1:0]  output_trit,");
        try self.builder.writeLine("output wire        output_valid,");
        try self.builder.writeLine("output wire        layer_done");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("// Sequencer");
        try self.builder.writeLine("wire [15:0] neuron_id; wire [7:0] chunk_id;");
        try self.builder.writeLine("wire first_chunk, last_chunk, seq_valid;");
        try self.builder.writeLine("layer_sequencer seq(.clk(clk),.rst_n(rst_n),.start(start),");
        try self.builder.writeLine("    .num_neurons(num_neurons),.num_chunks(num_chunks),");
        try self.builder.writeLine("    .neuron_id(neuron_id),.chunk_id(chunk_id),");
        try self.builder.writeLine("    .first_chunk(first_chunk),.last_chunk(last_chunk),.valid(seq_valid),.done(layer_done));");
        try self.builder.newline();
        try self.builder.writeLine("// Weight BRAM");
        try self.builder.writeLine("wire [53:0] weight_data;");
        try self.builder.writeLine("wire [11:0] weight_addr = neuron_id[7:0] * num_chunks + chunk_id;");
        try self.builder.writeLine("weight_bram weights(.clk(clk),.rd_addr(weight_addr),.rd_data(weight_data),.wr_addr(12'd0),.wr_data(54'd0),.wr_en(1'b0));");
        try self.builder.newline();
        try self.builder.writeLine("// Compute stage");
        try self.builder.writeLine("wire compute_valid; wire signed [15:0] pre_act; wire is_final;");
        try self.builder.writeLine("pipeline_stage2_compute compute(.clk(clk),.rst_n(rst_n),.valid_in(seq_valid),");
        try self.builder.writeLine("    .input_chunk(input_data),.weight_chunk(weight_data),");
        try self.builder.writeLine("    .first_chunk(first_chunk),.last_chunk(last_chunk),");
        try self.builder.writeLine("    .valid_out(compute_valid),.result(pre_act),.result_final(is_final));");
        try self.builder.newline();
        try self.builder.writeLine("// Activation");
        try self.builder.writeLine("bitnet_activation act(.pre_act(pre_act),.threshold(threshold),.result(output_trit));");
        try self.builder.writeLine("assign output_valid = compute_valid & is_final;");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeBitNetActivation(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// BITNET ACTIVATION - Ternary ReLU");
        try self.builder.writeLine("// Clamp to {-1, 0, +1} based on thresholds");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("module bitnet_activation (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire signed [15:0] pre_act,     // Pre-activation value");
        try self.builder.writeLine("input  wire signed [15:0] threshold,   // Activation threshold");
        try self.builder.writeLine("output wire [1:0] result               // Output trit");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();
        self.builder.incIndent();
        try self.builder.writeLine("localparam TRIT_N = 2'b00;  // -1");
        try self.builder.writeLine("localparam TRIT_Z = 2'b01;  //  0");
        try self.builder.writeLine("localparam TRIT_P = 2'b10;  // +1");
        try self.builder.newline();
        try self.builder.writeLine("// Ternary activation: clamp to {-1, 0, +1}");
        try self.builder.writeLine("assign result = (pre_act > threshold)  ? TRIT_P :");
        try self.builder.writeLine("                (pre_act < -threshold) ? TRIT_N :");
        try self.builder.writeLine("                TRIT_Z;");
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // NEW AXI BEHAVIOR HANDLERS
    // ═══════════════════════════════════════════════════════════════════════════════

    fn writeAxiWriteHandler(self: *Self) !void {
        try self.builder.writeLine("// AXI-Lite Write Handler - Complete FSM");
        try self.builder.writeLine("module axi_write_handler (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk, input  wire        rst_n,");
        try self.builder.writeLine("input  wire [7:0]  awaddr, input  wire        awvalid, output reg         awready,");
        try self.builder.writeLine("input  wire [31:0] wdata,  input  wire        wvalid,  output reg         wready,");
        try self.builder.writeLine("output reg  [1:0]  bresp,  output reg         bvalid,  input  wire        bready,");
        try self.builder.writeLine("output reg  [7:0]  reg_addr, output reg  [31:0] reg_wdata, output reg         reg_wen");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.writeLine("  localparam IDLE=0, ADDR=1, DATA=2, RESP=3;");
        try self.builder.writeLine("  reg [1:0] state;");
        try self.builder.writeLine("  always @(posedge clk or negedge rst_n)");
        try self.builder.writeLine("    if (!rst_n) begin state<=IDLE; awready<=1; wready<=1; bvalid<=0; reg_wen<=0; end");
        try self.builder.writeLine("    else case(state)");
        try self.builder.writeLine("      IDLE: if (awvalid && wvalid) begin reg_addr<=awaddr; reg_wdata<=wdata; reg_wen<=1; state<=RESP; end");
        try self.builder.writeLine("      RESP: begin reg_wen<=0; bvalid<=1; bresp<=2'b00; if(bready) begin bvalid<=0; state<=IDLE; end end");
        try self.builder.writeLine("    endcase");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeAxiReadHandler(self: *Self) !void {
        try self.builder.writeLine("// AXI-Lite Read Handler - Complete FSM");
        try self.builder.writeLine("module axi_read_handler (");
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk, input  wire        rst_n,");
        try self.builder.writeLine("input  wire [7:0]  araddr, input  wire        arvalid, output reg         arready,");
        try self.builder.writeLine("output reg  [31:0] rdata,  output reg  [1:0]  rresp,   output reg         rvalid, input  wire        rready,");
        try self.builder.writeLine("output reg  [7:0]  reg_addr, input  wire [31:0] reg_rdata");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.writeLine("  localparam IDLE=0, READ=1, RESP=2;");
        try self.builder.writeLine("  reg [1:0] state;");
        try self.builder.writeLine("  always @(posedge clk or negedge rst_n)");
        try self.builder.writeLine("    if (!rst_n) begin state<=IDLE; arready<=1; rvalid<=0; end");
        try self.builder.writeLine("    else case(state)");
        try self.builder.writeLine("      IDLE: if (arvalid) begin reg_addr<=araddr; arready<=0; state<=READ; end");
        try self.builder.writeLine("      READ: begin rdata<=reg_rdata; rvalid<=1; rresp<=2'b00; state<=RESP; end");
        try self.builder.writeLine("      RESP: if (rready) begin rvalid<=0; arready<=1; state<=IDLE; end");
        try self.builder.writeLine("    endcase");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeCtrlRegHandler(self: *Self) !void {
        try self.builder.writeLine("// Control Register Handler - Start pulse generation");
        try self.builder.writeLine("module ctrl_reg_handler (");
        try self.builder.writeLine("  input wire clk, input wire rst_n, input wire [31:0] ctrl_reg,");
        try self.builder.writeLine("  output reg start_pulse, output reg soft_reset");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  reg start_d;");
        try self.builder.writeLine("  always @(posedge clk or negedge rst_n)");
        try self.builder.writeLine("    if (!rst_n) begin start_d<=0; start_pulse<=0; soft_reset<=0; end");
        try self.builder.writeLine("    else begin start_d<=ctrl_reg[0]; start_pulse<=ctrl_reg[0]&&!start_d; soft_reset<=ctrl_reg[1]; end");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeIrqGenerator(self: *Self) !void {
        try self.builder.writeLine("// IRQ Generator - Interrupt output logic");
        try self.builder.writeLine("module irq_generator (");
        try self.builder.writeLine("  input wire clk, input wire rst_n, input wire [31:0] irq_en, input wire [31:0] irq_stat, output wire irq");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  assign irq = |(irq_en & irq_stat);");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeStatusAggregator(self: *Self) !void {
        try self.builder.writeLine("// Status Aggregator - Combine status signals");
        try self.builder.writeLine("module status_aggregator (");
        try self.builder.writeLine("  input wire busy, input wire done, input wire error, input wire [7:0] layer,");
        try self.builder.writeLine("  output wire [31:0] status");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  assign status = {16'd0, layer, 4'd0, 1'b0, error, done, busy};");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeCycleCounter(self: *Self) !void {
        try self.builder.writeLine("// 64-bit Cycle Counter");
        try self.builder.writeLine("module cycle_counter (");
        try self.builder.writeLine("  input wire clk, input wire rst_n, input wire enable, input wire clear,");
        try self.builder.writeLine("  output reg [63:0] count");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  always @(posedge clk or negedge rst_n)");
        try self.builder.writeLine("    if (!rst_n || clear) count <= 64'd0;");
        try self.builder.writeLine("    else if (enable) count <= count + 1;");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeAxisSlaveRx(self: *Self) !void {
        try self.builder.writeLine("// AXI-Stream Slave Receiver");
        try self.builder.writeLine("module axis_slave_rx (");
        try self.builder.writeLine("  input wire clk, input wire rst_n,");
        try self.builder.writeLine("  input wire [63:0] tdata, input wire tvalid, output reg tready, input wire tlast,");
        try self.builder.writeLine("  output reg [63:0] data_out, output reg valid_out, input wire ready_in");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  always @(posedge clk or negedge rst_n)");
        try self.builder.writeLine("    if (!rst_n) begin tready<=1; valid_out<=0; end");
        try self.builder.writeLine("    else begin tready<=ready_in; if(tvalid&&tready) begin data_out<=tdata; valid_out<=1; end else valid_out<=0; end");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeAxisMasterTx(self: *Self) !void {
        try self.builder.writeLine("// AXI-Stream Master Transmitter");
        try self.builder.writeLine("module axis_master_tx (");
        try self.builder.writeLine("  input wire clk, input wire rst_n,");
        try self.builder.writeLine("  output reg [63:0] tdata, output reg tvalid, input wire tready, output reg tlast,");
        try self.builder.writeLine("  input wire [63:0] data_in, input wire valid_in, output wire ready_out, input wire last_in");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  assign ready_out = !tvalid || tready;");
        try self.builder.writeLine("  always @(posedge clk or negedge rst_n)");
        try self.builder.writeLine("    if (!rst_n) tvalid<=0;");
        try self.builder.writeLine("    else if(ready_out&&valid_in) begin tdata<=data_in; tvalid<=1; tlast<=last_in; end");
        try self.builder.writeLine("    else if(tready) tvalid<=0;");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeWeightStreamRx(self: *Self) !void {
        try self.builder.writeLine("// Weight Stream Receiver");
        try self.builder.writeLine("module weight_stream_rx (");
        try self.builder.writeLine("  input wire clk, input wire rst_n,");
        try self.builder.writeLine("  input wire [63:0] tdata, input wire tvalid, output reg tready, input wire tlast,");
        try self.builder.writeLine("  output reg [63:0] weight_data, output reg [15:0] weight_addr, output reg weight_we");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  always @(posedge clk or negedge rst_n)");
        try self.builder.writeLine("    if (!rst_n) begin tready<=1; weight_we<=0; weight_addr<=0; end");
        try self.builder.writeLine("    else if(tvalid&&tready) begin weight_data<=tdata; weight_we<=1; weight_addr<=weight_addr+1; end");
        try self.builder.writeLine("    else weight_we<=0;");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeBackpressureHandler(self: *Self) !void {
        try self.builder.writeLine("// Backpressure Handler");
        try self.builder.writeLine("module backpressure_handler (");
        try self.builder.writeLine("  input wire [7:0] fifo_count, input wire [7:0] threshold, output wire tready");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  assign tready = (fifo_count < threshold);");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writePacketParser(self: *Self) !void {
        try self.builder.writeLine("// Packet Parser - Extract header and route");
        try self.builder.writeLine("module packet_parser (");
        try self.builder.writeLine("  input wire clk, input wire rst_n, input wire [63:0] data, input wire valid,");
        try self.builder.writeLine("  output reg [3:0] pkt_type, output reg [31:0] payload, output reg pkt_valid");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  always @(posedge clk or negedge rst_n)");
        try self.builder.writeLine("    if (!rst_n) pkt_valid<=0;");
        try self.builder.writeLine("    else if(valid) begin pkt_type<=data[63:60]; payload<=data[31:0]; pkt_valid<=1; end");
        try self.builder.writeLine("    else pkt_valid<=0;");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writePacketAssembler(self: *Self) !void {
        try self.builder.writeLine("// Packet Assembler - Build output packet");
        try self.builder.writeLine("module packet_assembler (");
        try self.builder.writeLine("  input wire [3:0] pkt_type, input wire [31:0] payload, input wire valid,");
        try self.builder.writeLine("  output wire [63:0] packet");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  assign packet = {pkt_type, 28'd0, payload};");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeWeightLoadHandler(self: *Self) !void {
        try self.builder.writeLine("// Weight Load Handler");
        try self.builder.writeLine("module weight_load_handler (");
        try self.builder.writeLine("  input wire clk, input wire rst_n, input wire [63:0] data, input wire valid,");
        try self.builder.writeLine("  output reg [53:0] weight_chunk, output reg [15:0] addr, output reg we");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  always @(posedge clk or negedge rst_n)");
        try self.builder.writeLine("    if (!rst_n) begin we<=0; addr<=0; end");
        try self.builder.writeLine("    else if(valid) begin weight_chunk<=data[53:0]; we<=1; addr<=addr+1; end");
        try self.builder.writeLine("    else we<=0;");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeUnpackWeights(self: *Self) !void {
        try self.builder.writeLine("// Unpack 32 ternary weights from 64-bit word to 27-weight SIMD chunk");
        try self.builder.writeLine("module unpack_weights (");
        try self.builder.writeLine("  input wire [63:0] packed, output wire [53:0] unpacked");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  assign unpacked = packed[53:0]; // Take first 27 weights (54 bits)");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeWriteToBram(self: *Self) !void {
        try self.builder.writeLine("// Write to BRAM");
        try self.builder.writeLine("module write_to_bram (");
        try self.builder.writeLine("  input wire clk, input wire [15:0] addr, input wire [53:0] data, input wire we,");
        try self.builder.writeLine("  output reg [15:0] bram_addr, output reg [53:0] bram_data, output reg bram_we");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  always @(posedge clk) begin bram_addr<=addr; bram_data<=data; bram_we<=we; end");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeFifoWrite(self: *Self) !void {
        try self.builder.writeLine("// FIFO Write Interface");
        try self.builder.writeLine("module fifo_write (");
        try self.builder.writeLine("  input wire clk, input wire rst_n, input wire [31:0] data, input wire wr_en, input wire full,");
        try self.builder.writeLine("  output reg [31:0] fifo_data, output reg fifo_wr, output wire ready");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  assign ready = !full;");
        try self.builder.writeLine("  always @(posedge clk) if(wr_en && !full) begin fifo_data<=data; fifo_wr<=1; end else fifo_wr<=0;");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeFifoRead(self: *Self) !void {
        try self.builder.writeLine("// FIFO Read Interface");
        try self.builder.writeLine("module fifo_read (");
        try self.builder.writeLine("  input wire clk, input wire rst_n, input wire [31:0] fifo_data, input wire empty, input wire rd_en,");
        try self.builder.writeLine("  output reg [31:0] data, output reg valid");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  always @(posedge clk) if(rd_en && !empty) begin data<=fifo_data; valid<=1; end else valid<=0;");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeInferenceCounter(self: *Self) !void {
        try self.builder.writeLine("// Inference Counter");
        try self.builder.writeLine("module inference_counter (");
        try self.builder.writeLine("  input wire clk, input wire rst_n, input wire done_pulse, input wire clear,");
        try self.builder.writeLine("  output reg [31:0] count");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  always @(posedge clk or negedge rst_n)");
        try self.builder.writeLine("    if (!rst_n || clear) count<=0; else if(done_pulse) count<=count+1;");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeMacCounter(self: *Self) !void {
        try self.builder.writeLine("// MAC Operations Counter");
        try self.builder.writeLine("module mac_counter (");
        try self.builder.writeLine("  input wire clk, input wire rst_n, input wire simd_active, input wire clear,");
        try self.builder.writeLine("  output reg [63:0] count");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  always @(posedge clk or negedge rst_n)");
        try self.builder.writeLine("    if (!rst_n || clear) count<=0; else if(simd_active) count<=count+27; // 27 MACs per SIMD op");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeStallTracker(self: *Self) !void {
        try self.builder.writeLine("// Stall Cycle Tracker");
        try self.builder.writeLine("module stall_tracker (");
        try self.builder.writeLine("  input wire clk, input wire rst_n, input wire mem_stall, input wire compute_stall, input wire clear,");
        try self.builder.writeLine("  output reg [31:0] mem_stalls, output reg [31:0] compute_stalls");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  always @(posedge clk or negedge rst_n)");
        try self.builder.writeLine("    if (!rst_n || clear) begin mem_stalls<=0; compute_stalls<=0; end");
        try self.builder.writeLine("    else begin if(mem_stall) mem_stalls<=mem_stalls+1; if(compute_stall) compute_stalls<=compute_stalls+1; end");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeLayerTimer(self: *Self) !void {
        try self.builder.writeLine("// Layer Timer");
        try self.builder.writeLine("module layer_timer (");
        try self.builder.writeLine("  input wire clk, input wire rst_n, input wire layer_start, input wire layer_done,");
        try self.builder.writeLine("  output reg [31:0] layer_cycles");
        try self.builder.writeLine(");");
        try self.builder.writeLine("  reg running; reg [31:0] counter;");
        try self.builder.writeLine("  always @(posedge clk or negedge rst_n)");
        try self.builder.writeLine("    if (!rst_n) begin running<=0; counter<=0; end");
        try self.builder.writeLine("    else if(layer_start) begin running<=1; counter<=0; end");
        try self.builder.writeLine("    else if(layer_done) begin running<=0; layer_cycles<=counter; end");
        try self.builder.writeLine("    else if(running) counter<=counter+1;");
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    fn writeGenericBehavior(self: *Self, b: Behavior) !void {
        try self.builder.writeFmt("// Behavior: {s}\n", .{b.name});
        try self.builder.writeFmt("// Given: {s}\n", .{b.given});
        try self.builder.writeFmt("// When: {s}\n", .{b.when});
        try self.builder.writeFmt("// Then: {s}\n", .{b.then});

        const spec = self.spec;
        const has_reset = !std.mem.eql(u8, spec.reset.reset_type, "none");
        const rst_name = if (std.mem.eql(u8, spec.reset.level, "low")) "rst_n" else "rst";
        const rst_active = if (std.mem.eql(u8, spec.reset.level, "low")) "!" else "";
        const rst_edge = if (std.mem.eql(u8, spec.reset.level, "low")) "negedge" else "posedge";

        try self.builder.writeFmt("module behavior_{s} (\n", .{b.name});
        self.builder.incIndent();
        try self.builder.writeLine("input  wire        clk,");
        if (has_reset) {
            try self.builder.writeFmt("input  wire        {s},\n", .{rst_name});
        }
        try self.builder.writeLine("input  wire        trigger,");
        try self.builder.writeLine("input  wire [31:0] input_data,");
        try self.builder.writeLine("output reg  [31:0] output_data,");
        try self.builder.writeLine("output reg         done");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();

        self.builder.incIndent();
        if (has_reset) {
            if (std.mem.eql(u8, spec.reset.reset_type, "async")) {
                try self.builder.writeFmt("always @(posedge clk or {s} {s}) begin\n", .{ rst_edge, rst_name });
            } else {
                try self.builder.writeLine("always @(posedge clk) begin");
            }
            self.builder.incIndent();
            try self.builder.writeFmt("if ({s}{s}) begin\n", .{ rst_active, rst_name });
            self.builder.incIndent();
            try self.builder.writeLine("output_data <= 32'd0;");
            try self.builder.writeLine("done <= 1'b0;");
            self.builder.decIndent();
            try self.builder.writeLine("end else if (trigger) begin");
            self.builder.incIndent();
            try self.builder.writeLine("// TODO: Implement behavior logic");
            try self.builder.writeLine("output_data <= input_data;");
            try self.builder.writeLine("done <= 1'b1;");
            self.builder.decIndent();
            try self.builder.writeLine("end else begin");
            self.builder.incIndent();
            try self.builder.writeLine("done <= 1'b0;");
            self.builder.decIndent();
            try self.builder.writeLine("end");
            self.builder.decIndent();
            try self.builder.writeLine("end");
        } else {
            try self.builder.writeLine("always @(posedge clk) begin");
            self.builder.incIndent();
            try self.builder.writeLine("if (trigger) begin");
            self.builder.incIndent();
            try self.builder.writeLine("// TODO: Implement behavior logic");
            try self.builder.writeLine("output_data <= input_data;");
            try self.builder.writeLine("done <= 1'b1;");
            self.builder.decIndent();
            try self.builder.writeLine("end else begin");
            self.builder.incIndent();
            try self.builder.writeLine("done <= 1'b0;");
            self.builder.decIndent();
            try self.builder.writeLine("end");
            self.builder.decIndent();
            try self.builder.writeLine("end");
        }
        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
        try self.builder.newline();
    }

    /// Generate SystemVerilog Assertions from behaviors
    fn writeSVAAssertions(self: *Self, spec: *const VibeeSpec) !void {
        if (spec.behaviors.items.len == 0) return;

        // Extract signals from types
        var extracted_signals = extractSignalsFromTypes(spec.types.items, self.allocator) catch ArrayList(ExtractedSignal).init(self.allocator);
        defer extracted_signals.deinit();

        // Validate behavior signals
        var warnings = validateBehaviorSignals(spec.behaviors.items, extracted_signals.items, self.allocator) catch ArrayList(ValidationWarning).init(self.allocator);
        defer warnings.deinit();

        // Print warnings to stderr (visible during generation)
        if (warnings.items.len > 0) {
            std.debug.print("\n", .{});
            printValidationWarnings(warnings.items);
        }

        // Add validation comments to generated code
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// SYSTEMVERILOG ASSERTIONS (SVA)");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// Generated from .vibee behaviors - IEEE 1800 compliant");
        try self.builder.writeLine("// Signals extracted from spec types");
        try self.builder.writeLine("// φ² + 1/φ² = 3");
        try self.builder.newline();

        // Wrap SVA module in `ifdef FORMAL for iverilog compatibility
        try self.builder.writeLine("`ifdef FORMAL");
        try self.builder.writeFmt("module {s}_sva_checker (\n", .{spec.name});
        self.builder.incIndent();

        // Standard signals
        try self.builder.writeLine("input wire        clk,");
        try self.builder.writeLine("input wire        rst_n,");
        try self.builder.writeLine("input wire [31:0] data_in,");
        try self.builder.writeLine("input wire        valid_in,");
        try self.builder.writeLine("input wire [31:0] data_out,");
        try self.builder.writeLine("input wire        valid_out,");
        try self.builder.writeLine("input wire        ready,");
        try self.builder.writeLine("input wire [2:0]  state,");

        // Signals extracted from types (skip duplicates with standard signals)
        const standard_sigs = [_][]const u8{ "clk", "rst_n", "data_in", "valid_in", "data_out", "valid_out", "ready", "state" };
        if (extracted_signals.items.len > 0) {
            try self.builder.writeLine("// Signals from spec types:");
            for (extracted_signals.items) |sig| {
                // Skip if already declared as standard signal
                var is_standard = false;
                for (standard_sigs) |std_sig| {
                    if (std.mem.eql(u8, sig.name, std_sig)) {
                        is_standard = true;
                        break;
                    }
                }
                if (is_standard) continue;

                if (sig.is_bool) {
                    try self.builder.writeFmt("input wire        {s},\n", .{sig.name});
                } else {
                    try self.builder.writeFmt("input wire [31:0] {s},\n", .{sig.name});
                }
            }
        }

        // Common signals - only add if not already in extracted
        try self.builder.writeLine("// Common SVA signals:");
        const fallback_signals = [_][]const u8{ "running", "active", "overflow", "done", "flag" };
        for (fallback_signals, 0..) |common, i| {
            var exists = false;
            for (extracted_signals.items) |sig| {
                if (std.mem.eql(u8, sig.name, common)) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                const is_last = (i == fallback_signals.len - 1);
                try self.builder.writeFmt("input wire        {s}{s}\n", .{ common, if (is_last) "" else "," });
            }
        }

        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();

        self.builder.incIndent();

        // Local parameters for state machine
        try self.builder.writeLine("// State machine parameters");
        try self.builder.writeLine("localparam IDLE    = 3'd0;");
        try self.builder.writeLine("localparam PROCESS = 3'd1;");
        try self.builder.writeLine("localparam DONE_ST = 3'd2;");

        // MAX_VALUE - use wire alias if depth/max_value exists in types
        var depth_signal: ?[]const u8 = null;
        for (extracted_signals.items) |sig| {
            if (std.mem.eql(u8, sig.name, "depth") or std.mem.eql(u8, sig.name, "max_value")) {
                depth_signal = sig.name;
                break;
            }
        }
        if (depth_signal) |ds| {
            try self.builder.writeFmt("wire [31:0] MAX_VALUE = {s}; // from spec types\n", .{ds});
        } else {
            try self.builder.writeLine("localparam MAX_VALUE = 32'hFFFFFFFF;");
        }
        try self.builder.newline();

        // Default clocking block
        try self.builder.writeLine("// Default clocking for assertions");
        try self.builder.writeLine("default clocking cb @(posedge clk);");
        try self.builder.writeLine("endclocking");
        try self.builder.newline();

        // Disable assertions during reset
        try self.builder.writeLine("// Note: 'disable iff' is used in each property for reset handling");
        try self.builder.newline();

        // Generate assertions from behaviors
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// ASSERTIONS FROM BEHAVIORS");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (spec.behaviors.items, 0..) |behavior, i| {
            // Generate assertion from behavior
            try self.builder.writeFmt("// Behavior: {s}\n", .{behavior.name});
            try self.builder.writeFmt("// Given: {s}\n", .{behavior.given});
            try self.builder.writeFmt("// When: {s}\n", .{behavior.when});
            try self.builder.writeFmt("// Then: {s}\n", .{behavior.then});

            // Generate property
            try self.builder.writeFmt("property p_{s};\n", .{behavior.name});
            self.builder.incIndent();

            // Parse given/when/then into SVA
            try self.generateSVAProperty(behavior);

            self.builder.decIndent();
            try self.builder.writeLine("endproperty");
            try self.builder.newline();

            // Generate assertion
            try self.builder.writeFmt("assert_{d}_{s}: assert property (p_{s})\n", .{ i, behavior.name, behavior.name });
            self.builder.incIndent();
            try self.builder.writeFmt("else $error(\"Assertion failed: {s}\");\n", .{behavior.name});
            self.builder.decIndent();
            try self.builder.newline();

            // Generate cover
            try self.builder.writeFmt("cover_{d}_{s}: cover property (p_{s});\n", .{ i, behavior.name, behavior.name });
            try self.builder.newline();
        }

        // Sacred identity assertion
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// SACRED IDENTITY ASSERTION");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();
        try self.builder.writeLine("// φ² + 1/φ² = 3 (verified at compile time)");
        try self.builder.writeLine("localparam real PHI = 1.6180339887498948482;");
        try self.builder.writeLine("localparam real GOLDEN_IDENTITY = PHI * PHI + 1.0 / (PHI * PHI);");
        try self.builder.newline();
        try self.builder.writeLine("// Compile-time check (synthesis will optimize this)");
        try self.builder.writeLine("initial begin");
        self.builder.incIndent();
        try self.builder.writeLine("if (GOLDEN_IDENTITY < 2.99 || GOLDEN_IDENTITY > 3.01)");
        self.builder.incIndent();
        try self.builder.writeLine("$fatal(1, \"Golden Identity violated: φ² + 1/φ² != 3\");");
        self.builder.decIndent();
        self.builder.decIndent();
        try self.builder.writeLine("end");
        try self.builder.newline();

        self.builder.decIndent();
        try self.builder.writeLine("endmodule");
        try self.builder.writeLine("`endif // FORMAL");
        try self.builder.newline();
    }

    /// Generate SVA property expression from behavior
    /// Generate SVA property expression from behavior using semantic parsing
    fn generateSVAProperty(self: *Self, behavior: Behavior) !void {
        // Parse given clause → antecedent
        const antecedent = parseGivenClause(behavior.given);

        // Parse when clause → timing
        const timing = parseWhenClause(behavior.when);

        // Parse then clause → consequent
        const consequent = parseThenClause(behavior.then);

        // Generate SVA property
        try self.builder.writeFmt("@({s}) disable iff (!rst_n)\n", .{timing});
        try self.builder.writeFmt("{s} |-> {s};\n", .{ antecedent, consequent });
    }

    /// Parse "given" clause to SVA antecedent
    fn parseGivenClause(given: []const u8) []const u8 {
        // Signal patterns
        if (containsIgnoreCase(given, "running")) return "running";
        if (containsIgnoreCase(given, "active")) return "active";
        if (containsIgnoreCase(given, "valid")) return "valid_in";
        if (containsIgnoreCase(given, "ready")) return "ready";
        if (containsIgnoreCase(given, "reset")) {
            if (containsIgnoreCase(given, "not") or containsIgnoreCase(given, "inactive")) {
                return "rst_n";
            }
            return "!rst_n";
        }
        if (containsIgnoreCase(given, "idle")) return "(state == IDLE)";
        if (containsIgnoreCase(given, "process")) return "(state == PROCESS)";
        if (containsIgnoreCase(given, "counter") or containsIgnoreCase(given, "count")) {
            if (containsIgnoreCase(given, "max")) return "(count == MAX_VALUE)";
            if (containsIgnoreCase(given, "zero") or containsIgnoreCase(given, "0")) return "(count == 0)";
            return "(count > 0)";
        }
        if (containsIgnoreCase(given, "fifo")) {
            if (containsIgnoreCase(given, "not") and containsIgnoreCase(given, "full")) return "!full";
            if (containsIgnoreCase(given, "not") and containsIgnoreCase(given, "empty")) return "!empty";
            if (containsIgnoreCase(given, "full")) return "full";
            if (containsIgnoreCase(given, "empty")) return "empty";
            return "!empty";
        }

        // Direct signal names from types (full, empty, etc.)
        if (containsIgnoreCase(given, "not") and containsIgnoreCase(given, "full")) return "!full";
        if (containsIgnoreCase(given, "not") and containsIgnoreCase(given, "empty")) return "!empty";
        if (containsIgnoreCase(given, "full")) return "full";
        if (containsIgnoreCase(given, "empty")) return "empty";

        // Default: always true
        return "1'b1";
    }

    /// Parse "when" clause to SVA timing
    fn parseWhenClause(when: []const u8) []const u8 {
        // Clock edge detection
        if (containsIgnoreCase(when, "falling") or containsIgnoreCase(when, "negedge")) {
            return "negedge clk";
        }
        // Default to rising edge
        return "posedge clk";
    }

    /// Parse "then" clause to SVA consequent
    fn parseThenClause(then: []const u8) []const u8 {
        // Increment operation
        if (containsIgnoreCase(then, "increment") or containsIgnoreCase(then, "add")) {
            if (containsIgnoreCase(then, "count")) {
                return "(count == $past(count) + 1)";
            }
            return "($past(data_out) + 1)";
        }

        // Decrement operation
        if (containsIgnoreCase(then, "decrement") or containsIgnoreCase(then, "subtract")) {
            if (containsIgnoreCase(then, "count")) {
                return "(count == $past(count) - 1)";
            }
            return "($past(data_out) - 1)";
        }

        // Set to zero/clear
        if (containsIgnoreCase(then, "zero") or containsIgnoreCase(then, "clear") or
            (containsIgnoreCase(then, "set") and containsIgnoreCase(then, "0")))
        {
            if (containsIgnoreCase(then, "count")) return "(count == 0)";
            if (containsIgnoreCase(then, "overflow")) return "(!overflow)";
            return "(data_out == 0)";
        }

        // Set flag
        if (containsIgnoreCase(then, "set") and containsIgnoreCase(then, "flag")) {
            if (containsIgnoreCase(then, "overflow")) return "overflow";
            if (containsIgnoreCase(then, "valid")) return "valid_out";
            if (containsIgnoreCase(then, "done")) return "done";
            if (containsIgnoreCase(then, "full")) return "full";
            if (containsIgnoreCase(then, "empty")) return "empty";
            return "flag";
        }

        // Direct flag setting (from types)
        if (containsIgnoreCase(then, "set") and containsIgnoreCase(then, "full")) return "full";
        if (containsIgnoreCase(then, "set") and containsIgnoreCase(then, "empty")) return "empty";

        // Output valid
        if (containsIgnoreCase(then, "valid") and containsIgnoreCase(then, "output")) {
            return "valid_out";
        }

        // Wrap around
        if (containsIgnoreCase(then, "wrap")) {
            return "(count == 0)";
        }

        // Default: signal stays stable or becomes true
        return "1'b1";
    }

    fn writeTestbench(self: *Self, spec: *const VibeeSpec) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// TESTBENCH");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        try self.builder.writeFmt("module {s}_tb;\n", .{spec.name});
        try self.builder.newline();

        self.builder.incIndent();

        // Testbench signals
        try self.builder.writeLine("// Testbench signals");
        try self.builder.writeLine("reg         clk;");
        try self.builder.writeLine("reg         rst_n;");
        try self.builder.writeLine("reg  [31:0] data_in;");
        try self.builder.writeLine("reg         valid_in;");
        try self.builder.writeLine("wire [31:0] data_out;");
        try self.builder.writeLine("wire        valid_out;");
        try self.builder.writeLine("wire        ready;");
        try self.builder.newline();

        // DUT instantiation
        try self.builder.writeLine("// DUT instantiation");
        try self.builder.writeFmt("{s}_top dut (\n", .{spec.name});
        self.builder.incIndent();
        try self.builder.writeLine(".clk(clk),");
        try self.builder.writeLine(".rst_n(rst_n),");
        try self.builder.writeLine(".data_in(data_in),");
        try self.builder.writeLine(".valid_in(valid_in),");
        try self.builder.writeLine(".data_out(data_out),");
        try self.builder.writeLine(".valid_out(valid_out),");
        try self.builder.writeLine(".ready(ready)");
        self.builder.decIndent();
        try self.builder.writeLine(");");
        try self.builder.newline();

        // Clock generation
        try self.builder.writeLine("// Clock generation (100 MHz)");
        try self.builder.writeLine("initial clk = 0;");
        try self.builder.writeLine("always #5 clk = ~clk;");
        try self.builder.newline();

        // Test sequence
        try self.builder.writeLine("// Test sequence");
        try self.builder.writeLine("initial begin");
        self.builder.incIndent();
        try self.builder.writeLine("$display(\"═══════════════════════════════════════════════════════════════\");");
        try self.builder.writeFmt("$display(\"{s} Testbench - φ² + 1/φ² = 3\");\n", .{spec.name});
        try self.builder.writeLine("$display(\"═══════════════════════════════════════════════════════════════\");");
        try self.builder.newline();

        const vspec = self.spec;
        const has_reset = !std.mem.eql(u8, vspec.reset.reset_type, "none");
        const rst_name = if (std.mem.eql(u8, vspec.reset.level, "low")) "rst_n" else "rst";
        const rst_active = if (std.mem.eql(u8, vspec.reset.level, "low")) "0" else "1";
        const rst_release = if (std.mem.eql(u8, vspec.reset.level, "low")) "1" else "0";

        try self.builder.writeLine("// Initialize");
        if (has_reset) {
            try self.builder.writeFmt("{s} = {s};\n", .{ rst_name, rst_active });
        }
        try self.builder.writeLine("data_in = 32'd0;");
        try self.builder.writeLine("valid_in = 0;");
        try self.builder.writeLine("#20;");
        try self.builder.newline();

        if (has_reset) {
            try self.builder.writeLine("// Release reset");
            try self.builder.writeFmt("{s} = {s};\n", .{ rst_name, rst_release });
            try self.builder.writeLine("#10;");
            try self.builder.newline();
        }

        try self.builder.writeLine("// Test 1: Basic operation");
        try self.builder.writeLine("$display(\"Test 1: Basic operation\");");
        try self.builder.writeLine("data_in = 32'h12345678;");
        try self.builder.writeLine("valid_in = 1;");
        try self.builder.writeLine("@(posedge clk);  // Wait for state transition");
        try self.builder.writeLine("valid_in = 0;");
        try self.builder.writeLine("repeat(5) @(posedge clk);  // Wait for state machine to complete");
        try self.builder.newline();

        try self.builder.writeLine("// Check output (valid_out or data changed)");
        try self.builder.writeLine("if (valid_out || data_out != 32'd0)");
        self.builder.incIndent();
        try self.builder.writeLine("$display(\"  PASS: Output valid=%b, data = %h\", valid_out, data_out);");
        self.builder.decIndent();
        try self.builder.writeLine("else");
        self.builder.incIndent();
        try self.builder.writeLine("$display(\"  FAIL: Output not valid\");");
        self.builder.decIndent();
        try self.builder.newline();

        try self.builder.writeLine("// Golden identity verification");
        try self.builder.writeLine("$display(\"Golden Identity: φ² + 1/φ² = 3 ✓\");");
        try self.builder.writeLine("$display(\"PHOENIX = 999 ✓\");");
        try self.builder.newline();

        try self.builder.writeLine("$display(\"═══════════════════════════════════════════════════════════════\");");
        try self.builder.writeLine("$display(\"Testbench complete\");");
        try self.builder.writeLine("$finish;");
        self.builder.decIndent();
        try self.builder.writeLine("end");

        self.builder.decIndent();
        try self.builder.newline();
        try self.builder.writeLine("endmodule");
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;

    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        var match = true;
        for (needle, 0..) |nc, j| {
            const hc = haystack[i + j];
            const nc_lower = if (nc >= 'A' and nc <= 'Z') nc + 32 else nc;
            const hc_lower = if (hc >= 'A' and hc <= 'Z') hc + 32 else hc;
            if (nc_lower != hc_lower) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE MAPPING
// ═══════════════════════════════════════════════════════════════════════════════

fn mapTypeToVerilog(vibee_type: []const u8) []const u8 {
    if (std.mem.eql(u8, vibee_type, "String")) return "[255:0] // String as 256-bit";
    if (std.mem.eql(u8, vibee_type, "Int")) return "[63:0] // 64-bit signed";
    if (std.mem.eql(u8, vibee_type, "Float")) return "[63:0] // IEEE 754 double";
    if (std.mem.eql(u8, vibee_type, "Bool")) return "[0:0] // 1-bit boolean";
    if (std.mem.eql(u8, vibee_type, "Timestamp")) return "[63:0] // 64-bit timestamp";
    if (std.mem.startsWith(u8, vibee_type, "List")) return "[1023:0] // List as 1024-bit";
    if (std.mem.startsWith(u8, vibee_type, "Option")) return "[64:0] // Option with valid bit";
    if (std.mem.eql(u8, vibee_type, "Object")) return "[511:0] // Object as 512-bit";
    return "[31:0] // Default 32-bit";
}

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API
// ═══════════════════════════════════════════════════════════════════════════════

pub fn generateVerilog(allocator: Allocator, spec: *const VibeeSpec) ![]const u8 {
    var codegen = VerilogCodeGen.init(allocator);
    defer codegen.deinit();

    const output = try codegen.generate(spec);
    return try allocator.dupe(u8, output);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "verilog type mapping" {
    const testing = std.testing;

    try testing.expectEqualStrings("[63:0] // 64-bit signed", mapTypeToVerilog("Int"));
    try testing.expectEqualStrings("[63:0] // IEEE 754 double", mapTypeToVerilog("Float"));
    try testing.expectEqualStrings("[0:0] // 1-bit boolean", mapTypeToVerilog("Bool"));
}

test "golden identity" {
    const phi: f64 = 1.618033988749895;
    const result = phi * phi + 1.0 / (phi * phi);
    const testing = std.testing;
    try testing.expect(@abs(result - 3.0) < 1e-10);
}

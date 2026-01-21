// ═══════════════════════════════════════════════════════════════════════════════
// VM JIT - Tracing JIT Compiler
// ═══════════════════════════════════════════════════════════════════════════════
// Target: 10-50x speedup for hot loops
// Architecture: Trace recording → IR → Native code
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const core = @import("vm_core.zig");
const opcodes = @import("vm_opcodes.zig");

const Value = core.Value;
const ValueTag = core.ValueTag;
const Opcode = opcodes.Opcode;

// ═══════════════════════════════════════════════════════════════════════════════
// TRACE RECORDING
// ═══════════════════════════════════════════════════════════════════════════════

pub const TraceEntry = struct {
    opcode: Opcode,
    operand: u16,
    /// Type of left operand (for specialization)
    left_type: ValueTag,
    /// Type of right operand (for specialization)
    right_type: ValueTag,
    /// Bytecode offset
    bc_offset: u16,
};

pub const Trace = struct {
    entries: [MAX_TRACE_LENGTH]TraceEntry,
    length: u16,
    loop_start: u16,
    loop_end: u16,
    iteration_count: u32,
    is_compiled: bool,
    /// Compiled native code (if any)
    native_code: ?[]const u8,
    
    pub const MAX_TRACE_LENGTH = 256;
    
    pub fn init(loop_start: u16, loop_end: u16) Trace {
        return .{
            .entries = undefined,
            .length = 0,
            .loop_start = loop_start,
            .loop_end = loop_end,
            .iteration_count = 0,
            .is_compiled = false,
            .native_code = null,
        };
    }
    
    pub fn record(self: *Trace, entry: TraceEntry) void {
        if (self.length < MAX_TRACE_LENGTH) {
            self.entries[self.length] = entry;
            self.length += 1;
        }
    }
    
    pub fn clear(self: *Trace) void {
        self.length = 0;
        self.iteration_count = 0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRACE RECORDER
// ═══════════════════════════════════════════════════════════════════════════════

pub const TraceRecorder = struct {
    traces: [MAX_TRACES]Trace,
    trace_count: u8,
    recording_trace: ?*Trace,
    hot_threshold: u32,
    
    pub const MAX_TRACES = 32;
    pub const DEFAULT_HOT_THRESHOLD = 1000;
    
    pub fn init() TraceRecorder {
        return .{
            .traces = undefined,
            .trace_count = 0,
            .recording_trace = null,
            .hot_threshold = DEFAULT_HOT_THRESHOLD,
        };
    }
    
    /// Start recording a trace for a loop
    pub fn startRecording(self: *TraceRecorder, loop_start: u16, loop_end: u16) void {
        if (self.trace_count >= MAX_TRACES) return;
        
        self.traces[self.trace_count] = Trace.init(loop_start, loop_end);
        self.recording_trace = &self.traces[self.trace_count];
        self.trace_count += 1;
    }
    
    /// Stop recording current trace
    pub fn stopRecording(self: *TraceRecorder) void {
        self.recording_trace = null;
    }
    
    /// Record an instruction during trace recording
    pub fn recordInstruction(
        self: *TraceRecorder,
        opcode: Opcode,
        operand: u16,
        left_type: ValueTag,
        right_type: ValueTag,
        bc_offset: u16,
    ) void {
        if (self.recording_trace) |trace| {
            trace.record(.{
                .opcode = opcode,
                .operand = operand,
                .left_type = left_type,
                .right_type = right_type,
                .bc_offset = bc_offset,
            });
        }
    }
    
    /// Check if a loop is hot and should be traced
    pub fn isHotLoop(self: *TraceRecorder, loop_start: u16, loop_end: u16) bool {
        var i: u8 = 0;
        while (i < self.trace_count) : (i += 1) {
            if (self.traces[i].loop_start == loop_start and self.traces[i].loop_end == loop_end) {
                return self.traces[i].iteration_count >= self.hot_threshold;
            }
        }
        return false;
    }
    
    /// Increment loop iteration count
    pub fn recordLoopIteration(self: *TraceRecorder, loop_start: u16, loop_end: u16) void {
        var i: u8 = 0;
        while (i < self.trace_count) : (i += 1) {
            if (self.traces[i].loop_start == loop_start and self.traces[i].loop_end == loop_end) {
                self.traces[i].iteration_count += 1;
                return;
            }
        }
        
        // New loop - start tracking
        if (self.trace_count < MAX_TRACES) {
            self.traces[self.trace_count] = Trace.init(loop_start, loop_end);
            self.traces[self.trace_count].iteration_count = 1;
            self.trace_count += 1;
        }
    }
    
    /// Get trace for a loop (if exists)
    pub fn getTrace(self: *TraceRecorder, loop_start: u16, loop_end: u16) ?*Trace {
        var i: u8 = 0;
        while (i < self.trace_count) : (i += 1) {
            if (self.traces[i].loop_start == loop_start and self.traces[i].loop_end == loop_end) {
                return &self.traces[i];
            }
        }
        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INTERMEDIATE REPRESENTATION (IR)
// ═══════════════════════════════════════════════════════════════════════════════

pub const IROpcode = enum(u8) {
    // Constants
    CONST_INT,
    CONST_FLOAT,
    
    // Arithmetic (type-specialized)
    ADD_INT,
    ADD_FLOAT,
    SUB_INT,
    SUB_FLOAT,
    MUL_INT,
    MUL_FLOAT,
    DIV_FLOAT,
    
    // Comparison
    LT_INT,
    LT_FLOAT,
    LE_INT,
    LE_FLOAT,
    
    // Control flow
    JUMP,
    BRANCH_TRUE,
    BRANCH_FALSE,
    
    // Stack
    LOAD_LOCAL,
    STORE_LOCAL,
    
    // Guards (for deoptimization)
    GUARD_INT,
    GUARD_FLOAT,
    DEOPT,
    
    // Return
    RETURN,
};

pub const IRInstruction = struct {
    opcode: IROpcode,
    dest: u8,      // Destination register
    src1: u8,      // Source register 1
    src2: u8,      // Source register 2
    imm: i64,      // Immediate value
    
    pub fn constInt(dest: u8, value: i64) IRInstruction {
        return .{ .opcode = .CONST_INT, .dest = dest, .src1 = 0, .src2 = 0, .imm = value };
    }
    
    pub fn addInt(dest: u8, src1: u8, src2: u8) IRInstruction {
        return .{ .opcode = .ADD_INT, .dest = dest, .src1 = src1, .src2 = src2, .imm = 0 };
    }
    
    pub fn mulInt(dest: u8, src1: u8, src2: u8) IRInstruction {
        return .{ .opcode = .MUL_INT, .dest = dest, .src1 = src1, .src2 = src2, .imm = 0 };
    }
    
    pub fn ltInt(dest: u8, src1: u8, src2: u8) IRInstruction {
        return .{ .opcode = .LT_INT, .dest = dest, .src1 = src1, .src2 = src2, .imm = 0 };
    }
    
    pub fn guardInt(src: u8, deopt_target: i64) IRInstruction {
        return .{ .opcode = .GUARD_INT, .dest = 0, .src1 = src, .src2 = 0, .imm = deopt_target };
    }
    
    pub fn ret(src: u8) IRInstruction {
        return .{ .opcode = .RETURN, .dest = 0, .src1 = src, .src2 = 0, .imm = 0 };
    }
};

pub const IRFunction = struct {
    instructions: [MAX_IR_LENGTH]IRInstruction,
    length: u16,
    num_registers: u8,
    
    pub const MAX_IR_LENGTH = 512;
    
    pub fn init() IRFunction {
        return .{
            .instructions = undefined,
            .length = 0,
            .num_registers = 0,
        };
    }
    
    pub fn emit(self: *IRFunction, inst: IRInstruction) void {
        if (self.length < MAX_IR_LENGTH) {
            self.instructions[self.length] = inst;
            self.length += 1;
            
            // Track register usage
            if (inst.dest >= self.num_registers) {
                self.num_registers = inst.dest + 1;
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRACE COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

pub const TraceCompiler = struct {
    /// Compile a trace to IR
    pub fn compileToIR(trace: *const Trace) IRFunction {
        var ir = IRFunction.init();
        var reg: u8 = 0;
        
        for (trace.entries[0..trace.length]) |entry| {
            switch (entry.opcode) {
                .PUSH_CONST => {
                    ir.emit(IRInstruction.constInt(reg, entry.operand));
                    reg += 1;
                },
                .ADD => {
                    if (entry.left_type == .INT and entry.right_type == .INT) {
                        // Type-specialized integer add
                        ir.emit(IRInstruction.addInt(reg - 2, reg - 2, reg - 1));
                        reg -= 1;
                    } else {
                        // Fallback to float
                        ir.emit(.{ .opcode = .ADD_FLOAT, .dest = reg - 2, .src1 = reg - 2, .src2 = reg - 1, .imm = 0 });
                        reg -= 1;
                    }
                },
                .MUL => {
                    if (entry.left_type == .INT and entry.right_type == .INT) {
                        ir.emit(IRInstruction.mulInt(reg - 2, reg - 2, reg - 1));
                        reg -= 1;
                    } else {
                        ir.emit(.{ .opcode = .MUL_FLOAT, .dest = reg - 2, .src1 = reg - 2, .src2 = reg - 1, .imm = 0 });
                        reg -= 1;
                    }
                },
                .LT => {
                    if (entry.left_type == .INT and entry.right_type == .INT) {
                        ir.emit(IRInstruction.ltInt(reg - 2, reg - 2, reg - 1));
                        reg -= 1;
                    } else {
                        ir.emit(.{ .opcode = .LT_FLOAT, .dest = reg - 2, .src1 = reg - 2, .src2 = reg - 1, .imm = 0 });
                        reg -= 1;
                    }
                },
                .INC => {
                    ir.emit(IRInstruction.constInt(reg, 1));
                    ir.emit(IRInstruction.addInt(reg - 1, reg - 1, reg));
                },
                .JNZ => {
                    ir.emit(.{ .opcode = .BRANCH_TRUE, .dest = 0, .src1 = reg - 1, .src2 = 0, .imm = entry.operand });
                    reg -= 1;
                },
                .HALT => {
                    if (reg > 0) {
                        ir.emit(IRInstruction.ret(reg - 1));
                    }
                },
                else => {
                    // Insert deoptimization point for unsupported opcodes
                    ir.emit(.{ .opcode = .DEOPT, .dest = 0, .src1 = 0, .src2 = 0, .imm = entry.bc_offset });
                },
            }
        }
        
        return ir;
    }
    
    /// Optimize IR (constant folding, dead code elimination)
    pub fn optimizeIR(ir: *IRFunction) void {
        // Simple constant folding
        var i: u16 = 0;
        while (i + 2 < ir.length) : (i += 1) {
            const inst1 = ir.instructions[i];
            const inst2 = ir.instructions[i + 1];
            const inst3 = ir.instructions[i + 2];
            
            // Pattern: CONST_INT r0, a; CONST_INT r1, b; ADD_INT r0, r0, r1
            // Fold to: CONST_INT r0, a+b
            if (inst1.opcode == .CONST_INT and 
                inst2.opcode == .CONST_INT and 
                inst3.opcode == .ADD_INT and
                inst3.src1 == inst1.dest and 
                inst3.src2 == inst2.dest) 
            {
                ir.instructions[i] = IRInstruction.constInt(inst3.dest, inst1.imm +% inst2.imm);
                // Mark folded instructions as NOPs (could remove later)
                ir.instructions[i + 1].opcode = .RETURN;
                ir.instructions[i + 1].src1 = 255; // NOP marker
                ir.instructions[i + 2].opcode = .RETURN;
                ir.instructions[i + 2].src1 = 255;
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// IR INTERPRETER (for testing before native codegen)
// ═══════════════════════════════════════════════════════════════════════════════

pub const IRInterpreter = struct {
    registers: [256]i64,
    
    pub fn init() IRInterpreter {
        return .{ .registers = [_]i64{0} ** 256 };
    }
    
    pub fn execute(self: *IRInterpreter, ir: *const IRFunction) i64 {
        var pc: u16 = 0;
        
        while (pc < ir.length) {
            const inst = ir.instructions[pc];
            pc += 1;
            
            switch (inst.opcode) {
                .CONST_INT => self.registers[inst.dest] = inst.imm,
                .ADD_INT => self.registers[inst.dest] = self.registers[inst.src1] +% self.registers[inst.src2],
                .SUB_INT => self.registers[inst.dest] = self.registers[inst.src1] -% self.registers[inst.src2],
                .MUL_INT => self.registers[inst.dest] = self.registers[inst.src1] *% self.registers[inst.src2],
                .LT_INT => self.registers[inst.dest] = if (self.registers[inst.src1] < self.registers[inst.src2]) 1 else 0,
                .BRANCH_TRUE => {
                    if (self.registers[inst.src1] != 0) {
                        pc = @intCast(inst.imm);
                    }
                },
                .RETURN => return self.registers[inst.src1],
                else => {},
            }
        }
        
        return self.registers[0];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// JIT STATISTICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const JITStats = struct {
    traces_recorded: u32,
    traces_compiled: u32,
    ir_instructions_generated: u32,
    optimizations_applied: u32,
    deoptimizations: u32,
    
    pub fn init() JITStats {
        return .{
            .traces_recorded = 0,
            .traces_compiled = 0,
            .ir_instructions_generated = 0,
            .optimizations_applied = 0,
            .deoptimizations = 0,
        };
    }
    
    pub fn print(self: JITStats, writer: anytype) !void {
        try writer.print("JIT Statistics:\n", .{});
        try writer.print("  Traces Recorded:    {d}\n", .{self.traces_recorded});
        try writer.print("  Traces Compiled:    {d}\n", .{self.traces_compiled});
        try writer.print("  IR Instructions:    {d}\n", .{self.ir_instructions_generated});
        try writer.print("  Optimizations:      {d}\n", .{self.optimizations_applied});
        try writer.print("  Deoptimizations:    {d}\n", .{self.deoptimizations});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TraceRecorder basic" {
    var recorder = TraceRecorder.init();
    
    recorder.recordLoopIteration(10, 20);
    recorder.recordLoopIteration(10, 20);
    
    const trace = recorder.getTrace(10, 20);
    try std.testing.expect(trace != null);
    try std.testing.expectEqual(@as(u32, 2), trace.?.iteration_count);
}

test "TraceRecorder hot detection" {
    var recorder = TraceRecorder.init();
    recorder.hot_threshold = 10;
    
    var i: u32 = 0;
    while (i < 15) : (i += 1) {
        recorder.recordLoopIteration(5, 15);
    }
    
    try std.testing.expect(recorder.isHotLoop(5, 15));
}

test "Trace recording" {
    var trace = Trace.init(0, 10);
    
    trace.record(.{
        .opcode = .PUSH_CONST,
        .operand = 0,
        .left_type = .INT,
        .right_type = .NIL,
        .bc_offset = 0,
    });
    
    trace.record(.{
        .opcode = .ADD,
        .operand = 0,
        .left_type = .INT,
        .right_type = .INT,
        .bc_offset = 3,
    });
    
    try std.testing.expectEqual(@as(u16, 2), trace.length);
    try std.testing.expectEqual(Opcode.PUSH_CONST, trace.entries[0].opcode);
    try std.testing.expectEqual(Opcode.ADD, trace.entries[1].opcode);
}

test "IR generation" {
    var trace = Trace.init(0, 10);
    
    // Simulate: push 5, push 3, add
    trace.record(.{ .opcode = .PUSH_CONST, .operand = 5, .left_type = .INT, .right_type = .NIL, .bc_offset = 0 });
    trace.record(.{ .opcode = .PUSH_CONST, .operand = 3, .left_type = .INT, .right_type = .NIL, .bc_offset = 3 });
    trace.record(.{ .opcode = .ADD, .operand = 0, .left_type = .INT, .right_type = .INT, .bc_offset = 6 });
    trace.record(.{ .opcode = .HALT, .operand = 0, .left_type = .NIL, .right_type = .NIL, .bc_offset = 7 });
    
    const ir = TraceCompiler.compileToIR(&trace);
    
    try std.testing.expect(ir.length > 0);
    try std.testing.expectEqual(IROpcode.CONST_INT, ir.instructions[0].opcode);
}

test "IR interpreter" {
    var ir = IRFunction.init();
    
    // 5 + 3 = 8
    ir.emit(IRInstruction.constInt(0, 5));
    ir.emit(IRInstruction.constInt(1, 3));
    ir.emit(IRInstruction.addInt(0, 0, 1));
    ir.emit(IRInstruction.ret(0));
    
    var interp = IRInterpreter.init();
    const result = interp.execute(&ir);
    
    try std.testing.expectEqual(@as(i64, 8), result);
}

test "IR constant folding" {
    var ir = IRFunction.init();
    
    // Before optimization: CONST 5, CONST 3, ADD
    ir.emit(IRInstruction.constInt(0, 5));
    ir.emit(IRInstruction.constInt(1, 3));
    ir.emit(IRInstruction.addInt(0, 0, 1));
    ir.emit(IRInstruction.ret(0));
    
    TraceCompiler.optimizeIR(&ir);
    
    // After optimization: first instruction should be CONST 8
    try std.testing.expectEqual(@as(i64, 8), ir.instructions[0].imm);
}

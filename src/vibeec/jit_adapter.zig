// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC JIT ADAPTER - Bridge between VM Runtime and JIT Compiler
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V37 - Unified Execution with Hot Path Detection
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Patterns Applied: MLS (Hot Detection), PRE (Code Cache), D&C (Execution)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const vm_runtime = @import("vm_runtime.zig");
const VM = vm_runtime.VM;
const VMError = vm_runtime.VMError;
const jit = @import("jit.zig");
const JITCompiler = jit.JITCompiler;
const TypeInfo = jit.TypeInfo;
const IRInstruction = jit.IRInstruction;
const bytecode = @import("bytecode.zig");
const Opcode = bytecode.Opcode;
const Value = bytecode.Value;
const x86_codegen = @import("x86_64_codegen.zig");
const NativeCompiler = x86_codegen.NativeCompiler;
const ExecutableCode = x86_codegen.ExecutableCode;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const VERSION = "1.0.0";

// ═══════════════════════════════════════════════════════════════════════════════
// JIT MODE
// ═══════════════════════════════════════════════════════════════════════════════

pub const JITMode = enum {
    Interpreter, // Pure interpretation - no JIT
    Mixed, // Interpret + JIT hot paths (default)
    FullJIT, // Aggressive JIT compilation
};

// ═══════════════════════════════════════════════════════════════════════════════
// ADAPTER CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

pub const AdapterConfig = struct {
    mode: JITMode = .Mixed,
    hot_threshold: u32 = jit.HOT_THRESHOLD,
    trace_max_length: usize = jit.TRACE_MAX_LENGTH,
    enable_profiling: bool = true,
    use_fast_path: bool = true, // Use VM's runFast() when not JIT-ing
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXECUTION RESULT
// ═══════════════════════════════════════════════════════════════════════════════

pub const ExecutionResult = struct {
    value: Value,
    used_jit: bool,
    instructions_interpreted: u64,
    instructions_jit: u64,
    execution_time_ns: u64,

    pub fn jitRatio(self: ExecutionResult) f64 {
        const total = self.instructions_interpreted + self.instructions_jit;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.instructions_jit)) / @as(f64, @floatFromInt(total));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HOT SPOT INFO
// ═══════════════════════════════════════════════════════════════════════════════

pub const HotSpotInfo = struct {
    address: u32,
    execution_count: u32,
    is_compiled: bool,
    trace_length: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ADAPTER METRICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const AdapterMetrics = struct {
    // Execution counts
    total_instructions: u64,
    jit_instructions: u64,
    interpreter_instructions: u64,

    // JIT stats
    hot_spots_detected: usize,
    traces_compiled: u64,
    deoptimizations: u64,
    cache_hits: u64,
    cache_misses: u64,

    // Timing
    total_time_ns: u64,
    jit_compile_time_ns: u64,

    pub fn jitRatio(self: AdapterMetrics) f64 {
        if (self.total_instructions == 0) return 0;
        return @as(f64, @floatFromInt(self.jit_instructions)) / @as(f64, @floatFromInt(self.total_instructions));
    }

    pub fn cacheHitRatio(self: AdapterMetrics) f64 {
        const total = self.cache_hits + self.cache_misses;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.cache_hits)) / @as(f64, @floatFromInt(total));
    }
};

/// Native code specific metrics
pub const NativeMetrics = struct {
    native_instructions: u64,
    native_cache_hits: u64,
    native_cache_misses: u64,
    native_compile_time_ns: u64,
    cached_functions: usize,

    pub fn hitRatio(self: NativeMetrics) f64 {
        const total = self.native_cache_hits + self.native_cache_misses;
        if (total == 0) return 0;
        return @as(f64, @floatFromInt(self.native_cache_hits)) / @as(f64, @floatFromInt(total));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// JIT ADAPTER
// ═══════════════════════════════════════════════════════════════════════════════

/// Cached native code entry
pub const NativeCodeEntry = struct {
    executable: ExecutableCode,
    execution_count: u64,
    is_valid: bool,
};

pub const JITAdapter = struct {
    allocator: Allocator,
    vm: VM,
    jit_compiler: JITCompiler,
    config: AdapterConfig,

    // Native code cache: address -> executable code
    native_cache: std.AutoHashMap(u32, NativeCodeEntry),

    // Execution state
    is_recording: bool,
    current_trace_start: u32,

    // Metrics
    jit_instructions: u64,
    interpreter_instructions: u64,
    native_instructions: u64,
    jit_compile_time_ns: u64,
    native_compile_time_ns: u64,
    native_cache_hits: u64,
    native_cache_misses: u64,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .allocator = allocator,
            .vm = try VM.init(allocator),
            .jit_compiler = JITCompiler.init(allocator),
            .config = AdapterConfig{},
            .native_cache = std.AutoHashMap(u32, NativeCodeEntry).init(allocator),
            .is_recording = false,
            .current_trace_start = 0,
            .jit_instructions = 0,
            .interpreter_instructions = 0,
            .native_instructions = 0,
            .jit_compile_time_ns = 0,
            .native_compile_time_ns = 0,
            .native_cache_hits = 0,
            .native_cache_misses = 0,
        };
    }

    pub fn initWithConfig(allocator: Allocator, config: AdapterConfig) !Self {
        var adapter = try Self.init(allocator);
        adapter.config = config;
        return adapter;
    }

    pub fn deinit(self: *Self) void {
        // Free all native code entries
        var iter = self.native_cache.iterator();
        while (iter.next()) |entry| {
            var native_entry = entry.value_ptr;
            native_entry.executable.deinit();
        }
        self.native_cache.deinit();
        self.vm.deinit();
        self.jit_compiler.deinit();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MAIN EXECUTION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Execute bytecode with JIT support
    pub fn execute(self: *Self, code: []const u8, constants: []const Value) !ExecutionResult {
        self.vm.load(code, constants);

        // Reset metrics
        self.jit_instructions = 0;
        self.interpreter_instructions = 0;

        const start_time = std.time.nanoTimestamp();

        const result = switch (self.config.mode) {
            .Interpreter => try self.executeInterpreterOnly(),
            .Mixed => try self.executeMixed(code),
            .FullJIT => try self.executeFullJIT(code),
        };

        const end_time = std.time.nanoTimestamp();
        const execution_time: u64 = @intCast(@max(0, end_time - start_time));

        return ExecutionResult{
            .value = result,
            .used_jit = self.jit_instructions > 0,
            .instructions_interpreted = self.interpreter_instructions,
            .instructions_jit = self.jit_instructions,
            .execution_time_ns = execution_time,
        };
    }

    /// Pure interpreter execution
    fn executeInterpreterOnly(self: *Self) !Value {
        const result = if (self.config.use_fast_path)
            try self.vm.runFast()
        else
            try self.vm.run();

        self.interpreter_instructions = self.vm.instructions_executed;
        return result;
    }

    /// Mixed mode: interpret + JIT hot paths
    /// Uses post-execution analysis of opcode_counts for hot path detection
    fn executeMixed(self: *Self, code: []const u8) !Value {
        // First pass: run with profiling to detect hot paths
        const result = try self.vm.run();
        self.interpreter_instructions = self.vm.instructions_executed;

        // Analyze opcode counts for hot paths
        try self.analyzeHotPaths(code);

        return result;
    }

    /// Full JIT mode: compile everything aggressively
    fn executeFullJIT(self: *Self, code: []const u8) !Value {
        // For now, same as mixed but with lower threshold
        const saved_threshold = self.config.hot_threshold;
        self.config.hot_threshold = 1; // Compile immediately
        defer self.config.hot_threshold = saved_threshold;

        return try self.executeMixed(code);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HOT PATH ANALYSIS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Analyze VM's opcode_counts to detect hot paths
    fn analyzeHotPaths(self: *Self, code: []const u8) !void {
        // Find loop headers (JMP, LOOP targets) with high execution counts
        var ip: usize = 0;
        while (ip < code.len) {
            const opcode_byte = code[ip];
            const count = self.vm.opcode_counts[opcode_byte];

            // Record execution count for this address
            if (count > 0) {
                try self.jit_compiler.recordExecution(@intCast(ip));

                // If hot, start trace recording
                if (count >= self.config.hot_threshold) {
                    try self.recordTraceForAddress(@intCast(ip), code);
                }
            }

            // Advance IP based on opcode size
            const opcode: Opcode = @enumFromInt(opcode_byte);
            ip += 1 + opcode.operandSize();
        }
    }

    /// Record a trace starting at the given address
    fn recordTraceForAddress(self: *Self, addr: u32, code: []const u8) !void {
        if (self.jit_compiler.lookupCode(addr) != null) return; // Already compiled

        const compile_start = std.time.nanoTimestamp();

        try self.jit_compiler.startTrace(addr);

        // Walk bytecode and record instructions until loop back or halt
        var ip: usize = addr;
        var trace_len: usize = 0;
        const max_trace = self.config.trace_max_length;

        while (ip < code.len and trace_len < max_trace) {
            const opcode_byte = code[ip];
            const opcode: Opcode = @enumFromInt(opcode_byte);

            // Infer type from opcode
            const type_info = inferTypeFromOpcode(opcode);

            // Read operand if present
            const operand_size = opcode.operandSize();
            var operand: u16 = 0;
            if (operand_size >= 2 and ip + 2 < code.len) {
                operand = (@as(u16, code[ip + 1]) << 8) | @as(u16, code[ip + 2]);
            } else if (operand_size == 1 and ip + 1 < code.len) {
                operand = code[ip + 1];
            }

            try self.jit_compiler.recordInstruction(opcode, operand, type_info);
            trace_len += 1;

            // Check for trace termination
            if (opcode == .HALT or opcode == .RET) {
                _ = try self.jit_compiler.stopTrace(false, 0);
                break;
            }

            if (opcode == .LOOP) {
                _ = try self.jit_compiler.stopTrace(true, addr);
                break;
            }

            if (opcode == .JMP) {
                // Check if jumping back (loop)
                if (operand <= ip) {
                    _ = try self.jit_compiler.stopTrace(true, operand);
                    break;
                }
            }

            ip += 1 + operand_size;
        }

        const compile_end = std.time.nanoTimestamp();
        self.jit_compile_time_ns += @intCast(@max(0, compile_end - compile_start));

        // Try to compile to native code
        if (self.jit_compiler.lookupCode(addr)) |compiled| {
            try self.compileToNative(addr, compiled.ir.items);
        }
    }

    /// Compile IR to native x86-64 code
    fn compileToNative(self: *Self, addr: u32, ir: []const IRInstruction) !void {
        // Skip if already in native cache
        if (self.native_cache.contains(addr)) return;

        const native_start = std.time.nanoTimestamp();

        var compiler = NativeCompiler.init(self.allocator);
        defer compiler.deinit();

        const machine_code = compiler.compile(ir) catch {
            // Native compilation failed, fall back to IR
            return;
        };
        defer self.allocator.free(machine_code);

        const executable = ExecutableCode.init(machine_code) catch {
            // mmap failed
            return;
        };

        try self.native_cache.put(addr, .{
            .executable = executable,
            .execution_count = 0,
            .is_valid = true,
        });

        const native_end = std.time.nanoTimestamp();
        self.native_compile_time_ns += @intCast(@max(0, native_end - native_start));
    }

    fn inferTypeFromOpcode(opcode: Opcode) TypeInfo {
        return switch (opcode) {
            .ADD, .SUB, .MUL, .DIV, .MOD, .INC, .DEC, .NEG => .int_type,
            .PUSH_PHI, .PUSH_PI, .PUSH_E => .float_type,
            .EQ, .NE, .LT, .LE, .GT, .GE, .NOT, .AND, .OR => .bool_type,
            else => .unknown,
        };
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // JIT CODE EXECUTION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Try to execute native code for the given address
    /// Returns null if no native code is available
    pub fn tryExecuteNative(self: *Self, addr: u32) ?i64 {
        if (self.native_cache.getPtr(addr)) |entry| {
            if (entry.is_valid) {
                self.native_cache_hits += 1;
                entry.execution_count += 1;
                self.native_instructions += 1;
                return entry.executable.call();
            }
        }
        self.native_cache_misses += 1;
        return null;
    }

    /// Execute compiled code - tries native first, falls back to IR
    pub fn executeCompiledCodeWithNative(self: *Self, addr: u32, compiled: *jit.CompiledCode) !Value {
        // Try native code first
        if (self.tryExecuteNative(addr)) |result| {
            return .{ .int_val = result };
        }

        // Fall back to IR interpretation
        return try self.executeCompiledCode(compiled);
    }

    /// Execute compiled IR code
    pub fn executeCompiledCode(self: *Self, compiled: *jit.CompiledCode) !Value {
        var registers: [32]Value = [_]Value{.{ .nil = {} }} ** 32;
        var pc: usize = 0;

        while (pc < compiled.ir.items.len) {
            const instr = compiled.ir.items[pc];
            pc += 1;
            self.jit_instructions += 1;

            switch (instr.opcode) {
                // ═══════════════════════════════════════════════════════════
                // LOAD/STORE
                // ═══════════════════════════════════════════════════════════
                .LOAD_CONST => {
                    const idx: usize = @intCast(instr.imm);
                    if (idx < self.vm.constants.len) {
                        registers[instr.dest] = self.vm.constants[idx];
                    }
                },

                .LOAD_LOCAL => {
                    const idx: usize = @intCast(instr.imm);
                    if (idx < vm_runtime.MAX_LOCALS) {
                        registers[instr.dest] = self.vm.locals[idx];
                    }
                },

                .STORE_LOCAL => {
                    const idx: usize = @intCast(instr.imm);
                    if (idx < vm_runtime.MAX_LOCALS) {
                        self.vm.locals[idx] = registers[instr.src1];
                    }
                },

                .LOAD_GLOBAL => {
                    const idx: usize = @intCast(instr.imm);
                    if (idx < vm_runtime.MAX_LOCALS) {
                        registers[instr.dest] = self.vm.locals[idx];
                    }
                },

                .STORE_GLOBAL => {
                    const idx: usize = @intCast(instr.imm);
                    if (idx < vm_runtime.MAX_LOCALS) {
                        self.vm.locals[idx] = registers[instr.src1];
                    }
                },

                // ═══════════════════════════════════════════════════════════
                // STACK
                // ═══════════════════════════════════════════════════════════
                .DUP => {
                    registers[instr.dest] = registers[instr.src1];
                },

                .SWAP => {
                    const tmp = registers[instr.src1];
                    registers[instr.src1] = registers[instr.src2];
                    registers[instr.src2] = tmp;
                },

                .POP => {
                    // No-op in register-based IR
                },

                // ═══════════════════════════════════════════════════════════
                // ARITHMETIC
                // ═══════════════════════════════════════════════════════════
                .ADD_INT => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    const b = registers[instr.src2].toInt() orelse 0;
                    registers[instr.dest] = .{ .int_val = a + b };
                },

                .ADD_FLOAT => {
                    const a = registers[instr.src1].toFloat() orelse 0;
                    const b = registers[instr.src2].toFloat() orelse 0;
                    registers[instr.dest] = .{ .float_val = a + b };
                },

                .SUB_INT => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    const b = registers[instr.src2].toInt() orelse 0;
                    registers[instr.dest] = .{ .int_val = a - b };
                },

                .SUB_FLOAT => {
                    const a = registers[instr.src1].toFloat() orelse 0;
                    const b = registers[instr.src2].toFloat() orelse 0;
                    registers[instr.dest] = .{ .float_val = a - b };
                },

                .MUL_INT => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    const b = registers[instr.src2].toInt() orelse 0;
                    registers[instr.dest] = .{ .int_val = a * b };
                },

                .MUL_FLOAT => {
                    const a = registers[instr.src1].toFloat() orelse 0;
                    const b = registers[instr.src2].toFloat() orelse 0;
                    registers[instr.dest] = .{ .float_val = a * b };
                },

                .DIV_INT => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    const b = registers[instr.src2].toInt() orelse 1;
                    if (b == 0) return VMError.DivisionByZero;
                    registers[instr.dest] = .{ .int_val = @divTrunc(a, b) };
                },

                .DIV_FLOAT => {
                    const a = registers[instr.src1].toFloat() orelse 0;
                    const b = registers[instr.src2].toFloat() orelse 1;
                    if (b == 0) return VMError.DivisionByZero;
                    registers[instr.dest] = .{ .float_val = a / b };
                },

                .MOD_INT => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    const b = registers[instr.src2].toInt() orelse 1;
                    if (b == 0) return VMError.DivisionByZero;
                    registers[instr.dest] = .{ .int_val = @mod(a, b) };
                },

                .NEG_INT => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    registers[instr.dest] = .{ .int_val = -a };
                },

                .NEG_FLOAT => {
                    const a = registers[instr.src1].toFloat() orelse 0;
                    registers[instr.dest] = .{ .float_val = -a };
                },

                .INC_INT => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    registers[instr.dest] = .{ .int_val = a + 1 };
                },

                .DEC_INT => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    registers[instr.dest] = .{ .int_val = a - 1 };
                },

                // ═══════════════════════════════════════════════════════════
                // COMPARISON
                // ═══════════════════════════════════════════════════════════
                .CMP_LT_INT => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    const b = registers[instr.src2].toInt() orelse 0;
                    registers[instr.dest] = .{ .bool_val = a < b };
                },

                .CMP_LE_INT => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    const b = registers[instr.src2].toInt() orelse 0;
                    registers[instr.dest] = .{ .bool_val = a <= b };
                },

                .CMP_GT_INT => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    const b = registers[instr.src2].toInt() orelse 0;
                    registers[instr.dest] = .{ .bool_val = a > b };
                },

                .CMP_GE_INT => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    const b = registers[instr.src2].toInt() orelse 0;
                    registers[instr.dest] = .{ .bool_val = a >= b };
                },

                .CMP_EQ_INT => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    const b = registers[instr.src2].toInt() orelse 0;
                    registers[instr.dest] = .{ .bool_val = a == b };
                },

                .CMP_NE_INT => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    const b = registers[instr.src2].toInt() orelse 0;
                    registers[instr.dest] = .{ .bool_val = a != b };
                },

                // ═══════════════════════════════════════════════════════════
                // LOGIC
                // ═══════════════════════════════════════════════════════════
                .NOT => {
                    const a = registers[instr.src1].toBool();
                    registers[instr.dest] = .{ .bool_val = !a };
                },

                .AND => {
                    const a = registers[instr.src1].toBool();
                    const b = registers[instr.src2].toBool();
                    registers[instr.dest] = .{ .bool_val = a and b };
                },

                .OR => {
                    const a = registers[instr.src1].toBool();
                    const b = registers[instr.src2].toBool();
                    registers[instr.dest] = .{ .bool_val = a or b };
                },

                .XOR => {
                    const a = registers[instr.src1].toBool();
                    const b = registers[instr.src2].toBool();
                    registers[instr.dest] = .{ .bool_val = a != b };
                },

                // ═══════════════════════════════════════════════════════════
                // BITWISE
                // ═══════════════════════════════════════════════════════════
                .SHL => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    const b = registers[instr.src2].toInt() orelse 0;
                    const shift: u6 = @intCast(@min(63, @max(0, b)));
                    registers[instr.dest] = .{ .int_val = a << shift };
                },

                .SHR => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    const b = registers[instr.src2].toInt() orelse 0;
                    const shift: u6 = @intCast(@min(63, @max(0, b)));
                    registers[instr.dest] = .{ .int_val = a >> shift };
                },

                .BAND => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    const b = registers[instr.src2].toInt() orelse 0;
                    registers[instr.dest] = .{ .int_val = a & b };
                },

                .BOR => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    const b = registers[instr.src2].toInt() orelse 0;
                    registers[instr.dest] = .{ .int_val = a | b };
                },

                .BXOR => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    const b = registers[instr.src2].toInt() orelse 0;
                    registers[instr.dest] = .{ .int_val = a ^ b };
                },

                .BNOT => {
                    const a = registers[instr.src1].toInt() orelse 0;
                    registers[instr.dest] = .{ .int_val = ~a };
                },

                // ═══════════════════════════════════════════════════════════
                // CONTROL FLOW
                // ═══════════════════════════════════════════════════════════
                .JUMP => {
                    pc = @intCast(instr.imm);
                },

                .JUMP_IF_ZERO => {
                    const cond = registers[instr.src1].toBool();
                    if (!cond) {
                        pc = @intCast(instr.imm);
                    }
                },

                .JUMP_IF_NOT_ZERO => {
                    const cond = registers[instr.src1].toBool();
                    if (cond) {
                        pc = @intCast(instr.imm);
                    }
                },

                .LOOP_BACK => {
                    // Jump back to start of trace
                    pc = 0;
                },

                .GUARD_TYPE => {
                    const expected_type: u8 = @intCast(instr.imm);
                    const actual = registers[instr.src1];
                    const actual_type: u8 = @intFromEnum(actual);
                    if (actual_type != expected_type) {
                        self.jit_compiler.invalidate(compiled.start_addr);
                        return .{ .nil = {} };
                    }
                },

                .DEOPT => {
                    self.jit_compiler.invalidate(compiled.start_addr);
                    return .{ .nil = {} };
                },

                // ═══════════════════════════════════════════════════════════
                // TRYTE OPERATIONS
                // ═══════════════════════════════════════════════════════════
                .TRYTE_ADD => {
                    const a = registers[instr.src1].toTryte() orelse 0;
                    const b = registers[instr.src2].toTryte() orelse 0;
                    const sum: i16 = @as(i16, a) + @as(i16, b);
                    registers[instr.dest] = .{ .tryte_val = wrapTryte(sum) };
                },

                .TRYTE_SUB => {
                    const a = registers[instr.src1].toTryte() orelse 0;
                    const b = registers[instr.src2].toTryte() orelse 0;
                    const diff: i16 = @as(i16, a) - @as(i16, b);
                    registers[instr.dest] = .{ .tryte_val = wrapTryte(diff) };
                },

                .TRYTE_MUL => {
                    const a = registers[instr.src1].toTryte() orelse 0;
                    const b = registers[instr.src2].toTryte() orelse 0;
                    var prod: i16 = @as(i16, a) * @as(i16, b);
                    while (prod > 13) prod -= 27;
                    while (prod < -13) prod += 27;
                    registers[instr.dest] = .{ .tryte_val = @intCast(prod) };
                },

                .TRYTE_NEG => {
                    const a = registers[instr.src1].toTryte() orelse 0;
                    registers[instr.dest] = .{ .tryte_val = -a };
                },

                .TRYTE_INC => {
                    const a = registers[instr.src1].toTryte() orelse 0;
                    registers[instr.dest] = .{ .tryte_val = wrapTryte(@as(i16, a) + 1) };
                },

                .TRYTE_DEC => {
                    const a = registers[instr.src1].toTryte() orelse 0;
                    registers[instr.dest] = .{ .tryte_val = wrapTryte(@as(i16, a) - 1) };
                },

                .TRYTE_LT => {
                    const a = registers[instr.src1].toTryte() orelse 0;
                    const b = registers[instr.src2].toTryte() orelse 0;
                    registers[instr.dest] = .{ .bool_val = a < b };
                },

                .TRYTE_EQ => {
                    const a = registers[instr.src1].toTryte() orelse 0;
                    const b = registers[instr.src2].toTryte() orelse 0;
                    registers[instr.dest] = .{ .bool_val = a == b };
                },

                // ═══════════════════════════════════════════════════════════
                // SACRED CONSTANTS
                // ═══════════════════════════════════════════════════════════
                .LOAD_PHI => {
                    registers[instr.dest] = .{ .float_val = PHI };
                },

                .LOAD_PI => {
                    registers[instr.dest] = .{ .float_val = vm_runtime.PI };
                },

                .LOAD_E => {
                    registers[instr.dest] = .{ .float_val = vm_runtime.E };
                },

                .GOLDEN_IDENTITY_IR => {
                    registers[instr.dest] = .{ .float_val = GOLDEN_IDENTITY };
                },

                .SACRED_FORMULA_IR => {
                    // V = n × 3^k × π^m × φ^p × e^q
                    // Simplified: just return PHI for now
                    registers[instr.dest] = .{ .float_val = PHI };
                },

                // ═══════════════════════════════════════════════════════════
                // RETURN
                // ═══════════════════════════════════════════════════════════
                .RETURN => {
                    return registers[instr.dest];
                },
            }
        }

        return .{ .nil = {} };
    }

    /// Wrap tryte value to balanced ternary range [-13, 13]
    fn wrapTryte(val: i16) i8 {
        var v = val;
        while (v > 13) v -= 27;
        while (v < -13) v += 27;
        return @intCast(v);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DEOPTIMIZATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Invalidate compiled code at address
    pub fn invalidateCode(self: *Self, addr: u32) void {
        self.jit_compiler.invalidate(addr);
    }

    /// Invalidate all compiled code
    pub fn invalidateAll(self: *Self) void {
        var iter = self.jit_compiler.code_cache.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.is_valid = false;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONFIGURATION
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn setMode(self: *Self, mode: JITMode) void {
        self.config.mode = mode;
    }

    pub fn setHotThreshold(self: *Self, threshold: u32) void {
        self.config.hot_threshold = threshold;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // METRICS
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn getMetrics(self: *const Self) AdapterMetrics {
        const jit_metrics = self.jit_compiler.getMetrics();

        return AdapterMetrics{
            .total_instructions = self.interpreter_instructions + self.jit_instructions + self.native_instructions,
            .jit_instructions = self.jit_instructions,
            .interpreter_instructions = self.interpreter_instructions,
            .hot_spots_detected = jit_metrics.hot_spots,
            .traces_compiled = jit_metrics.traces_compiled,
            .deoptimizations = jit_metrics.deoptimizations,
            .cache_hits = jit_metrics.cache_hits + self.native_cache_hits,
            .cache_misses = jit_metrics.cache_misses + self.native_cache_misses,
            .total_time_ns = self.vm.execution_time_ns,
            .jit_compile_time_ns = self.jit_compile_time_ns + self.native_compile_time_ns,
        };
    }

    /// Get native-specific metrics
    pub fn getNativeMetrics(self: *const Self) NativeMetrics {
        return .{
            .native_instructions = self.native_instructions,
            .native_cache_hits = self.native_cache_hits,
            .native_cache_misses = self.native_cache_misses,
            .native_compile_time_ns = self.native_compile_time_ns,
            .cached_functions = self.native_cache.count(),
        };
    }

    pub fn getHotSpots(self: *Self, buffer: []HotSpotInfo) []HotSpotInfo {
        var count: usize = 0;
        var iter = self.jit_compiler.execution_counts.iterator();

        while (iter.next()) |entry| {
            if (count >= buffer.len) break;

            const addr = entry.key_ptr.*;
            const exec_count = entry.value_ptr.*;

            if (exec_count >= self.config.hot_threshold) {
                const is_compiled = if (self.jit_compiler.code_cache.getPtr(addr)) |code|
                    code.is_valid
                else
                    false;

                const trace_len = if (self.jit_compiler.traces.getPtr(addr)) |trace|
                    trace.entries.items.len
                else
                    0;

                buffer[count] = HotSpotInfo{
                    .address = addr,
                    .execution_count = exec_count,
                    .is_compiled = is_compiled,
                    .trace_length = trace_len,
                };
                count += 1;
            }
        }

        return buffer[0..count];
    }

    /// Get VM reference for direct access
    pub fn getVM(self: *Self) *VM {
        return &self.vm;
    }

    /// Get JIT compiler reference
    pub fn getJIT(self: *Self) *JITCompiler {
        return &self.jit_compiler;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "JITAdapter init" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();

    try std.testing.expectEqual(JITMode.Mixed, adapter.config.mode);
    try std.testing.expectEqual(@as(u32, jit.HOT_THRESHOLD), adapter.config.hot_threshold);
}

test "JITAdapter interpreter mode" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();
    
    // Set interpreter mode
    adapter.setMode(.Interpreter);
    adapter.config.use_fast_path = false;
    
    const code = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0x00, 0x00, // PUSH_CONST idx=0
        @intFromEnum(Opcode.HALT), // HALT
    };
    const constants = [_]Value{.{ .int_val = 42 }};
    
    const result = try adapter.execute(&code, &constants);
    
    try std.testing.expect(result.value == .int_val);
    try std.testing.expectEqual(@as(i64, 42), result.value.int_val);
    try std.testing.expect(!result.used_jit);
}

test "JITAdapter metrics" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();

    const metrics = adapter.getMetrics();
    try std.testing.expectEqual(@as(u64, 0), metrics.total_instructions);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}

test "JITAdapter native code compilation" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();

    // Manually compile some IR to native code
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 42 },
        .{ .opcode = .RETURN, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    try adapter.compileToNative(0, &ir);

    // Check that native code was cached
    try std.testing.expect(adapter.native_cache.contains(0));
}

test "JITAdapter execute native code" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();

    // Compile IR to native
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 42 },
        .{ .opcode = .RETURN, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    try adapter.compileToNative(0, &ir);

    // Execute native code
    const result = adapter.tryExecuteNative(0);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(i64, 42), result.?);
}

test "JITAdapter native arithmetic" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();

    // Compile: return 2 + 3
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 2 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    try adapter.compileToNative(100, &ir);

    const result = adapter.tryExecuteNative(100);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(i64, 5), result.?);
}

test "JITAdapter native metrics" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();

    // Compile some code
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 1 },
        .{ .opcode = .RETURN, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    try adapter.compileToNative(0, &ir);

    // Execute multiple times
    _ = adapter.tryExecuteNative(0);
    _ = adapter.tryExecuteNative(0);
    _ = adapter.tryExecuteNative(0);

    const metrics = adapter.getNativeMetrics();
    try std.testing.expectEqual(@as(u64, 3), metrics.native_cache_hits);
    try std.testing.expectEqual(@as(usize, 1), metrics.cached_functions);
}

test "Benchmark: VM vs JIT IR vs Native" {
    const allocator = std.testing.allocator;

    // IR for: (2 + 3) * 7 = 35
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 2 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .LOAD_CONST, .dest = 3, .src1 = 0, .src2 = 0, .imm = 7 },
        .{ .opcode = .MUL_INT, .dest = 4, .src1 = 2, .src2 = 3, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 4, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const iterations: usize = 10000;

    // Benchmark Native Code
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();
    try adapter.compileToNative(0, &ir);

    const native_start = std.time.nanoTimestamp();
    var native_result: i64 = 0;
    for (0..iterations) |_| {
        native_result = adapter.tryExecuteNative(0).?;
    }
    const native_end = std.time.nanoTimestamp();
    const native_time = native_end - native_start;

    // Verify result
    try std.testing.expectEqual(@as(i64, 35), native_result);

    // Print benchmark results
    if (@import("builtin").mode == .Debug) {
        std.debug.print("\n=== VM vs JIT IR vs Native Benchmark ===\n", .{});
        std.debug.print("Iterations: {d}\n", .{iterations});
        std.debug.print("Native:     {d} ns ({d:.2} ns/iter)\n", .{
            native_time,
            @as(f64, @floatFromInt(native_time)) / @as(f64, @floatFromInt(iterations)),
        });
        std.debug.print("Result: {d} (expected 35)\n", .{native_result});
    }
}

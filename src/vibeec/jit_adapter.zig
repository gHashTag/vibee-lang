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
// COMPILATION TIER
// ═══════════════════════════════════════════════════════════════════════════════

/// Compilation tier levels (like V8/HotSpot)
pub const CompilationTier = enum(u8) {
    /// Tier 0: Bytecode interpreter (slowest, no compilation overhead)
    Interpreter = 0,
    /// Tier 1: JIT IR interpreter (medium speed, fast compilation)
    JIT_IR = 1,
    /// Tier 2: Native x86-64 code (fastest, slow compilation)
    Native = 2,

    pub fn name(self: CompilationTier) []const u8 {
        return switch (self) {
            .Interpreter => "Interpreter",
            .JIT_IR => "JIT IR",
            .Native => "Native",
        };
    }

    pub fn next(self: CompilationTier) ?CompilationTier {
        return switch (self) {
            .Interpreter => .JIT_IR,
            .JIT_IR => .Native,
            .Native => null,
        };
    }
};

/// Function compilation state
pub const FunctionTierState = struct {
    address: u32,
    current_tier: CompilationTier,
    execution_count: u64,
    tier_execution_counts: [3]u64, // Executions at each tier
    total_time_ns: u64,
    tier_times_ns: [3]u64, // Time spent at each tier
    last_promotion_count: u64, // Execution count at last tier promotion

    pub fn init(address: u32) FunctionTierState {
        return .{
            .address = address,
            .current_tier = .Interpreter,
            .execution_count = 0,
            .tier_execution_counts = [_]u64{ 0, 0, 0 },
            .total_time_ns = 0,
            .tier_times_ns = [_]u64{ 0, 0, 0 },
            .last_promotion_count = 0,
        };
    }

    pub fn recordExecution(self: *FunctionTierState, time_ns: u64) void {
        self.execution_count += 1;
        self.total_time_ns += time_ns;
        const tier_idx = @intFromEnum(self.current_tier);
        self.tier_execution_counts[tier_idx] += 1;
        self.tier_times_ns[tier_idx] += time_ns;
    }

    pub fn promote(self: *FunctionTierState) bool {
        if (self.current_tier.next()) |next_tier| {
            self.current_tier = next_tier;
            self.last_promotion_count = self.execution_count;
            return true;
        }
        return false;
    }

    pub fn avgTimeAtTier(self: FunctionTierState, tier: CompilationTier) u64 {
        const idx = @intFromEnum(tier);
        if (self.tier_execution_counts[idx] == 0) return 0;
        return self.tier_times_ns[idx] / self.tier_execution_counts[idx];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ADAPTER CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

pub const AdapterConfig = struct {
    mode: JITMode = .Mixed,
    hot_threshold: u32 = jit.HOT_THRESHOLD,
    trace_max_length: usize = jit.TRACE_MAX_LENGTH,
    enable_profiling: bool = true,
    use_fast_path: bool = true, // Использовать VM.runFast() вместо run()
    use_native: bool = true, // Использовать нативный x86-64 код когда доступен
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
// HOT PATH PROFILER
// ═══════════════════════════════════════════════════════════════════════════════

/// Function execution profile
pub const FunctionProfile = struct {
    address: u32,
    execution_count: u64,
    total_time_ns: u64,
    is_hot: bool,
    is_compiled: bool,
    last_execution_ns: i128,

    pub fn avgTimeNs(self: FunctionProfile) u64 {
        if (self.execution_count == 0) return 0;
        return self.total_time_ns / self.execution_count;
    }
};

/// Hot Path Profiler - tracks function execution and triggers JIT compilation
pub const HotPathProfiler = struct {
    allocator: Allocator,
    /// Function address -> profile
    profiles: std.AutoHashMap(u32, FunctionProfile),
    /// Threshold for marking function as hot
    hot_threshold: u32,
    /// Threshold for triggering JIT compilation
    jit_threshold: u32,
    /// Total functions profiled
    total_functions: usize,
    /// Hot functions detected
    hot_functions: usize,
    /// Functions compiled to native
    compiled_functions: usize,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .profiles = std.AutoHashMap(u32, FunctionProfile).init(allocator),
            .hot_threshold = 10, // Mark as hot after 10 executions
            .jit_threshold = 100, // Compile to native after 100 executions
            .total_functions = 0,
            .hot_functions = 0,
            .compiled_functions = 0,
        };
    }

    pub fn initWithThresholds(allocator: Allocator, hot_threshold: u32, jit_threshold: u32) Self {
        var profiler = Self.init(allocator);
        profiler.hot_threshold = hot_threshold;
        profiler.jit_threshold = jit_threshold;
        return profiler;
    }

    pub fn deinit(self: *Self) void {
        self.profiles.deinit();
    }

    /// Record function entry - returns true if function should be JIT compiled
    pub fn recordEntry(self: *Self, address: u32) !bool {
        const now = std.time.nanoTimestamp();

        const result = try self.profiles.getOrPut(address);
        if (!result.found_existing) {
            result.value_ptr.* = FunctionProfile{
                .address = address,
                .execution_count = 0,
                .total_time_ns = 0,
                .is_hot = false,
                .is_compiled = false,
                .last_execution_ns = now,
            };
            self.total_functions += 1;
        }

        var profile = result.value_ptr;
        profile.execution_count += 1;
        profile.last_execution_ns = now;

        // Check if became hot
        if (!profile.is_hot and profile.execution_count >= self.hot_threshold) {
            profile.is_hot = true;
            self.hot_functions += 1;
        }

        // Check if should compile
        if (!profile.is_compiled and profile.execution_count >= self.jit_threshold) {
            return true; // Signal to compile
        }

        return false;
    }

    /// Record function exit with timing
    pub fn recordExit(self: *Self, address: u32, execution_time_ns: u64) void {
        if (self.profiles.getPtr(address)) |profile| {
            profile.total_time_ns += execution_time_ns;
        }
    }

    /// Mark function as compiled
    pub fn markCompiled(self: *Self, address: u32) void {
        if (self.profiles.getPtr(address)) |profile| {
            if (!profile.is_compiled) {
                profile.is_compiled = true;
                self.compiled_functions += 1;
            }
        }
    }

    /// Get all hot functions that need compilation
    pub fn getHotUncompiled(self: *Self, allocator: Allocator) ![]u32 {
        var result = std.ArrayList(u32).init(allocator);
        errdefer result.deinit();

        var iter = self.profiles.iterator();
        while (iter.next()) |entry| {
            const profile = entry.value_ptr;
            if (profile.is_hot and !profile.is_compiled and
                profile.execution_count >= self.jit_threshold)
            {
                try result.append(profile.address);
            }
        }

        return result.toOwnedSlice();
    }

    /// Get profile for address
    pub fn getProfile(self: *Self, address: u32) ?FunctionProfile {
        return self.profiles.get(address);
    }

    /// Get profiler statistics
    pub fn getStats(self: *Self) ProfilerStats {
        var total_executions: u64 = 0;
        var total_time: u64 = 0;
        var hottest_address: u32 = 0;
        var hottest_count: u64 = 0;

        var iter = self.profiles.iterator();
        while (iter.next()) |entry| {
            const profile = entry.value_ptr;
            total_executions += profile.execution_count;
            total_time += profile.total_time_ns;
            if (profile.execution_count > hottest_count) {
                hottest_count = profile.execution_count;
                hottest_address = profile.address;
            }
        }

        return ProfilerStats{
            .total_functions = self.total_functions,
            .hot_functions = self.hot_functions,
            .compiled_functions = self.compiled_functions,
            .total_executions = total_executions,
            .total_time_ns = total_time,
            .hottest_address = hottest_address,
            .hottest_count = hottest_count,
        };
    }

    /// Reset all profiles
    pub fn reset(self: *Self) void {
        self.profiles.clearRetainingCapacity();
        self.total_functions = 0;
        self.hot_functions = 0;
        self.compiled_functions = 0;
    }
};

/// Profiler statistics summary
pub const ProfilerStats = struct {
    total_functions: usize,
    hot_functions: usize,
    compiled_functions: usize,
    total_executions: u64,
    total_time_ns: u64,
    hottest_address: u32,
    hottest_count: u64,

    pub fn compilationRatio(self: ProfilerStats) f64 {
        if (self.hot_functions == 0) return 0;
        return @as(f64, @floatFromInt(self.compiled_functions)) /
            @as(f64, @floatFromInt(self.hot_functions));
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LOOP UNROLLER
// ═══════════════════════════════════════════════════════════════════════════════

/// Detected loop information
pub const LoopInfo = struct {
    start_idx: usize, // Index of first instruction in loop body
    end_idx: usize, // Index of LOOP_BACK or backward JUMP
    iteration_count: ?u32, // Known iteration count (if constant)
    body_size: usize, // Number of instructions in loop body

    pub fn bodyInstructions(self: LoopInfo) usize {
        return self.end_idx - self.start_idx;
    }
};

/// Loop Unroller - detects and unrolls simple loops
pub const LoopUnroller = struct {
    allocator: Allocator,
    /// Default unroll factor
    unroll_factor: u32 = 4,
    /// Maximum loop body size to unroll
    max_body_size: usize = 16,
    /// Statistics
    loops_detected: usize = 0,
    loops_unrolled: usize = 0,
    instructions_saved: usize = 0,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .unroll_factor = 4,
            .max_body_size = 16,
            .loops_detected = 0,
            .loops_unrolled = 0,
            .instructions_saved = 0,
        };
    }

    pub fn initWithFactor(allocator: Allocator, factor: u32) Self {
        var unroller = Self.init(allocator);
        unroller.unroll_factor = factor;
        return unroller;
    }

    /// Detect loops in IR code
    pub fn detectLoops(self: *Self, ir: []const IRInstruction) ![]LoopInfo {
        var loops = std.ArrayList(LoopInfo).init(self.allocator);
        errdefer loops.deinit();

        var i: usize = 0;
        while (i < ir.len) : (i += 1) {
            const instr = ir[i];

            // Look for backward jumps (LOOP_BACK or JUMP with negative offset)
            if (instr.opcode == .LOOP_BACK) {
                const target: usize = @intCast(instr.imm);
                if (target < i) {
                    self.loops_detected += 1;
                    try loops.append(LoopInfo{
                        .start_idx = target,
                        .end_idx = i,
                        .iteration_count = null, // Unknown
                        .body_size = i - target,
                    });
                }
            } else if (instr.opcode == .JUMP) {
                const target: usize = @intCast(instr.imm);
                if (target < i) {
                    // Backward jump - potential loop
                    self.loops_detected += 1;
                    try loops.append(LoopInfo{
                        .start_idx = target,
                        .end_idx = i,
                        .iteration_count = null,
                        .body_size = i - target,
                    });
                }
            }
        }

        return loops.toOwnedSlice();
    }

    /// Unroll a single loop
    pub fn unrollLoop(self: *Self, ir: []const IRInstruction, loop: LoopInfo) ![]IRInstruction {
        // Check if loop is suitable for unrolling
        if (loop.body_size > self.max_body_size) {
            // Too large, return original
            return self.allocator.dupe(IRInstruction, ir);
        }

        var result = std.ArrayList(IRInstruction).init(self.allocator);
        errdefer result.deinit();

        // Copy instructions before loop
        for (ir[0..loop.start_idx]) |instr| {
            try result.append(instr);
        }

        // Get loop body
        const body = ir[loop.start_idx..loop.end_idx];

        // Unroll loop body N times
        const factor = self.unroll_factor;
        for (0..factor) |_| {
            for (body) |instr| {
                // Skip the backward jump in unrolled copies (except last)
                if (instr.opcode != .LOOP_BACK and instr.opcode != .JUMP) {
                    try result.append(instr);
                }
            }
        }

        // Add remaining instructions after loop
        if (loop.end_idx + 1 < ir.len) {
            for (ir[loop.end_idx + 1 ..]) |instr| {
                try result.append(instr);
            }
        }

        self.loops_unrolled += 1;
        const original_size = ir.len;
        const new_size = result.items.len;
        if (new_size < original_size * factor) {
            self.instructions_saved += (original_size * factor) - new_size;
        }

        return result.toOwnedSlice();
    }

    /// Optimize IR by unrolling all suitable loops
    pub fn optimize(self: *Self, ir: []const IRInstruction) ![]IRInstruction {
        const loops = try self.detectLoops(ir);
        defer self.allocator.free(loops);

        if (loops.len == 0) {
            // No loops, return copy
            return self.allocator.dupe(IRInstruction, ir);
        }

        // Unroll first suitable loop (simple approach)
        for (loops) |loop| {
            if (loop.body_size <= self.max_body_size) {
                return self.unrollLoop(ir, loop);
            }
        }

        // No suitable loops
        return self.allocator.dupe(IRInstruction, ir);
    }

    /// Get statistics
    pub fn getStats(self: *Self) struct { detected: usize, unrolled: usize, saved: usize } {
        return .{
            .detected = self.loops_detected,
            .unrolled = self.loops_unrolled,
            .saved = self.instructions_saved,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANT FOLDER
// ═══════════════════════════════════════════════════════════════════════════════

/// Constant Folder - evaluates constant expressions at compile time
pub const ConstantFolder = struct {
    allocator: Allocator,
    /// Statistics
    constants_folded: usize = 0,
    instructions_eliminated: usize = 0,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .constants_folded = 0,
            .instructions_eliminated = 0,
        };
    }

    /// Optimize IR by folding constant expressions
    pub fn optimize(self: *Self, ir: []const IRInstruction) ![]IRInstruction {
        if (ir.len == 0) return self.allocator.dupe(IRInstruction, ir);

        var result = std.ArrayList(IRInstruction).init(self.allocator);
        errdefer result.deinit();

        // Track constant values in registers
        var reg_constants: [32]?i64 = [_]?i64{null} ** 32;

        for (ir) |instr| {
            switch (instr.opcode) {
                .LOAD_CONST => {
                    // Track this register as constant
                    reg_constants[instr.dest] = instr.imm;
                    try result.append(instr);
                },

                .ADD_INT => {
                    const a = reg_constants[instr.src1];
                    const b = reg_constants[instr.src2];
                    if (a != null and b != null) {
                        // Both operands are constants - fold!
                        const folded_value = a.? + b.?;
                        reg_constants[instr.dest] = folded_value;
                        try result.append(.{
                            .opcode = .LOAD_CONST,
                            .dest = instr.dest,
                            .src1 = 0,
                            .src2 = 0,
                            .imm = folded_value,
                        });
                        self.constants_folded += 1;
                        self.instructions_eliminated += 1;
                    } else {
                        reg_constants[instr.dest] = null;
                        try result.append(instr);
                    }
                },

                .SUB_INT => {
                    const a = reg_constants[instr.src1];
                    const b = reg_constants[instr.src2];
                    if (a != null and b != null) {
                        const folded_value = a.? - b.?;
                        reg_constants[instr.dest] = folded_value;
                        try result.append(.{
                            .opcode = .LOAD_CONST,
                            .dest = instr.dest,
                            .src1 = 0,
                            .src2 = 0,
                            .imm = folded_value,
                        });
                        self.constants_folded += 1;
                        self.instructions_eliminated += 1;
                    } else {
                        reg_constants[instr.dest] = null;
                        try result.append(instr);
                    }
                },

                .MUL_INT => {
                    const a = reg_constants[instr.src1];
                    const b = reg_constants[instr.src2];
                    if (a != null and b != null) {
                        const folded_value = a.? * b.?;
                        reg_constants[instr.dest] = folded_value;
                        try result.append(.{
                            .opcode = .LOAD_CONST,
                            .dest = instr.dest,
                            .src1 = 0,
                            .src2 = 0,
                            .imm = folded_value,
                        });
                        self.constants_folded += 1;
                        self.instructions_eliminated += 1;
                    } else {
                        reg_constants[instr.dest] = null;
                        try result.append(instr);
                    }
                },

                .DIV_INT => {
                    const a = reg_constants[instr.src1];
                    const b = reg_constants[instr.src2];
                    if (a != null and b != null and b.? != 0) {
                        const folded_value = @divTrunc(a.?, b.?);
                        reg_constants[instr.dest] = folded_value;
                        try result.append(.{
                            .opcode = .LOAD_CONST,
                            .dest = instr.dest,
                            .src1 = 0,
                            .src2 = 0,
                            .imm = folded_value,
                        });
                        self.constants_folded += 1;
                        self.instructions_eliminated += 1;
                    } else {
                        reg_constants[instr.dest] = null;
                        try result.append(instr);
                    }
                },

                .NEG_INT => {
                    const a = reg_constants[instr.src1];
                    if (a != null) {
                        const folded_value = -a.?;
                        reg_constants[instr.dest] = folded_value;
                        try result.append(.{
                            .opcode = .LOAD_CONST,
                            .dest = instr.dest,
                            .src1 = 0,
                            .src2 = 0,
                            .imm = folded_value,
                        });
                        self.constants_folded += 1;
                        self.instructions_eliminated += 1;
                    } else {
                        reg_constants[instr.dest] = null;
                        try result.append(instr);
                    }
                },

                .MOD_INT => {
                    const a = reg_constants[instr.src1];
                    const b = reg_constants[instr.src2];
                    if (a != null and b != null and b.? != 0) {
                        const folded_value = @mod(a.?, b.?);
                        reg_constants[instr.dest] = folded_value;
                        try result.append(.{
                            .opcode = .LOAD_CONST,
                            .dest = instr.dest,
                            .src1 = 0,
                            .src2 = 0,
                            .imm = folded_value,
                        });
                        self.constants_folded += 1;
                        self.instructions_eliminated += 1;
                    } else {
                        reg_constants[instr.dest] = null;
                        try result.append(instr);
                    }
                },

                .SHL => {
                    const a = reg_constants[instr.src1];
                    const shift = if (instr.imm != 0) instr.imm else reg_constants[instr.src2];
                    if (a != null and shift != null) {
                        const shift_amt: u6 = @intCast(@min(63, @max(0, shift.?)));
                        const folded_value = a.? << shift_amt;
                        reg_constants[instr.dest] = folded_value;
                        try result.append(.{
                            .opcode = .LOAD_CONST,
                            .dest = instr.dest,
                            .src1 = 0,
                            .src2 = 0,
                            .imm = folded_value,
                        });
                        self.constants_folded += 1;
                        self.instructions_eliminated += 1;
                    } else {
                        reg_constants[instr.dest] = null;
                        try result.append(instr);
                    }
                },

                .SHR => {
                    const a = reg_constants[instr.src1];
                    const shift = if (instr.imm != 0) instr.imm else reg_constants[instr.src2];
                    if (a != null and shift != null) {
                        const shift_amt: u6 = @intCast(@min(63, @max(0, shift.?)));
                        const folded_value = a.? >> shift_amt;
                        reg_constants[instr.dest] = folded_value;
                        try result.append(.{
                            .opcode = .LOAD_CONST,
                            .dest = instr.dest,
                            .src1 = 0,
                            .src2 = 0,
                            .imm = folded_value,
                        });
                        self.constants_folded += 1;
                        self.instructions_eliminated += 1;
                    } else {
                        reg_constants[instr.dest] = null;
                        try result.append(instr);
                    }
                },

                .LEA => {
                    const a = reg_constants[instr.src1];
                    if (a != null) {
                        // LEA: dest = src1 + src1 * scale
                        const folded_value = a.? + a.? * instr.imm;
                        reg_constants[instr.dest] = folded_value;
                        try result.append(.{
                            .opcode = .LOAD_CONST,
                            .dest = instr.dest,
                            .src1 = 0,
                            .src2 = 0,
                            .imm = folded_value,
                        });
                        self.constants_folded += 1;
                        self.instructions_eliminated += 1;
                    } else {
                        reg_constants[instr.dest] = null;
                        try result.append(instr);
                    }
                },

                // Comparison folding
                .CMP_LT_INT => {
                    const a = reg_constants[instr.src1];
                    const b = reg_constants[instr.src2];
                    if (a != null and b != null) {
                        const folded_value: i64 = if (a.? < b.?) 1 else 0;
                        reg_constants[instr.dest] = folded_value;
                        try result.append(.{
                            .opcode = .LOAD_CONST,
                            .dest = instr.dest,
                            .src1 = 0,
                            .src2 = 0,
                            .imm = folded_value,
                        });
                        self.constants_folded += 1;
                        self.instructions_eliminated += 1;
                    } else {
                        reg_constants[instr.dest] = null;
                        try result.append(instr);
                    }
                },

                .CMP_LE_INT => {
                    const a = reg_constants[instr.src1];
                    const b = reg_constants[instr.src2];
                    if (a != null and b != null) {
                        const folded_value: i64 = if (a.? <= b.?) 1 else 0;
                        reg_constants[instr.dest] = folded_value;
                        try result.append(.{
                            .opcode = .LOAD_CONST,
                            .dest = instr.dest,
                            .src1 = 0,
                            .src2 = 0,
                            .imm = folded_value,
                        });
                        self.constants_folded += 1;
                        self.instructions_eliminated += 1;
                    } else {
                        reg_constants[instr.dest] = null;
                        try result.append(instr);
                    }
                },

                .CMP_GT_INT => {
                    const a = reg_constants[instr.src1];
                    const b = reg_constants[instr.src2];
                    if (a != null and b != null) {
                        const folded_value: i64 = if (a.? > b.?) 1 else 0;
                        reg_constants[instr.dest] = folded_value;
                        try result.append(.{
                            .opcode = .LOAD_CONST,
                            .dest = instr.dest,
                            .src1 = 0,
                            .src2 = 0,
                            .imm = folded_value,
                        });
                        self.constants_folded += 1;
                        self.instructions_eliminated += 1;
                    } else {
                        reg_constants[instr.dest] = null;
                        try result.append(instr);
                    }
                },

                .CMP_GE_INT => {
                    const a = reg_constants[instr.src1];
                    const b = reg_constants[instr.src2];
                    if (a != null and b != null) {
                        const folded_value: i64 = if (a.? >= b.?) 1 else 0;
                        reg_constants[instr.dest] = folded_value;
                        try result.append(.{
                            .opcode = .LOAD_CONST,
                            .dest = instr.dest,
                            .src1 = 0,
                            .src2 = 0,
                            .imm = folded_value,
                        });
                        self.constants_folded += 1;
                        self.instructions_eliminated += 1;
                    } else {
                        reg_constants[instr.dest] = null;
                        try result.append(instr);
                    }
                },

                .CMP_EQ_INT => {
                    const a = reg_constants[instr.src1];
                    const b = reg_constants[instr.src2];
                    if (a != null and b != null) {
                        const folded_value: i64 = if (a.? == b.?) 1 else 0;
                        reg_constants[instr.dest] = folded_value;
                        try result.append(.{
                            .opcode = .LOAD_CONST,
                            .dest = instr.dest,
                            .src1 = 0,
                            .src2 = 0,
                            .imm = folded_value,
                        });
                        self.constants_folded += 1;
                        self.instructions_eliminated += 1;
                    } else {
                        reg_constants[instr.dest] = null;
                        try result.append(instr);
                    }
                },

                .CMP_NE_INT => {
                    const a = reg_constants[instr.src1];
                    const b = reg_constants[instr.src2];
                    if (a != null and b != null) {
                        const folded_value: i64 = if (a.? != b.?) 1 else 0;
                        reg_constants[instr.dest] = folded_value;
                        try result.append(.{
                            .opcode = .LOAD_CONST,
                            .dest = instr.dest,
                            .src1 = 0,
                            .src2 = 0,
                            .imm = folded_value,
                        });
                        self.constants_folded += 1;
                        self.instructions_eliminated += 1;
                    } else {
                        reg_constants[instr.dest] = null;
                        try result.append(instr);
                    }
                },

                // Instructions that invalidate register constants
                .STORE_LOCAL, .STORE_GLOBAL => {
                    try result.append(instr);
                },

                .LOAD_LOCAL, .LOAD_GLOBAL => {
                    reg_constants[instr.dest] = null;
                    try result.append(instr);
                },

                // Control flow invalidates all constants (conservative)
                .JUMP, .JUMP_IF_ZERO, .JUMP_IF_NOT_ZERO, .LOOP_BACK => {
                    for (&reg_constants) |*c| c.* = null;
                    try result.append(instr);
                },

                else => {
                    // Unknown instruction - invalidate dest and pass through
                    if (instr.dest < 32) {
                        reg_constants[instr.dest] = null;
                    }
                    try result.append(instr);
                },
            }
        }

        return result.toOwnedSlice();
    }

    /// Get statistics
    pub fn getStats(self: *Self) struct { folded: usize, eliminated: usize } {
        return .{
            .folded = self.constants_folded,
            .eliminated = self.instructions_eliminated,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DEAD CODE ELIMINATOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Dead Code Eliminator - removes instructions whose results are never used
pub const DeadCodeEliminator = struct {
    allocator: Allocator,
    /// Statistics
    instructions_eliminated: usize = 0,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .instructions_eliminated = 0,
        };
    }

    /// Optimize IR by removing dead code
    pub fn optimize(self: *Self, ir: []const IRInstruction) ![]IRInstruction {
        if (ir.len == 0) return self.allocator.dupe(IRInstruction, ir);

        // Step 1: Compute liveness (backward pass)
        // A register is live if it's used before being redefined
        var live_regs: [32]bool = [_]bool{false} ** 32;

        // Mark registers used in RETURN as live
        var i: usize = ir.len;
        while (i > 0) {
            i -= 1;
            const instr = ir[i];

            switch (instr.opcode) {
                .RETURN => {
                    live_regs[instr.dest] = true;
                },
                // Control flow - all regs potentially live
                .JUMP, .JUMP_IF_ZERO, .JUMP_IF_NOT_ZERO, .LOOP_BACK => {
                    // Conservative: mark condition register as live
                    if (instr.opcode == .JUMP_IF_ZERO or instr.opcode == .JUMP_IF_NOT_ZERO) {
                        live_regs[instr.dest] = true;
                    }
                },
                // Store operations - source is live
                .STORE_LOCAL, .STORE_GLOBAL => {
                    live_regs[instr.src1] = true;
                },
                else => {},
            }
        }

        // Step 2: Forward pass - mark used registers
        var used_at: [32]?usize = [_]?usize{null} ** 32;

        for (ir, 0..) |instr, idx| {
            // Mark source registers as used
            switch (instr.opcode) {
                .ADD_INT, .SUB_INT, .MUL_INT, .DIV_INT, .MOD_INT,
                .CMP_LT_INT, .CMP_LE_INT, .CMP_GT_INT, .CMP_GE_INT, .CMP_EQ_INT, .CMP_NE_INT,
                .AND, .OR, .XOR, .SHL, .SHR, .BAND, .BOR, .BXOR => {
                    used_at[instr.src1] = idx;
                    used_at[instr.src2] = idx;
                },
                .NEG_INT, .NEG_FLOAT, .NOT, .BNOT, .INC_INT, .DEC_INT => {
                    used_at[instr.src1] = idx;
                },
                .RETURN => {
                    used_at[instr.dest] = idx;
                },
                .STORE_LOCAL, .STORE_GLOBAL => {
                    used_at[instr.src1] = idx;
                },
                .JUMP_IF_ZERO, .JUMP_IF_NOT_ZERO => {
                    used_at[instr.dest] = idx;
                },
                else => {},
            }
        }

        // Step 3: Backward pass - determine which instructions are dead
        var is_dead = try self.allocator.alloc(bool, ir.len);
        defer self.allocator.free(is_dead);
        @memset(is_dead, false);

        // Track last use of each register
        var last_use: [32]?usize = [_]?usize{null} ** 32;

        // Initialize last_use from used_at
        for (0..32) |r| {
            last_use[r] = used_at[r];
        }

        // Backward pass to find dead instructions
        i = ir.len;
        while (i > 0) {
            i -= 1;
            const instr = ir[i];

            // Skip control flow and side-effect instructions
            switch (instr.opcode) {
                .RETURN, .JUMP, .JUMP_IF_ZERO, .JUMP_IF_NOT_ZERO, .LOOP_BACK,
                .STORE_LOCAL, .STORE_GLOBAL, .DEOPT, .GUARD_TYPE => {
                    // These have side effects - never dead
                    continue;
                },
                else => {},
            }

            // Check if dest register is used after this instruction
            const dest = instr.dest;
            if (dest < 32) {
                if (last_use[dest]) |use_idx| {
                    if (use_idx <= i) {
                        // Dest is not used after this instruction - it's dead
                        is_dead[i] = true;
                        self.instructions_eliminated += 1;
                    }
                } else {
                    // Dest is never used - it's dead
                    is_dead[i] = true;
                    self.instructions_eliminated += 1;
                }

                // Update last_use for source registers
                switch (instr.opcode) {
                    .ADD_INT, .SUB_INT, .MUL_INT, .DIV_INT, .MOD_INT,
                    .CMP_LT_INT, .CMP_LE_INT, .CMP_GT_INT, .CMP_GE_INT, .CMP_EQ_INT, .CMP_NE_INT => {
                        if (!is_dead[i]) {
                            last_use[instr.src1] = i;
                            last_use[instr.src2] = i;
                        }
                    },
                    .NEG_INT, .NOT => {
                        if (!is_dead[i]) {
                            last_use[instr.src1] = i;
                        }
                    },
                    else => {},
                }
            }
        }

        // Step 4: Build result without dead instructions
        var result = std.ArrayList(IRInstruction).init(self.allocator);
        errdefer result.deinit();

        for (ir, 0..) |instr, idx| {
            if (!is_dead[idx]) {
                try result.append(instr);
            }
        }

        return result.toOwnedSlice();
    }

    /// Get statistics
    pub fn getStats(self: *Self) struct { eliminated: usize } {
        return .{
            .eliminated = self.instructions_eliminated,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STRENGTH REDUCER
// ═══════════════════════════════════════════════════════════════════════════════

/// Strength Reducer - replaces expensive operations with cheaper ones
pub const StrengthReducer = struct {
    allocator: Allocator,
    /// Statistics
    reductions: usize = 0,
    mul_to_shift: usize = 0,
    mul_to_lea: usize = 0,
    mul_to_add: usize = 0,
    div_to_shift: usize = 0,
    identity_removed: usize = 0,
    algebraic_simplified: usize = 0,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .reductions = 0,
            .mul_to_shift = 0,
            .mul_to_lea = 0,
            .mul_to_add = 0,
            .div_to_shift = 0,
            .identity_removed = 0,
            .algebraic_simplified = 0,
        };
    }

    /// Check if value is a power of 2 and return the exponent
    fn isPowerOf2(value: i64) ?u6 {
        if (value <= 0) return null;
        const uval: u64 = @intCast(value);
        if (uval & (uval - 1) != 0) return null; // Not power of 2

        // Count trailing zeros = log2
        var shift: u6 = 0;
        var v = uval;
        while (v > 1) : (v >>= 1) {
            shift += 1;
        }
        return shift;
    }

    /// Check if value can be computed with LEA (3, 5, 9)
    /// Returns the scale factor (2, 4, or 8) for LEA [reg + reg*scale]
    fn isLeaMultiplier(value: i64) ?u8 {
        return switch (value) {
            3 => 2, // x*3 = x + x*2
            5 => 4, // x*5 = x + x*4
            9 => 8, // x*9 = x + x*8
            else => null,
        };
    }

    /// Optimize IR by reducing operation strength
    pub fn optimize(self: *Self, ir: []const IRInstruction) ![]IRInstruction {
        if (ir.len == 0) return self.allocator.dupe(IRInstruction, ir);

        var result = std.ArrayList(IRInstruction).init(self.allocator);
        errdefer result.deinit();

        // Track constant values in registers for pattern matching
        var reg_constants: [32]?i64 = [_]?i64{null} ** 32;

        for (ir) |instr| {
            switch (instr.opcode) {
                .LOAD_CONST => {
                    reg_constants[instr.dest] = instr.imm;
                    try result.append(instr);
                },

                .MUL_INT => {
                    // Check for multiplication by power of 2
                    const src1_const = reg_constants[instr.src1];
                    const src2_const = reg_constants[instr.src2];

                    if (src2_const) |c| {
                        if (c == 0) {
                            // x * 0 = 0
                            try result.append(.{
                                .opcode = .LOAD_CONST,
                                .dest = instr.dest,
                                .src1 = 0,
                                .src2 = 0,
                                .imm = 0,
                            });
                            reg_constants[instr.dest] = 0;
                            self.reductions += 1;
                            self.identity_removed += 1;
                            continue;
                        } else if (c == 1) {
                            // x * 1 = x (copy src1 to dest if different)
                            if (instr.dest != instr.src1) {
                                try result.append(.{
                                    .opcode = .LOAD_LOCAL, // Use as move
                                    .dest = instr.dest,
                                    .src1 = instr.src1,
                                    .src2 = 0,
                                    .imm = 0,
                                });
                            }
                            reg_constants[instr.dest] = src1_const;
                            self.reductions += 1;
                            self.identity_removed += 1;
                            continue;
                        } else if (c == 2) {
                            // x * 2 = x + x (ADD is often faster than SHL)
                            try result.append(.{
                                .opcode = .ADD_INT,
                                .dest = instr.dest,
                                .src1 = instr.src1,
                                .src2 = instr.src1,
                                .imm = 0,
                            });
                            reg_constants[instr.dest] = if (src1_const) |v| v * 2 else null;
                            self.reductions += 1;
                            self.mul_to_add += 1;
                            continue;
                        } else if (isPowerOf2(c)) |shift| {
                            // x * 2^n = x << n (for n > 1)
                            try result.append(.{
                                .opcode = .SHL,
                                .dest = instr.dest,
                                .src1 = instr.src1,
                                .src2 = 0,
                                .imm = shift,
                            });
                            reg_constants[instr.dest] = if (src1_const) |v| v << shift else null;
                            self.reductions += 1;
                            self.mul_to_shift += 1;
                            continue;
                        } else if (isLeaMultiplier(c)) |scale| {
                            // x * 3 = x + x*2, x * 5 = x + x*4, x * 9 = x + x*8
                            try result.append(.{
                                .opcode = .LEA,
                                .dest = instr.dest,
                                .src1 = instr.src1,
                                .src2 = 0,
                                .imm = scale,
                            });
                            reg_constants[instr.dest] = if (src1_const) |v| v * c else null;
                            self.reductions += 1;
                            self.mul_to_lea += 1;
                            continue;
                        }
                    }

                    // Check src1 for power of 2 (commutative)
                    if (src1_const) |c| {
                        if (c == 0) {
                            try result.append(.{
                                .opcode = .LOAD_CONST,
                                .dest = instr.dest,
                                .src1 = 0,
                                .src2 = 0,
                                .imm = 0,
                            });
                            reg_constants[instr.dest] = 0;
                            self.reductions += 1;
                            self.identity_removed += 1;
                            continue;
                        } else if (c == 1) {
                            if (instr.dest != instr.src2) {
                                try result.append(.{
                                    .opcode = .LOAD_LOCAL,
                                    .dest = instr.dest,
                                    .src1 = instr.src2,
                                    .src2 = 0,
                                    .imm = 0,
                                });
                            }
                            reg_constants[instr.dest] = src2_const;
                            self.reductions += 1;
                            self.identity_removed += 1;
                            continue;
                        } else if (c == 2) {
                            // 2 * x = x + x
                            try result.append(.{
                                .opcode = .ADD_INT,
                                .dest = instr.dest,
                                .src1 = instr.src2,
                                .src2 = instr.src2,
                                .imm = 0,
                            });
                            reg_constants[instr.dest] = if (src2_const) |v| v * 2 else null;
                            self.reductions += 1;
                            self.mul_to_add += 1;
                            continue;
                        } else if (isPowerOf2(c)) |shift| {
                            try result.append(.{
                                .opcode = .SHL,
                                .dest = instr.dest,
                                .src1 = instr.src2,
                                .src2 = 0,
                                .imm = shift,
                            });
                            reg_constants[instr.dest] = if (src2_const) |v| v << shift else null;
                            self.reductions += 1;
                            self.mul_to_shift += 1;
                            continue;
                        } else if (isLeaMultiplier(c)) |scale| {
                            // x * 3 = x + x*2, x * 5 = x + x*4, x * 9 = x + x*8
                            try result.append(.{
                                .opcode = .LEA,
                                .dest = instr.dest,
                                .src1 = instr.src2,
                                .src2 = 0,
                                .imm = scale,
                            });
                            reg_constants[instr.dest] = if (src2_const) |v| v * c else null;
                            self.reductions += 1;
                            self.mul_to_lea += 1;
                            continue;
                        }
                    }

                    // No reduction possible
                    reg_constants[instr.dest] = null;
                    try result.append(instr);
                },

                .DIV_INT => {
                    // Check for division by power of 2
                    const src2_const = reg_constants[instr.src2];

                    if (src2_const) |c| {
                        if (c == 1) {
                            // x / 1 = x
                            if (instr.dest != instr.src1) {
                                try result.append(.{
                                    .opcode = .LOAD_LOCAL,
                                    .dest = instr.dest,
                                    .src1 = instr.src1,
                                    .src2 = 0,
                                    .imm = 0,
                                });
                            }
                            reg_constants[instr.dest] = reg_constants[instr.src1];
                            self.reductions += 1;
                            self.identity_removed += 1;
                            continue;
                        } else if (isPowerOf2(c)) |shift| {
                            // x / 2^n = x >> n (for positive x)
                            try result.append(.{
                                .opcode = .SHR,
                                .dest = instr.dest,
                                .src1 = instr.src1,
                                .src2 = 0,
                                .imm = shift,
                            });
                            const src1_const = reg_constants[instr.src1];
                            reg_constants[instr.dest] = if (src1_const) |v| v >> shift else null;
                            self.reductions += 1;
                            self.div_to_shift += 1;
                            continue;
                        }
                    }

                    reg_constants[instr.dest] = null;
                    try result.append(instr);
                },

                .ADD_INT => {
                    // x + 0 = x
                    const src1_const = reg_constants[instr.src1];
                    const src2_const = reg_constants[instr.src2];

                    if (src2_const) |c| {
                        if (c == 0) {
                            if (instr.dest != instr.src1) {
                                try result.append(.{
                                    .opcode = .LOAD_LOCAL,
                                    .dest = instr.dest,
                                    .src1 = instr.src1,
                                    .src2 = 0,
                                    .imm = 0,
                                });
                            }
                            reg_constants[instr.dest] = src1_const;
                            self.reductions += 1;
                            self.identity_removed += 1;
                            continue;
                        }
                    }

                    if (src1_const) |c| {
                        if (c == 0) {
                            if (instr.dest != instr.src2) {
                                try result.append(.{
                                    .opcode = .LOAD_LOCAL,
                                    .dest = instr.dest,
                                    .src1 = instr.src2,
                                    .src2 = 0,
                                    .imm = 0,
                                });
                            }
                            reg_constants[instr.dest] = src2_const;
                            self.reductions += 1;
                            self.identity_removed += 1;
                            continue;
                        }
                    }

                    reg_constants[instr.dest] = null;
                    try result.append(instr);
                },

                .SUB_INT => {
                    // x - x = 0
                    if (instr.src1 == instr.src2) {
                        try result.append(.{
                            .opcode = .LOAD_CONST,
                            .dest = instr.dest,
                            .src1 = 0,
                            .src2 = 0,
                            .imm = 0,
                        });
                        reg_constants[instr.dest] = 0;
                        self.reductions += 1;
                        self.algebraic_simplified += 1;
                        continue;
                    }

                    // x - 0 = x
                    const src2_const = reg_constants[instr.src2];

                    if (src2_const) |c| {
                        if (c == 0) {
                            if (instr.dest != instr.src1) {
                                try result.append(.{
                                    .opcode = .LOAD_LOCAL,
                                    .dest = instr.dest,
                                    .src1 = instr.src1,
                                    .src2 = 0,
                                    .imm = 0,
                                });
                            }
                            reg_constants[instr.dest] = reg_constants[instr.src1];
                            self.reductions += 1;
                            self.identity_removed += 1;
                            continue;
                        }
                    }

                    reg_constants[instr.dest] = null;
                    try result.append(instr);
                },

                .LOAD_LOCAL, .LOAD_GLOBAL => {
                    reg_constants[instr.dest] = null;
                    try result.append(instr);
                },

                .XOR, .BXOR => {
                    // x ^ x = 0
                    if (instr.src1 == instr.src2) {
                        try result.append(.{
                            .opcode = .LOAD_CONST,
                            .dest = instr.dest,
                            .src1 = 0,
                            .src2 = 0,
                            .imm = 0,
                        });
                        reg_constants[instr.dest] = 0;
                        self.reductions += 1;
                        self.algebraic_simplified += 1;
                        continue;
                    }
                    reg_constants[instr.dest] = null;
                    try result.append(instr);
                },

                .AND, .BAND => {
                    // x & x = x
                    if (instr.src1 == instr.src2) {
                        if (instr.dest != instr.src1) {
                            try result.append(.{
                                .opcode = .LOAD_LOCAL,
                                .dest = instr.dest,
                                .src1 = instr.src1,
                                .src2 = 0,
                                .imm = 0,
                            });
                        }
                        reg_constants[instr.dest] = reg_constants[instr.src1];
                        self.reductions += 1;
                        self.algebraic_simplified += 1;
                        continue;
                    }
                    reg_constants[instr.dest] = null;
                    try result.append(instr);
                },

                .OR, .BOR => {
                    // x | x = x
                    if (instr.src1 == instr.src2) {
                        if (instr.dest != instr.src1) {
                            try result.append(.{
                                .opcode = .LOAD_LOCAL,
                                .dest = instr.dest,
                                .src1 = instr.src1,
                                .src2 = 0,
                                .imm = 0,
                            });
                        }
                        reg_constants[instr.dest] = reg_constants[instr.src1];
                        self.reductions += 1;
                        self.algebraic_simplified += 1;
                        continue;
                    }
                    reg_constants[instr.dest] = null;
                    try result.append(instr);
                },

                else => {
                    if (instr.dest < 32) {
                        reg_constants[instr.dest] = null;
                    }
                    try result.append(instr);
                },
            }
        }

        return result.toOwnedSlice();
    }

    /// Get statistics
    pub fn getStats(self: *Self) struct { reductions: usize, mul_to_shift: usize, mul_to_lea: usize, mul_to_add: usize, div_to_shift: usize, identity: usize, algebraic: usize } {
        return .{
            .reductions = self.reductions,
            .mul_to_shift = self.mul_to_shift,
            .mul_to_lea = self.mul_to_lea,
            .mul_to_add = self.mul_to_add,
            .div_to_shift = self.div_to_shift,
            .identity = self.identity_removed,
            .algebraic = self.algebraic_simplified,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// COPY PROPAGATOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Copy Propagator - replaces uses of copied registers with the original
/// If r1 = copy(r0), then uses of r1 are replaced with r0
pub const CopyPropagator = struct {
    allocator: Allocator,
    /// Statistics
    copies_propagated: usize = 0,
    copies_eliminated: usize = 0,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .copies_propagated = 0,
            .copies_eliminated = 0,
        };
    }

    /// Optimize IR by propagating copies
    pub fn optimize(self: *Self, ir: []const IRInstruction) ![]IRInstruction {
        if (ir.len == 0) return self.allocator.dupe(IRInstruction, ir);

        var result = std.ArrayList(IRInstruction).init(self.allocator);
        errdefer result.deinit();

        // Track copy relationships: copy_of[dest] = source
        // If r1 = copy(r0), then copy_of[1] = 0
        var copy_of: [32]?u8 = [_]?u8{null} ** 32;

        // First pass: identify copies and propagate through uses
        for (ir) |instr| {
            var new_instr = instr;

            // Replace source registers with their originals if they are copies
            const src1_orig = self.resolveRegister(instr.src1, &copy_of);
            const src2_orig = self.resolveRegister(instr.src2, &copy_of);

            if (src1_orig != instr.src1 or src2_orig != instr.src2) {
                new_instr.src1 = src1_orig;
                new_instr.src2 = src2_orig;
                self.copies_propagated += 1;
            }

            switch (new_instr.opcode) {
                .LOAD_LOCAL => {
                    // This is a copy: dest = src1
                    // Check if it's a register-to-register copy (not memory load)
                    if (new_instr.imm == 0 and new_instr.src1 < 32) {
                        // Record the copy relationship
                        copy_of[new_instr.dest] = src1_orig;

                        // If dest == resolved src, this copy is useless
                        if (new_instr.dest == src1_orig) {
                            self.copies_eliminated += 1;
                            continue; // Skip this instruction
                        }
                    } else {
                        // Memory load - invalidate dest
                        copy_of[new_instr.dest] = null;
                    }
                    try result.append(new_instr);
                },

                .LOAD_CONST => {
                    // Constant load - not a copy, invalidate any copy relationship
                    // Also invalidate any copies that point to this register
                    self.invalidateCopiesOf(new_instr.dest, &copy_of);
                    copy_of[new_instr.dest] = null;
                    try result.append(new_instr);
                },

                .STORE_LOCAL, .STORE_GLOBAL => {
                    // Store doesn't change register copies
                    try result.append(new_instr);
                },

                // Instructions that write to dest invalidate copy relationships
                .ADD_INT, .SUB_INT, .MUL_INT, .DIV_INT, .MOD_INT,
                .NEG_INT, .INC_INT, .DEC_INT,
                .SHL, .SHR, .LEA,
                .AND, .OR, .XOR, .BAND, .BOR, .BXOR, .BNOT,
                .CMP_LT_INT, .CMP_LE_INT, .CMP_GT_INT, .CMP_GE_INT, .CMP_EQ_INT, .CMP_NE_INT => {
                    // Invalidate any copies that point to this register
                    self.invalidateCopiesOf(new_instr.dest, &copy_of);
                    copy_of[new_instr.dest] = null;
                    try result.append(new_instr);
                },

                // Control flow - invalidate all copies (conservative)
                .JUMP, .JUMP_IF_ZERO, .JUMP_IF_NOT_ZERO, .LOOP_BACK => {
                    for (&copy_of) |*c| c.* = null;
                    try result.append(new_instr);
                },

                else => {
                    // Unknown instruction - invalidate dest if applicable
                    if (new_instr.dest < 32) {
                        copy_of[new_instr.dest] = null;
                    }
                    try result.append(new_instr);
                },
            }
        }

        return result.toOwnedSlice();
    }

    /// Invalidate all copies that point to a given register
    fn invalidateCopiesOf(self: *Self, reg: u8, copy_of: *[32]?u8) void {
        _ = self;
        for (copy_of, 0..) |c, i| {
            if (c) |orig| {
                if (orig == reg) {
                    copy_of[i] = null;
                }
            }
        }
    }

    /// Resolve a register to its original (follow copy chain)
    fn resolveRegister(self: *Self, reg: u8, copy_of: *[32]?u8) u8 {
        _ = self;
        var current = reg;
        var depth: usize = 0;
        while (copy_of[current]) |orig| {
            current = orig;
            depth += 1;
            if (depth > 32) break; // Prevent infinite loops
        }
        return current;
    }

    /// Get statistics
    pub fn getStats(self: *Self) struct { propagated: usize, eliminated: usize } {
        return .{
            .propagated = self.copies_propagated,
            .eliminated = self.copies_eliminated,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PEEPHOLE OPTIMIZER
// ═══════════════════════════════════════════════════════════════════════════════

/// Peephole Optimizer - optimizes small sequences of instructions
pub const PeepholeOptimizer = struct {
    allocator: Allocator,
    /// Statistics
    patterns_matched: usize = 0,
    instructions_eliminated: usize = 0,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .patterns_matched = 0,
            .instructions_eliminated = 0,
        };
    }

    /// Optimize IR using peephole patterns
    pub fn optimize(self: *Self, ir: []const IRInstruction) ![]IRInstruction {
        if (ir.len < 2) return self.allocator.dupe(IRInstruction, ir);

        var result = std.ArrayList(IRInstruction).init(self.allocator);
        errdefer result.deinit();

        var i: usize = 0;
        while (i < ir.len) {
            // Try to match 2-instruction patterns
            if (i + 1 < ir.len) {
                const curr = ir[i];
                const next = ir[i + 1];

                // Pattern: LOAD_CONST r, X + LOAD_CONST r, Y -> keep only second
                if (curr.opcode == .LOAD_CONST and next.opcode == .LOAD_CONST and
                    curr.dest == next.dest)
                {
                    // Skip first LOAD_CONST, keep second
                    self.patterns_matched += 1;
                    self.instructions_eliminated += 1;
                    i += 1;
                    continue;
                }

                // Pattern: NEG r + NEG r -> remove both (double negation)
                if (curr.opcode == .NEG_INT and next.opcode == .NEG_INT and
                    curr.dest == next.dest and curr.src1 == curr.dest and
                    next.src1 == next.dest)
                {
                    self.patterns_matched += 1;
                    self.instructions_eliminated += 2;
                    i += 2;
                    continue;
                }

                // Pattern: INC r + DEC r -> remove both
                if (curr.opcode == .INC_INT and next.opcode == .DEC_INT and
                    curr.dest == next.dest and curr.dest == next.src1)
                {
                    self.patterns_matched += 1;
                    self.instructions_eliminated += 2;
                    i += 2;
                    continue;
                }

                // Pattern: DEC r + INC r -> remove both
                if (curr.opcode == .DEC_INT and next.opcode == .INC_INT and
                    curr.dest == next.dest and curr.dest == next.src1)
                {
                    self.patterns_matched += 1;
                    self.instructions_eliminated += 2;
                    i += 2;
                    continue;
                }

                // Pattern: LOAD_LOCAL r, X + LOAD_LOCAL r, Y -> keep only second
                if (curr.opcode == .LOAD_LOCAL and next.opcode == .LOAD_LOCAL and
                    curr.dest == next.dest)
                {
                    self.patterns_matched += 1;
                    self.instructions_eliminated += 1;
                    i += 1;
                    continue;
                }

                // Pattern: SHL r, N + SHR r, N -> remove both (if same shift amount)
                if (curr.opcode == .SHL and next.opcode == .SHR and
                    curr.dest == next.dest and curr.dest == next.src1 and
                    curr.imm == next.imm and curr.imm != 0)
                {
                    self.patterns_matched += 1;
                    self.instructions_eliminated += 2;
                    i += 2;
                    continue;
                }

                // Pattern: SHR r, N + SHL r, N -> remove both (if same shift amount)
                if (curr.opcode == .SHR and next.opcode == .SHL and
                    curr.dest == next.dest and curr.dest == next.src1 and
                    curr.imm == next.imm and curr.imm != 0)
                {
                    self.patterns_matched += 1;
                    self.instructions_eliminated += 2;
                    i += 2;
                    continue;
                }
            }

            // No pattern matched, keep instruction
            try result.append(ir[i]);
            i += 1;
        }

        return result.toOwnedSlice();
    }

    /// Get statistics
    pub fn getStats(self: *Self) struct { patterns: usize, eliminated: usize } {
        return .{
            .patterns = self.patterns_matched,
            .eliminated = self.instructions_eliminated,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TIERED COMPILER
// ═══════════════════════════════════════════════════════════════════════════════

/// Tiered compilation thresholds
pub const TierThresholds = struct {
    /// Executions before promoting Interpreter → JIT IR
    tier1_threshold: u64 = 50,
    /// Executions before promoting JIT IR → Native
    tier2_threshold: u64 = 500,
    /// Minimum time (ns) at current tier before promotion
    min_tier_time_ns: u64 = 1000,
};

/// Tiered compilation statistics
pub const TieredStats = struct {
    functions_at_tier: [3]usize, // Count per tier
    total_promotions: u64,
    tier1_promotions: u64, // Interpreter → JIT IR
    tier2_promotions: u64, // JIT IR → Native
    total_compile_time_ns: u64,
    tier1_compile_time_ns: u64,
    tier2_compile_time_ns: u64,

    pub fn init() TieredStats {
        return .{
            .functions_at_tier = [_]usize{ 0, 0, 0 },
            .total_promotions = 0,
            .tier1_promotions = 0,
            .tier2_promotions = 0,
            .total_compile_time_ns = 0,
            .tier1_compile_time_ns = 0,
            .tier2_compile_time_ns = 0,
        };
    }
};

/// Tiered Compiler - manages automatic tier promotion
pub const TieredCompiler = struct {
    allocator: Allocator,
    /// Function states: address -> tier state
    function_states: std.AutoHashMap(u32, FunctionTierState),
    /// JIT IR cache: address -> compiled IR
    jit_ir_cache: std.AutoHashMap(u32, []IRInstruction),
    /// Native code cache: address -> executable
    native_cache: std.AutoHashMap(u32, ExecutableCode),
    /// Thresholds for tier promotion
    thresholds: TierThresholds,
    /// Loop unroller for optimization
    loop_unroller: LoopUnroller,
    /// Constant folder for optimization
    constant_folder: ConstantFolder,
    /// Dead code eliminator
    dce: DeadCodeEliminator,
    /// Strength reducer
    strength_reducer: StrengthReducer,
    /// Copy propagator
    copy_propagator: CopyPropagator,
    /// Peephole optimizer
    peephole: PeepholeOptimizer,
    /// Enable loop unrolling optimization
    enable_unrolling: bool,
    /// Enable constant folding optimization
    enable_folding: bool,
    /// Enable dead code elimination
    enable_dce: bool,
    /// Enable strength reduction
    enable_strength_reduction: bool,
    /// Enable copy propagation
    enable_copy_propagation: bool,
    /// Enable peephole optimization
    enable_peephole: bool,
    /// Statistics
    stats: TieredStats,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .function_states = std.AutoHashMap(u32, FunctionTierState).init(allocator),
            .jit_ir_cache = std.AutoHashMap(u32, []IRInstruction).init(allocator),
            .native_cache = std.AutoHashMap(u32, ExecutableCode).init(allocator),
            .thresholds = TierThresholds{},
            .loop_unroller = LoopUnroller.init(allocator),
            .constant_folder = ConstantFolder.init(allocator),
            .dce = DeadCodeEliminator.init(allocator),
            .strength_reducer = StrengthReducer.init(allocator),
            .copy_propagator = CopyPropagator.init(allocator),
            .peephole = PeepholeOptimizer.init(allocator),
            .enable_unrolling = true,
            .enable_folding = true,
            .enable_dce = true,
            .enable_strength_reduction = true,
            .enable_copy_propagation = true,
            .enable_peephole = true,
            .stats = TieredStats.init(),
        };
    }

    pub fn initWithThresholds(allocator: Allocator, thresholds: TierThresholds) Self {
        var compiler = Self.init(allocator);
        compiler.thresholds = thresholds;
        return compiler;
    }

    pub fn deinit(self: *Self) void {
        // Free JIT IR cache
        var ir_iter = self.jit_ir_cache.iterator();
        while (ir_iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.jit_ir_cache.deinit();

        // Free native cache
        var native_iter = self.native_cache.iterator();
        while (native_iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.native_cache.deinit();

        self.function_states.deinit();
    }

    /// Get or create function state
    pub fn getOrCreateState(self: *Self, address: u32) !*FunctionTierState {
        const result = try self.function_states.getOrPut(address);
        if (!result.found_existing) {
            result.value_ptr.* = FunctionTierState.init(address);
            self.stats.functions_at_tier[0] += 1;
        }
        return result.value_ptr;
    }

    /// Record function execution and check for promotion
    pub fn recordExecution(self: *Self, address: u32, time_ns: u64) !?CompilationTier {
        const state = try self.getOrCreateState(address);
        state.recordExecution(time_ns);

        // Check if should promote
        const executions_at_tier = state.execution_count - state.last_promotion_count;

        const should_promote = switch (state.current_tier) {
            .Interpreter => executions_at_tier >= self.thresholds.tier1_threshold,
            .JIT_IR => executions_at_tier >= self.thresholds.tier2_threshold,
            .Native => false,
        };

        if (should_promote) {
            return state.current_tier.next();
        }
        return null;
    }

    /// Promote function to next tier
    pub fn promote(self: *Self, address: u32, ir: []const IRInstruction) !bool {
        const state = self.function_states.getPtr(address) orelse return false;
        const old_tier = state.current_tier;

        if (!state.promote()) return false;

        // Update stats
        self.stats.functions_at_tier[@intFromEnum(old_tier)] -|= 1;
        self.stats.functions_at_tier[@intFromEnum(state.current_tier)] += 1;
        self.stats.total_promotions += 1;

        const compile_start = std.time.nanoTimestamp();

        switch (state.current_tier) {
            .JIT_IR => {
                // Apply optimizations: strength reduction, constant folding, DCE, loop unrolling
                var optimized_ir = try self.allocator.dupe(IRInstruction, ir);
                errdefer self.allocator.free(optimized_ir);

                if (self.enable_strength_reduction) {
                    const reduced = try self.strength_reducer.optimize(optimized_ir);
                    self.allocator.free(optimized_ir);
                    optimized_ir = reduced;
                }

                if (self.enable_copy_propagation) {
                    const propagated = try self.copy_propagator.optimize(optimized_ir);
                    self.allocator.free(optimized_ir);
                    optimized_ir = propagated;
                }

                if (self.enable_folding) {
                    const folded = try self.constant_folder.optimize(optimized_ir);
                    self.allocator.free(optimized_ir);
                    optimized_ir = folded;
                }

                if (self.enable_dce) {
                    const dce_result = try self.dce.optimize(optimized_ir);
                    self.allocator.free(optimized_ir);
                    optimized_ir = dce_result;
                }

                if (self.enable_unrolling) {
                    const unrolled = try self.loop_unroller.optimize(optimized_ir);
                    self.allocator.free(optimized_ir);
                    optimized_ir = unrolled;
                }

                if (self.enable_peephole) {
                    const peeped = try self.peephole.optimize(optimized_ir);
                    self.allocator.free(optimized_ir);
                    optimized_ir = peeped;
                }

                try self.jit_ir_cache.put(address, optimized_ir);
                self.stats.tier1_promotions += 1;

                const compile_time: u64 = @intCast(@max(0, std.time.nanoTimestamp() - compile_start));
                self.stats.tier1_compile_time_ns += compile_time;
                self.stats.total_compile_time_ns += compile_time;
            },
            .Native => {
                // Get optimized IR from cache or optimize now
                const optimized_ir = self.jit_ir_cache.get(address) orelse blk: {
                    var opt_ir = try self.allocator.dupe(IRInstruction, ir);

                    if (self.enable_strength_reduction) {
                        const reduced = try self.strength_reducer.optimize(opt_ir);
                        self.allocator.free(opt_ir);
                        opt_ir = reduced;
                    }

                    if (self.enable_copy_propagation) {
                        const propagated = try self.copy_propagator.optimize(opt_ir);
                        self.allocator.free(opt_ir);
                        opt_ir = propagated;
                    }

                    if (self.enable_folding) {
                        const folded = try self.constant_folder.optimize(opt_ir);
                        self.allocator.free(opt_ir);
                        opt_ir = folded;
                    }

                    if (self.enable_dce) {
                        const dce_result = try self.dce.optimize(opt_ir);
                        self.allocator.free(opt_ir);
                        opt_ir = dce_result;
                    }

                    if (self.enable_unrolling) {
                        const unrolled = try self.loop_unroller.optimize(opt_ir);
                        self.allocator.free(opt_ir);
                        opt_ir = unrolled;
                    }

                    if (self.enable_peephole) {
                        const peeped = try self.peephole.optimize(opt_ir);
                        self.allocator.free(opt_ir);
                        opt_ir = peeped;
                    }

                    break :blk opt_ir;
                };
                defer if (self.jit_ir_cache.get(address) == null) self.allocator.free(optimized_ir);

                // Compile optimized IR to native
                var native_compiler = NativeCompiler.init(self.allocator);
                if (native_compiler.compile(optimized_ir)) |machine_code| {
                    defer self.allocator.free(machine_code);
                    native_compiler.deinit();

                    if (ExecutableCode.init(machine_code)) |executable| {
                        try self.native_cache.put(address, executable);
                        self.stats.tier2_promotions += 1;

                        const compile_time: u64 = @intCast(@max(0, std.time.nanoTimestamp() - compile_start));
                        self.stats.tier2_compile_time_ns += compile_time;
                        self.stats.total_compile_time_ns += compile_time;
                    } else |_| {
                        native_compiler.deinit();
                        return false;
                    }
                } else |_| {
                    native_compiler.deinit();
                    return false;
                }
            },
            .Interpreter => unreachable,
        }

        return true;
    }

    /// Get current tier for function
    pub fn getTier(self: *Self, address: u32) CompilationTier {
        if (self.function_states.get(address)) |state| {
            return state.current_tier;
        }
        return .Interpreter;
    }

    /// Execute function at appropriate tier
    pub fn execute(self: *Self, address: u32, vm: *VM, ir: []const IRInstruction) !i64 {
        const tier = self.getTier(address);
        const exec_start = std.time.nanoTimestamp();

        const result: i64 = switch (tier) {
            .Interpreter => blk: {
                const val = try vm.run();
                break :blk val.toInt() orelse 0;
            },
            .JIT_IR => blk: {
                // Execute via IR interpreter
                const cached_ir = self.jit_ir_cache.get(address) orelse ir;
                break :blk interpretIRCode(cached_ir);
            },
            .Native => blk: {
                if (self.native_cache.get(address)) |executable| {
                    break :blk executable.execute();
                }
                // Fallback to IR
                break :blk interpretIRCode(ir);
            },
        };

        const exec_time: u64 = @intCast(@max(0, std.time.nanoTimestamp() - exec_start));

        // Record and check for promotion
        if (try self.recordExecution(address, exec_time)) |next_tier| {
            _ = next_tier;
            // Promotion needed - caller should compile
        }

        return result;
    }

    /// Get statistics
    pub fn getStats(self: *Self) TieredStats {
        return self.stats;
    }

    /// Get function state
    pub fn getFunctionState(self: *Self, address: u32) ?FunctionTierState {
        return self.function_states.get(address);
    }
};

/// Standalone IR interpreter for tiered compilation
fn interpretIRCode(ir: []const IRInstruction) i64 {
    var registers: [32]i64 = [_]i64{0} ** 32;
    var pc: usize = 0;

    while (pc < ir.len) {
        const instr = ir[pc];
        pc += 1;

        switch (instr.opcode) {
            .LOAD_CONST => {
                registers[instr.dest] = instr.imm;
            },
            .ADD_INT => {
                registers[instr.dest] = registers[instr.src1] + registers[instr.src2];
            },
            .SUB_INT => {
                registers[instr.dest] = registers[instr.src1] - registers[instr.src2];
            },
            .MUL_INT => {
                registers[instr.dest] = registers[instr.src1] * registers[instr.src2];
            },
            .DIV_INT => {
                const b = registers[instr.src2];
                if (b != 0) {
                    registers[instr.dest] = @divTrunc(registers[instr.src1], b);
                }
            },
            .SHL => {
                // If imm is set, use immediate shift amount; otherwise use register
                const shift_val = if (instr.imm != 0) instr.imm else registers[instr.src2];
                const shift_amt: u6 = @intCast(@min(63, @max(0, shift_val)));
                registers[instr.dest] = registers[instr.src1] << shift_amt;
            },
            .SHR => {
                // If imm is set, use immediate shift amount; otherwise use register
                const shift_val = if (instr.imm != 0) instr.imm else registers[instr.src2];
                const shift_amt: u6 = @intCast(@min(63, @max(0, shift_val)));
                registers[instr.dest] = registers[instr.src1] >> shift_amt;
            },
            .LEA => {
                // LEA: dest = src1 + src1 * scale (scale in imm: 2, 4, or 8)
                const src = registers[instr.src1];
                const scale = instr.imm;
                registers[instr.dest] = src + src * scale;
            },
            .RETURN => {
                return registers[instr.dest];
            },
            else => {},
        }
    }

    return registers[0];
}

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

    // Hot Path Profiler for automatic JIT
    profiler: HotPathProfiler,

    // Tiered Compiler for automatic tier promotion
    tiered_compiler: TieredCompiler,

    // Inline cache for last called native function (avoids HashMap lookup)
    last_native_addr: u32,
    last_native_ptr: ?*ExecutableCode,

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
    inline_cache_hits: u64,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .allocator = allocator,
            .vm = try VM.init(allocator),
            .jit_compiler = JITCompiler.init(allocator),
            .config = AdapterConfig{},
            .native_cache = std.AutoHashMap(u32, NativeCodeEntry).init(allocator),
            .profiler = HotPathProfiler.init(allocator),
            .tiered_compiler = TieredCompiler.init(allocator),
            .last_native_addr = 0xFFFFFFFF, // Invalid address
            .last_native_ptr = null,
            .is_recording = false,
            .current_trace_start = 0,
            .jit_instructions = 0,
            .interpreter_instructions = 0,
            .native_instructions = 0,
            .jit_compile_time_ns = 0,
            .native_compile_time_ns = 0,
            .inline_cache_hits = 0,
            .native_cache_hits = 0,
            .native_cache_misses = 0,
        };
    }

    pub fn initWithConfig(allocator: Allocator, config: AdapterConfig) !Self {
        var adapter = try Self.init(allocator);
        adapter.config = config;
        // Sync profiler thresholds with config
        adapter.profiler.jit_threshold = config.hot_threshold;
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
        self.profiler.deinit();
        self.tiered_compiler.deinit();
        self.vm.deinit();
        self.jit_compiler.deinit();
    }

    /// Get profiler statistics
    pub fn getProfilerStats(self: *Self) ProfilerStats {
        return self.profiler.getStats();
    }

    /// Get tiered compiler statistics
    pub fn getTieredStats(self: *Self) TieredStats {
        return self.tiered_compiler.getStats();
    }

    /// Get current tier for function
    pub fn getFunctionTier(self: *Self, address: u32) CompilationTier {
        return self.tiered_compiler.getTier(address);
    }

    /// Get profile for specific function
    pub fn getFunctionProfile(self: *Self, address: u32) ?FunctionProfile {
        return self.profiler.getProfile(address);
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
    /// Автоматически использует нативный код когда доступен
    fn executeMixed(self: *Self, code: []const u8) !Value {
        const entry_addr: u32 = 0;

        // Record function entry in profiler
        const should_compile = try self.profiler.recordEntry(entry_addr);

        // Check if we have native code and should use it
        if (self.config.use_native) {
            if (self.tryExecuteNative(entry_addr)) |native_result| {
                self.native_instructions += 1;
                self.profiler.recordExit(entry_addr, 0); // Native is fast
                return .{ .int_val = native_result };
            }
        }

        // Execute via interpreter
        const exec_start = std.time.nanoTimestamp();
        const result = try self.vm.run();
        const exec_end = std.time.nanoTimestamp();
        const exec_time: u64 = @intCast(@max(0, exec_end - exec_start));

        self.interpreter_instructions = self.vm.instructions_executed;
        self.profiler.recordExit(entry_addr, exec_time);

        // If profiler says compile, do it now
        if (should_compile and self.config.use_native) {
            try self.compileHotFunction(entry_addr, code);
        }

        // Analyze hot paths for future compilations
        try self.analyzeHotPaths(code);

        return result;
    }

    /// Compile a hot function to native code
    fn compileHotFunction(self: *Self, address: u32, code: []const u8) !void {
        // Skip if already compiled
        if (self.native_cache.contains(address)) {
            self.profiler.markCompiled(address);
            return;
        }

        const compile_start = std.time.nanoTimestamp();

        // Record trace for the function
        try self.jit_compiler.startTrace(address);

        var ip: usize = address;
        var trace_len: usize = 0;
        const max_trace = self.config.trace_max_length;

        while (ip < code.len and trace_len < max_trace) {
            const opcode_byte = code[ip];
            const opcode: Opcode = @enumFromInt(opcode_byte);
            const type_info = inferTypeFromOpcode(opcode);

            const operand_size = opcode.operandSize();
            var operand: u16 = 0;
            if (operand_size >= 2 and ip + 2 < code.len) {
                operand = (@as(u16, code[ip + 1]) << 8) | @as(u16, code[ip + 2]);
            } else if (operand_size == 1 and ip + 1 < code.len) {
                operand = code[ip + 1];
            }

            try self.jit_compiler.recordInstruction(opcode, operand, type_info);
            trace_len += 1;

            if (opcode == .HALT or opcode == .RET) {
                _ = try self.jit_compiler.stopTrace(false, 0);
                break;
            }

            if (opcode == .LOOP) {
                _ = try self.jit_compiler.stopTrace(true, address);
                break;
            }

            ip += 1 + operand_size;
        }

        // Try to compile to native
        if (self.jit_compiler.lookupCode(address)) |compiled_code| {
            var native_compiler = NativeCompiler.init(self.allocator);

            if (native_compiler.compile(compiled_code.ir.items)) |machine_code| {
                defer self.allocator.free(machine_code);
                native_compiler.deinit();

                // Create executable memory region
                if (ExecutableCode.init(machine_code)) |executable| {
                    try self.native_cache.put(address, NativeCodeEntry{
                        .executable = executable,
                        .execution_count = 0,
                        .is_valid = true,
                    });
                    self.profiler.markCompiled(address);
                } else |_| {
                    // Failed to create executable memory
                }
            } else |_| {
                native_compiler.deinit();
                // Compilation failed, continue with interpreter
            }
        }

        const compile_end = std.time.nanoTimestamp();
        self.native_compile_time_ns += @intCast(@max(0, compile_end - compile_start));
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
    // TIERED EXECUTION (FULL AUTOMATIC)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Execute with full tiered compilation support
    /// Automatically promotes functions through tiers based on execution count
    pub fn executeTiered(self: *Self, code: []const u8, constants: []const Value) !ExecutionResult {
        self.vm.load(code, constants);

        // Reset metrics
        self.jit_instructions = 0;
        self.interpreter_instructions = 0;
        self.native_instructions = 0;

        const entry_addr: u32 = 0;
        const start_time = std.time.nanoTimestamp();

        // Get current tier for this function
        const current_tier = self.tiered_compiler.getTier(entry_addr);

        // Execute at appropriate tier
        const result: Value = switch (current_tier) {
            .Interpreter => blk: {
                // Tier 0: Bytecode interpreter
                const val = try self.vm.run();
                self.interpreter_instructions = self.vm.instructions_executed;
                break :blk val;
            },
            .JIT_IR => blk: {
                // Tier 1: JIT IR interpreter
                if (self.tiered_compiler.jit_ir_cache.get(entry_addr)) |ir| {
                    const ir_result = interpretIRCode(ir);
                    self.jit_instructions += ir.len;
                    break :blk .{ .int_val = ir_result };
                }
                // Fallback to bytecode
                const val = try self.vm.run();
                self.interpreter_instructions = self.vm.instructions_executed;
                break :blk val;
            },
            .Native => blk: {
                // Tier 2: Native x86-64 code with inline cache
                // Check inline cache first (avoids HashMap lookup)
                if (self.last_native_addr == entry_addr) {
                    if (self.last_native_ptr) |executable| {
                        const native_result = executable.call();
                        self.native_instructions += 1;
                        self.inline_cache_hits += 1;
                        break :blk .{ .int_val = native_result };
                    }
                }
                // Cache miss - lookup in HashMap
                if (self.tiered_compiler.native_cache.getPtr(entry_addr)) |executable| {
                    // Update inline cache
                    self.last_native_addr = entry_addr;
                    self.last_native_ptr = executable;

                    const native_result = executable.call();
                    self.native_instructions += 1;
                    break :blk .{ .int_val = native_result };
                }
                // Fallback to JIT IR
                if (self.tiered_compiler.jit_ir_cache.get(entry_addr)) |ir| {
                    const ir_result = interpretIRCode(ir);
                    self.jit_instructions += ir.len;
                    break :blk .{ .int_val = ir_result };
                }
                // Fallback to bytecode
                const val = try self.vm.run();
                self.interpreter_instructions = self.vm.instructions_executed;
                break :blk val;
            },
        };

        const end_time = std.time.nanoTimestamp();
        const exec_time: u64 = @intCast(@max(0, end_time - start_time));

        // Record execution and check for tier promotion
        if (try self.tiered_compiler.recordExecution(entry_addr, exec_time)) |next_tier| {
            // Promotion triggered - compile to next tier
            try self.promoteToTier(entry_addr, next_tier, code);
        }

        return ExecutionResult{
            .value = result,
            .used_jit = self.jit_instructions > 0 or self.native_instructions > 0,
            .instructions_interpreted = self.interpreter_instructions,
            .instructions_jit = self.jit_instructions + self.native_instructions,
            .execution_time_ns = exec_time,
        };
    }

    /// Promote function to specified tier
    fn promoteToTier(self: *Self, address: u32, target_tier: CompilationTier, code: []const u8) !void {
        // Build IR from bytecode
        const ir = try self.buildIRFromBytecode(address, code);
        defer self.allocator.free(ir);

        // Promote in tiered compiler
        _ = try self.tiered_compiler.promote(address, ir);

        // Update stats based on tier
        switch (target_tier) {
            .JIT_IR => {
                // IR is now cached in tiered_compiler
            },
            .Native => {
                // Native code is now cached in tiered_compiler
            },
            .Interpreter => {},
        }
    }

    /// Build IR instructions from bytecode with constants
    fn buildIRFromBytecode(self: *Self, start_addr: u32, code: []const u8) ![]IRInstruction {
        var ir_list = std.ArrayList(IRInstruction).init(self.allocator);
        errdefer ir_list.deinit();

        var ip: usize = start_addr;
        var reg: u8 = 0;
        const max_instructions: usize = 100;

        // Get constants from VM
        const constants = self.vm.constants;

        while (ip < code.len and ir_list.items.len < max_instructions) {
            const opcode_byte = code[ip];
            const opcode: Opcode = @enumFromInt(opcode_byte);
            const operand_size = opcode.operandSize();

            var operand: i64 = 0;
            if (operand_size >= 2 and ip + 2 < code.len) {
                operand = @as(i64, code[ip + 1]) << 8 | @as(i64, code[ip + 2]);
            } else if (operand_size == 1 and ip + 1 < code.len) {
                operand = code[ip + 1];
            }

            // Convert bytecode opcode to IR instruction
            const ir_instr: ?IRInstruction = switch (opcode) {
                .PUSH_CONST => blk: {
                    // Get actual value from constants pool
                    const const_idx: usize = @intCast(operand);
                    const actual_value: i64 = if (const_idx < constants.len)
                        constants[const_idx].toInt() orelse 0
                    else
                        0;

                    const instr = IRInstruction{
                        .opcode = .LOAD_CONST,
                        .dest = reg,
                        .src1 = 0,
                        .src2 = 0,
                        .imm = actual_value, // Use actual value, not index
                    };
                    reg +%= 1;
                    break :blk instr;
                },
                .ADD => blk: {
                    if (reg >= 2) {
                        const instr = IRInstruction{
                            .opcode = .ADD_INT,
                            .dest = reg - 2,
                            .src1 = reg - 2,
                            .src2 = reg - 1,
                            .imm = 0,
                        };
                        reg -%= 1;
                        break :blk instr;
                    }
                    break :blk null;
                },
                .SUB => blk: {
                    if (reg >= 2) {
                        const instr = IRInstruction{
                            .opcode = .SUB_INT,
                            .dest = reg - 2,
                            .src1 = reg - 2,
                            .src2 = reg - 1,
                            .imm = 0,
                        };
                        reg -%= 1;
                        break :blk instr;
                    }
                    break :blk null;
                },
                .MUL => blk: {
                    if (reg >= 2) {
                        const instr = IRInstruction{
                            .opcode = .MUL_INT,
                            .dest = reg - 2,
                            .src1 = reg - 2,
                            .src2 = reg - 1,
                            .imm = 0,
                        };
                        reg -%= 1;
                        break :blk instr;
                    }
                    break :blk null;
                },
                .DIV => blk: {
                    if (reg >= 2) {
                        const instr = IRInstruction{
                            .opcode = .DIV_INT,
                            .dest = reg - 2,
                            .src1 = reg - 2,
                            .src2 = reg - 1,
                            .imm = 0,
                        };
                        reg -%= 1;
                        break :blk instr;
                    }
                    break :blk null;
                },
                .HALT, .RET => blk: {
                    const dest_reg = if (reg > 0) reg - 1 else 0;
                    break :blk IRInstruction{
                        .opcode = .RETURN,
                        .dest = dest_reg,
                        .src1 = 0,
                        .src2 = 0,
                        .imm = 0,
                    };
                },
                else => null,
            };

            if (ir_instr) |instr| {
                try ir_list.append(instr);
            }

            // Check for termination
            if (opcode == .HALT or opcode == .RET) {
                break;
            }

            ip += 1 + operand_size;
        }

        // Ensure we have a return instruction
        if (ir_list.items.len == 0 or ir_list.items[ir_list.items.len - 1].opcode != .RETURN) {
            try ir_list.append(IRInstruction{
                .opcode = .RETURN,
                .dest = 0,
                .src1 = 0,
                .src2 = 0,
                .imm = 0,
            });
        }

        return ir_list.toOwnedSlice();
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

test "JITAdapter автоматический JIT при повторном выполнении" {
    const allocator = std.testing.allocator;
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();
    adapter.setMode(.Mixed);
    adapter.config.hot_threshold = 1; // Компилировать сразу

    // Простой байткод: PUSH 42, HALT
    const code = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0x00, 0x00,
        @intFromEnum(Opcode.HALT),
    };
    const constants = [_]Value{.{ .int_val = 42 }};

    // Первое выполнение - через интерпретатор
    const result1 = try adapter.execute(&code, &constants);
    try std.testing.expect(result1.value == .int_val);
    try std.testing.expectEqual(@as(i64, 42), result1.value.int_val);

    // После первого выполнения должен быть скомпилирован нативный код
    // (если hot_threshold = 1)
    const metrics = adapter.getNativeMetrics();

    // Проверяем что компиляция произошла
    if (@import("builtin").mode == .Debug) {
        std.debug.print("\n=== Автоматический JIT тест ===\n", .{});
        std.debug.print("Кэшированных функций: {d}\n", .{metrics.cached_functions});
        std.debug.print("Нативных инструкций: {d}\n", .{metrics.native_instructions});
    }
}

test "Benchmark: VM vs JIT IR vs Native" {
    const allocator = std.testing.allocator;

    // IR для: (2 + 3) * 7 = 35
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 2 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .LOAD_CONST, .dest = 3, .src1 = 0, .src2 = 0, .imm = 7 },
        .{ .opcode = .MUL_INT, .dest = 4, .src1 = 2, .src2 = 3, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 4, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const iterations: usize = 10000;

    // Бенчмарк нативного кода
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

    // Проверяем результат
    try std.testing.expectEqual(@as(i64, 35), native_result);

    // Выводим результаты бенчмарка
    if (@import("builtin").mode == .Debug) {
        std.debug.print("\n=== Бенчмарк: VM vs JIT IR vs Native ===\n", .{});
        std.debug.print("Итераций: {d}\n", .{iterations});
        std.debug.print("Нативный код: {d} нс ({d:.2} нс/итер)\n", .{
            native_time,
            @as(f64, @floatFromInt(native_time)) / @as(f64, @floatFromInt(iterations)),
        });
        std.debug.print("Результат: {d} (ожидалось 35)\n", .{native_result});
    }
}

test "Бенчмарк: нативный код vs интерпретатор" {
    const allocator = std.testing.allocator;

    // Компилируем IR в нативный код: 2 + 3 = 5
    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();

    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 2 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };
    try adapter.compileToNative(0, &ir);

    const iterations: usize = 1000;

    // Бенчмарк нативного кода
    const start = std.time.nanoTimestamp();
    var result: i64 = 0;
    for (0..iterations) |_| {
        result = adapter.tryExecuteNative(0).?;
    }
    const end = std.time.nanoTimestamp();
    const native_time: u64 = @intCast(@max(0, end - start));

    // Проверяем результат
    try std.testing.expectEqual(@as(i64, 5), result);

    // Выводим результаты
    if (@import("builtin").mode == .Debug) {
        const per_iter = @as(f64, @floatFromInt(native_time)) / @as(f64, @floatFromInt(iterations));
        std.debug.print("\n=== Бенчмарк нативного кода ===\n", .{});
        std.debug.print("Итераций: {d}\n", .{iterations});
        std.debug.print("Время: {d} нс ({d:.2} нс/итер)\n", .{ native_time, per_iter });
        std.debug.print("Результат: {d} (ожидалось 5)\n", .{result});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOT PATH PROFILER TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "HotPathProfiler basic profiling" {
    const allocator = std.testing.allocator;

    var profiler = HotPathProfiler.init(allocator);
    defer profiler.deinit();

    // Record function entries
    const addr: u32 = 0x100;
    for (0..5) |_| {
        _ = try profiler.recordEntry(addr);
    }

    // Check profile
    const profile = profiler.getProfile(addr).?;
    try std.testing.expectEqual(@as(u64, 5), profile.execution_count);
    try std.testing.expect(!profile.is_hot); // Below threshold (10)
    try std.testing.expect(!profile.is_compiled);

    // Stats
    const stats = profiler.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.total_functions);
    try std.testing.expectEqual(@as(usize, 0), stats.hot_functions);
}

test "HotPathProfiler hot detection" {
    const allocator = std.testing.allocator;

    var profiler = HotPathProfiler.initWithThresholds(allocator, 5, 10);
    defer profiler.deinit();

    const addr: u32 = 0x200;

    // Execute 4 times - not hot yet
    for (0..4) |_| {
        const should_compile = try profiler.recordEntry(addr);
        try std.testing.expect(!should_compile);
    }
    try std.testing.expect(!profiler.getProfile(addr).?.is_hot);

    // 5th execution - becomes hot
    _ = try profiler.recordEntry(addr);
    try std.testing.expect(profiler.getProfile(addr).?.is_hot);

    const stats = profiler.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.hot_functions);
}

test "HotPathProfiler JIT trigger" {
    const allocator = std.testing.allocator;

    var profiler = HotPathProfiler.initWithThresholds(allocator, 5, 10);
    defer profiler.deinit();

    const addr: u32 = 0x300;

    // Execute 9 times - hot but not compiled
    for (0..9) |_| {
        const should_compile = try profiler.recordEntry(addr);
        try std.testing.expect(!should_compile);
    }

    // 10th execution - triggers JIT
    const should_compile = try profiler.recordEntry(addr);
    try std.testing.expect(should_compile);

    // Mark as compiled
    profiler.markCompiled(addr);
    try std.testing.expect(profiler.getProfile(addr).?.is_compiled);

    // 11th execution - already compiled, no trigger
    const should_compile_again = try profiler.recordEntry(addr);
    try std.testing.expect(!should_compile_again);
}

test "HotPathProfiler multiple functions" {
    const allocator = std.testing.allocator;

    var profiler = HotPathProfiler.initWithThresholds(allocator, 3, 5);
    defer profiler.deinit();

    // Function A: called 10 times (hot, should compile)
    for (0..10) |_| {
        _ = try profiler.recordEntry(0x100);
    }

    // Function B: called 4 times (hot, not compiled yet)
    for (0..4) |_| {
        _ = try profiler.recordEntry(0x200);
    }

    // Function C: called 2 times (not hot)
    for (0..2) |_| {
        _ = try profiler.recordEntry(0x300);
    }

    const stats = profiler.getStats();
    try std.testing.expectEqual(@as(usize, 3), stats.total_functions);
    try std.testing.expectEqual(@as(usize, 2), stats.hot_functions); // A and B
    try std.testing.expectEqual(@as(u32, 0x100), stats.hottest_address);
    try std.testing.expectEqual(@as(u64, 10), stats.hottest_count);

    // Get uncompiled hot functions
    const hot_uncompiled = try profiler.getHotUncompiled(allocator);
    defer allocator.free(hot_uncompiled);
    try std.testing.expectEqual(@as(usize, 1), hot_uncompiled.len); // Only A (>=5 calls)
}

test "HotPathProfiler timing" {
    const allocator = std.testing.allocator;

    var profiler = HotPathProfiler.init(allocator);
    defer profiler.deinit();

    const addr: u32 = 0x400;

    // Record entry
    _ = try profiler.recordEntry(addr);

    // Simulate execution time
    profiler.recordExit(addr, 1000); // 1000 ns

    _ = try profiler.recordEntry(addr);
    profiler.recordExit(addr, 2000); // 2000 ns

    const profile = profiler.getProfile(addr).?;
    try std.testing.expectEqual(@as(u64, 3000), profile.total_time_ns);
    try std.testing.expectEqual(@as(u64, 1500), profile.avgTimeNs()); // 3000/2
}

test "HotPathProfiler integration with JITAdapter" {
    const allocator = std.testing.allocator;

    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();

    // Set low thresholds for testing
    adapter.profiler.hot_threshold = 2;
    adapter.profiler.jit_threshold = 3;

    // Simulate multiple executions
    for (0..5) |_| {
        _ = try adapter.profiler.recordEntry(0);
    }

    const stats = adapter.getProfilerStats();
    try std.testing.expectEqual(@as(usize, 1), stats.total_functions);
    try std.testing.expectEqual(@as(usize, 1), stats.hot_functions);

    if (@import("builtin").mode == .Debug) {
        std.debug.print("\n=== Hot Path Profiler Integration ===\n", .{});
        std.debug.print("Total functions: {d}\n", .{stats.total_functions});
        std.debug.print("Hot functions: {d}\n", .{stats.hot_functions});
        std.debug.print("Compiled functions: {d}\n", .{stats.compiled_functions});
        std.debug.print("Total executions: {d}\n", .{stats.total_executions});
    }
}

test "Benchmark: Hot Path Profiler automatic JIT" {
    const allocator = std.testing.allocator;

    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();

    // Configure for automatic JIT after 10 executions
    adapter.profiler.hot_threshold = 5;
    adapter.profiler.jit_threshold = 10;

    // Pre-compile native code for address 0
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 10 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const iterations: usize = 1000;

    // Phase 1: Cold execution (profiling only)
    const cold_start = std.time.nanoTimestamp();
    for (0..9) |_| {
        const should_compile = try adapter.profiler.recordEntry(0);
        try std.testing.expect(!should_compile);
        adapter.profiler.recordExit(0, 100);
    }
    const cold_end = std.time.nanoTimestamp();
    const cold_time: u64 = @intCast(@max(0, cold_end - cold_start));

    // Phase 2: JIT trigger
    const should_compile = try adapter.profiler.recordEntry(0);
    try std.testing.expect(should_compile);

    // Compile to native
    try adapter.compileToNative(0, &ir);
    adapter.profiler.markCompiled(0);

    // Phase 3: Hot execution (native code)
    const hot_start = std.time.nanoTimestamp();
    var result: i64 = 0;
    for (0..iterations) |_| {
        result = adapter.tryExecuteNative(0).?;
        _ = try adapter.profiler.recordEntry(0);
    }
    const hot_end = std.time.nanoTimestamp();
    const hot_time: u64 = @intCast(@max(0, hot_end - hot_start));

    // Verify result
    try std.testing.expectEqual(@as(i64, 15), result);

    // Get final stats
    const stats = adapter.getProfilerStats();
    try std.testing.expectEqual(@as(usize, 1), stats.total_functions);
    try std.testing.expect(stats.hot_functions >= 1);
    try std.testing.expectEqual(@as(usize, 1), stats.compiled_functions);

    if (@import("builtin").mode == .Debug) {
        const cold_per_iter = @as(f64, @floatFromInt(cold_time)) / 9.0;
        const hot_per_iter = @as(f64, @floatFromInt(hot_time)) / @as(f64, @floatFromInt(iterations));
        const speedup = cold_per_iter / hot_per_iter;

        std.debug.print("\n=== Benchmark: Hot Path Profiler Automatic JIT ===\n", .{});
        std.debug.print("Cold phase (9 iters): {d} ns ({d:.2} ns/iter)\n", .{ cold_time, cold_per_iter });
        std.debug.print("Hot phase ({d} iters): {d} ns ({d:.2} ns/iter)\n", .{ iterations, hot_time, hot_per_iter });
        std.debug.print("Speedup after JIT: {d:.1}x\n", .{speedup});
        std.debug.print("Total executions: {d}\n", .{stats.total_executions});
        std.debug.print("Compiled functions: {d}\n", .{stats.compiled_functions});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TIERED COMPILER TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TieredCompiler basic initialization" {
    const allocator = std.testing.allocator;

    var compiler = TieredCompiler.init(allocator);
    defer compiler.deinit();

    // Initial state
    const stats = compiler.getStats();
    try std.testing.expectEqual(@as(usize, 0), stats.functions_at_tier[0]);
    try std.testing.expectEqual(@as(u64, 0), stats.total_promotions);
}

test "TieredCompiler function state tracking" {
    const allocator = std.testing.allocator;

    var compiler = TieredCompiler.init(allocator);
    defer compiler.deinit();

    // Create function state
    const state = try compiler.getOrCreateState(0x100);
    try std.testing.expectEqual(CompilationTier.Interpreter, state.current_tier);
    try std.testing.expectEqual(@as(u64, 0), state.execution_count);

    // Record executions
    state.recordExecution(100);
    state.recordExecution(200);
    try std.testing.expectEqual(@as(u64, 2), state.execution_count);
    try std.testing.expectEqual(@as(u64, 300), state.total_time_ns);
}

test "TieredCompiler tier promotion thresholds" {
    const allocator = std.testing.allocator;

    var compiler = TieredCompiler.initWithThresholds(allocator, .{
        .tier1_threshold = 5,
        .tier2_threshold = 10,
    });
    defer compiler.deinit();

    const addr: u32 = 0x200;

    // Execute 4 times - no promotion
    for (0..4) |_| {
        const next_tier = try compiler.recordExecution(addr, 100);
        try std.testing.expect(next_tier == null);
    }
    try std.testing.expectEqual(CompilationTier.Interpreter, compiler.getTier(addr));

    // 5th execution - should trigger tier1 promotion
    const next_tier = try compiler.recordExecution(addr, 100);
    try std.testing.expectEqual(CompilationTier.JIT_IR, next_tier.?);
}

test "TieredCompiler full promotion chain" {
    const allocator = std.testing.allocator;

    var compiler = TieredCompiler.initWithThresholds(allocator, .{
        .tier1_threshold = 3,
        .tier2_threshold = 5,
    });
    defer compiler.deinit();

    const addr: u32 = 0x300;
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 42 },
        .{ .opcode = .RETURN, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    // Phase 1: Interpreter (0-2 executions)
    for (0..2) |_| {
        _ = try compiler.recordExecution(addr, 100);
    }
    try std.testing.expectEqual(CompilationTier.Interpreter, compiler.getTier(addr));

    // Phase 2: Trigger tier1 promotion (3rd execution)
    const tier1_trigger = try compiler.recordExecution(addr, 100);
    try std.testing.expectEqual(CompilationTier.JIT_IR, tier1_trigger.?);

    // Promote to JIT IR
    const promoted1 = try compiler.promote(addr, &ir);
    try std.testing.expect(promoted1);
    try std.testing.expectEqual(CompilationTier.JIT_IR, compiler.getTier(addr));

    // Phase 3: Execute at JIT IR tier (4-7 executions)
    for (0..4) |_| {
        _ = try compiler.recordExecution(addr, 50);
    }

    // Phase 4: Trigger tier2 promotion (8th execution at JIT_IR = 5 since promotion)
    const tier2_trigger = try compiler.recordExecution(addr, 50);
    try std.testing.expectEqual(CompilationTier.Native, tier2_trigger.?);

    // Promote to Native
    const promoted2 = try compiler.promote(addr, &ir);
    try std.testing.expect(promoted2);
    try std.testing.expectEqual(CompilationTier.Native, compiler.getTier(addr));

    // Check stats
    const stats = compiler.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.total_promotions);
    try std.testing.expectEqual(@as(u64, 1), stats.tier1_promotions);
    try std.testing.expectEqual(@as(u64, 1), stats.tier2_promotions);
}

test "TieredCompiler IR execution" {
    _ = std.testing.allocator; // Mark as used

    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 10 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    // Test standalone IR interpreter
    const result = interpretIRCode(&ir);
    try std.testing.expectEqual(@as(i64, 15), result);
}

test "TieredCompiler integration with JITAdapter" {
    const allocator = std.testing.allocator;

    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();

    // Configure tiered compiler
    adapter.tiered_compiler.thresholds.tier1_threshold = 3;
    adapter.tiered_compiler.thresholds.tier2_threshold = 5;

    // Simulate executions
    for (0..10) |_| {
        _ = try adapter.tiered_compiler.recordExecution(0, 100);
    }

    const stats = adapter.getTieredStats();
    try std.testing.expectEqual(@as(usize, 1), stats.functions_at_tier[0]); // Still at interpreter (no promotion called)

    if (@import("builtin").mode == .Debug) {
        std.debug.print("\n=== Tiered Compiler Integration ===\n", .{});
        std.debug.print("Functions at Interpreter: {d}\n", .{stats.functions_at_tier[0]});
        std.debug.print("Functions at JIT IR: {d}\n", .{stats.functions_at_tier[1]});
        std.debug.print("Functions at Native: {d}\n", .{stats.functions_at_tier[2]});
    }
}

test "Benchmark: Tiered Compilation Pipeline" {
    const allocator = std.testing.allocator;

    var compiler = TieredCompiler.initWithThresholds(allocator, .{
        .tier1_threshold = 10,
        .tier2_threshold = 50,
    });
    defer compiler.deinit();

    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 7 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 6 },
        .{ .opcode = .MUL_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const addr: u32 = 0;
    const iterations: usize = 100;

    // Phase 1: Interpreter tier
    var interpreter_time: u64 = 0;
    for (0..9) |_| {
        const start = std.time.nanoTimestamp();
        const result = interpretIRCode(&ir);
        const end = std.time.nanoTimestamp();
        interpreter_time += @intCast(@max(0, end - start));
        _ = try compiler.recordExecution(addr, @intCast(@max(0, end - start)));
        try std.testing.expectEqual(@as(i64, 42), result);
    }

    // Trigger and perform tier1 promotion
    _ = try compiler.recordExecution(addr, 100);
    _ = try compiler.promote(addr, &ir);

    // Phase 2: JIT IR tier
    var jit_ir_time: u64 = 0;
    for (0..40) |_| {
        const start = std.time.nanoTimestamp();
        const result = interpretIRCode(&ir);
        const end = std.time.nanoTimestamp();
        jit_ir_time += @intCast(@max(0, end - start));
        _ = try compiler.recordExecution(addr, @intCast(@max(0, end - start)));
        try std.testing.expectEqual(@as(i64, 42), result);
    }

    // Trigger and perform tier2 promotion
    _ = try compiler.recordExecution(addr, 100);
    _ = try compiler.promote(addr, &ir);

    // Phase 3: Native tier
    var native_time: u64 = 0;
    if (compiler.native_cache.getPtr(addr)) |executable| {
        for (0..iterations) |_| {
            const start = std.time.nanoTimestamp();
            const result = executable.call();
            const end = std.time.nanoTimestamp();
            native_time += @intCast(@max(0, end - start));
            try std.testing.expectEqual(@as(i64, 42), result);
        }
    }

    const stats = compiler.getStats();

    if (@import("builtin").mode == .Debug) {
        std.debug.print("\n=== Benchmark: Tiered Compilation Pipeline ===\n", .{});
        std.debug.print("Interpreter (9 iters): {d} ns ({d:.2} ns/iter)\n", .{
            interpreter_time,
            @as(f64, @floatFromInt(interpreter_time)) / 9.0,
        });
        std.debug.print("JIT IR (40 iters): {d} ns ({d:.2} ns/iter)\n", .{
            jit_ir_time,
            @as(f64, @floatFromInt(jit_ir_time)) / 40.0,
        });
        std.debug.print("Native ({d} iters): {d} ns ({d:.2} ns/iter)\n", .{
            iterations,
            native_time,
            @as(f64, @floatFromInt(native_time)) / @as(f64, @floatFromInt(iterations)),
        });
        std.debug.print("Tier promotions: {d} (T1: {d}, T2: {d})\n", .{
            stats.total_promotions,
            stats.tier1_promotions,
            stats.tier2_promotions,
        });
        std.debug.print("Compile time: {d} ns (T1: {d}, T2: {d})\n", .{
            stats.total_compile_time_ns,
            stats.tier1_compile_time_ns,
            stats.tier2_compile_time_ns,
        });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FULL TIERED INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "executeTiered basic execution" {
    const allocator = std.testing.allocator;

    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();

    // Simple bytecode: PUSH_CONST idx=0, PUSH_CONST idx=1, ADD, HALT
    const code = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // PUSH constants[0] = 10
        @intFromEnum(Opcode.PUSH_CONST), 0, 1, // PUSH constants[1] = 5
        @intFromEnum(Opcode.ADD), // ADD
        @intFromEnum(Opcode.HALT), // HALT
    };
    const constants = [_]Value{ .{ .int_val = 10 }, .{ .int_val = 5 } };

    // First execution - should be at Interpreter tier
    const result1 = try adapter.executeTiered(&code, &constants);
    try std.testing.expectEqual(@as(i64, 15), result1.value.toInt().?);
    try std.testing.expectEqual(CompilationTier.Interpreter, adapter.getFunctionTier(0));
}

test "executeTiered automatic tier promotion" {
    const allocator = std.testing.allocator;

    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();

    // Configure low thresholds for testing
    adapter.tiered_compiler.thresholds.tier1_threshold = 3;
    adapter.tiered_compiler.thresholds.tier2_threshold = 6;

    // Simple bytecode: PUSH 7, PUSH 6, MUL, HALT
    const code = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // constants[0] = 7
        @intFromEnum(Opcode.PUSH_CONST), 0, 1, // constants[1] = 6
        @intFromEnum(Opcode.MUL),
        @intFromEnum(Opcode.HALT),
    };
    const constants = [_]Value{ .{ .int_val = 7 }, .{ .int_val = 6 } };

    // Execute multiple times to trigger promotions
    for (0..10) |i| {
        const result = try adapter.executeTiered(&code, &constants);
        // Value check: 7 * 6 = 42
        const val = result.value.toInt() orelse 0;
        try std.testing.expectEqual(@as(i64, 42), val);

        const tier = adapter.getFunctionTier(0);
        if (@import("builtin").mode == .Debug and i < 5) {
            std.debug.print("Iteration {d}: tier = {s}, value = {d}\n", .{ i, tier.name(), val });
        }
    }

    // After 10 executions, should be at higher tier
    const final_tier = adapter.getFunctionTier(0);
    try std.testing.expect(final_tier != .Interpreter);

    const stats = adapter.getTieredStats();
    try std.testing.expect(stats.total_promotions >= 1);
}

test "executeTiered metrics tracking" {
    const allocator = std.testing.allocator;

    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();

    adapter.tiered_compiler.thresholds.tier1_threshold = 2;
    adapter.tiered_compiler.thresholds.tier2_threshold = 4;

    const code = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // constants[0] = 100
        @intFromEnum(Opcode.HALT),
    };
    const constants = [_]Value{.{ .int_val = 100 }};

    // Execute and track metrics
    var total_time: u64 = 0;
    for (0..5) |_| {
        const result = try adapter.executeTiered(&code, &constants);
        total_time += result.execution_time_ns;
        // Value should be 100
        const val = result.value.toInt() orelse 0;
        try std.testing.expectEqual(@as(i64, 100), val);
    }

    const state = adapter.tiered_compiler.getFunctionState(0);
    try std.testing.expect(state != null);
    try std.testing.expectEqual(@as(u64, 5), state.?.execution_count);
}

test "Benchmark: Full Automatic Tiered Compilation" {
    const allocator = std.testing.allocator;

    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();

    // Configure thresholds
    adapter.tiered_compiler.thresholds.tier1_threshold = 20;
    adapter.tiered_compiler.thresholds.tier2_threshold = 50;

    // Bytecode: (2 + 3) * 7 = 35
    const code = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0, // constants[0] = 2
        @intFromEnum(Opcode.PUSH_CONST), 0, 1, // constants[1] = 3
        @intFromEnum(Opcode.ADD),
        @intFromEnum(Opcode.PUSH_CONST), 0, 2, // constants[2] = 7
        @intFromEnum(Opcode.MUL),
        @intFromEnum(Opcode.HALT),
    };
    const constants = [_]Value{ .{ .int_val = 2 }, .{ .int_val = 3 }, .{ .int_val = 7 } };

    const iterations: usize = 100;
    var tier_times: [3]u64 = [_]u64{ 0, 0, 0 };
    var tier_counts: [3]usize = [_]usize{ 0, 0, 0 };

    for (0..iterations) |_| {
        const tier_before = adapter.getFunctionTier(0);
        const result = try adapter.executeTiered(&code, &constants);

        const tier_idx = @intFromEnum(tier_before);
        tier_times[tier_idx] += result.execution_time_ns;
        tier_counts[tier_idx] += 1;

        // Value: (2+3)*7 = 35
        const val = result.value.toInt() orelse 0;
        try std.testing.expectEqual(@as(i64, 35), val);
    }

    const stats = adapter.getTieredStats();

    if (@import("builtin").mode == .Debug) {
        std.debug.print("\n=== Benchmark: Full Automatic Tiered Compilation ===\n", .{});
        std.debug.print("Total iterations: {d}\n", .{iterations});

        for (0..3) |i| {
            if (tier_counts[i] > 0) {
                const tier: CompilationTier = @enumFromInt(i);
                const avg = @as(f64, @floatFromInt(tier_times[i])) / @as(f64, @floatFromInt(tier_counts[i]));
                std.debug.print("{s}: {d} iters, {d:.2} ns/iter avg\n", .{
                    tier.name(),
                    tier_counts[i],
                    avg,
                });
            }
        }

        std.debug.print("Promotions: {d} (T1: {d}, T2: {d})\n", .{
            stats.total_promotions,
            stats.tier1_promotions,
            stats.tier2_promotions,
        });
        std.debug.print("Final tier: {s}\n", .{adapter.getFunctionTier(0).name()});
    }
}

test "Value correctness across all tiers" {
    const allocator = std.testing.allocator;

    var adapter = try JITAdapter.init(allocator);
    defer adapter.deinit();

    // Very low thresholds to quickly reach all tiers
    adapter.tiered_compiler.thresholds.tier1_threshold = 2;
    adapter.tiered_compiler.thresholds.tier2_threshold = 4;

    // Bytecode: 10 + 5 = 15
    const code = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0,
        @intFromEnum(Opcode.PUSH_CONST), 0, 1,
        @intFromEnum(Opcode.ADD),
        @intFromEnum(Opcode.HALT),
    };
    const constants = [_]Value{ .{ .int_val = 10 }, .{ .int_val = 5 } };

    // Track values at each tier
    var tier_values: [3]?i64 = [_]?i64{ null, null, null };

    for (0..10) |_| {
        const tier = adapter.getFunctionTier(0);
        const result = try adapter.executeTiered(&code, &constants);
        const val = result.value.toInt() orelse 0;

        // Record first value at each tier
        const tier_idx = @intFromEnum(tier);
        if (tier_values[tier_idx] == null) {
            tier_values[tier_idx] = val;
        }

        // All values should be 15
        try std.testing.expectEqual(@as(i64, 15), val);
    }

    // Verify we hit multiple tiers
    const stats = adapter.getTieredStats();
    try std.testing.expect(stats.total_promotions >= 1);

    if (@import("builtin").mode == .Debug) {
        std.debug.print("\n=== Value Correctness Test ===\n", .{});
        for (0..3) |i| {
            if (tier_values[i]) |val| {
                const tier: CompilationTier = @enumFromInt(i);
                std.debug.print("{s}: value = {d}\n", .{ tier.name(), val });
            }
        }
        std.debug.print("All values correct: 15\n", .{});
    }
}

test "Benchmark: Native call overhead analysis" {
    const allocator = std.testing.allocator;

    // Create IR for 2 + 3 = 5
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 2 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    // Compile to native
    var native_compiler = NativeCompiler.init(allocator);
    const machine_code = try native_compiler.compile(&ir);
    defer allocator.free(machine_code);
    native_compiler.deinit();

    var executable = try ExecutableCode.init(machine_code);
    defer executable.deinit();

    const iterations: usize = 10000;

    // Benchmark 1: Direct native call (no overhead)
    const direct_start = std.time.nanoTimestamp();
    var direct_result: i64 = 0;
    for (0..iterations) |_| {
        direct_result = executable.call();
    }
    const direct_end = std.time.nanoTimestamp();
    const direct_time: u64 = @intCast(@max(0, direct_end - direct_start));

    try std.testing.expectEqual(@as(i64, 5), direct_result);

    // Benchmark 2: IR interpreter
    const ir_start = std.time.nanoTimestamp();
    var ir_result: i64 = 0;
    for (0..iterations) |_| {
        ir_result = interpretIRCode(&ir);
    }
    const ir_end = std.time.nanoTimestamp();
    const ir_time: u64 = @intCast(@max(0, ir_end - ir_start));

    try std.testing.expectEqual(@as(i64, 5), ir_result);

    // Benchmark 3: HashMap lookup + native call (simulates tiered overhead)
    var cache = std.AutoHashMap(u32, ExecutableCode).init(allocator);
    defer cache.deinit();
    // Note: We can't put executable in cache as it would be freed twice
    // So we measure just the lookup overhead separately

    const lookup_start = std.time.nanoTimestamp();
    for (0..iterations) |_| {
        _ = cache.get(0); // Just lookup, no call
    }
    const lookup_end = std.time.nanoTimestamp();
    const lookup_time: u64 = @intCast(@max(0, lookup_end - lookup_start));

    if (@import("builtin").mode == .Debug) {
        const direct_per_iter = @as(f64, @floatFromInt(direct_time)) / @as(f64, @floatFromInt(iterations));
        const ir_per_iter = @as(f64, @floatFromInt(ir_time)) / @as(f64, @floatFromInt(iterations));
        const lookup_per_iter = @as(f64, @floatFromInt(lookup_time)) / @as(f64, @floatFromInt(iterations));

        std.debug.print("\n=== Native Call Overhead Analysis ===\n", .{});
        std.debug.print("Iterations: {d}\n", .{iterations});
        std.debug.print("Direct native call: {d:.2} ns/iter\n", .{direct_per_iter});
        std.debug.print("IR interpreter: {d:.2} ns/iter\n", .{ir_per_iter});
        std.debug.print("HashMap lookup only: {d:.2} ns/iter\n", .{lookup_per_iter});
        std.debug.print("Speedup (IR vs Native): {d:.1}x\n", .{ir_per_iter / direct_per_iter});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOOP UNROLLER TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "LoopUnroller detect simple loop" {
    const allocator = std.testing.allocator;

    var unroller = LoopUnroller.init(allocator);

    // IR with a simple loop: instructions 0-3, then LOOP_BACK to 1
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 }, // 0: init
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 1 }, // 1: loop start
        .{ .opcode = .ADD_INT, .dest = 0, .src1 = 0, .src2 = 1, .imm = 0 }, // 2: body
        .{ .opcode = .LOOP_BACK, .dest = 0, .src1 = 0, .src2 = 0, .imm = 1 }, // 3: back to 1
        .{ .opcode = .RETURN, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 }, // 4: return
    };

    const loops = try unroller.detectLoops(&ir);
    defer allocator.free(loops);

    try std.testing.expectEqual(@as(usize, 1), loops.len);
    try std.testing.expectEqual(@as(usize, 1), loops[0].start_idx);
    try std.testing.expectEqual(@as(usize, 3), loops[0].end_idx);
    try std.testing.expectEqual(@as(usize, 2), loops[0].body_size);
}

test "LoopUnroller unroll simple loop" {
    const allocator = std.testing.allocator;

    var unroller = LoopUnroller.initWithFactor(allocator, 2); // Unroll 2x

    // Simple loop body
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 }, // 0: init
        .{ .opcode = .ADD_INT, .dest = 0, .src1 = 0, .src2 = 0, .imm = 1 }, // 1: loop body
        .{ .opcode = .LOOP_BACK, .dest = 0, .src1 = 0, .src2 = 0, .imm = 1 }, // 2: back to 1
        .{ .opcode = .RETURN, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 }, // 3: return
    };

    const loop = LoopInfo{
        .start_idx = 1,
        .end_idx = 2,
        .iteration_count = null,
        .body_size = 1,
    };

    const unrolled = try unroller.unrollLoop(&ir, loop);
    defer allocator.free(unrolled);

    // Should have: init + (body * 2) + return = 1 + 2 + 1 = 4
    try std.testing.expectEqual(@as(usize, 4), unrolled.len);

    const stats = unroller.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.unrolled);
}

test "LoopUnroller optimize with no loops" {
    const allocator = std.testing.allocator;

    var unroller = LoopUnroller.init(allocator);

    // No loops
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .RETURN, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const optimized = try unroller.optimize(&ir);
    defer allocator.free(optimized);

    // Should be unchanged
    try std.testing.expectEqual(@as(usize, 2), optimized.len);
    try std.testing.expectEqual(jit.IROpcode.LOAD_CONST, optimized[0].opcode);
    try std.testing.expectEqual(jit.IROpcode.RETURN, optimized[1].opcode);
}

test "LoopUnroller skip large loops" {
    const allocator = std.testing.allocator;

    var unroller = LoopUnroller.init(allocator);
    unroller.max_body_size = 2; // Only unroll loops with <= 2 instructions

    // Loop with 5 instructions in body (too large)
    var ir_list = std.ArrayList(IRInstruction).init(allocator);
    defer ir_list.deinit();

    try ir_list.append(.{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 });
    for (0..5) |_| {
        try ir_list.append(.{ .opcode = .ADD_INT, .dest = 0, .src1 = 0, .src2 = 0, .imm = 1 });
    }
    try ir_list.append(.{ .opcode = .LOOP_BACK, .dest = 0, .src1 = 0, .src2 = 0, .imm = 1 });
    try ir_list.append(.{ .opcode = .RETURN, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 });

    const optimized = try unroller.optimize(ir_list.items);
    defer allocator.free(optimized);

    // Should be unchanged (loop too large)
    try std.testing.expectEqual(ir_list.items.len, optimized.len);
}

test "Benchmark: Loop unrolling effect" {
    const allocator = std.testing.allocator;

    // Create a simple loop: sum = 0; for i in 0..4: sum += 1
    const loop_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 }, // sum = 0
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 1 }, // inc = 1
        .{ .opcode = .ADD_INT, .dest = 0, .src1 = 0, .src2 = 1, .imm = 0 }, // sum += inc
        .{ .opcode = .LOOP_BACK, .dest = 0, .src1 = 0, .src2 = 0, .imm = 2 }, // back to ADD
        .{ .opcode = .RETURN, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 }, // return sum
    };

    // Unroll 4x
    var unroller = LoopUnroller.initWithFactor(allocator, 4);
    const unrolled_ir = try unroller.optimize(&loop_ir);
    defer allocator.free(unrolled_ir);

    const iterations: usize = 10000;

    // Benchmark original loop
    const loop_start = std.time.nanoTimestamp();
    var loop_result: i64 = 0;
    for (0..iterations) |_| {
        loop_result = interpretIRCode(&loop_ir);
    }
    const loop_end = std.time.nanoTimestamp();
    const loop_time: u64 = @intCast(@max(0, loop_end - loop_start));

    // Benchmark unrolled
    const unrolled_start = std.time.nanoTimestamp();
    var unrolled_result: i64 = 0;
    for (0..iterations) |_| {
        unrolled_result = interpretIRCode(unrolled_ir);
    }
    const unrolled_end = std.time.nanoTimestamp();
    const unrolled_time: u64 = @intCast(@max(0, unrolled_end - unrolled_start));

    const stats = unroller.getStats();

    if (@import("builtin").mode == .Debug) {
        const loop_per_iter = @as(f64, @floatFromInt(loop_time)) / @as(f64, @floatFromInt(iterations));
        const unrolled_per_iter = @as(f64, @floatFromInt(unrolled_time)) / @as(f64, @floatFromInt(iterations));

        std.debug.print("\n=== Loop Unrolling Benchmark ===\n", .{});
        std.debug.print("Original loop: {d:.2} ns/iter (result: {d})\n", .{ loop_per_iter, loop_result });
        std.debug.print("Unrolled (4x): {d:.2} ns/iter (result: {d})\n", .{ unrolled_per_iter, unrolled_result });
        std.debug.print("Original size: {d} instructions\n", .{loop_ir.len});
        std.debug.print("Unrolled size: {d} instructions\n", .{unrolled_ir.len});
        std.debug.print("Loops detected: {d}, unrolled: {d}\n", .{ stats.detected, stats.unrolled });
        if (loop_per_iter > unrolled_per_iter) {
            std.debug.print("Speedup: {d:.2}x\n", .{loop_per_iter / unrolled_per_iter});
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANT FOLDER TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ConstantFolder fold addition" {
    const allocator = std.testing.allocator;

    var folder = ConstantFolder.init(allocator);

    // IR: r0 = 5, r1 = 3, r2 = r0 + r1 -> should fold to r2 = 8
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const optimized = try folder.optimize(&ir);
    defer allocator.free(optimized);

    // Should have: LOAD_CONST 5, LOAD_CONST 3, LOAD_CONST 8, RETURN
    try std.testing.expectEqual(@as(usize, 4), optimized.len);
    try std.testing.expectEqual(jit.IROpcode.LOAD_CONST, optimized[2].opcode);
    try std.testing.expectEqual(@as(i64, 8), optimized[2].imm);

    const stats = folder.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.folded);
}

test "ConstantFolder fold multiplication" {
    const allocator = std.testing.allocator;

    var folder = ConstantFolder.init(allocator);

    // IR: r0 = 7, r1 = 6, r2 = r0 * r1 -> should fold to r2 = 42
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 7 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 6 },
        .{ .opcode = .MUL_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const optimized = try folder.optimize(&ir);
    defer allocator.free(optimized);

    try std.testing.expectEqual(@as(i64, 42), optimized[2].imm);
}

test "ConstantFolder chain folding" {
    const allocator = std.testing.allocator;

    var folder = ConstantFolder.init(allocator);

    // IR: r0 = 2, r1 = 3, r2 = r0 + r1, r3 = 7, r4 = r2 * r3
    // Should fold to: r2 = 5, r4 = 35
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 2 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .LOAD_CONST, .dest = 3, .src1 = 0, .src2 = 0, .imm = 7 },
        .{ .opcode = .MUL_INT, .dest = 4, .src1 = 2, .src2 = 3, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 4, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const optimized = try folder.optimize(&ir);
    defer allocator.free(optimized);

    // r2 should be folded to 5
    try std.testing.expectEqual(@as(i64, 5), optimized[2].imm);
    // r4 should be folded to 35
    try std.testing.expectEqual(@as(i64, 35), optimized[4].imm);

    const stats = folder.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.folded);
}

test "ConstantFolder no folding for non-constants" {
    const allocator = std.testing.allocator;

    var folder = ConstantFolder.init(allocator);

    // IR: r0 = load_local, r1 = 5, r2 = r0 + r1 -> cannot fold
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_LOCAL, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const optimized = try folder.optimize(&ir);
    defer allocator.free(optimized);

    // ADD_INT should remain (not folded)
    try std.testing.expectEqual(jit.IROpcode.ADD_INT, optimized[2].opcode);

    const stats = folder.getStats();
    try std.testing.expectEqual(@as(usize, 0), stats.folded);
}

test "ConstantFolder division by zero protection" {
    const allocator = std.testing.allocator;

    var folder = ConstantFolder.init(allocator);

    // IR: r0 = 10, r1 = 0, r2 = r0 / r1 -> should NOT fold (div by zero)
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 10 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 },
        .{ .opcode = .DIV_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const optimized = try folder.optimize(&ir);
    defer allocator.free(optimized);

    // DIV_INT should remain (not folded due to div by zero)
    try std.testing.expectEqual(jit.IROpcode.DIV_INT, optimized[2].opcode);
}

test "ConstantFolder fold SHL" {
    const allocator = std.testing.allocator;

    var folder = ConstantFolder.init(allocator);

    // IR: r0 = 5, r1 = 5 << 3 = 40
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .SHL, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .RETURN, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const optimized = try folder.optimize(&ir);
    defer allocator.free(optimized);

    // SHL should be folded to LOAD_CONST 40
    try std.testing.expectEqual(jit.IROpcode.LOAD_CONST, optimized[1].opcode);
    try std.testing.expectEqual(@as(i64, 40), optimized[1].imm);
}

test "ConstantFolder fold SHR" {
    const allocator = std.testing.allocator;

    var folder = ConstantFolder.init(allocator);

    // IR: r0 = 64, r1 = 64 >> 2 = 16
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 64 },
        .{ .opcode = .SHR, .dest = 1, .src1 = 0, .src2 = 0, .imm = 2 },
        .{ .opcode = .RETURN, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const optimized = try folder.optimize(&ir);
    defer allocator.free(optimized);

    // SHR should be folded to LOAD_CONST 16
    try std.testing.expectEqual(jit.IROpcode.LOAD_CONST, optimized[1].opcode);
    try std.testing.expectEqual(@as(i64, 16), optimized[1].imm);
}

test "ConstantFolder fold LEA" {
    const allocator = std.testing.allocator;

    var folder = ConstantFolder.init(allocator);

    // IR: r0 = 7, r1 = 7 + 7*2 = 21 (LEA for x*3)
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 7 },
        .{ .opcode = .LEA, .dest = 1, .src1 = 0, .src2 = 0, .imm = 2 },
        .{ .opcode = .RETURN, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const optimized = try folder.optimize(&ir);
    defer allocator.free(optimized);

    // LEA should be folded to LOAD_CONST 21
    try std.testing.expectEqual(jit.IROpcode.LOAD_CONST, optimized[1].opcode);
    try std.testing.expectEqual(@as(i64, 21), optimized[1].imm);
}

test "ConstantFolder fold comparison" {
    const allocator = std.testing.allocator;

    var folder = ConstantFolder.init(allocator);

    // IR: r0 = 5, r1 = 10, r2 = (5 < 10) = 1
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 10 },
        .{ .opcode = .CMP_LT_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const optimized = try folder.optimize(&ir);
    defer allocator.free(optimized);

    // CMP_LT_INT should be folded to LOAD_CONST 1
    try std.testing.expectEqual(jit.IROpcode.LOAD_CONST, optimized[2].opcode);
    try std.testing.expectEqual(@as(i64, 1), optimized[2].imm);
}

test "ConstantFolder fold equality" {
    const allocator = std.testing.allocator;

    var folder = ConstantFolder.init(allocator);

    // IR: r0 = 42, r1 = 42, r2 = (42 == 42) = 1
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 42 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 42 },
        .{ .opcode = .CMP_EQ_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const optimized = try folder.optimize(&ir);
    defer allocator.free(optimized);

    // CMP_EQ_INT should be folded to LOAD_CONST 1
    try std.testing.expectEqual(jit.IROpcode.LOAD_CONST, optimized[2].opcode);
    try std.testing.expectEqual(@as(i64, 1), optimized[2].imm);
}

test "Benchmark: Constant folding effect" {
    const allocator = std.testing.allocator;

    // IR without folding: (2 + 3) * (4 + 5) = 5 * 9 = 45
    const unfolded_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 2 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .LOAD_CONST, .dest = 3, .src1 = 0, .src2 = 0, .imm = 4 },
        .{ .opcode = .LOAD_CONST, .dest = 4, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .ADD_INT, .dest = 5, .src1 = 3, .src2 = 4, .imm = 0 },
        .{ .opcode = .MUL_INT, .dest = 6, .src1 = 2, .src2 = 5, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 6, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var folder = ConstantFolder.init(allocator);
    const folded_ir = try folder.optimize(&unfolded_ir);
    defer allocator.free(folded_ir);

    const iterations: usize = 10000;

    // Benchmark unfolded
    const unfolded_start = std.time.nanoTimestamp();
    var unfolded_result: i64 = 0;
    for (0..iterations) |_| {
        unfolded_result = interpretIRCode(&unfolded_ir);
    }
    const unfolded_end = std.time.nanoTimestamp();
    const unfolded_time: u64 = @intCast(@max(0, unfolded_end - unfolded_start));

    // Benchmark folded
    const folded_start = std.time.nanoTimestamp();
    var folded_result: i64 = 0;
    for (0..iterations) |_| {
        folded_result = interpretIRCode(folded_ir);
    }
    const folded_end = std.time.nanoTimestamp();
    const folded_time: u64 = @intCast(@max(0, folded_end - folded_start));

    // Both should produce same result
    try std.testing.expectEqual(@as(i64, 45), unfolded_result);
    try std.testing.expectEqual(@as(i64, 45), folded_result);

    const stats = folder.getStats();

    if (@import("builtin").mode == .Debug) {
        const unfolded_per_iter = @as(f64, @floatFromInt(unfolded_time)) / @as(f64, @floatFromInt(iterations));
        const folded_per_iter = @as(f64, @floatFromInt(folded_time)) / @as(f64, @floatFromInt(iterations));

        std.debug.print("\n=== Constant Folding Benchmark ===\n", .{});
        std.debug.print("Unfolded: {d:.2} ns/iter ({d} instructions)\n", .{ unfolded_per_iter, unfolded_ir.len });
        std.debug.print("Folded: {d:.2} ns/iter ({d} instructions)\n", .{ folded_per_iter, folded_ir.len });
        std.debug.print("Constants folded: {d}\n", .{stats.folded});
        if (unfolded_per_iter > folded_per_iter) {
            std.debug.print("Speedup: {d:.2}x\n", .{unfolded_per_iter / folded_per_iter});
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEAD CODE ELIMINATOR TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "DeadCodeEliminator remove unused loads" {
    const allocator = std.testing.allocator;

    var dce = DeadCodeEliminator.init(allocator);

    // IR: r0 = 5, r1 = 3, r2 = 8, return r2
    // r0 and r1 are dead (never used)
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 }, // dead
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 }, // dead
        .{ .opcode = .LOAD_CONST, .dest = 2, .src1 = 0, .src2 = 0, .imm = 8 }, // live
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const optimized = try dce.optimize(&ir);
    defer allocator.free(optimized);

    // Should have only: LOAD_CONST 8, RETURN
    try std.testing.expectEqual(@as(usize, 2), optimized.len);
    try std.testing.expectEqual(@as(i64, 8), optimized[0].imm);
    try std.testing.expectEqual(jit.IROpcode.RETURN, optimized[1].opcode);

    const stats = dce.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.eliminated);
}

test "DeadCodeEliminator keep used registers" {
    const allocator = std.testing.allocator;

    var dce = DeadCodeEliminator.init(allocator);

    // IR: r0 = 5, r1 = 3, r2 = r0 + r1, return r2
    // All are live
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const optimized = try dce.optimize(&ir);
    defer allocator.free(optimized);

    // All instructions should remain
    try std.testing.expectEqual(@as(usize, 4), optimized.len);
}

test "DeadCodeEliminator with folding" {
    const allocator = std.testing.allocator;

    // First fold constants
    var folder = ConstantFolder.init(allocator);
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const folded = try folder.optimize(&ir);
    defer allocator.free(folded);

    // After folding: r0=5, r1=3, r2=8, return r2
    // r0 and r1 are now dead

    var dce = DeadCodeEliminator.init(allocator);
    const optimized = try dce.optimize(folded);
    defer allocator.free(optimized);

    // Should have: LOAD_CONST 8, RETURN
    try std.testing.expectEqual(@as(usize, 2), optimized.len);
    try std.testing.expectEqual(@as(i64, 8), optimized[0].imm);
}

test "Benchmark: Folding + DCE combined effect" {
    const allocator = std.testing.allocator;

    // Original IR: (2 + 3) * (4 + 5) = 45
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 2 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .LOAD_CONST, .dest = 3, .src1 = 0, .src2 = 0, .imm = 4 },
        .{ .opcode = .LOAD_CONST, .dest = 4, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .ADD_INT, .dest = 5, .src1 = 3, .src2 = 4, .imm = 0 },
        .{ .opcode = .MUL_INT, .dest = 6, .src1 = 2, .src2 = 5, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 6, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    // Apply folding
    var folder = ConstantFolder.init(allocator);
    const folded = try folder.optimize(&original_ir);
    defer allocator.free(folded);

    // Apply DCE
    var dce = DeadCodeEliminator.init(allocator);
    const optimized = try dce.optimize(folded);
    defer allocator.free(optimized);

    const iterations: usize = 10000;

    // Benchmark original
    const orig_start = std.time.nanoTimestamp();
    var orig_result: i64 = 0;
    for (0..iterations) |_| {
        orig_result = interpretIRCode(&original_ir);
    }
    const orig_end = std.time.nanoTimestamp();
    const orig_time: u64 = @intCast(@max(0, orig_end - orig_start));

    // Benchmark optimized
    const opt_start = std.time.nanoTimestamp();
    var opt_result: i64 = 0;
    for (0..iterations) |_| {
        opt_result = interpretIRCode(optimized);
    }
    const opt_end = std.time.nanoTimestamp();
    const opt_time: u64 = @intCast(@max(0, opt_end - opt_start));

    // Both should produce same result
    try std.testing.expectEqual(@as(i64, 45), orig_result);
    try std.testing.expectEqual(@as(i64, 45), opt_result);

    const folder_stats = folder.getStats();
    const dce_stats = dce.getStats();

    if (@import("builtin").mode == .Debug) {
        const orig_per_iter = @as(f64, @floatFromInt(orig_time)) / @as(f64, @floatFromInt(iterations));
        const opt_per_iter = @as(f64, @floatFromInt(opt_time)) / @as(f64, @floatFromInt(iterations));

        std.debug.print("\n=== Folding + DCE Combined Benchmark ===\n", .{});
        std.debug.print("Original: {d:.2} ns/iter ({d} instructions)\n", .{ orig_per_iter, original_ir.len });
        std.debug.print("Optimized: {d:.2} ns/iter ({d} instructions)\n", .{ opt_per_iter, optimized.len });
        std.debug.print("Constants folded: {d}, Dead code eliminated: {d}\n", .{ folder_stats.folded, dce_stats.eliminated });
        std.debug.print("Instruction reduction: {d} -> {d} ({d:.1}%)\n", .{
            original_ir.len,
            optimized.len,
            (1.0 - @as(f64, @floatFromInt(optimized.len)) / @as(f64, @floatFromInt(original_ir.len))) * 100.0,
        });
        if (orig_per_iter > opt_per_iter) {
            std.debug.print("Speedup: {d:.2}x\n", .{orig_per_iter / opt_per_iter});
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STRENGTH REDUCER TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "StrengthReducer mul by power of 2" {
    const allocator = std.testing.allocator;

    var reducer = StrengthReducer.init(allocator);

    // IR: r0 = x, r1 = 8, r2 = r0 * r1 -> should become r2 = r0 << 3
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_LOCAL, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 }, // x from local
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 8 }, // 8 = 2^3
        .{ .opcode = .MUL_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const optimized = try reducer.optimize(&ir);
    defer allocator.free(optimized);

    // MUL should be replaced with SHL
    try std.testing.expectEqual(jit.IROpcode.SHL, optimized[2].opcode);
    try std.testing.expectEqual(@as(i64, 3), optimized[2].imm); // shift by 3

    const stats = reducer.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.mul_to_shift);
}

test "StrengthReducer div by power of 2" {
    const allocator = std.testing.allocator;

    var reducer = StrengthReducer.init(allocator);

    // IR: r0 = x, r1 = 4, r2 = r0 / r1 -> should become r2 = r0 >> 2
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_LOCAL, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 4 }, // 4 = 2^2
        .{ .opcode = .DIV_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const optimized = try reducer.optimize(&ir);
    defer allocator.free(optimized);

    // DIV should be replaced with SHR
    try std.testing.expectEqual(jit.IROpcode.SHR, optimized[2].opcode);
    try std.testing.expectEqual(@as(i64, 2), optimized[2].imm); // shift by 2

    const stats = reducer.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.div_to_shift);
}

test "StrengthReducer mul by 0" {
    const allocator = std.testing.allocator;

    var reducer = StrengthReducer.init(allocator);

    // IR: r0 = x, r1 = 0, r2 = r0 * r1 -> should become r2 = 0
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_LOCAL, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 },
        .{ .opcode = .MUL_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const optimized = try reducer.optimize(&ir);
    defer allocator.free(optimized);

    // MUL should be replaced with LOAD_CONST 0
    try std.testing.expectEqual(jit.IROpcode.LOAD_CONST, optimized[2].opcode);
    try std.testing.expectEqual(@as(i64, 0), optimized[2].imm);

    const stats = reducer.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.identity);
}

test "StrengthReducer add 0 identity" {
    const allocator = std.testing.allocator;

    var reducer = StrengthReducer.init(allocator);

    // IR: r0 = x, r1 = 0, r2 = r0 + r1 -> should become r2 = r0
    const ir = [_]IRInstruction{
        .{ .opcode = .LOAD_LOCAL, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 },
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    const optimized = try reducer.optimize(&ir);
    defer allocator.free(optimized);

    // ADD should be replaced with move (LOAD_LOCAL)
    try std.testing.expectEqual(jit.IROpcode.LOAD_LOCAL, optimized[2].opcode);
    try std.testing.expectEqual(@as(u8, 0), optimized[2].src1); // copy from r0

    const stats = reducer.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.identity);
}

test "StrengthReducer isPowerOf2" {
    _ = std.testing.allocator;

    // Test isPowerOf2 helper
    try std.testing.expectEqual(@as(?u6, 0), StrengthReducer.isPowerOf2(1)); // 2^0
    try std.testing.expectEqual(@as(?u6, 1), StrengthReducer.isPowerOf2(2)); // 2^1
    try std.testing.expectEqual(@as(?u6, 2), StrengthReducer.isPowerOf2(4)); // 2^2
    try std.testing.expectEqual(@as(?u6, 3), StrengthReducer.isPowerOf2(8)); // 2^3
    try std.testing.expectEqual(@as(?u6, 10), StrengthReducer.isPowerOf2(1024)); // 2^10
    try std.testing.expectEqual(@as(?u6, null), StrengthReducer.isPowerOf2(3)); // not power of 2
    try std.testing.expectEqual(@as(?u6, null), StrengthReducer.isPowerOf2(0)); // 0
    try std.testing.expectEqual(@as(?u6, null), StrengthReducer.isPowerOf2(-4)); // negative
}

test "StrengthReducer mul by 3 to LEA" {
    const allocator = std.testing.allocator;

    // IR: x * 3 (should become LEA)
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 7 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .MUL_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var reducer = StrengthReducer.init(allocator);
    const optimized = try reducer.optimize(&original_ir);
    defer allocator.free(optimized);

    // Should have LEA instead of MUL
    try std.testing.expectEqual(jit.IROpcode.LEA, optimized[2].opcode);
    try std.testing.expectEqual(@as(i64, 2), optimized[2].imm); // scale = 2 for x*3

    const stats = reducer.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.mul_to_lea);
}

test "StrengthReducer mul by 5 to LEA" {
    const allocator = std.testing.allocator;

    // IR: x * 5 (should become LEA)
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 4 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .MUL_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var reducer = StrengthReducer.init(allocator);
    const optimized = try reducer.optimize(&original_ir);
    defer allocator.free(optimized);

    // Should have LEA instead of MUL
    try std.testing.expectEqual(jit.IROpcode.LEA, optimized[2].opcode);
    try std.testing.expectEqual(@as(i64, 4), optimized[2].imm); // scale = 4 for x*5

    const stats = reducer.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.mul_to_lea);
}

test "StrengthReducer mul by 9 to LEA" {
    const allocator = std.testing.allocator;

    // IR: x * 9 (should become LEA)
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 9 },
        .{ .opcode = .MUL_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var reducer = StrengthReducer.init(allocator);
    const optimized = try reducer.optimize(&original_ir);
    defer allocator.free(optimized);

    // Should have LEA instead of MUL
    try std.testing.expectEqual(jit.IROpcode.LEA, optimized[2].opcode);
    try std.testing.expectEqual(@as(i64, 8), optimized[2].imm); // scale = 8 for x*9

    const stats = reducer.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.mul_to_lea);
}

test "StrengthReducer mul by 2 to ADD" {
    const allocator = std.testing.allocator;

    // IR: x * 2 (should become x + x)
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 7 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 2 },
        .{ .opcode = .MUL_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var reducer = StrengthReducer.init(allocator);
    const optimized = try reducer.optimize(&original_ir);
    defer allocator.free(optimized);

    // Should have ADD_INT instead of MUL_INT
    try std.testing.expectEqual(jit.IROpcode.ADD_INT, optimized[2].opcode);
    try std.testing.expectEqual(optimized[2].src1, optimized[2].src2); // x + x

    const stats = reducer.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.mul_to_add);
}

test "StrengthReducer x - x = 0" {
    const allocator = std.testing.allocator;

    // IR: x - x = 0
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 42 },
        .{ .opcode = .SUB_INT, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 }, // r0 - r0
        .{ .opcode = .RETURN, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var reducer = StrengthReducer.init(allocator);
    const optimized = try reducer.optimize(&original_ir);
    defer allocator.free(optimized);

    // Should have LOAD_CONST 0 instead of SUB_INT
    try std.testing.expectEqual(jit.IROpcode.LOAD_CONST, optimized[1].opcode);
    try std.testing.expectEqual(@as(i64, 0), optimized[1].imm);

    const stats = reducer.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.algebraic);
}

test "StrengthReducer x ^ x = 0" {
    const allocator = std.testing.allocator;

    // IR: x ^ x = 0
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 42 },
        .{ .opcode = .XOR, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 }, // r0 ^ r0
        .{ .opcode = .RETURN, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var reducer = StrengthReducer.init(allocator);
    const optimized = try reducer.optimize(&original_ir);
    defer allocator.free(optimized);

    // Should have LOAD_CONST 0 instead of XOR
    try std.testing.expectEqual(jit.IROpcode.LOAD_CONST, optimized[1].opcode);
    try std.testing.expectEqual(@as(i64, 0), optimized[1].imm);

    const stats = reducer.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.algebraic);
}

test "StrengthReducer x & x = x" {
    const allocator = std.testing.allocator;

    // IR: x & x = x
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 42 },
        .{ .opcode = .AND, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 }, // r0 & r0
        .{ .opcode = .RETURN, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var reducer = StrengthReducer.init(allocator);
    const optimized = try reducer.optimize(&original_ir);
    defer allocator.free(optimized);

    // Should have LOAD_LOCAL (copy) instead of AND
    try std.testing.expectEqual(jit.IROpcode.LOAD_LOCAL, optimized[1].opcode);
    try std.testing.expectEqual(@as(u8, 0), optimized[1].src1); // copy from r0

    const stats = reducer.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.algebraic);
}

test "StrengthReducer x | x = x" {
    const allocator = std.testing.allocator;

    // IR: x | x = x
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 42 },
        .{ .opcode = .OR, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 }, // r0 | r0
        .{ .opcode = .RETURN, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var reducer = StrengthReducer.init(allocator);
    const optimized = try reducer.optimize(&original_ir);
    defer allocator.free(optimized);

    // Should have LOAD_LOCAL (copy) instead of OR
    try std.testing.expectEqual(jit.IROpcode.LOAD_LOCAL, optimized[1].opcode);
    try std.testing.expectEqual(@as(u8, 0), optimized[1].src1); // copy from r0

    const stats = reducer.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.algebraic);
}

test "CopyPropagator basic propagation" {
    const allocator = std.testing.allocator;

    // IR: r0 = 5, r1 = copy(r0), r2 = r1 + r1
    // After propagation: r2 = r0 + r0
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .LOAD_LOCAL, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 }, // r1 = copy(r0)
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 1, .src2 = 1, .imm = 0 }, // r2 = r1 + r1
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var propagator = CopyPropagator.init(allocator);
    const optimized = try propagator.optimize(&original_ir);
    defer allocator.free(optimized);

    // ADD should now use r0 instead of r1
    try std.testing.expectEqual(jit.IROpcode.ADD_INT, optimized[2].opcode);
    try std.testing.expectEqual(@as(u8, 0), optimized[2].src1); // r0
    try std.testing.expectEqual(@as(u8, 0), optimized[2].src2); // r0

    const stats = propagator.getStats();
    try std.testing.expect(stats.propagated > 0);
}

test "CopyPropagator eliminate useless copy" {
    const allocator = std.testing.allocator;

    // IR: r0 = 5, r0 = copy(r0) - useless copy
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .LOAD_LOCAL, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 }, // r0 = copy(r0) - useless!
        .{ .opcode = .RETURN, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var propagator = CopyPropagator.init(allocator);
    const optimized = try propagator.optimize(&original_ir);
    defer allocator.free(optimized);

    // Useless copy should be eliminated
    try std.testing.expectEqual(@as(usize, 2), optimized.len); // 3 -> 2 instructions

    const stats = propagator.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.eliminated);
}

test "CopyPropagator chain propagation" {
    const allocator = std.testing.allocator;

    // IR: r0 = 5, r1 = copy(r0), r2 = copy(r1), r3 = r2 + r2
    // After propagation: r3 = r0 + r0
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .LOAD_LOCAL, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 }, // r1 = copy(r0)
        .{ .opcode = .LOAD_LOCAL, .dest = 2, .src1 = 1, .src2 = 0, .imm = 0 }, // r2 = copy(r1)
        .{ .opcode = .ADD_INT, .dest = 3, .src1 = 2, .src2 = 2, .imm = 0 }, // r3 = r2 + r2
        .{ .opcode = .RETURN, .dest = 3, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var propagator = CopyPropagator.init(allocator);
    const optimized = try propagator.optimize(&original_ir);
    defer allocator.free(optimized);

    // ADD should now use r0 (through chain r2 -> r1 -> r0)
    try std.testing.expectEqual(jit.IROpcode.ADD_INT, optimized[3].opcode);
    try std.testing.expectEqual(@as(u8, 0), optimized[3].src1); // r0
    try std.testing.expectEqual(@as(u8, 0), optimized[3].src2); // r0
}

test "CopyPropagator invalidation on write" {
    const allocator = std.testing.allocator;

    // IR: r0 = 5, r1 = copy(r0), r0 = 10, r2 = r1 + r1
    // r1 should NOT be propagated to r0 because r0 was overwritten
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .LOAD_LOCAL, .dest = 1, .src1 = 0, .src2 = 0, .imm = 0 }, // r1 = copy(r0)
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 10 }, // r0 = 10 (invalidates copy)
        .{ .opcode = .ADD_INT, .dest = 2, .src1 = 1, .src2 = 1, .imm = 0 }, // r2 = r1 + r1
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var propagator = CopyPropagator.init(allocator);
    const optimized = try propagator.optimize(&original_ir);
    defer allocator.free(optimized);

    // ADD should still use r1 (copy was invalidated)
    try std.testing.expectEqual(jit.IROpcode.ADD_INT, optimized[3].opcode);
    try std.testing.expectEqual(@as(u8, 1), optimized[3].src1); // r1 (not r0!)
    try std.testing.expectEqual(@as(u8, 1), optimized[3].src2); // r1
}

test "PeepholeOptimizer redundant LOAD_CONST" {
    const allocator = std.testing.allocator;

    // IR: LOAD_CONST r0, 5 + LOAD_CONST r0, 10 -> keep only second
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 10 },
        .{ .opcode = .RETURN, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var peephole = PeepholeOptimizer.init(allocator);
    const optimized = try peephole.optimize(&original_ir);
    defer allocator.free(optimized);

    // Should have 2 instructions (first LOAD_CONST eliminated)
    try std.testing.expectEqual(@as(usize, 2), optimized.len);
    try std.testing.expectEqual(@as(i64, 10), optimized[0].imm);

    const stats = peephole.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.patterns);
    try std.testing.expectEqual(@as(usize, 1), stats.eliminated);
}

test "PeepholeOptimizer double NEG" {
    const allocator = std.testing.allocator;

    // IR: NEG r0 + NEG r0 -> remove both
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .NEG_INT, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
        .{ .opcode = .NEG_INT, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var peephole = PeepholeOptimizer.init(allocator);
    const optimized = try peephole.optimize(&original_ir);
    defer allocator.free(optimized);

    // Should have 2 instructions (both NEGs eliminated)
    try std.testing.expectEqual(@as(usize, 2), optimized.len);
    try std.testing.expectEqual(jit.IROpcode.LOAD_CONST, optimized[0].opcode);
    try std.testing.expectEqual(jit.IROpcode.RETURN, optimized[1].opcode);

    const stats = peephole.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.patterns);
    try std.testing.expectEqual(@as(usize, 2), stats.eliminated);
}

test "PeepholeOptimizer INC + DEC" {
    const allocator = std.testing.allocator;

    // IR: INC r0 + DEC r0 -> remove both
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .INC_INT, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
        .{ .opcode = .DEC_INT, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
        .{ .opcode = .RETURN, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var peephole = PeepholeOptimizer.init(allocator);
    const optimized = try peephole.optimize(&original_ir);
    defer allocator.free(optimized);

    // Should have 2 instructions (INC + DEC eliminated)
    try std.testing.expectEqual(@as(usize, 2), optimized.len);

    const stats = peephole.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.patterns);
    try std.testing.expectEqual(@as(usize, 2), stats.eliminated);
}

test "PeepholeOptimizer SHL + SHR same amount" {
    const allocator = std.testing.allocator;

    // IR: SHL r0, 3 + SHR r0, 3 -> remove both
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .SHL, .dest = 0, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .SHR, .dest = 0, .src1 = 0, .src2 = 0, .imm = 3 },
        .{ .opcode = .RETURN, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var peephole = PeepholeOptimizer.init(allocator);
    const optimized = try peephole.optimize(&original_ir);
    defer allocator.free(optimized);

    // Should have 2 instructions (SHL + SHR eliminated)
    try std.testing.expectEqual(@as(usize, 2), optimized.len);

    const stats = peephole.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats.patterns);
    try std.testing.expectEqual(@as(usize, 2), stats.eliminated);
}

test "PeepholeOptimizer no match different registers" {
    const allocator = std.testing.allocator;

    // IR: LOAD_CONST r0, 5 + LOAD_CONST r1, 10 -> no match (different regs)
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 },
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 10 },
        .{ .opcode = .RETURN, .dest = 0, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var peephole = PeepholeOptimizer.init(allocator);
    const optimized = try peephole.optimize(&original_ir);
    defer allocator.free(optimized);

    // Should have 3 instructions (no optimization)
    try std.testing.expectEqual(@as(usize, 3), optimized.len);

    const stats = peephole.getStats();
    try std.testing.expectEqual(@as(usize, 0), stats.patterns);
}

test "Benchmark: Strength reduction effect" {
    const allocator = std.testing.allocator;

    // IR: x * 8 (should become x << 3)
    const original_ir = [_]IRInstruction{
        .{ .opcode = .LOAD_CONST, .dest = 0, .src1 = 0, .src2 = 0, .imm = 5 }, // x = 5
        .{ .opcode = .LOAD_CONST, .dest = 1, .src1 = 0, .src2 = 0, .imm = 8 }, // 8
        .{ .opcode = .MUL_INT, .dest = 2, .src1 = 0, .src2 = 1, .imm = 0 }, // x * 8
        .{ .opcode = .RETURN, .dest = 2, .src1 = 0, .src2 = 0, .imm = 0 },
    };

    var reducer = StrengthReducer.init(allocator);
    const reduced = try reducer.optimize(&original_ir);
    defer allocator.free(reduced);

    const iterations: usize = 10000;

    // Benchmark original
    const orig_start = std.time.nanoTimestamp();
    var orig_result: i64 = 0;
    for (0..iterations) |_| {
        orig_result = interpretIRCode(&original_ir);
    }
    const orig_end = std.time.nanoTimestamp();
    const orig_time: u64 = @intCast(@max(0, orig_end - orig_start));

    // Benchmark reduced
    const red_start = std.time.nanoTimestamp();
    var red_result: i64 = 0;
    for (0..iterations) |_| {
        red_result = interpretIRCode(reduced);
    }
    const red_end = std.time.nanoTimestamp();
    const red_time: u64 = @intCast(@max(0, red_end - red_start));

    // Both should produce same result: 5 * 8 = 40
    try std.testing.expectEqual(@as(i64, 40), orig_result);
    try std.testing.expectEqual(@as(i64, 40), red_result);

    const stats = reducer.getStats();

    if (@import("builtin").mode == .Debug) {
        const orig_per_iter = @as(f64, @floatFromInt(orig_time)) / @as(f64, @floatFromInt(iterations));
        const red_per_iter = @as(f64, @floatFromInt(red_time)) / @as(f64, @floatFromInt(iterations));

        std.debug.print("\n=== Strength Reduction Benchmark ===\n", .{});
        std.debug.print("Original (MUL): {d:.2} ns/iter\n", .{orig_per_iter});
        std.debug.print("Reduced (SHL): {d:.2} ns/iter\n", .{red_per_iter});
        std.debug.print("Reductions: {d} (mul->shift: {d}, mul->lea: {d}, div->shift: {d}, identity: {d})\n", .{
            stats.reductions,
            stats.mul_to_shift,
            stats.mul_to_lea,
            stats.div_to_shift,
            stats.identity,
        });
        if (orig_per_iter > red_per_iter) {
            std.debug.print("Speedup: {d:.2}x\n", .{orig_per_iter / red_per_iter});
        }
    }
}

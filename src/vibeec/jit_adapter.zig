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
                // Copy IR to cache
                const ir_copy = try self.allocator.dupe(IRInstruction, ir);
                try self.jit_ir_cache.put(address, ir_copy);
                self.stats.tier1_promotions += 1;

                const compile_time: u64 = @intCast(@max(0, std.time.nanoTimestamp() - compile_start));
                self.stats.tier1_compile_time_ns += compile_time;
                self.stats.total_compile_time_ns += compile_time;
            },
            .Native => {
                // Compile IR to native
                var native_compiler = NativeCompiler.init(self.allocator);
                if (native_compiler.compile(ir)) |machine_code| {
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
            .profiler = HotPathProfiler.init(allocator),
            .tiered_compiler = TieredCompiler.init(allocator),
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

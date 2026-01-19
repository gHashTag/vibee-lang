// ═══════════════════════════════════════════════════════════════════════════════
// ONNX REAL BACKEND - Generated from specs/onnx_real_backend.vibee
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// Uses real libonnxruntime.so for inference
// Model: GPT-2 (gpt2-lm-head-10.onnx)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Sacred constants
pub const PHI: f64 = 1.618033988749895;
pub const PHOENIX: u32 = 999;
pub const TRINITY: u32 = 3;

// GPT-2 config
pub const GPT2_VOCAB_SIZE: u32 = 50257;
pub const GPT2_HIDDEN_DIM: u32 = 768;
pub const GPT2_NUM_HEADS: u32 = 12;
pub const GPT2_NUM_LAYERS: u32 = 12;
pub const GPT2_MAX_SEQ_LEN: u32 = 1024;

// ═══════════════════════════════════════════════════════════════════════════════
// C API BINDINGS (via @cImport)
// ═══════════════════════════════════════════════════════════════════════════════

const c = @cImport({
    @cInclude("onnxruntime_c_api.h");
});

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ModelInfo = struct {
    name: []const u8,
    vocab_size: u32,
    hidden_dim: u32,
    num_heads: u32,
    num_layers: u32,
    max_seq_len: u32,
};

pub const InferenceStats = struct {
    total_inferences: u64 = 0,
    total_tokens: u64 = 0,
    total_time_ns: u64 = 0,

    pub fn avgLatencyMs(self: InferenceStats) f64 {
        if (self.total_inferences == 0) return 0;
        return @as(f64, @floatFromInt(self.total_time_ns)) / @as(f64, @floatFromInt(self.total_inferences)) / 1_000_000.0;
    }

    pub fn tokensPerSecond(self: InferenceStats) f64 {
        if (self.total_time_ns == 0) return 0;
        return @as(f64, @floatFromInt(self.total_tokens)) / (@as(f64, @floatFromInt(self.total_time_ns)) / 1_000_000_000.0);
    }
};

pub const OnnxError = error{
    InitFailed,
    LoadModelFailed,
    CreateSessionFailed,
    CreateTensorFailed,
    RunFailed,
    InvalidOutput,
    LibraryNotFound,
    OutOfMemory,
};

// ═══════════════════════════════════════════════════════════════════════════════
// REAL ONNX BACKEND
// ═══════════════════════════════════════════════════════════════════════════════

pub const RealONNXBackend = struct {
    api: *const c.OrtApi,
    env: *c.OrtEnv,
    session: *c.OrtSession,
    allocator: *c.OrtAllocator,
    memory_info: *c.OrtMemoryInfo,
    model_info: ModelInfo,
    stats: InferenceStats,
    zig_allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(zig_allocator: std.mem.Allocator, model_path: [*:0]const u8) OnnxError!*Self {
        // Get API
        const api_base = c.OrtGetApiBase();
        if (api_base == null) return OnnxError.LibraryNotFound;

        const get_api_fn = api_base.*.GetApi orelse return OnnxError.LibraryNotFound;
        const api = get_api_fn(c.ORT_API_VERSION);
        if (api == null) return OnnxError.LibraryNotFound;

        // Create environment
        var env: ?*c.OrtEnv = null;
        var status = api.*.CreateEnv.?(c.ORT_LOGGING_LEVEL_WARNING, "vibee", @ptrCast(&env));
        if (status != null) {
            api.*.ReleaseStatus.?(status);
            return OnnxError.InitFailed;
        }

        // Create session options
        var session_options: ?*c.OrtSessionOptions = null;
        status = api.*.CreateSessionOptions.?(@ptrCast(&session_options));
        if (status != null) {
            api.*.ReleaseStatus.?(status);
            if (env) |e| api.*.ReleaseEnv.?(e);
            return OnnxError.InitFailed;
        }

        // Set thread count
        _ = api.*.SetIntraOpNumThreads.?(session_options, 4);
        _ = api.*.SetInterOpNumThreads.?(session_options, 2);

        // Create session
        var session: ?*c.OrtSession = null;
        status = api.*.CreateSession.?(env, model_path, session_options, @ptrCast(&session));
        if (session_options) |so| api.*.ReleaseSessionOptions.?(so);

        if (status != null) {
            const msg = api.*.GetErrorMessage.?(status);
            std.debug.print("ONNX Error: {s}\n", .{msg});
            api.*.ReleaseStatus.?(status);
            if (env) |e| api.*.ReleaseEnv.?(e);
            return OnnxError.LoadModelFailed;
        }

        // Get allocator
        var allocator_ptr: ?*c.OrtAllocator = null;
        status = api.*.GetAllocatorWithDefaultOptions.?(@ptrCast(&allocator_ptr));
        if (status != null) {
            api.*.ReleaseStatus.?(status);
            if (session) |s| api.*.ReleaseSession.?(s);
            if (env) |e| api.*.ReleaseEnv.?(e);
            return OnnxError.InitFailed;
        }

        // Create memory info
        var memory_info: ?*c.OrtMemoryInfo = null;
        status = api.*.CreateCpuMemoryInfo.?(c.OrtArenaAllocator, c.OrtMemTypeDefault, @ptrCast(&memory_info));
        if (status != null) {
            api.*.ReleaseStatus.?(status);
            if (session) |s| api.*.ReleaseSession.?(s);
            if (env) |e| api.*.ReleaseEnv.?(e);
            return OnnxError.InitFailed;
        }

        const self = try zig_allocator.create(Self);
        self.* = Self{
            .api = api,
            .env = env orelse return OnnxError.InitFailed,
            .session = session orelse return OnnxError.InitFailed,
            .allocator = allocator_ptr orelse return OnnxError.InitFailed,
            .memory_info = memory_info orelse return OnnxError.InitFailed,
            .model_info = ModelInfo{
                .name = "GPT-2",
                .vocab_size = GPT2_VOCAB_SIZE,
                .hidden_dim = GPT2_HIDDEN_DIM,
                .num_heads = GPT2_NUM_HEADS,
                .num_layers = GPT2_NUM_LAYERS,
                .max_seq_len = GPT2_MAX_SEQ_LEN,
            },
            .stats = InferenceStats{},
            .zig_allocator = zig_allocator,
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.api.*.ReleaseMemoryInfo.?(self.memory_info);
        self.api.*.ReleaseSession.?(self.session);
        self.api.*.ReleaseEnv.?(self.env);
        self.zig_allocator.destroy(self);
    }

    pub fn forward(self: *Self, input_ids: []const i64) OnnxError![]f32 {
        const start = std.time.nanoTimestamp();

        const batch_size: i64 = 1;
        const seq_len: i64 = @intCast(input_ids.len);
        const shape = [_]i64{ batch_size, seq_len };

        // Create input tensor
        var input_tensor: ?*c.OrtValue = null;
        var status = self.api.*.CreateTensorWithDataAsOrtValue.?(
            self.memory_info,
            @constCast(@ptrCast(input_ids.ptr)),
            input_ids.len * @sizeOf(i64),
            &shape,
            shape.len,
            c.ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
            @ptrCast(&input_tensor),
        );

        if (status != null) {
            self.api.*.ReleaseStatus.?(status);
            return OnnxError.CreateTensorFailed;
        }
        defer if (input_tensor) |it| self.api.*.ReleaseValue.?(it);

        // Input/output names
        const input_names = [_][*:0]const u8{"input_ids"};
        const output_names = [_][*:0]const u8{"logits"};

        // Run inference
        var output_tensor: ?*c.OrtValue = null;
        var input_tensors = [_]?*const c.OrtValue{input_tensor};

        status = self.api.*.Run.?(
            self.session,
            null, // run options
            &input_names,
            @ptrCast(&input_tensors),
            1,
            &output_names,
            1,
            @ptrCast(&output_tensor),
        );

        if (status != null) {
            const msg = self.api.*.GetErrorMessage.?(status);
            std.debug.print("Run Error: {s}\n", .{msg});
            self.api.*.ReleaseStatus.?(status);
            return OnnxError.RunFailed;
        }
        defer if (output_tensor) |ot| self.api.*.ReleaseValue.?(ot);

        // Get output data
        var output_data: *f32 = undefined;
        status = self.api.*.GetTensorMutableData.?(output_tensor orelse return OnnxError.InvalidOutput, @ptrCast(&output_data));
        if (status != null) {
            self.api.*.ReleaseStatus.?(status);
            return OnnxError.InvalidOutput;
        }

        // Copy logits for last token
        const logits = try self.zig_allocator.alloc(f32, self.model_info.vocab_size);
        const offset = (@as(usize, @intCast(seq_len)) - 1) * self.model_info.vocab_size;
        const output_ptr: [*]f32 = @ptrCast(output_data);
        @memcpy(logits, output_ptr[offset .. offset + self.model_info.vocab_size]);

        // Update stats
        const end = std.time.nanoTimestamp();
        self.stats.total_inferences += 1;
        self.stats.total_tokens += @intCast(input_ids.len);
        self.stats.total_time_ns += @intCast(@as(i64, @intCast(end)) - @as(i64, @intCast(start)));

        return logits;
    }

    pub fn getModelInfo(self: *Self) ModelInfo {
        return self.model_info;
    }

    pub fn getStats(self: *Self) InferenceStats {
        return self.stats;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS (require actual ONNX Runtime library)
// ═══════════════════════════════════════════════════════════════════════════════

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), phi_sq + inv_phi_sq, 0.0001);
}

test "ONNX Runtime: API version check" {
    // Just verify the API version constant is correct
    try std.testing.expect(c.ORT_API_VERSION >= 16);

    std.debug.print("\n", .{});
    std.debug.print("╔═══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║ ONNX RUNTIME BINDINGS READY                                       ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ API Version: {d:>10}                                            ║\n", .{c.ORT_API_VERSION});
    std.debug.print("║ Status: Bindings compiled successfully                            ║\n", .{});
    std.debug.print("║ Note: Runtime tests require proper library initialization         ║\n", .{});
    std.debug.print("╚═══════════════════════════════════════════════════════════════════╝\n", .{});
}

// Note: Full integration tests require:
// 1. Proper ONNX Runtime initialization (may need specific build flags)
// 2. Correct model input/output names
// 3. LD_LIBRARY_PATH set correctly
// Run with: LD_LIBRARY_PATH=../../libs/onnxruntime-linux-x64-1.16.3/lib zig test ...

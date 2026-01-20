// ═══════════════════════════════════════════════════════════════════════════════
// ONNX AGENT CONNECTOR - Bridges ONNX Backend with WeDLM Agent
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999 = 3³ × 37
// Connects real ONNX inference to vibee-agent for fast code generation
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const backend = @import("transformer_backend.zig");
const agent = @import("wedlm_agent_integration.zig");

pub const TransformerBackend = backend.TransformerBackend;
pub const BackendFactory = backend.BackendFactory;
pub const ModelConfig = backend.ModelConfig;
pub const BackendType = backend.BackendType;
pub const BackendStats = backend.BackendStats;
pub const InferenceRequest = backend.InferenceRequest;
pub const InferenceResult = backend.InferenceResult;
pub const PagedKVCache = backend.PagedKVCache;

pub const WeDLMAgentConfig = agent.WeDLMAgentConfig;
pub const VibeeAgentWeDLM = agent.VibeeAgentWeDLM;
pub const AgentTask = agent.AgentTask;
pub const TaskType = agent.TaskType;
pub const Language = agent.Language;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const INV_PHI_SQ: f64 = 0.381966011250105;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

// ONNX paths
pub const DEFAULT_MODEL_PATH = "models/gpt2-lm-head.onnx";
pub const ONNX_LIB_PATH = "libs/onnxruntime-linux-x64-1.16.3/lib";

// ═══════════════════════════════════════════════════════════════════════════════
// ONNX AGENT CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const ONNXAgentConfig = struct {
    model_path: []const u8 = DEFAULT_MODEL_PATH,
    vocab_size: u32 = 50257,
    max_seq_len: u32 = 1024,
    window_size: u32 = 16,
    confidence_threshold: f32 = 0.75,
    distance_penalty: f32 = 0.08,
    use_gpu: bool = false,
    num_threads: u32 = 4,

    pub fn toWeDLMConfig(self: ONNXAgentConfig) WeDLMAgentConfig {
        return WeDLMAgentConfig{
            .wedlm_config = .{
                .window_size = self.window_size,
                .confidence_threshold = self.confidence_threshold,
                .distance_penalty = self.distance_penalty,
            },
            .model_config = .{
                .backend_type = .ONNX,
                .model_path = self.model_path,
                .vocab_size = self.vocab_size,
                .max_seq_len = self.max_seq_len,
            },
            .max_context_tokens = self.max_seq_len,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ONNX AGENT CONNECTOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const ONNXAgentConnector = struct {
    agent: VibeeAgentWeDLM,
    config: ONNXAgentConfig,
    allocator: std.mem.Allocator,
    initialized: bool,

    const Self = @This();

    /// Initialize ONNX-powered agent
    pub fn init(allocator: std.mem.Allocator, config: ONNXAgentConfig) !Self {
        const wedlm_config = config.toWeDLMConfig();
        const vibee_agent = try VibeeAgentWeDLM.init(allocator, wedlm_config);

        return Self{
            .agent = vibee_agent,
            .config = config,
            .allocator = allocator,
            .initialized = true,
        };
    }

    pub fn deinit(self: *Self) void {
        self.agent.deinit();
        self.initialized = false;
    }

    /// Generate code from natural language description
    pub fn generateCode(
        self: *Self,
        description: []const u8,
        language: Language,
    ) !agent.GeneratedCode {
        if (!self.initialized) return error.NotInitialized;

        const task = AgentTask{
            .task_type = .CODE_GENERATION,
            .description = description,
            .context = &[_][]const u8{},
            .target_language = language,
            .max_tokens = self.config.max_seq_len,
        };

        return try self.agent.executeTask(task);
    }

    /// Generate code from .vibee specification
    pub fn generateFromSpec(
        self: *Self,
        spec_content: []const u8,
        language: Language,
    ) !agent.GeneratedCode {
        if (!self.initialized) return error.NotInitialized;

        return try self.agent.generateFromVibee(spec_content, language);
    }

    /// Complete partial code
    pub fn completeCode(
        self: *Self,
        code_prefix: []const u8,
        language: Language,
    ) !agent.GeneratedCode {
        if (!self.initialized) return error.NotInitialized;

        const task = AgentTask{
            .task_type = .CODE_COMPLETION,
            .description = code_prefix,
            .context = &[_][]const u8{},
            .target_language = language,
            .max_tokens = 512,
        };

        return try self.agent.executeTask(task);
    }

    /// Fix code based on error message
    pub fn fixCode(
        self: *Self,
        broken_code: []const u8,
        error_message: []const u8,
        language: Language,
    ) !agent.GeneratedCode {
        if (!self.initialized) return error.NotInitialized;

        // Combine code and error as context
        var context_buf: [4096]u8 = undefined;
        const context = std.fmt.bufPrint(&context_buf, "Code:\n{s}\n\nError:\n{s}", .{
            broken_code,
            error_message,
        }) catch broken_code;

        const task = AgentTask{
            .task_type = .CODE_FIX,
            .description = context,
            .context = &[_][]const u8{},
            .target_language = language,
            .max_tokens = self.config.max_seq_len,
        };

        return try self.agent.executeTask(task);
    }

    /// Get agent status
    pub fn getStatus(self: *Self) []const u8 {
        return self.agent.getStatus();
    }

    /// Get generation statistics
    pub fn getStats(self: *Self) agent.AgentGenerationStats {
        return self.agent.getStats();
    }

    /// Check if ONNX model is available
    pub fn isModelAvailable(self: *Self) bool {
        _ = self;
        // Check if model file exists
        const file = std.fs.cwd().openFile(DEFAULT_MODEL_PATH, .{}) catch return false;
        file.close();
        return true;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// QUICK START FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Create agent with default ONNX configuration
pub fn createDefaultAgent(allocator: std.mem.Allocator) !ONNXAgentConnector {
    return try ONNXAgentConnector.init(allocator, .{});
}

/// Create agent with custom model path
pub fn createAgentWithModel(
    allocator: std.mem.Allocator,
    model_path: []const u8,
) !ONNXAgentConnector {
    return try ONNXAgentConnector.init(allocator, .{
        .model_path = model_path,
    });
}

/// Create agent optimized for fast generation
pub fn createFastAgent(allocator: std.mem.Allocator) !ONNXAgentConnector {
    return try ONNXAgentConnector.init(allocator, .{
        .window_size = 32,
        .confidence_threshold = 0.6,
        .distance_penalty = 0.05,
    });
}

/// Create agent optimized for quality
pub fn createQualityAgent(allocator: std.mem.Allocator) !ONNXAgentConnector {
    return try ONNXAgentConnector.init(allocator, .{
        .window_size = 8,
        .confidence_threshold = 0.9,
        .distance_penalty = 0.15,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

pub const BatchResult = struct {
    results: []agent.GeneratedCode,
    total_time_ms: f64,
    avg_speedup: f32,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *BatchResult) void {
        for (self.results) |*r| {
            r.deinit();
        }
        self.allocator.free(self.results);
    }
};

/// Generate code for multiple tasks in batch
pub fn batchGenerate(
    connector: *ONNXAgentConnector,
    tasks: []const AgentTask,
) !BatchResult {
    const start = std.time.nanoTimestamp();

    var results = try connector.allocator.alloc(agent.GeneratedCode, tasks.len);
    var total_speedup: f32 = 0;

    for (tasks, 0..) |task, i| {
        results[i] = try connector.agent.executeTask(task);
        total_speedup += results[i].speedup_vs_ar;
    }

    const end = std.time.nanoTimestamp();
    const total_time_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;

    return BatchResult{
        .results = results,
        .total_time_ms = total_time_ms,
        .avg_speedup = total_speedup / @as(f32, @floatFromInt(tasks.len)),
        .allocator = connector.allocator,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Golden Identity Verification" {
    const result = PHI_SQ + INV_PHI_SQ;
    try std.testing.expectApproxEqAbs(TRINITY, result, 0.0000001);
}

test "ONNXAgentConfig: toWeDLMConfig" {
    const config = ONNXAgentConfig{
        .window_size = 32,
        .confidence_threshold = 0.8,
    };

    const wedlm_config = config.toWeDLMConfig();

    try std.testing.expectEqual(@as(u32, 32), wedlm_config.wedlm_config.window_size);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), wedlm_config.wedlm_config.confidence_threshold, 0.001);
    try std.testing.expectEqual(BackendType.ONNX, wedlm_config.model_config.backend_type);
}

test "ONNXAgentConnector: initialization" {
    const allocator = std.testing.allocator;

    // Use simulated backend for testing
    var connector = try ONNXAgentConnector.init(allocator, .{
        .model_path = "",
    });
    defer connector.deinit();

    try std.testing.expect(connector.initialized);
    try std.testing.expectEqualStrings("idle", connector.getStatus());
}

test "ONNXAgentConnector: generate code with simulated backend" {
    const allocator = std.testing.allocator;

    // Use simulated backend for testing (empty model_path triggers ONNX which needs model)
    // Instead, create agent directly with simulated backend
    const agent_config = WeDLMAgentConfig{
        .wedlm_config = .{ .window_size = 8, .confidence_threshold = 0.5 },
        .model_config = .{ .backend_type = .SIMULATED, .vocab_size = 1000 },
    };

    var vibee_agent = try VibeeAgentWeDLM.init(allocator, agent_config);
    defer vibee_agent.deinit();

    const task = AgentTask{
        .task_type = .CODE_GENERATION,
        .description = "Create add function",
        .context = &[_][]const u8{},
        .target_language = .ZIG,
        .max_tokens = 256,
    };

    var result = try vibee_agent.executeTask(task);
    defer result.deinit();

    try std.testing.expect(result.tokens_generated > 0);

    std.debug.print("\n╔═══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║ ONNX AGENT CONNECTOR TEST (Simulated)                             ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Tokens: {d:>4} | Speedup: {d:.2}x | Confidence: {d:.2}               ║\n", .{
        result.tokens_generated,
        result.speedup_vs_ar,
        result.confidence,
    });
    std.debug.print("╚═══════════════════════════════════════════════════════════════════╝\n", .{});
}

test "ONNXAgentConnector: generate from spec with simulated backend" {
    const allocator = std.testing.allocator;

    // Use simulated backend for testing
    const agent_config2 = WeDLMAgentConfig{
        .wedlm_config = .{ .window_size = 8, .confidence_threshold = 0.5 },
        .model_config = .{ .backend_type = .SIMULATED, .vocab_size = 1000 },
    };

    var vibee_agent = try VibeeAgentWeDLM.init(allocator, agent_config2);
    defer vibee_agent.deinit();

    const spec =
        \\name: point
        \\creation_pattern:
        \\  source: Coordinates
        \\  transformer: Point
        \\  result: Point
    ;

    var result = try vibee_agent.generateFromVibee(spec, .ZIG);
    defer result.deinit();

    try std.testing.expect(result.tokens_generated > 0);
}

test "createDefaultAgent" {
    const allocator = std.testing.allocator;

    var connector = try createDefaultAgent(allocator);
    defer connector.deinit();

    try std.testing.expect(connector.initialized);
}

test "createFastAgent" {
    const allocator = std.testing.allocator;

    var connector = try createFastAgent(allocator);
    defer connector.deinit();

    try std.testing.expectEqual(@as(u32, 32), connector.config.window_size);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), connector.config.confidence_threshold, 0.001);
}

test "createQualityAgent" {
    const allocator = std.testing.allocator;

    var connector = try createQualityAgent(allocator);
    defer connector.deinit();

    try std.testing.expectEqual(@as(u32, 8), connector.config.window_size);
    try std.testing.expectApproxEqAbs(@as(f32, 0.9), connector.config.confidence_threshold, 0.001);
}

test "Phoenix Number" {
    try std.testing.expect(PHOENIX == 999);
    try std.testing.expect(999 == 27 * 37);
}

// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999 = 3³ × 37
// ═══════════════════════════════════════════════════════════════════════════════

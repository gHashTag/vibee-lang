// VIBEE v68 Multi-Model Router
// Dynamic Model Selection & Routing
// φ² + 1/φ² = 3 | PHOENIX = 999
const std = @import("std");
const testing = std.testing;

// === SACRED CONSTANTS ===
pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: u32 = 3;
pub const PHOENIX: u32 = 999;

// === PROVIDERS ===
pub const Provider = enum { anthropic, openai, google, deepseek, local, ollama };

// === MODEL TIERS ===
pub const ModelTier = enum { flagship, standard, fast, reasoning, code };

// === TASK TYPES ===
pub const TaskType = enum {
    code_generation,
    code_review,
    debugging,
    documentation,
    refactoring,
    testing,
    chat,
    reasoning,
};

// === ROUTING STRATEGIES ===
pub const RoutingStrategy = enum {
    cost_optimized,
    quality_optimized,
    speed_optimized,
    balanced,
    task_specific,
};

// === MODEL DEFINITION ===
pub const Model = struct {
    id: []const u8,
    provider: Provider,
    tier: ModelTier,
    context_window: u32,
    max_output: u32,
    input_cost_per_mtok: f64,
    output_cost_per_mtok: f64,
    speed_toks_per_sec: u32,
    swe_bench: f64,
    supports_vision: bool,
    supports_tools: bool,
};

// === MODEL CATALOG ===

// Anthropic Models
pub const CLAUDE_4_OPUS = Model{
    .id = "claude-4-opus",
    .provider = .anthropic,
    .tier = .flagship,
    .context_window = 200000,
    .max_output = 32000,
    .input_cost_per_mtok = 15.0,
    .output_cost_per_mtok = 75.0,
    .speed_toks_per_sec = 80,
    .swe_bench = 72.7,
    .supports_vision = true,
    .supports_tools = true,
};

pub const CLAUDE_4_SONNET = Model{
    .id = "claude-4-sonnet",
    .provider = .anthropic,
    .tier = .standard,
    .context_window = 200000,
    .max_output = 16000,
    .input_cost_per_mtok = 3.0,
    .output_cost_per_mtok = 15.0,
    .speed_toks_per_sec = 120,
    .swe_bench = 65.0,
    .supports_vision = true,
    .supports_tools = true,
};

pub const CLAUDE_4_HAIKU = Model{
    .id = "claude-4-haiku",
    .provider = .anthropic,
    .tier = .fast,
    .context_window = 200000,
    .max_output = 8000,
    .input_cost_per_mtok = 0.25,
    .output_cost_per_mtok = 1.25,
    .speed_toks_per_sec = 200,
    .swe_bench = 45.0,
    .supports_vision = true,
    .supports_tools = true,
};

// OpenAI Models
pub const GPT_5 = Model{
    .id = "gpt-5",
    .provider = .openai,
    .tier = .flagship,
    .context_window = 128000,
    .max_output = 16000,
    .input_cost_per_mtok = 10.0,
    .output_cost_per_mtok = 30.0,
    .speed_toks_per_sec = 100,
    .swe_bench = 68.0,
    .supports_vision = true,
    .supports_tools = true,
};

pub const O3 = Model{
    .id = "o3",
    .provider = .openai,
    .tier = .reasoning,
    .context_window = 200000,
    .max_output = 100000,
    .input_cost_per_mtok = 15.0,
    .output_cost_per_mtok = 60.0,
    .speed_toks_per_sec = 50,
    .swe_bench = 71.7,
    .supports_vision = false,
    .supports_tools = true,
};

pub const GPT_4O_MINI = Model{
    .id = "gpt-4o-mini",
    .provider = .openai,
    .tier = .fast,
    .context_window = 128000,
    .max_output = 16000,
    .input_cost_per_mtok = 0.15,
    .output_cost_per_mtok = 0.60,
    .speed_toks_per_sec = 180,
    .swe_bench = 42.0,
    .supports_vision = true,
    .supports_tools = true,
};

// Google Models
pub const GEMINI_2_ULTRA = Model{
    .id = "gemini-2-ultra",
    .provider = .google,
    .tier = .flagship,
    .context_window = 1000000,
    .max_output = 32000,
    .input_cost_per_mtok = 12.0,
    .output_cost_per_mtok = 36.0,
    .speed_toks_per_sec = 90,
    .swe_bench = 62.0,
    .supports_vision = true,
    .supports_tools = true,
};

pub const GEMINI_2_FLASH = Model{
    .id = "gemini-2-flash",
    .provider = .google,
    .tier = .fast,
    .context_window = 1000000,
    .max_output = 8000,
    .input_cost_per_mtok = 0.075,
    .output_cost_per_mtok = 0.30,
    .speed_toks_per_sec = 250,
    .swe_bench = 40.0,
    .supports_vision = true,
    .supports_tools = true,
};

// DeepSeek Models
pub const DEEPSEEK_V3 = Model{
    .id = "deepseek-v3",
    .provider = .deepseek,
    .tier = .code,
    .context_window = 64000,
    .max_output = 8000,
    .input_cost_per_mtok = 0.14,
    .output_cost_per_mtok = 0.28,
    .speed_toks_per_sec = 150,
    .swe_bench = 48.0,
    .supports_vision = false,
    .supports_tools = true,
};

pub const DEEPSEEK_R1 = Model{
    .id = "deepseek-r1",
    .provider = .deepseek,
    .tier = .reasoning,
    .context_window = 64000,
    .max_output = 8000,
    .input_cost_per_mtok = 0.55,
    .output_cost_per_mtok = 2.19,
    .speed_toks_per_sec = 80,
    .swe_bench = 55.0,
    .supports_vision = false,
    .supports_tools = true,
};

// Local Models
pub const LLAMA_3_3_70B = Model{
    .id = "llama-3.3-70b",
    .provider = .local,
    .tier = .standard,
    .context_window = 128000,
    .max_output = 8000,
    .input_cost_per_mtok = 0.0,
    .output_cost_per_mtok = 0.0,
    .speed_toks_per_sec = 40,
    .swe_bench = 35.0,
    .supports_vision = false,
    .supports_tools = true,
};

pub const QWEN_CODER_32B = Model{
    .id = "qwen-2.5-coder-32b",
    .provider = .local,
    .tier = .code,
    .context_window = 32000,
    .max_output = 8000,
    .input_cost_per_mtok = 0.0,
    .output_cost_per_mtok = 0.0,
    .speed_toks_per_sec = 60,
    .swe_bench = 40.0,
    .supports_vision = false,
    .supports_tools = true,
};

// === ALL MODELS ===
pub const ALL_MODELS = [_]Model{
    CLAUDE_4_OPUS,
    CLAUDE_4_SONNET,
    CLAUDE_4_HAIKU,
    GPT_5,
    O3,
    GPT_4O_MINI,
    GEMINI_2_ULTRA,
    GEMINI_2_FLASH,
    DEEPSEEK_V3,
    DEEPSEEK_R1,
    LLAMA_3_3_70B,
    QWEN_CODER_32B,
};

// === ROUTER CONFIG ===
pub const RouterConfig = struct {
    strategy: RoutingStrategy,
    max_cost_per_request: f64,
    min_quality_score: f64,
    max_latency_ms: u32,
    fallback_model: []const u8,
};

pub const DEFAULT_CONFIG = RouterConfig{
    .strategy = .balanced,
    .max_cost_per_request = 1.0,
    .min_quality_score = 50.0,
    .max_latency_ms = 30000,
    .fallback_model = "claude-4-haiku",
};

// === MULTI-MODEL ROUTER ===
pub const MultiModelRouter = struct {
    config: RouterConfig,
    request_count: u32,
    total_cost: f64,

    pub fn init() MultiModelRouter {
        return .{
            .config = DEFAULT_CONFIG,
            .request_count = 0,
            .total_cost = 0,
        };
    }

    pub fn setConfig(self: *MultiModelRouter, config: RouterConfig) void {
        self.config = config;
    }

    pub fn selectModel(self: *const MultiModelRouter, task: TaskType) *const Model {
        return switch (self.config.strategy) {
            .cost_optimized => selectCheapest(task),
            .quality_optimized => selectBestQuality(task),
            .speed_optimized => selectFastest(task),
            .balanced => selectBalanced(task),
            .task_specific => selectForTask(task),
        };
    }

    pub fn estimateCost(self: *const MultiModelRouter, model: *const Model, input_tokens: u32, output_tokens: u32) f64 {
        _ = self;
        const input_cost = @as(f64, @floatFromInt(input_tokens)) * model.input_cost_per_mtok / 1000000.0;
        const output_cost = @as(f64, @floatFromInt(output_tokens)) * model.output_cost_per_mtok / 1000000.0;
        return input_cost + output_cost;
    }

    pub fn recordRequest(self: *MultiModelRouter, cost: f64) void {
        self.request_count += 1;
        self.total_cost += cost;
    }
};

// === SELECTION FUNCTIONS ===
fn selectCheapest(task: TaskType) *const Model {
    _ = task;
    // Local models are free
    return &QWEN_CODER_32B;
}

fn selectBestQuality(task: TaskType) *const Model {
    return switch (task) {
        .code_review, .debugging => &CLAUDE_4_OPUS,
        .reasoning => &O3,
        else => &CLAUDE_4_OPUS,
    };
}

fn selectFastest(task: TaskType) *const Model {
    _ = task;
    return &GEMINI_2_FLASH; // 250 tok/s
}

fn selectBalanced(task: TaskType) *const Model {
    return switch (task) {
        .code_generation => &CLAUDE_4_SONNET,
        .code_review => &CLAUDE_4_OPUS,
        .debugging => &CLAUDE_4_SONNET,
        .documentation => &CLAUDE_4_HAIKU,
        .refactoring => &CLAUDE_4_SONNET,
        .testing => &CLAUDE_4_SONNET,
        .chat => &CLAUDE_4_HAIKU,
        .reasoning => &O3,
    };
}

fn selectForTask(task: TaskType) *const Model {
    return switch (task) {
        .code_generation => &DEEPSEEK_V3,
        .code_review => &CLAUDE_4_OPUS,
        .debugging => &DEEPSEEK_R1,
        .documentation => &GPT_4O_MINI,
        .refactoring => &DEEPSEEK_V3,
        .testing => &CLAUDE_4_SONNET,
        .chat => &CLAUDE_4_HAIKU,
        .reasoning => &O3,
    };
}

// === HELPER FUNCTIONS ===
pub fn findModel(id: []const u8) ?*const Model {
    for (&ALL_MODELS) |*model| {
        if (std.mem.eql(u8, model.id, id)) return model;
    }
    return null;
}

pub fn countByProvider(provider: Provider) u32 {
    var count: u32 = 0;
    for (ALL_MODELS) |model| {
        if (model.provider == provider) count += 1;
    }
    return count;
}

pub fn countByTier(tier: ModelTier) u32 {
    var count: u32 = 0;
    for (ALL_MODELS) |model| {
        if (model.tier == tier) count += 1;
    }
    return count;
}

pub fn getFreeModels() u32 {
    var count: u32 = 0;
    for (ALL_MODELS) |model| {
        if (model.input_cost_per_mtok == 0 and model.output_cost_per_mtok == 0) count += 1;
    }
    return count;
}

// ============================================================
// TESTS: SACRED CONSTANTS
// ============================================================
test "PHI" { try testing.expectApproxEqAbs(@as(f64, 1.618033988749895), PHI, 0.0001); }
test "TRINITY" { try testing.expectEqual(@as(u32, 3), TRINITY); }
test "PHOENIX" { try testing.expectEqual(@as(u32, 999), PHOENIX); }
test "37*27=999" { try testing.expectEqual(@as(u32, 999), 37 * 27); }

// ============================================================
// TESTS: MODEL CATALOG
// ============================================================
test "models.count" { try testing.expectEqual(@as(usize, 12), ALL_MODELS.len); }
test "models.anthropic" { try testing.expectEqual(@as(u32, 3), countByProvider(.anthropic)); }
test "models.openai" { try testing.expectEqual(@as(u32, 3), countByProvider(.openai)); }
test "models.google" { try testing.expectEqual(@as(u32, 2), countByProvider(.google)); }
test "models.deepseek" { try testing.expectEqual(@as(u32, 2), countByProvider(.deepseek)); }
test "models.local" { try testing.expectEqual(@as(u32, 2), countByProvider(.local)); }
test "models.free" { try testing.expectEqual(@as(u32, 2), getFreeModels()); }

// ============================================================
// TESTS: MODEL TIERS
// ============================================================
test "tier.flagship" { try testing.expectEqual(@as(u32, 3), countByTier(.flagship)); }
test "tier.standard" { try testing.expectEqual(@as(u32, 2), countByTier(.standard)); }
test "tier.fast" { try testing.expectEqual(@as(u32, 3), countByTier(.fast)); }
test "tier.reasoning" { try testing.expectEqual(@as(u32, 2), countByTier(.reasoning)); }
test "tier.code" { try testing.expectEqual(@as(u32, 2), countByTier(.code)); }

// ============================================================
// TESTS: CLAUDE MODELS
// ============================================================
test "claude.opus.swe" { try testing.expectApproxEqAbs(@as(f64, 72.7), CLAUDE_4_OPUS.swe_bench, 0.1); }
test "claude.opus.context" { try testing.expectEqual(@as(u32, 200000), CLAUDE_4_OPUS.context_window); }
test "claude.sonnet.swe" { try testing.expectApproxEqAbs(@as(f64, 65.0), CLAUDE_4_SONNET.swe_bench, 0.1); }
test "claude.haiku.speed" { try testing.expectEqual(@as(u32, 200), CLAUDE_4_HAIKU.speed_toks_per_sec); }
test "claude.vision" { try testing.expect(CLAUDE_4_OPUS.supports_vision); }
test "claude.tools" { try testing.expect(CLAUDE_4_OPUS.supports_tools); }

// ============================================================
// TESTS: OPENAI MODELS
// ============================================================
test "gpt5.swe" { try testing.expectApproxEqAbs(@as(f64, 68.0), GPT_5.swe_bench, 0.1); }
test "o3.swe" { try testing.expectApproxEqAbs(@as(f64, 71.7), O3.swe_bench, 0.1); }
test "o3.reasoning" { try testing.expect(O3.tier == .reasoning); }
test "gpt4o_mini.fast" { try testing.expect(GPT_4O_MINI.tier == .fast); }

// ============================================================
// TESTS: GOOGLE MODELS
// ============================================================
test "gemini.ultra.context" { try testing.expectEqual(@as(u32, 1000000), GEMINI_2_ULTRA.context_window); }
test "gemini.flash.speed" { try testing.expectEqual(@as(u32, 250), GEMINI_2_FLASH.speed_toks_per_sec); }
test "gemini.flash.cheap" { try testing.expectApproxEqAbs(@as(f64, 0.075), GEMINI_2_FLASH.input_cost_per_mtok, 0.001); }

// ============================================================
// TESTS: DEEPSEEK MODELS
// ============================================================
test "deepseek.v3.code" { try testing.expect(DEEPSEEK_V3.tier == .code); }
test "deepseek.r1.reasoning" { try testing.expect(DEEPSEEK_R1.tier == .reasoning); }
test "deepseek.cheap" { try testing.expect(DEEPSEEK_V3.input_cost_per_mtok < 0.5); }

// ============================================================
// TESTS: LOCAL MODELS
// ============================================================
test "local.free" { try testing.expectApproxEqAbs(@as(f64, 0.0), LLAMA_3_3_70B.input_cost_per_mtok, 0.001); }
test "local.qwen.code" { try testing.expect(QWEN_CODER_32B.tier == .code); }
test "local.no_vision" { try testing.expect(!LLAMA_3_3_70B.supports_vision); }

// ============================================================
// TESTS: FIND MODEL
// ============================================================
test "find.claude_opus" {
    const model = findModel("claude-4-opus");
    try testing.expect(model != null);
    try testing.expect(model.?.provider == .anthropic);
}
test "find.gpt5" {
    const model = findModel("gpt-5");
    try testing.expect(model != null);
}
test "find.nonexistent" {
    const model = findModel("nonexistent");
    try testing.expect(model == null);
}

// ============================================================
// TESTS: ROUTER
// ============================================================
test "router.init" {
    const router = MultiModelRouter.init();
    try testing.expect(router.config.strategy == .balanced);
    try testing.expectEqual(@as(u32, 0), router.request_count);
}

test "router.select_code_gen" {
    const router = MultiModelRouter.init();
    const model = router.selectModel(.code_generation);
    try testing.expect(std.mem.eql(u8, model.id, "claude-4-sonnet"));
}

test "router.select_code_review" {
    const router = MultiModelRouter.init();
    const model = router.selectModel(.code_review);
    try testing.expect(std.mem.eql(u8, model.id, "claude-4-opus"));
}

test "router.select_reasoning" {
    const router = MultiModelRouter.init();
    const model = router.selectModel(.reasoning);
    try testing.expect(std.mem.eql(u8, model.id, "o3"));
}

test "router.select_docs" {
    const router = MultiModelRouter.init();
    const model = router.selectModel(.documentation);
    try testing.expect(std.mem.eql(u8, model.id, "claude-4-haiku"));
}

test "router.cost_optimized" {
    var router = MultiModelRouter.init();
    router.config.strategy = .cost_optimized;
    const model = router.selectModel(.code_generation);
    try testing.expect(model.input_cost_per_mtok == 0); // Free model
}

test "router.speed_optimized" {
    var router = MultiModelRouter.init();
    router.config.strategy = .speed_optimized;
    const model = router.selectModel(.code_generation);
    try testing.expect(std.mem.eql(u8, model.id, "gemini-2-flash"));
}

test "router.quality_optimized" {
    var router = MultiModelRouter.init();
    router.config.strategy = .quality_optimized;
    const model = router.selectModel(.code_generation);
    try testing.expect(std.mem.eql(u8, model.id, "claude-4-opus"));
}

// ============================================================
// TESTS: COST ESTIMATION
// ============================================================
test "cost.claude_sonnet" {
    const router = MultiModelRouter.init();
    // 1000 input, 500 output tokens
    const cost = router.estimateCost(&CLAUDE_4_SONNET, 1000, 500);
    // (1000 * 3.0 + 500 * 15.0) / 1_000_000 = 0.0105
    try testing.expectApproxEqAbs(@as(f64, 0.0105), cost, 0.0001);
}

test "cost.free_model" {
    const router = MultiModelRouter.init();
    const cost = router.estimateCost(&LLAMA_3_3_70B, 10000, 5000);
    try testing.expectApproxEqAbs(@as(f64, 0.0), cost, 0.0001);
}

// ============================================================
// TESTS: REQUEST TRACKING
// ============================================================
test "router.record_request" {
    var router = MultiModelRouter.init();
    router.recordRequest(0.05);
    router.recordRequest(0.03);
    try testing.expectEqual(@as(u32, 2), router.request_count);
    try testing.expectApproxEqAbs(@as(f64, 0.08), router.total_cost, 0.001);
}

// ============================================================
// TESTS: TASK TYPES
// ============================================================
test "task.code_generation" { try testing.expect(TaskType.code_generation == .code_generation); }
test "task.code_review" { try testing.expect(TaskType.code_review == .code_review); }
test "task.debugging" { try testing.expect(TaskType.debugging == .debugging); }
test "task.documentation" { try testing.expect(TaskType.documentation == .documentation); }
test "task.refactoring" { try testing.expect(TaskType.refactoring == .refactoring); }
test "task.testing" { try testing.expect(TaskType.testing == .testing); }
test "task.chat" { try testing.expect(TaskType.chat == .chat); }
test "task.reasoning" { try testing.expect(TaskType.reasoning == .reasoning); }

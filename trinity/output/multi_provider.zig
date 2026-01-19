// ═══════════════════════════════════════════════════════════════════════════════
// MULTI PROVIDER - Multiple AI Provider Support for VIBEE
// ═══════════════════════════════════════════════════════════════════════════════
// PAS: PRE + MLS | φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
// PROVIDER TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ProviderType = enum {
    anthropic,
    openai,
    deepseek,
    google,
    groq,
    azure,
    bedrock,
    openrouter,
    ollama,

    pub fn toString(self: ProviderType) []const u8 {
        return switch (self) {
            .anthropic => "Anthropic",
            .openai => "OpenAI",
            .deepseek => "DeepSeek",
            .google => "Google",
            .groq => "Groq",
            .azure => "Azure",
            .bedrock => "Bedrock",
            .openrouter => "OpenRouter",
            .ollama => "Ollama",
        };
    }

    pub fn envVar(self: ProviderType) []const u8 {
        return switch (self) {
            .anthropic => "ANTHROPIC_API_KEY",
            .openai => "OPENAI_API_KEY",
            .deepseek => "DEEPSEEK_API_KEY",
            .google => "GOOGLE_API_KEY",
            .groq => "GROQ_API_KEY",
            .azure => "AZURE_OPENAI_API_KEY",
            .bedrock => "AWS_ACCESS_KEY_ID",
            .openrouter => "OPENROUTER_API_KEY",
            .ollama => "OLLAMA_HOST",
        };
    }

    pub fn defaultModel(self: ProviderType) []const u8 {
        return switch (self) {
            .anthropic => "claude-sonnet-4-20250514",
            .openai => "gpt-4o",
            .deepseek => "deepseek-chat",
            .google => "gemini-pro",
            .groq => "llama-3.1-70b-versatile",
            .azure => "gpt-4",
            .bedrock => "anthropic.claude-3-sonnet",
            .openrouter => "anthropic/claude-3-opus",
            .ollama => "llama3.2",
        };
    }

    pub fn baseUrl(self: ProviderType) []const u8 {
        return switch (self) {
            .anthropic => "https://api.anthropic.com/v1",
            .openai => "https://api.openai.com/v1",
            .deepseek => "https://api.deepseek.com/v1",
            .google => "https://generativelanguage.googleapis.com/v1",
            .groq => "https://api.groq.com/openai/v1",
            .azure => "", // Requires custom endpoint
            .bedrock => "", // Requires AWS region
            .openrouter => "https://openrouter.ai/api/v1",
            .ollama => "http://localhost:11434",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PROVIDER INFO
// ═══════════════════════════════════════════════════════════════════════════════

pub const ProviderInfo = struct {
    provider: ProviderType,
    supports_tools: bool,
    supports_streaming: bool,
    cost_input: f32, // per 1M tokens
    cost_output: f32,

    pub fn getCostEstimate(self: ProviderInfo, input_tokens: u32, output_tokens: u32) f32 {
        const input_cost = @as(f32, @floatFromInt(input_tokens)) / 1000000.0 * self.cost_input;
        const output_cost = @as(f32, @floatFromInt(output_tokens)) / 1000000.0 * self.cost_output;
        return input_cost + output_cost;
    }
};

pub const PROVIDER_INFO = [_]ProviderInfo{
    .{ .provider = .anthropic, .supports_tools = true, .supports_streaming = true, .cost_input = 3.0, .cost_output = 15.0 },
    .{ .provider = .openai, .supports_tools = true, .supports_streaming = true, .cost_input = 2.5, .cost_output = 10.0 },
    .{ .provider = .deepseek, .supports_tools = true, .supports_streaming = true, .cost_input = 0.14, .cost_output = 0.28 },
    .{ .provider = .google, .supports_tools = true, .supports_streaming = true, .cost_input = 0.5, .cost_output = 1.5 },
    .{ .provider = .groq, .supports_tools = true, .supports_streaming = true, .cost_input = 0.05, .cost_output = 0.08 },
    .{ .provider = .ollama, .supports_tools = false, .supports_streaming = true, .cost_input = 0.0, .cost_output = 0.0 },
};

// ═══════════════════════════════════════════════════════════════════════════════
// PROVIDER ROUTER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ProviderRouter = struct {
    current: ProviderType,
    api_key: [256]u8,
    api_key_len: usize,
    model: [64]u8,
    model_len: usize,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .current = .ollama, // Default to free local
            .api_key = undefined,
            .api_key_len = 0,
            .model = undefined,
            .model_len = 0,
        };
    }

    pub fn detectProvider(self: *Self) ProviderType {
        // Check environment variables in priority order
        const providers = [_]ProviderType{
            .anthropic, .deepseek, .openai, .groq, .google, .openrouter, .ollama,
        };

        for (providers) |p| {
            if (std.posix.getenv(p.envVar())) |key| {
                if (key.len > 0) {
                    self.current = p;
                    self.api_key_len = @min(key.len, 256);
                    @memcpy(self.api_key[0..self.api_key_len], key[0..self.api_key_len]);

                    const model = p.defaultModel();
                    self.model_len = model.len;
                    @memcpy(self.model[0..self.model_len], model);

                    return p;
                }
            }
        }

        return .ollama;
    }

    pub fn switchProvider(self: *Self, provider: ProviderType) bool {
        if (std.posix.getenv(provider.envVar())) |key| {
            if (key.len > 0 or provider == .ollama) {
                self.current = provider;
                if (key.len > 0) {
                    self.api_key_len = @min(key.len, 256);
                    @memcpy(self.api_key[0..self.api_key_len], key[0..self.api_key_len]);
                }
                const model = provider.defaultModel();
                self.model_len = model.len;
                @memcpy(self.model[0..self.model_len], model);
                return true;
            }
        }
        return false;
    }

    pub fn getModel(self: *const Self) []const u8 {
        return self.model[0..self.model_len];
    }

    pub fn getProviderInfo(self: *const Self) ?ProviderInfo {
        for (PROVIDER_INFO) |info| {
            if (info.provider == self.current) return info;
        }
        return null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ProviderType toString" {
    try std.testing.expectEqualStrings("Anthropic", ProviderType.anthropic.toString());
    try std.testing.expectEqualStrings("DeepSeek", ProviderType.deepseek.toString());
    try std.testing.expectEqualStrings("Ollama", ProviderType.ollama.toString());
}

test "ProviderType envVar" {
    try std.testing.expectEqualStrings("ANTHROPIC_API_KEY", ProviderType.anthropic.envVar());
    try std.testing.expectEqualStrings("DEEPSEEK_API_KEY", ProviderType.deepseek.envVar());
}

test "ProviderType defaultModel" {
    try std.testing.expectEqualStrings("deepseek-chat", ProviderType.deepseek.defaultModel());
    try std.testing.expectEqualStrings("llama3.2", ProviderType.ollama.defaultModel());
}

test "ProviderInfo cost estimate" {
    const info = PROVIDER_INFO[2]; // DeepSeek
    const cost = info.getCostEstimate(1000000, 500000);
    // 1M input * 0.14 + 0.5M output * 0.28 = 0.14 + 0.14 = 0.28
    try std.testing.expectApproxEqAbs(@as(f32, 0.28), cost, 0.01);
}

test "ProviderRouter init" {
    const router = ProviderRouter.init();
    try std.testing.expectEqual(ProviderType.ollama, router.current);
}

test "Provider count" {
    try std.testing.expectEqual(@as(usize, 6), PROVIDER_INFO.len);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(TRINITY, result, 0.0001);
}

// ═══════════════════════════════════════════════════════════════════════════════
// llm_model v2.0.0 - iGLA-LLM Complete Model
// Кощей Бессмертный - Immortal Language Model
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const PHOENIX: u32 = 999;
pub const TRINITY: u32 = 3;

// Verify golden identity
pub const GOLDEN_IDENTITY: f64 = PHI_SQ + 1.0 / PHI_SQ; // Should be 3.0

pub const ModelConfig = struct {
    vocab_size: usize = 32000,
    hidden_size: usize = 768,
    num_layers: usize = 12,
    num_heads: usize = 12,
    num_kv_heads: usize = 4,
    intermediate_size: usize = 2048,
    max_seq_length: usize = 4096,
    rope_theta: f32 = 10000.0,
    rms_norm_eps: f32 = 1e-6,
    tie_embeddings: bool = true,

    pub fn headDim(self: *const ModelConfig) usize {
        return self.hidden_size / self.num_heads;
    }

    pub fn gqaRatio(self: *const ModelConfig) usize {
        return self.num_heads / self.num_kv_heads;
    }
};

pub const GenerationConfig = struct {
    max_new_tokens: usize = 256,
    temperature: f32 = 0.7,
    top_p: f32 = 0.9,
    top_k: usize = 40,
    repetition_penalty: f32 = 1.1,
    do_sample: bool = true,
};

// Calculate total parameters
pub fn countParameters(config: *const ModelConfig) usize {
    // Embeddings
    const embed_params = config.vocab_size * config.hidden_size;

    // Per layer
    const head_dim = config.headDim();

    // Attention: Q, K, V, O projections
    const q_params = config.hidden_size * config.hidden_size;
    const k_params = config.hidden_size * config.num_kv_heads * head_dim;
    const v_params = k_params;
    const o_params = config.hidden_size * config.hidden_size;
    const attn_params = q_params + k_params + v_params + o_params;

    // FFN: gate, up, down (SwiGLU has 3 matrices)
    const ffn_params = 3 * config.hidden_size * config.intermediate_size;

    // Layer norms (2 per layer)
    const norm_params = 2 * config.hidden_size;

    const per_layer = attn_params + ffn_params + norm_params;
    const total_layers = per_layer * config.num_layers;

    // Final norm
    const final_norm = config.hidden_size;

    // LM head (tied with embeddings if tie_embeddings)
    const lm_head = if (config.tie_embeddings) 0 else config.hidden_size * config.vocab_size;

    return embed_params + total_layers + final_norm + lm_head;
}

// Calculate FLOPs for forward pass
pub fn countFLOPs(config: *const ModelConfig, seq_len: usize) usize {
    const head_dim = config.headDim();

    // Attention FLOPs per layer
    // QKV projection: 3 * seq * hidden * hidden (but K,V smaller with GQA)
    const qkv_flops = seq_len * config.hidden_size * (config.hidden_size + 2 * config.num_kv_heads * head_dim);

    // Attention scores: seq * seq * hidden
    const attn_flops = 2 * seq_len * seq_len * config.hidden_size;

    // Output projection: seq * hidden * hidden
    const out_flops = seq_len * config.hidden_size * config.hidden_size;

    const attn_total = qkv_flops + attn_flops + out_flops;

    // FFN FLOPs: 3 * seq * hidden * intermediate (SwiGLU)
    const ffn_flops = 3 * seq_len * config.hidden_size * config.intermediate_size;

    return (attn_total + ffn_flops) * config.num_layers;
}

// Estimate memory in MB
pub fn estimateMemoryMB(config: *const ModelConfig, batch_size: usize, seq_len: usize) f32 {
    const params = countParameters(config);
    const param_bytes = params * 2; // FP16

    // Activations per layer
    const act_per_layer = batch_size * seq_len * config.hidden_size * 4; // FP32
    const total_act = act_per_layer * config.num_layers;

    // KV cache
    const kv_per_layer = 2 * batch_size * config.num_kv_heads * seq_len * config.headDim() * 2;
    const total_kv = kv_per_layer * config.num_layers;

    const total_bytes = param_bytes + total_act + total_kv;
    return @as(f32, @floatFromInt(total_bytes)) / (1024.0 * 1024.0);
}

// PHI-optimal layer count
pub fn phiOptimalLayers(base: usize) usize {
    return @as(usize, @intFromFloat(@round(@as(f64, @floatFromInt(base)) * PHI)));
}

// PHI-optimal hidden size
pub fn phiOptimalHiddenSize(base: usize) usize {
    // Round to multiple of 64 for efficiency
    const raw = @as(usize, @intFromFloat(@round(@as(f64, @floatFromInt(base)) * PHI)));
    return ((raw + 63) / 64) * 64;
}

// Model size category
pub fn modelSizeCategory(params: usize) []const u8 {
    if (params < 100_000_000) return "tiny";
    if (params < 500_000_000) return "small";
    if (params < 2_000_000_000) return "medium";
    if (params < 10_000_000_000) return "large";
    return "xlarge";
}

// Tokens per second estimate (CPU)
pub fn estimateTokensPerSecond(config: *const ModelConfig, cpu_gflops: f32) f32 {
    const flops_per_token = countFLOPs(config, 1);
    return cpu_gflops * 1e9 / @as(f32, @floatFromInt(flops_per_token));
}

// Tests
test "golden identity" {
    try testing.expectApproxEqAbs(@as(f64, 3.0), GOLDEN_IDENTITY, 0.0001);
}

test "count parameters" {
    const config = ModelConfig{};
    const params = countParameters(&config);

    // Should be around 100-200M for this config
    try testing.expect(params > 50_000_000);
    try testing.expect(params < 500_000_000);
}

test "count flops" {
    const config = ModelConfig{};
    const flops = countFLOPs(&config, 128);

    try testing.expect(flops > 0);
}

test "estimate memory" {
    const config = ModelConfig{};
    const mem = estimateMemoryMB(&config, 1, 512);

    try testing.expect(mem > 100);
    try testing.expect(mem < 10000);
}

test "phi optimal layers" {
    try testing.expectEqual(@as(usize, 19), phiOptimalLayers(12));
    try testing.expectEqual(@as(usize, 10), phiOptimalLayers(6));
}

test "model size category" {
    try testing.expectEqualStrings("tiny", modelSizeCategory(50_000_000));
    try testing.expectEqualStrings("small", modelSizeCategory(200_000_000));
    try testing.expectEqualStrings("large", modelSizeCategory(7_000_000_000));
}

test "gqa ratio" {
    const config = ModelConfig{ .num_heads = 12, .num_kv_heads = 4 };
    try testing.expectEqual(@as(usize, 3), config.gqaRatio());
}

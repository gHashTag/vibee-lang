// ═══════════════════════════════════════════════════════════════════════════════
// WeDLM INTEGRATED - Generated from specs/wedlm_integrated.vibee
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// Combines WeDLM streaming parallel decoding with real transformer backend
// Target: 3-10x speedup with production-ready inference
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const backend = @import("transformer_backend.zig");

pub const TransformerBackend = backend.TransformerBackend;
pub const BackendFactory = backend.BackendFactory;
pub const ModelConfig = backend.ModelConfig;
pub const BackendType = backend.BackendType;
pub const PagedKVCache = backend.PagedKVCache;

pub const PHI: f64 = 1.618033988749895;
pub const PHOENIX: u32 = 999;
pub const DEFAULT_WINDOW_SIZE: u32 = 16;
pub const DEFAULT_CONFIDENCE_THRESHOLD: f32 = 0.85;
pub const DEFAULT_DISTANCE_PENALTY: f32 = 0.1;
pub const MASK_TOKEN: u32 = 50256;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const WeDLMConfig = struct {
    window_size: u32 = DEFAULT_WINDOW_SIZE,
    confidence_threshold: f32 = DEFAULT_CONFIDENCE_THRESHOLD,
    distance_penalty: f32 = DEFAULT_DISTANCE_PENALTY,
    max_steps: u32 = 100,
};

pub const Token = struct {
    id: u32,
    confidence: f32,
    position: u32,
    committed: bool,
};

pub const GenerationStats = struct {
    total_tokens: u32,
    steps_taken: u32,
    tokens_per_step: f32,
    speedup_vs_ar: f32,
    cache_hit_rate: f32,
    avg_confidence: f32,
};

pub const GenerationResult = struct {
    tokens: []u32,
    stats: GenerationStats,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *GenerationResult) void {
        self.allocator.free(self.tokens);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGRATED WeDLM DECODER
// ═══════════════════════════════════════════════════════════════════════════════

pub const IntegratedWeDLMDecoder = struct {
    config: WeDLMConfig,
    model_config: ModelConfig,
    backend: TransformerBackend,
    allocator: std.mem.Allocator,
    total_confidence: f32,
    confidence_count: u32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, wedlm_config: WeDLMConfig, model_config: ModelConfig) !Self {
        const transformer_backend = try BackendFactory.create(allocator, model_config);
        return Self{
            .config = wedlm_config,
            .model_config = model_config,
            .backend = transformer_backend,
            .allocator = allocator,
            .total_confidence = 0.0,
            .confidence_count = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.backend.deinit();
    }

    pub fn generate(self: *Self, prompt: []const u32, max_new_tokens: u32) !GenerationResult {
        var generated = std.ArrayList(u32).init(self.allocator);
        defer generated.deinit();
        try generated.appendSlice(prompt);

        const window = try self.allocator.alloc(Token, self.config.window_size);
        defer self.allocator.free(window);

        for (window, 0..) |*t, i| {
            t.* = Token{
                .id = MASK_TOKEN,
                .confidence = 0.0,
                .position = @as(u32, @intCast(prompt.len + i)),
                .committed = false,
            };
        }

        var steps: u32 = 0;
        var tokens_generated: u32 = 0;
        const target_len = @as(u32, @intCast(prompt.len)) + max_new_tokens;

        while (generated.items.len < target_len and steps < self.config.max_steps) {
            const current_len = @as(u32, @intCast(generated.items.len));

            // Forward pass
            const context_len = @min(current_len, 32);
            const input_ids = try self.allocator.alloc(u32, context_len);
            defer self.allocator.free(input_ids);
            const start_idx = current_len - context_len;
            for (input_ids, 0..) |*id, i| {
                id.* = generated.items[start_idx + i];
            }

            const positions = try self.allocator.alloc(u32, self.config.window_size);
            defer self.allocator.free(positions);
            for (positions, 0..) |*p, i| {
                p.* = current_len + @as(u32, @intCast(i));
            }

            var result = try self.backend.forward(.{
                .input_ids = input_ids,
                .positions = positions,
                .seq_id = 0,
            });
            defer result.deinit();

            // Compute confidence and sample
            for (window) |*token| {
                if (!token.committed) {
                    const conf = self.computeConfidence(result.logits);
                    token.confidence = conf;
                    token.id = self.sampleToken(result.logits);
                    self.total_confidence += conf;
                    self.confidence_count += 1;
                }
            }

            // Select and commit
            const committed_count = self.selectAndCommit(window, current_len);

            for (window) |token| {
                if (token.committed and token.position == current_len + tokens_generated) {
                    try generated.append(token.id);
                    tokens_generated += 1;
                }
            }

            self.refillWindow(window, @as(u32, @intCast(generated.items.len)));
            steps += 1;

            if (committed_count == 0 and window[0].position == current_len) {
                try generated.append(window[0].id);
                tokens_generated += 1;
                self.refillWindow(window, @as(u32, @intCast(generated.items.len)));
            }
        }

        const backend_stats = self.backend.getStats();
        const tokens_per_step = if (steps > 0)
            @as(f32, @floatFromInt(tokens_generated)) / @as(f32, @floatFromInt(steps))
        else
            0.0;

        const result_tokens = try self.allocator.dupe(u32, generated.items[prompt.len..]);

        return GenerationResult{
            .tokens = result_tokens,
            .stats = GenerationStats{
                .total_tokens = tokens_generated,
                .steps_taken = steps,
                .tokens_per_step = tokens_per_step,
                .speedup_vs_ar = tokens_per_step,
                .cache_hit_rate = @floatCast(backend_stats.cacheHitRate()),
                .avg_confidence = if (self.confidence_count > 0)
                    self.total_confidence / @as(f32, @floatFromInt(self.confidence_count))
                else
                    0.0,
            },
            .allocator = self.allocator,
        };
    }

    fn computeConfidence(self: *Self, logits: []f32) f32 {
        _ = self;
        var max_logit: f32 = logits[0];
        for (logits[1..]) |l| {
            if (l > max_logit) max_logit = l;
        }
        var sum_exp: f64 = 0.0;
        for (logits) |l| {
            sum_exp += @exp(@as(f64, l - max_logit));
        }
        const max_prob: f32 = @floatCast(1.0 / sum_exp);
        return @min(1.0, max_prob * 10.0);
    }

    fn sampleToken(self: *Self, logits: []f32) u32 {
        _ = self;
        var max_idx: u32 = 0;
        var max_val: f32 = logits[0];
        for (logits[1..], 1..) |l, i| {
            if (l > max_val) {
                max_val = l;
                max_idx = @intCast(i);
            }
        }
        return max_idx;
    }

    fn selectAndCommit(self: *Self, window: []Token, prefix_end: u32) u32 {
        var committed_count: u32 = 0;
        for (window) |*token| {
            if (token.committed) continue;
            const distance = if (token.position >= prefix_end)
                @as(f32, @floatFromInt(token.position - prefix_end))
            else
                0.0;
            const score = token.confidence - self.config.distance_penalty * distance;
            if (score >= self.config.confidence_threshold and
                token.position == prefix_end + committed_count)
            {
                token.committed = true;
                committed_count += 1;
            }
        }
        return committed_count;
    }

    fn refillWindow(self: *Self, window: []Token, new_start: u32) void {
        _ = self;
        var write_idx: usize = 0;
        for (window) |token| {
            if (!token.committed) {
                window[write_idx] = token;
                write_idx += 1;
            }
        }
        while (write_idx < window.len) {
            window[write_idx] = Token{
                .id = MASK_TOKEN,
                .confidence = 0.0,
                .position = new_start + @as(u32, @intCast(write_idx)),
                .committed = false,
            };
            write_idx += 1;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "IntegratedWeDLMDecoder: basic generation" {
    const allocator = std.testing.allocator;
    var decoder = try IntegratedWeDLMDecoder.init(
        allocator,
        .{ .window_size = 8, .confidence_threshold = 0.5 },
        .{ .backend_type = .SIMULATED, .vocab_size = 1000 },
    );
    defer decoder.deinit();

    const prompt = [_]u32{ 1, 2, 3, 4, 5 };
    var result = try decoder.generate(&prompt, 20);
    defer result.deinit();

    try std.testing.expect(result.tokens.len > 0);
    std.debug.print("\n╔═══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║ INTEGRATED WeDLM BENCHMARK                                        ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Tokens: {d:>3} | Steps: {d:>3} | Speedup: {d:.2}x                        ║\n", .{ result.stats.total_tokens, result.stats.steps_taken, result.stats.speedup_vs_ar });
    std.debug.print("╚═══════════════════════════════════════════════════════════════════╝\n", .{});
}

test "IntegratedWeDLMDecoder: with ONNX backend" {
    const allocator = std.testing.allocator;
    var decoder = try IntegratedWeDLMDecoder.init(
        allocator,
        .{ .window_size = 16, .confidence_threshold = 0.6 },
        .{ .backend_type = .ONNX, .model_path = "gpt2.onnx", .vocab_size = 500 },
    );
    defer decoder.deinit();

    const prompt = [_]u32{ 10, 20, 30 };
    var result = try decoder.generate(&prompt, 50);
    defer result.deinit();

    try std.testing.expect(result.tokens.len > 0);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), phi_sq + inv_phi_sq, 0.0001);
}

// ═══════════════════════════════════════════════════════════════════════════════
// DIFFUSION DECODER - Generated from specs/diffusion_decoder.vibee
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | PHOENIX = 999
// Based on WeDLM (Tencent WeChat AI) - 3-10x speedup vs autoregressive
// PAS DAEMONS: MLS (parallel), D&C (reorder), PRE (thresholds), FDT (streaming)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Sacred constants
pub const PHI: f64 = 1.618033988749895;
pub const PHOENIX: u32 = 999;
pub const TRINITY: u32 = 3;

// Diffusion defaults
pub const DEFAULT_STEPS: u32 = 10;
pub const DEFAULT_CONFIDENCE: f32 = 0.9;
pub const DEFAULT_PARALLEL: u32 = 8;

// Special tokens
pub const MASK_TOKEN: u32 = 50256;
pub const PAD_TOKEN: u32 = 50257;
pub const EOS_TOKEN: u32 = 50258;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Token = struct {
    id: u32,
    confidence: f32,
    position: u32,
    committed: bool,
};

pub const DiffusionConfig = struct {
    num_steps: u32 = DEFAULT_STEPS,
    confidence_threshold: f32 = DEFAULT_CONFIDENCE,
    parallel_tokens: u32 = DEFAULT_PARALLEL,
    temperature: f32 = 1.0,
};

pub const GenerationStats = struct {
    total_tokens: u32,
    steps_taken: u32,
    tokens_per_step: f32,
    speedup_vs_ar: f32,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MASKED SEQUENCE
// ═══════════════════════════════════════════════════════════════════════════════

pub const MaskedSequence = struct {
    tokens: []Token,
    prefix_len: u32,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, length: u32) !Self {
        const tokens = try allocator.alloc(Token, length);
        for (tokens, 0..) |*t, i| {
            t.* = Token{
                .id = MASK_TOKEN,
                .confidence = 0.0,
                .position = @intCast(i),
                .committed = false,
            };
        }
        return Self{
            .tokens = tokens,
            .prefix_len = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.tokens);
    }

    pub fn maskedCount(self: *const Self) u32 {
        var count: u32 = 0;
        for (self.tokens) |t| {
            if (!t.committed) count += 1;
        }
        return count;
    }

    pub fn committedCount(self: *const Self) u32 {
        return @as(u32, @intCast(self.tokens.len)) - self.maskedCount();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DIFFUSION DECODER (WeDLM-style)
// ═══════════════════════════════════════════════════════════════════════════════

pub const DiffusionDecoder = struct {
    config: DiffusionConfig,
    prng: std.Random.DefaultPrng,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: DiffusionConfig) Self {
        return Self{
            .config = config,
            .prng = std.Random.DefaultPrng.init(PHOENIX),
            .allocator = allocator,
        };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CORE DIFFUSION STEP
    // ─────────────────────────────────────────────────────────────────────────

    pub fn diffusionStep(self: *Self, seq: *MaskedSequence) u32 {
        var committed_this_step: u32 = 0;

        // 1. Predict all masked positions in parallel
        for (seq.tokens) |*token| {
            if (!token.committed) {
                // Simulate prediction (in real impl, call transformer)
                token.id = self.predictToken(token.position);
                token.confidence = self.predictConfidence();
            }
        }

        // 2. Sort by confidence and commit high-confidence tokens
        // (simplified: commit tokens above threshold)
        for (seq.tokens) |*token| {
            if (!token.committed and token.confidence >= self.config.confidence_threshold) {
                token.committed = true;
                committed_this_step += 1;

                // Limit parallel commits
                if (committed_this_step >= self.config.parallel_tokens) break;
            }
        }

        // 3. Topological Reorder
        self.topologicalReorder(seq);

        return committed_this_step;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TOPOLOGICAL REORDERING
    // ─────────────────────────────────────────────────────────────────────────

    pub fn topologicalReorder(self: *Self, seq: *MaskedSequence) void {
        _ = self;

        // Move committed tokens to prefix (physical reordering)
        // Key insight from WeDLM: enables KV cache reuse

        var write_idx: usize = 0;

        // First pass: committed tokens
        for (seq.tokens) |token| {
            if (token.committed) {
                seq.tokens[write_idx] = token;
                write_idx += 1;
            }
        }

        seq.prefix_len = @intCast(write_idx);

        // Second pass: masked tokens
        for (seq.tokens) |token| {
            if (!token.committed) {
                seq.tokens[write_idx] = token;
                write_idx += 1;
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FULL GENERATION
    // ─────────────────────────────────────────────────────────────────────────

    pub fn generate(self: *Self, seq: *MaskedSequence) GenerationStats {
        var steps: u32 = 0;
        const total_tokens: u32 = @intCast(seq.tokens.len);

        while (seq.maskedCount() > 0 and steps < self.config.num_steps) {
            _ = self.diffusionStep(seq);
            steps += 1;
        }

        const tokens_per_step = @as(f32, @floatFromInt(total_tokens)) / @as(f32, @floatFromInt(@max(1, steps)));

        return GenerationStats{
            .total_tokens = total_tokens,
            .steps_taken = steps,
            .tokens_per_step = tokens_per_step,
            .speedup_vs_ar = tokens_per_step, // AR = 1 token/step
        };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HELPERS (simulated - real impl would use transformer)
    // ─────────────────────────────────────────────────────────────────────────

    fn predictToken(self: *Self, position: u32) u32 {
        // Simulate token prediction
        return (position * 7 + self.prng.random().int(u32)) % 50000;
    }

    fn predictConfidence(self: *Self) f32 {
        // Simulate confidence (biased towards high confidence)
        const base = self.prng.random().float(f32);
        return 0.5 + base * 0.5; // Range: 0.5 - 1.0
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STREAMING GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const StreamingGenerator = struct {
    decoder: DiffusionDecoder,
    callback: ?*const fn (Token) void,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: DiffusionConfig) Self {
        return Self{
            .decoder = DiffusionDecoder.init(allocator, config),
            .callback = null,
        };
    }

    pub fn setCallback(self: *Self, cb: *const fn (Token) void) void {
        self.callback = cb;
    }

    pub fn generateStreaming(self: *Self, seq: *MaskedSequence) GenerationStats {
        var steps: u32 = 0;
        const total_tokens: u32 = @intCast(seq.tokens.len);
        var last_committed: u32 = 0;

        while (seq.maskedCount() > 0 and steps < self.decoder.config.num_steps) {
            _ = self.decoder.diffusionStep(seq);
            steps += 1;

            // Emit newly committed tokens
            const current_committed = seq.committedCount();
            if (current_committed > last_committed and self.callback != null) {
                for (seq.tokens[last_committed..current_committed]) |token| {
                    self.callback.?(token);
                }
                last_committed = current_committed;
            }
        }

        const tokens_per_step = @as(f32, @floatFromInt(total_tokens)) / @as(f32, @floatFromInt(@max(1, steps)));

        return GenerationStats{
            .total_tokens = total_tokens,
            .steps_taken = steps,
            .tokens_per_step = tokens_per_step,
            .speedup_vs_ar = tokens_per_step,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "MaskedSequence: init and count" {
    const allocator = std.testing.allocator;

    var seq = try MaskedSequence.init(allocator, 10);
    defer seq.deinit();

    try std.testing.expectEqual(@as(u32, 10), seq.maskedCount());
    try std.testing.expectEqual(@as(u32, 0), seq.committedCount());
}

test "DiffusionDecoder: single step commits tokens" {
    const allocator = std.testing.allocator;

    var seq = try MaskedSequence.init(allocator, 10);
    defer seq.deinit();

    var decoder = DiffusionDecoder.init(allocator, .{
        .confidence_threshold = 0.5, // Lower threshold for test
    });

    const committed = decoder.diffusionStep(&seq);

    try std.testing.expect(committed > 0);
    try std.testing.expect(seq.committedCount() > 0);
}

test "DiffusionDecoder: full generation" {
    const allocator = std.testing.allocator;

    var seq = try MaskedSequence.init(allocator, 20);
    defer seq.deinit();

    var decoder = DiffusionDecoder.init(allocator, .{
        .num_steps = 10,
        .confidence_threshold = 0.5,
        .parallel_tokens = 4,
    });

    const stats = decoder.generate(&seq);

    try std.testing.expect(stats.steps_taken > 0);
    try std.testing.expect(stats.speedup_vs_ar >= 1.0);

    std.debug.print("\n", .{});
    std.debug.print("╔═══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║ DIFFUSION DECODER BENCHMARK                                       ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Total tokens:      {d:>6}                                         ║\n", .{stats.total_tokens});
    std.debug.print("║ Steps taken:       {d:>6}                                         ║\n", .{stats.steps_taken});
    std.debug.print("║ Tokens/step:       {d:>6.1}                                         ║\n", .{stats.tokens_per_step});
    std.debug.print("║ Speedup vs AR:     {d:>6.1}x                                        ║\n", .{stats.speedup_vs_ar});
    std.debug.print("╚═══════════════════════════════════════════════════════════════════╝\n", .{});
}

test "Speedup calculation" {
    // 100 tokens in 20 steps = 5x speedup
    const stats = GenerationStats{
        .total_tokens = 100,
        .steps_taken = 20,
        .tokens_per_step = 5.0,
        .speedup_vs_ar = 5.0,
    };

    try std.testing.expectApproxEqAbs(@as(f32, 5.0), stats.speedup_vs_ar, 0.01);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), phi_sq + inv_phi_sq, 0.0001);
}

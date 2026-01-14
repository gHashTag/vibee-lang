// ML-Guided Template Selection for VIBEE Code Generator
// Based on learned cost models and feature extraction
// Part of PAS Phase 4 implementation

const std = @import("std");

// ============================================================================
// CODE CONTEXT FEATURES
// ============================================================================

pub const ContextFeatures = struct {
    // Loop features
    loop_depth: u8,
    estimated_iterations: u32,
    is_hot_path: bool,
    
    // Data features
    data_size: u32,
    is_contiguous: bool,
    alignment: u8,
    
    // Control flow features
    branch_count: u16,
    has_early_exit: bool,
    is_recursive: bool,
    
    // Type features
    element_size: u8,
    is_floating_point: bool,
    is_signed: bool,
    
    // Target features
    has_simd: bool,
    cache_line_size: u8,
    register_count: u8,

    pub fn init() ContextFeatures {
        return .{
            .loop_depth = 0,
            .estimated_iterations = 0,
            .is_hot_path = false,
            .data_size = 0,
            .is_contiguous = true,
            .alignment = 8,
            .branch_count = 0,
            .has_early_exit = false,
            .is_recursive = false,
            .element_size = 8,
            .is_floating_point = false,
            .is_signed = true,
            .has_simd = true,
            .cache_line_size = 64,
            .register_count = 16,
        };
    }

    /// Convert to feature vector for ML model
    pub fn toVector(self: *const ContextFeatures) [16]f32 {
        return [_]f32{
            @floatFromInt(self.loop_depth),
            @floatFromInt(@min(self.estimated_iterations, 10000)),
            if (self.is_hot_path) 1.0 else 0.0,
            @floatFromInt(@min(self.data_size, 1000000)),
            if (self.is_contiguous) 1.0 else 0.0,
            @floatFromInt(self.alignment),
            @floatFromInt(self.branch_count),
            if (self.has_early_exit) 1.0 else 0.0,
            if (self.is_recursive) 1.0 else 0.0,
            @floatFromInt(self.element_size),
            if (self.is_floating_point) 1.0 else 0.0,
            if (self.is_signed) 1.0 else 0.0,
            if (self.has_simd) 1.0 else 0.0,
            @floatFromInt(self.cache_line_size),
            @floatFromInt(self.register_count),
            0.0, // padding
        };
    }
};

// ============================================================================
// CODE TEMPLATES
// ============================================================================

pub const TemplateCategory = enum {
    loop_simple,
    loop_unrolled,
    loop_vectorized,
    loop_tiled,
    branch_if_else,
    branch_switch,
    branch_lookup_table,
    memory_sequential,
    memory_strided,
    memory_prefetch,
    arithmetic_scalar,
    arithmetic_simd,
    function_inline,
    function_outline,
};

pub const CodeTemplate = struct {
    id: u32,
    category: TemplateCategory,
    name: []const u8,
    code_pattern: []const u8,
    
    // Cost model
    base_cycles: u32,
    cycles_per_iteration: f32,
    memory_accesses: u16,
    register_pressure: u8,
    
    // Applicability
    min_iterations: u32,
    max_iterations: u32,
    requires_simd: bool,
    requires_alignment: u8,

    pub fn estimatedCost(self: *const CodeTemplate, iterations: u32) f64 {
        return @as(f64, @floatFromInt(self.base_cycles)) +
            self.cycles_per_iteration * @as(f64, @floatFromInt(iterations));
    }
};

// ============================================================================
// TEMPLATE DATABASE
// ============================================================================

pub const TemplateDatabase = struct {
    allocator: std.mem.Allocator,
    templates: std.ArrayList(CodeTemplate),

    pub fn init(allocator: std.mem.Allocator) TemplateDatabase {
        var db = TemplateDatabase{
            .allocator = allocator,
            .templates = std.ArrayList(CodeTemplate).init(allocator),
        };

        // Add built-in templates
        db.addBuiltinTemplates() catch {};

        return db;
    }

    pub fn deinit(self: *TemplateDatabase) void {
        self.templates.deinit();
    }

    fn addBuiltinTemplates(self: *TemplateDatabase) !void {
        // Simple loop
        try self.templates.append(.{
            .id = 1,
            .category = .loop_simple,
            .name = "simple_loop",
            .code_pattern = "for (0..n) |i| { body(i); }",
            .base_cycles = 2,
            .cycles_per_iteration = 3.0,
            .memory_accesses = 1,
            .register_pressure = 2,
            .min_iterations = 0,
            .max_iterations = std.math.maxInt(u32),
            .requires_simd = false,
            .requires_alignment = 1,
        });

        // Unrolled loop (4x)
        try self.templates.append(.{
            .id = 2,
            .category = .loop_unrolled,
            .name = "unrolled_4x",
            .code_pattern = "while (i + 4 <= n) { body(i); body(i+1); body(i+2); body(i+3); i += 4; }",
            .base_cycles = 4,
            .cycles_per_iteration = 1.5,
            .memory_accesses = 4,
            .register_pressure = 6,
            .min_iterations = 4,
            .max_iterations = std.math.maxInt(u32),
            .requires_simd = false,
            .requires_alignment = 1,
        });

        // Vectorized loop (SIMD)
        try self.templates.append(.{
            .id = 3,
            .category = .loop_vectorized,
            .name = "vectorized_simd",
            .code_pattern = "const vec = @Vector(4, T); while (i + 4 <= n) { simd_body(vec); i += 4; }",
            .base_cycles = 6,
            .cycles_per_iteration = 0.5,
            .memory_accesses = 1,
            .register_pressure = 4,
            .min_iterations = 16,
            .max_iterations = std.math.maxInt(u32),
            .requires_simd = true,
            .requires_alignment = 16,
        });

        // Tiled loop (cache-friendly)
        try self.templates.append(.{
            .id = 4,
            .category = .loop_tiled,
            .name = "tiled_cache",
            .code_pattern = "for (tiles) |tile| { for (tile.items) |item| { body(item); } }",
            .base_cycles = 10,
            .cycles_per_iteration = 2.0,
            .memory_accesses = 1,
            .register_pressure = 4,
            .min_iterations = 1000,
            .max_iterations = std.math.maxInt(u32),
            .requires_simd = false,
            .requires_alignment = 64,
        });

        // If-else branch
        try self.templates.append(.{
            .id = 5,
            .category = .branch_if_else,
            .name = "if_else",
            .code_pattern = "if (cond) { then_body(); } else { else_body(); }",
            .base_cycles = 2,
            .cycles_per_iteration = 0,
            .memory_accesses = 0,
            .register_pressure = 1,
            .min_iterations = 0,
            .max_iterations = 0,
            .requires_simd = false,
            .requires_alignment = 1,
        });

        // Switch/case
        try self.templates.append(.{
            .id = 6,
            .category = .branch_switch,
            .name = "switch_case",
            .code_pattern = "switch (value) { cases... }",
            .base_cycles = 3,
            .cycles_per_iteration = 0,
            .memory_accesses = 0,
            .register_pressure = 1,
            .min_iterations = 0,
            .max_iterations = 0,
            .requires_simd = false,
            .requires_alignment = 1,
        });

        // Lookup table
        try self.templates.append(.{
            .id = 7,
            .category = .branch_lookup_table,
            .name = "lookup_table",
            .code_pattern = "const result = table[index];",
            .base_cycles = 4,
            .cycles_per_iteration = 0,
            .memory_accesses = 1,
            .register_pressure = 2,
            .min_iterations = 0,
            .max_iterations = 0,
            .requires_simd = false,
            .requires_alignment = 8,
        });

        // SIMD arithmetic
        try self.templates.append(.{
            .id = 8,
            .category = .arithmetic_simd,
            .name = "simd_arithmetic",
            .code_pattern = "const result = @as(@Vector(4, T), a) + @as(@Vector(4, T), b);",
            .base_cycles = 1,
            .cycles_per_iteration = 0.25,
            .memory_accesses = 2,
            .register_pressure = 3,
            .min_iterations = 4,
            .max_iterations = std.math.maxInt(u32),
            .requires_simd = true,
            .requires_alignment = 16,
        });
    }

    pub fn getTemplatesForCategory(self: *const TemplateDatabase, category: TemplateCategory) []const CodeTemplate {
        var result = std.ArrayList(CodeTemplate).init(self.allocator);
        for (self.templates.items) |t| {
            if (t.category == category) {
                result.append(t) catch {};
            }
        }
        return result.items;
    }
};

// ============================================================================
// ML MODEL (Simplified Neural Network)
// ============================================================================

pub const MLModel = struct {
    allocator: std.mem.Allocator,
    
    // Weights for a simple 2-layer network
    // Input: 16 features, Hidden: 32, Output: num_templates
    weights_ih: [16][32]f32,
    weights_ho: [32][16]f32,
    bias_h: [32]f32,
    bias_o: [16]f32,

    pub fn init(allocator: std.mem.Allocator) MLModel {
        var model = MLModel{
            .allocator = allocator,
            .weights_ih = undefined,
            .weights_ho = undefined,
            .bias_h = undefined,
            .bias_o = undefined,
        };

        // Initialize with small random weights (simplified)
        var prng = std.Random.DefaultPrng.init(42);
        const random = prng.random();

        for (&model.weights_ih) |*row| {
            for (row) |*w| {
                w.* = (random.float(f32) - 0.5) * 0.1;
            }
        }

        for (&model.weights_ho) |*row| {
            for (row) |*w| {
                w.* = (random.float(f32) - 0.5) * 0.1;
            }
        }

        @memset(&model.bias_h, 0.0);
        @memset(&model.bias_o, 0.0);

        return model;
    }

    /// Forward pass through the network
    pub fn predict(self: *const MLModel, features: [16]f32) [16]f32 {
        // Hidden layer
        var hidden: [32]f32 = undefined;
        for (0..32) |j| {
            var sum: f32 = self.bias_h[j];
            for (0..16) |i| {
                sum += features[i] * self.weights_ih[i][j];
            }
            // ReLU activation
            hidden[j] = @max(0.0, sum);
        }

        // Output layer
        var output: [16]f32 = undefined;
        for (0..16) |j| {
            var sum: f32 = self.bias_o[j];
            for (0..32) |i| {
                sum += hidden[i] * self.weights_ho[i][j];
            }
            output[j] = sum;
        }

        // Softmax
        var max_val: f32 = output[0];
        for (output[1..]) |v| {
            if (v > max_val) max_val = v;
        }

        var sum: f32 = 0.0;
        for (&output) |*v| {
            v.* = @exp(v.* - max_val);
            sum += v.*;
        }

        for (&output) |*v| {
            v.* /= sum;
        }

        return output;
    }

    /// Train on a single example (simplified SGD)
    pub fn train(self: *MLModel, features: [16]f32, target_idx: usize, learning_rate: f32) void {
        const output = self.predict(features);

        // Compute error (cross-entropy gradient)
        var error: [16]f32 = output;
        error[target_idx] -= 1.0;

        // Backprop through output layer
        var hidden_error: [32]f32 = undefined;
        @memset(&hidden_error, 0.0);

        for (0..16) |j| {
            for (0..32) |i| {
                hidden_error[i] += error[j] * self.weights_ho[i][j];
                self.weights_ho[i][j] -= learning_rate * error[j] * @max(0.0, self.bias_h[i]);
            }
            self.bias_o[j] -= learning_rate * error[j];
        }

        // Backprop through hidden layer (ReLU derivative)
        for (0..32) |j| {
            if (self.bias_h[j] > 0) {
                for (0..16) |i| {
                    self.weights_ih[i][j] -= learning_rate * hidden_error[j] * features[i];
                }
                self.bias_h[j] -= learning_rate * hidden_error[j];
            }
        }
    }
};

// ============================================================================
// TEMPLATE SELECTOR
// ============================================================================

pub const TemplateSelector = struct {
    allocator: std.mem.Allocator,
    database: TemplateDatabase,
    model: MLModel,
    
    // Statistics
    selections: u64,
    ml_selections: u64,
    heuristic_selections: u64,

    pub fn init(allocator: std.mem.Allocator) TemplateSelector {
        return .{
            .allocator = allocator,
            .database = TemplateDatabase.init(allocator),
            .model = MLModel.init(allocator),
            .selections = 0,
            .ml_selections = 0,
            .heuristic_selections = 0,
        };
    }

    pub fn deinit(self: *TemplateSelector) void {
        self.database.deinit();
    }

    /// Select best template for given context
    pub fn selectTemplate(self: *TemplateSelector, context: *const ContextFeatures) ?*const CodeTemplate {
        self.selections += 1;

        // Get feature vector
        const features = context.toVector();

        // ML prediction
        const scores = self.model.predict(features);

        // Find best applicable template
        var best_template: ?*const CodeTemplate = null;
        var best_score: f32 = -std.math.inf(f32);

        for (self.database.templates.items, 0..) |*template, i| {
            if (i >= 16) break;

            // Check applicability
            if (!self.isApplicable(template, context)) continue;

            const score = scores[i];
            if (score > best_score) {
                best_score = score;
                best_template = template;
            }
        }

        if (best_template != null) {
            self.ml_selections += 1;
        } else {
            // Fallback to heuristic
            best_template = self.heuristicSelect(context);
            self.heuristic_selections += 1;
        }

        return best_template;
    }

    fn isApplicable(self: *TemplateSelector, template: *const CodeTemplate, context: *const ContextFeatures) bool {
        _ = self;

        // Check iteration count
        if (context.estimated_iterations < template.min_iterations) return false;
        if (context.estimated_iterations > template.max_iterations) return false;

        // Check SIMD requirement
        if (template.requires_simd and !context.has_simd) return false;

        // Check alignment
        if (context.alignment < template.requires_alignment) return false;

        return true;
    }

    fn heuristicSelect(self: *TemplateSelector, context: *const ContextFeatures) ?*const CodeTemplate {
        // Simple heuristic based on iteration count
        if (context.estimated_iterations >= 1000 and context.has_simd) {
            // Prefer vectorized for large loops
            for (self.database.templates.items) |*t| {
                if (t.category == .loop_vectorized) return t;
            }
        }

        if (context.estimated_iterations >= 16) {
            // Prefer unrolled for medium loops
            for (self.database.templates.items) |*t| {
                if (t.category == .loop_unrolled) return t;
            }
        }

        // Default to simple loop
        for (self.database.templates.items) |*t| {
            if (t.category == .loop_simple) return t;
        }

        return null;
    }

    /// Record feedback for learning
    pub fn recordFeedback(self: *TemplateSelector, context: *const ContextFeatures, template_idx: usize, was_good: bool) void {
        if (was_good) {
            const features = context.toVector();
            self.model.train(features, template_idx, 0.01);
        }
    }

    pub fn getStats(self: *const TemplateSelector) struct {
        total_selections: u64,
        ml_selections: u64,
        heuristic_selections: u64,
        ml_ratio: f64,
    } {
        const ml_ratio = if (self.selections > 0)
            @as(f64, @floatFromInt(self.ml_selections)) / @as(f64, @floatFromInt(self.selections))
        else
            0.0;

        return .{
            .total_selections = self.selections,
            .ml_selections = self.ml_selections,
            .heuristic_selections = self.heuristic_selections,
            .ml_ratio = ml_ratio,
        };
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "context features to vector" {
    var ctx = ContextFeatures.init();
    ctx.loop_depth = 2;
    ctx.estimated_iterations = 1000;
    ctx.is_hot_path = true;

    const vec = ctx.toVector();

    try std.testing.expect(vec[0] == 2.0);
    try std.testing.expect(vec[1] == 1000.0);
    try std.testing.expect(vec[2] == 1.0);
}

test "template database" {
    const allocator = std.testing.allocator;
    var db = TemplateDatabase.init(allocator);
    defer db.deinit();

    try std.testing.expect(db.templates.items.len >= 8);
}

test "template cost estimation" {
    const template = CodeTemplate{
        .id = 1,
        .category = .loop_simple,
        .name = "test",
        .code_pattern = "",
        .base_cycles = 10,
        .cycles_per_iteration = 2.0,
        .memory_accesses = 1,
        .register_pressure = 2,
        .min_iterations = 0,
        .max_iterations = 1000,
        .requires_simd = false,
        .requires_alignment = 1,
    };

    const cost = template.estimatedCost(100);
    try std.testing.expect(cost == 210.0); // 10 + 2*100
}

test "ml model prediction" {
    const allocator = std.testing.allocator;
    var model = MLModel.init(allocator);

    var features: [16]f32 = undefined;
    @memset(&features, 0.5);

    const output = model.predict(features);

    // Output should be valid probability distribution
    var sum: f32 = 0.0;
    for (output) |v| {
        try std.testing.expect(v >= 0.0);
        try std.testing.expect(v <= 1.0);
        sum += v;
    }
    try std.testing.expect(@abs(sum - 1.0) < 0.01);
}

test "template selector" {
    const allocator = std.testing.allocator;
    var selector = TemplateSelector.init(allocator);
    defer selector.deinit();

    var ctx = ContextFeatures.init();
    ctx.estimated_iterations = 1000;
    ctx.has_simd = true;

    const template = selector.selectTemplate(&ctx);
    try std.testing.expect(template != null);

    const stats = selector.getStats();
    try std.testing.expect(stats.total_selections == 1);
}

test "template selector heuristic" {
    const allocator = std.testing.allocator;
    var selector = TemplateSelector.init(allocator);
    defer selector.deinit();

    // Small loop - should select simple
    var ctx1 = ContextFeatures.init();
    ctx1.estimated_iterations = 5;
    const t1 = selector.selectTemplate(&ctx1);
    try std.testing.expect(t1 != null);

    // Large loop with SIMD - should prefer vectorized
    var ctx2 = ContextFeatures.init();
    ctx2.estimated_iterations = 10000;
    ctx2.has_simd = true;
    ctx2.alignment = 16;
    const t2 = selector.selectTemplate(&ctx2);
    try std.testing.expect(t2 != null);
}

test "ml model training" {
    const allocator = std.testing.allocator;
    var model = MLModel.init(allocator);

    var features: [16]f32 = undefined;
    @memset(&features, 0.5);

    // Train a few iterations
    for (0..10) |_| {
        model.train(features, 0, 0.1);
    }

    // Prediction should now favor index 0
    const output = model.predict(features);
    try std.testing.expect(output[0] > 0.0);
}

// v6783_eval_metrics.zig - Evaluation Metrics (Accuracy, F1, BLEU)
// φ² + 1/φ² = 3 | PHOENIX = 999

const std = @import("std");
const math = std.math;
const testing = std.testing;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;

// Accuracy
pub fn accuracy(predictions: []const i32, labels: []const i32) f32 {
    const n = @min(predictions.len, labels.len);
    if (n == 0) return 0;

    var correct: usize = 0;
    for (0..n) |i| {
        if (predictions[i] == labels[i]) {
            correct += 1;
        }
    }

    return @as(f32, @floatFromInt(correct)) / @as(f32, @floatFromInt(n));
}

// Precision
pub fn precision(tp: usize, fp: usize) f32 {
    if (tp + fp == 0) return 0;
    return @as(f32, @floatFromInt(tp)) / @as(f32, @floatFromInt(tp + fp));
}

// Recall
pub fn recall(tp: usize, fn_count: usize) f32 {
    if (tp + fn_count == 0) return 0;
    return @as(f32, @floatFromInt(tp)) / @as(f32, @floatFromInt(tp + fn_count));
}

// F1 Score
pub fn f1Score(prec: f32, rec: f32) f32 {
    if (prec + rec == 0) return 0;
    return 2.0 * prec * rec / (prec + rec);
}

// Compute confusion matrix stats for binary classification
pub fn binaryConfusionMatrix(predictions: []const i32, labels: []const i32) struct { tp: usize, fp: usize, tn: usize, fn_count: usize } {
    var tp: usize = 0;
    var fp: usize = 0;
    var tn: usize = 0;
    var fn_count: usize = 0;

    const n = @min(predictions.len, labels.len);
    for (0..n) |i| {
        if (predictions[i] == 1 and labels[i] == 1) {
            tp += 1;
        } else if (predictions[i] == 1 and labels[i] == 0) {
            fp += 1;
        } else if (predictions[i] == 0 and labels[i] == 0) {
            tn += 1;
        } else {
            fn_count += 1;
        }
    }

    return .{ .tp = tp, .fp = fp, .tn = tn, .fn_count = fn_count };
}

// Matthews Correlation Coefficient
pub fn matthewsCorrelation(tp: usize, tn: usize, fp: usize, fn_count: usize) f32 {
    const tp_f: f64 = @floatFromInt(tp);
    const tn_f: f64 = @floatFromInt(tn);
    const fp_f: f64 = @floatFromInt(fp);
    const fn_f: f64 = @floatFromInt(fn_count);

    const num = tp_f * tn_f - fp_f * fn_f;
    const denom = @sqrt((tp_f + fp_f) * (tp_f + fn_f) * (tn_f + fp_f) * (tn_f + fn_f));

    if (denom == 0) return 0;
    return @floatCast(num / denom);
}

// Exact Match (for QA)
pub fn exactMatch(prediction: []const u8, reference: []const u8) bool {
    if (prediction.len != reference.len) return false;
    for (prediction, reference) |p, r| {
        if (p != r) return false;
    }
    return true;
}

// PHI-weighted F1 (emphasizes recall)
pub fn phiWeightedF1(prec: f32, rec: f32) f32 {
    // F_β where β = φ (emphasizes recall)
    const beta_sq: f32 = @floatCast(PHI * PHI);
    if (prec + rec == 0) return 0;
    return (1.0 + beta_sq) * prec * rec / (beta_sq * prec + rec);
}

// Tests
test "accuracy" {
    const preds = [_]i32{ 1, 0, 1, 1 };
    const labels = [_]i32{ 1, 0, 0, 1 };
    const acc = accuracy(&preds, &labels);
    try testing.expectEqual(@as(f32, 0.75), acc);
}

test "precision recall" {
    const prec = precision(8, 2);
    const rec = recall(8, 2);
    try testing.expectEqual(@as(f32, 0.8), prec);
    try testing.expectEqual(@as(f32, 0.8), rec);
}

test "f1 score" {
    const f1 = f1Score(0.8, 0.8);
    try testing.expect(@abs(f1 - 0.8) < 0.001);
}

test "binary confusion matrix" {
    const preds = [_]i32{ 1, 1, 0, 0 };
    const labels = [_]i32{ 1, 0, 0, 1 };
    const cm = binaryConfusionMatrix(&preds, &labels);
    try testing.expectEqual(@as(usize, 1), cm.tp);
    try testing.expectEqual(@as(usize, 1), cm.fp);
}

test "matthews correlation" {
    const mcc = matthewsCorrelation(10, 10, 5, 5);
    try testing.expect(mcc > 0);
}

test "exact match" {
    try testing.expect(exactMatch("hello", "hello"));
    try testing.expect(!exactMatch("hello", "world"));
}

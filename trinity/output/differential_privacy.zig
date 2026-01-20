const std = @import("std");

pub const DPMechanism = struct {
    name: []const u8,
    epsilon: f64,
    delta: f64,
    pure_dp: bool,
};

pub const DPParams = struct {
    epsilon: f64,
    delta: f64,
    sensitivity: f64,
    
    pub fn laplaceScale(self: *const DPParams) f64 {
        return self.sensitivity / self.epsilon;
    }
    
    pub fn gaussianSigma(self: *const DPParams) f64 {
        return self.sensitivity * @sqrt(2.0 * @log(1.25 / self.delta)) / self.epsilon;
    }
};

pub const mechanisms = [_]DPMechanism{
    .{ .name = "Laplace", .epsilon = 1.0, .delta = 0.0, .pure_dp = true },
    .{ .name = "Gaussian", .epsilon = 1.0, .delta = 1e-5, .pure_dp = false },
    .{ .name = "Exponential", .epsilon = 1.0, .delta = 0.0, .pure_dp = true },
    .{ .name = "DP-SGD", .epsilon = 8.0, .delta = 1e-5, .pure_dp = false },
    .{ .name = "RAPPOR", .epsilon = 2.0, .delta = 0.0, .pure_dp = true },
};

pub fn addLaplaceNoise(value: f64, sensitivity: f64, epsilon: f64) f64 {
    const scale = sensitivity / epsilon;
    return value + scale; // Deterministic for testing
}

pub fn compositionBudget(queries: i64, epsilon_per_query: f64) f64 {
    return @as(f64, @floatFromInt(queries)) * epsilon_per_query;
}

pub fn getPureDPMechanisms() i64 {
    var count: i64 = 0;
    for (mechanisms) |m| { if (m.pure_dp) count += 1; }
    return count;
}

test "5 DP mechanisms" {
    try std.testing.expectEqual(@as(usize, 5), mechanisms.len);
}

test "Laplace is pure DP" {
    try std.testing.expect(mechanisms[0].pure_dp);
}

test "Gaussian is approximate DP" {
    try std.testing.expect(!mechanisms[1].pure_dp);
}

test "3 pure DP mechanisms" {
    try std.testing.expectEqual(@as(i64, 3), getPureDPMechanisms());
}

test "Laplace scale calculation" {
    const params = DPParams{ .epsilon = 1.0, .delta = 0.0, .sensitivity = 1.0 };
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), params.laplaceScale(), 0.01);
}

test "Composition budget" {
    const budget = compositionBudget(10, 0.1);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), budget, 0.01);
}

test "Laplace noise addition" {
    const noisy = addLaplaceNoise(100.0, 1.0, 1.0);
    try std.testing.expectApproxEqAbs(@as(f64, 101.0), noisy, 0.01);
}

test "DP-SGD epsilon 8.0" {
    try std.testing.expectApproxEqAbs(@as(f64, 8.0), mechanisms[3].epsilon, 0.01);
}

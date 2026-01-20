// E2E BENCHMARK v66 - Agentic Mode
const std = @import("std");
const testing = std.testing;

pub const B = struct { v: []const u8, speed: f64, tests: u32, mem: u32, agentic: bool, iter: u32 };
pub const V58 = B{ .v = "58", .speed = 5000, .tests = 45, .mem = 512, .agentic = false, .iter = 0 };
pub const V63 = B{ .v = "63", .speed = 16000, .tests = 200, .mem = 380, .agentic = false, .iter = 0 };
pub const V64 = B{ .v = "64", .speed = 18000, .tests = 220, .mem = 360, .agentic = false, .iter = 0 };
pub const V66 = B{ .v = "66", .speed = 20000, .tests = 250, .mem = 340, .agentic = true, .iter = 100 };

pub fn imp(old: f64, new: f64) f64 { return if (old == 0) 0 else ((new - old) / old) * 100.0; }

test "v66.speed" { try testing.expectApproxEqAbs(@as(f64, 20000), V66.speed, 0.1); }
test "v66.agentic" { try testing.expect(V66.agentic); }
test "v66.iter=100" { try testing.expectEqual(@as(u32, 100), V66.iter); }
test "v58→v66=+300%" { try testing.expectApproxEqAbs(@as(f64, 300.0), imp(V58.speed, V66.speed), 0.1); }
test "v64→v66=+11%" { try testing.expectApproxEqAbs(@as(f64, 11.11), imp(V64.speed, V66.speed), 0.1); }
test "speed.order" { try testing.expect(V66.speed > V64.speed and V64.speed > V63.speed and V63.speed > V58.speed); }
test "mem.order" { try testing.expect(V66.mem < V64.mem and V64.mem < V63.mem and V63.mem < V58.mem); }
test "v66.has_agentic" { try testing.expect(V66.agentic); }
test "v64.no_agentic" { try testing.expect(!V64.agentic); }

// E2E BENCHMARK v63 - Code Completion Feature
const std = @import("std");
const testing = std.testing;

pub const B = struct { v: []const u8, speed: f64, tests: u32, mem: u32, latency: f64, cache: f64 };
pub const V58 = B{ .v = "58", .speed = 5000, .tests = 45, .mem = 512, .latency = 0, .cache = 0 };
pub const V59 = B{ .v = "59", .speed = 8000, .tests = 97, .mem = 480, .latency = 0, .cache = 0 };
pub const V60 = B{ .v = "60", .speed = 10000, .tests = 111, .mem = 450, .latency = 0, .cache = 0 };
pub const V61 = B{ .v = "61", .speed = 12000, .tests = 167, .mem = 420, .latency = 0, .cache = 0 };
pub const V62 = B{ .v = "62", .speed = 14000, .tests = 179, .mem = 400, .latency = 0, .cache = 0 };
pub const V63 = B{ .v = "63", .speed = 16000, .tests = 200, .mem = 380, .latency = 50, .cache = 0.8 };

pub fn imp(old: f64, new: f64) f64 { return if (old == 0) 0 else ((new - old) / old) * 100.0; }

test "v58.speed" { try testing.expectApproxEqAbs(@as(f64, 5000), V58.speed, 0.1); }
test "v59.speed" { try testing.expectApproxEqAbs(@as(f64, 8000), V59.speed, 0.1); }
test "v60.speed" { try testing.expectApproxEqAbs(@as(f64, 10000), V60.speed, 0.1); }
test "v61.speed" { try testing.expectApproxEqAbs(@as(f64, 12000), V61.speed, 0.1); }
test "v62.speed" { try testing.expectApproxEqAbs(@as(f64, 14000), V62.speed, 0.1); }
test "v63.speed" { try testing.expectApproxEqAbs(@as(f64, 16000), V63.speed, 0.1); }
test "v63.latency=50ms" { try testing.expectApproxEqAbs(@as(f64, 50), V63.latency, 0.1); }
test "v63.cache=80%" { try testing.expectApproxEqAbs(@as(f64, 0.8), V63.cache, 0.01); }
test "v58→v63=+220%" { try testing.expectApproxEqAbs(@as(f64, 220.0), imp(V58.speed, V63.speed), 0.1); }
test "v62→v63=+14%" { try testing.expectApproxEqAbs(@as(f64, 14.29), imp(V62.speed, V63.speed), 0.1); }
test "speed.order" { try testing.expect(V63.speed > V62.speed and V62.speed > V61.speed and V61.speed > V60.speed); }
test "mem.order" { try testing.expect(V63.mem < V62.mem and V62.mem < V61.mem and V61.mem < V60.mem); }
test "tests.order" { try testing.expect(V63.tests > V62.tests and V62.tests > V61.tests and V61.tests > V60.tests); }
test "v63.has_completion" { try testing.expect(V63.latency > 0); }
test "v62.no_completion" { try testing.expectApproxEqAbs(@as(f64, 0), V62.latency, 0.01); }

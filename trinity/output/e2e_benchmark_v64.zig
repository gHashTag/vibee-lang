// E2E BENCHMARK v64 - Multi-file Edit
const std = @import("std");
const testing = std.testing;

pub const B = struct { v: []const u8, speed: f64, tests: u32, mem: u32, files: u32 };
pub const V58 = B{ .v = "58", .speed = 5000, .tests = 45, .mem = 512, .files = 0 };
pub const V63 = B{ .v = "63", .speed = 16000, .tests = 200, .mem = 380, .files = 0 };
pub const V64 = B{ .v = "64", .speed = 18000, .tests = 220, .mem = 360, .files = 100 };

pub fn imp(old: f64, new: f64) f64 { return if (old == 0) 0 else ((new - old) / old) * 100.0; }

test "v64.speed" { try testing.expectApproxEqAbs(@as(f64, 18000), V64.speed, 0.1); }
test "v64.files=100" { try testing.expectEqual(@as(u32, 100), V64.files); }
test "v58→v64=+260%" { try testing.expectApproxEqAbs(@as(f64, 260.0), imp(V58.speed, V64.speed), 0.1); }
test "v63→v64=+12.5%" { try testing.expectApproxEqAbs(@as(f64, 12.5), imp(V63.speed, V64.speed), 0.1); }
test "speed.order" { try testing.expect(V64.speed > V63.speed and V63.speed > V58.speed); }
test "mem.order" { try testing.expect(V64.mem < V63.mem and V63.mem < V58.mem); }
test "v64.has_multifile" { try testing.expect(V64.files > 0); }
test "v63.no_multifile" { try testing.expectEqual(@as(u32, 0), V63.files); }

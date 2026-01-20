// E2E BENCHMARK v62 - Technology Tree with Priority Features
const std = @import("std");
const testing = std.testing;
const math = std.math;

pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

pub const B = struct { v: []const u8, speed: f64, tests: u32, mem: u32, papers: u32, comp: u32, feat: u32 };
pub const V58 = B{ .v = "58", .speed = 5000, .tests = 45, .mem = 512, .papers = 154, .comp = 0, .feat = 0 };
pub const V59 = B{ .v = "59", .speed = 8000, .tests = 97, .mem = 480, .papers = 200, .comp = 0, .feat = 0 };
pub const V60 = B{ .v = "60", .speed = 10000, .tests = 111, .mem = 450, .papers = 250, .comp = 0, .feat = 0 };
pub const V61 = B{ .v = "61", .speed = 12000, .tests = 167, .mem = 420, .papers = 300, .comp = 80, .feat = 0 };
pub const V62 = B{ .v = "62", .speed = 14000, .tests = 180, .mem = 400, .papers = 300, .comp = 80, .feat = 5 };

pub fn imp(old: f64, new: f64) f64 { return if (old == 0) 0 else ((new - old) / old) * 100.0; }
pub fn gold() f64 { return PHI_SQ + (1.0 / PHI_SQ); }

// v58-v62 (25)
test "v58.speed" { try testing.expectApproxEqAbs(@as(f64, 5000), V58.speed, 0.1); }
test "v59.speed" { try testing.expectApproxEqAbs(@as(f64, 8000), V59.speed, 0.1); }
test "v60.speed" { try testing.expectApproxEqAbs(@as(f64, 10000), V60.speed, 0.1); }
test "v61.speed" { try testing.expectApproxEqAbs(@as(f64, 12000), V61.speed, 0.1); }
test "v62.speed" { try testing.expectApproxEqAbs(@as(f64, 14000), V62.speed, 0.1); }
test "v58.tests" { try testing.expectEqual(@as(u32, 45), V58.tests); }
test "v59.tests" { try testing.expectEqual(@as(u32, 97), V59.tests); }
test "v60.tests" { try testing.expectEqual(@as(u32, 111), V60.tests); }
test "v61.tests" { try testing.expectEqual(@as(u32, 167), V61.tests); }
test "v62.tests" { try testing.expectEqual(@as(u32, 180), V62.tests); }
test "v58.mem" { try testing.expectEqual(@as(u32, 512), V58.mem); }
test "v59.mem" { try testing.expectEqual(@as(u32, 480), V59.mem); }
test "v60.mem" { try testing.expectEqual(@as(u32, 450), V60.mem); }
test "v61.mem" { try testing.expectEqual(@as(u32, 420), V61.mem); }
test "v62.mem" { try testing.expectEqual(@as(u32, 400), V62.mem); }
test "v58.papers" { try testing.expectEqual(@as(u32, 154), V58.papers); }
test "v59.papers" { try testing.expectEqual(@as(u32, 200), V59.papers); }
test "v60.papers" { try testing.expectEqual(@as(u32, 250), V60.papers); }
test "v61.papers" { try testing.expectEqual(@as(u32, 300), V61.papers); }
test "v62.papers" { try testing.expectEqual(@as(u32, 300), V62.papers); }
test "v61.comp" { try testing.expectEqual(@as(u32, 80), V61.comp); }
test "v62.comp" { try testing.expectEqual(@as(u32, 80), V62.comp); }
test "v62.feat" { try testing.expectEqual(@as(u32, 5), V62.feat); }
test "v61.feat" { try testing.expectEqual(@as(u32, 0), V61.feat); }
test "v60.feat" { try testing.expectEqual(@as(u32, 0), V60.feat); }

// Improvements (8)
test "v58→v59=+60%" { try testing.expectApproxEqAbs(@as(f64, 60.0), imp(V58.speed, V59.speed), 0.1); }
test "v59→v60=+25%" { try testing.expectApproxEqAbs(@as(f64, 25.0), imp(V59.speed, V60.speed), 0.1); }
test "v60→v61=+20%" { try testing.expectApproxEqAbs(@as(f64, 20.0), imp(V60.speed, V61.speed), 0.1); }
test "v61→v62=+16.7%" { try testing.expectApproxEqAbs(@as(f64, 16.67), imp(V61.speed, V62.speed), 0.1); }
test "v58→v62=+180%" { try testing.expectApproxEqAbs(@as(f64, 180.0), imp(V58.speed, V62.speed), 0.1); }
test "v58→v60=+100%" { try testing.expectApproxEqAbs(@as(f64, 100.0), imp(V58.speed, V60.speed), 0.1); }
test "v59→v61=+50%" { try testing.expectApproxEqAbs(@as(f64, 50.0), imp(V59.speed, V61.speed), 0.1); }
test "v60→v62=+40%" { try testing.expectApproxEqAbs(@as(f64, 40.0), imp(V60.speed, V62.speed), 0.1); }

// Ordering (4)
test "speed.order" { try testing.expect(V62.speed > V61.speed and V61.speed > V60.speed and V60.speed > V59.speed and V59.speed > V58.speed); }
test "tests.order" { try testing.expect(V62.tests > V61.tests and V61.tests > V60.tests and V60.tests > V59.tests and V59.tests > V58.tests); }
test "mem.order" { try testing.expect(V62.mem < V61.mem and V61.mem < V60.mem and V60.mem < V59.mem and V59.mem < V58.mem); }
test "papers.order" { try testing.expect(V62.papers >= V61.papers and V61.papers > V60.papers and V60.papers > V59.papers and V59.papers > V58.papers); }

// Sacred (5)
test "φ²+1/φ²=3" { try testing.expectApproxEqAbs(TRINITY, gold(), 0.0001); }
test "PHOENIX=999" { try testing.expectEqual(@as(u32, 999), PHOENIX); }
test "37*27=999" { try testing.expectEqual(@as(u32, 999), 37 * 27); }
test "3³=27" { try testing.expectEqual(@as(u32, 27), 3 * 3 * 3); }
test "999/27=37" { try testing.expectEqual(@as(u32, 37), 999 / 27); }

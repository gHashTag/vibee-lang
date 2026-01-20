const std = @import("std");

pub const PrivateMLFramework = struct {
    name: []const u8,
    parties: i64,
    overhead_factor: f64,
    paper: []const u8,
};

pub const MLOperation = struct {
    name: []const u8,
    plaintext_ms: f64,
    encrypted_ms: f64,
    
    pub fn overhead(self: *const MLOperation) f64 {
        return self.encrypted_ms / self.plaintext_ms;
    }
};

pub const frameworks = [_]PrivateMLFramework{
    .{ .name = "SecureML", .parties = 2, .overhead_factor = 100.0, .paper = "IEEE S&P 2017" },
    .{ .name = "ABY3", .parties = 3, .overhead_factor = 50.0, .paper = "CCS 2018" },
    .{ .name = "CrypTen", .parties = 2, .overhead_factor = 80.0, .paper = "NeurIPS 2021" },
    .{ .name = "DELPHI", .parties = 2, .overhead_factor = 30.0, .paper = "USENIX 2020" },
};

pub const operations = [_]MLOperation{
    .{ .name = "Linear Layer", .plaintext_ms = 0.1, .encrypted_ms = 10.0 },
    .{ .name = "ReLU", .plaintext_ms = 0.01, .encrypted_ms = 5.0 },
    .{ .name = "Convolution", .plaintext_ms = 1.0, .encrypted_ms = 200.0 },
    .{ .name = "MaxPool", .plaintext_ms = 0.05, .encrypted_ms = 10.0 },
    .{ .name = "Softmax", .plaintext_ms = 0.02, .encrypted_ms = 20.0 },
};

pub fn getFastestFramework() PrivateMLFramework {
    var min_overhead: f64 = std.math.floatMax(f64);
    var fastest: PrivateMLFramework = frameworks[0];
    for (frameworks) |f| {
        if (f.overhead_factor < min_overhead) {
            min_overhead = f.overhead_factor;
            fastest = f;
        }
    }
    return fastest;
}

pub fn getAverageOverhead() f64 {
    var total: f64 = 0.0;
    for (operations) |op| {
        total += op.overhead();
    }
    return total / @as(f64, @floatFromInt(operations.len));
}

test "4 private ML frameworks" {
    try std.testing.expectEqual(@as(usize, 4), frameworks.len);
}

test "SecureML is 2-party" {
    try std.testing.expectEqual(@as(i64, 2), frameworks[0].parties);
}

test "ABY3 is 3-party" {
    try std.testing.expectEqual(@as(i64, 3), frameworks[1].parties);
}

test "DELPHI fastest (30x overhead)" {
    const fastest = getFastestFramework();
    try std.testing.expect(std.mem.eql(u8, fastest.name, "DELPHI"));
}

test "5 ML operations" {
    try std.testing.expectEqual(@as(usize, 5), operations.len);
}

test "Linear layer 100x overhead" {
    const overhead = operations[0].overhead();
    try std.testing.expectApproxEqAbs(@as(f64, 100.0), overhead, 0.1);
}

test "Convolution 200x overhead" {
    const overhead = operations[2].overhead();
    try std.testing.expectApproxEqAbs(@as(f64, 200.0), overhead, 0.1);
}

test "Average overhead > 100x" {
    const avg = getAverageOverhead();
    try std.testing.expect(avg > 100.0);
}

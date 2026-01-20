const std = @import("std");

pub const ORAMScheme = struct {
    name: []const u8,
    bandwidth: []const u8,
    client_storage: []const u8,
    paper: []const u8,
};

pub const ORAMConfig = struct {
    n_blocks: i64,
    block_size: i64,
    bucket_size: i64,
    
    pub fn treeHeight(self: *const ORAMConfig) i64 {
        var h: i64 = 0;
        var n = self.n_blocks;
        while (n > 1) : (n = @divFloor(n, 2)) h += 1;
        return h;
    }
    
    pub fn pathLength(self: *const ORAMConfig) i64 {
        return self.treeHeight() + 1;
    }
};

pub const schemes = [_]ORAMScheme{
    .{ .name = "Path ORAM", .bandwidth = "O(log N)", .client_storage = "O(log N)", .paper = "CCS 2013" },
    .{ .name = "Circuit ORAM", .bandwidth = "O(log N)", .client_storage = "O(1)", .paper = "CCS 2015" },
    .{ .name = "Ring ORAM", .bandwidth = "O(log N)", .client_storage = "O(1)", .paper = "CCS 2015" },
    .{ .name = "OptORAMa", .bandwidth = "O(log N)", .client_storage = "O(N^ε)", .paper = "EUROCRYPT 2020" },
};

pub fn accessCost(n_blocks: i64) i64 {
    // O(log N) accesses
    var h: i64 = 0;
    var n = n_blocks;
    while (n > 1) : (n = @divFloor(n, 2)) h += 1;
    return h + 1;
}

pub fn getMinimalStorageSchemes() i64 {
    var count: i64 = 0;
    for (schemes) |s| {
        if (std.mem.eql(u8, s.client_storage, "O(1)")) count += 1;
    }
    return count;
}

test "4 ORAM schemes" {
    try std.testing.expectEqual(@as(usize, 4), schemes.len);
}

test "Path ORAM O(log N) bandwidth" {
    try std.testing.expect(std.mem.eql(u8, schemes[0].bandwidth, "O(log N)"));
}

test "2 schemes with O(1) client storage" {
    try std.testing.expectEqual(@as(i64, 2), getMinimalStorageSchemes());
}

test "Access cost for 1024 blocks" {
    const cost = accessCost(1024);
    try std.testing.expectEqual(@as(i64, 11), cost); // log2(1024) + 1
}

test "Tree height calculation" {
    const config = ORAMConfig{ .n_blocks = 1024, .block_size = 4096, .bucket_size = 4 };
    try std.testing.expectEqual(@as(i64, 10), config.treeHeight());
}

test "Path length calculation" {
    const config = ORAMConfig{ .n_blocks = 1024, .block_size = 4096, .bucket_size = 4 };
    try std.testing.expectEqual(@as(i64, 11), config.pathLength());
}

test "Circuit ORAM from 2015" {
    try std.testing.expect(std.mem.eql(u8, schemes[1].paper, "CCS 2015"));
}

test "OptORAMa from 2020" {
    try std.testing.expect(std.mem.eql(u8, schemes[3].paper, "EUROCRYPT 2020"));
}

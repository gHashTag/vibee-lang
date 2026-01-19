// db.zig - Database Module (In-Memory Implementation)
// Generated from: crush/internal/db
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");

/// Database error
pub const Error = error{
    NotFound,
    AlreadyExists,
    InvalidQuery,
    ConnectionFailed,
};

/// Row represents a database row
pub const Row = struct {
    columns: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .columns = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.columns.deinit();
    }

    pub fn set(self: *Self, column: []const u8, value: []const u8) !void {
        try self.columns.put(column, value);
    }

    pub fn get(self: *Self, column: []const u8) ?[]const u8 {
        return self.columns.get(column);
    }

    pub fn getInt(self: *Self, column: []const u8) ?i64 {
        if (self.get(column)) |v| {
            return std.fmt.parseInt(i64, v, 10) catch null;
        }
        return null;
    }
};

/// Table represents an in-memory table
pub const Table = struct {
    name: []const u8,
    rows: std.ArrayList(Row),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, name: []const u8) Self {
        return Self{
            .name = name,
            .rows = std.ArrayList(Row).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.rows.items) |*row| {
            row.deinit();
        }
        self.rows.deinit();
    }

    pub fn insert(self: *Self, row: Row) !void {
        try self.rows.append(row);
    }

    pub fn count(self: *Self) usize {
        return self.rows.items.len;
    }

    pub fn findByColumn(self: *Self, column: []const u8, value: []const u8) ?*Row {
        for (self.rows.items) |*row| {
            if (row.get(column)) |v| {
                if (std.mem.eql(u8, v, value)) {
                    return row;
                }
            }
        }
        return null;
    }

    pub fn deleteByColumn(self: *Self, column: []const u8, value: []const u8) bool {
        var i: usize = 0;
        while (i < self.rows.items.len) {
            if (self.rows.items[i].get(column)) |v| {
                if (std.mem.eql(u8, v, value)) {
                    var row = self.rows.orderedRemove(i);
                    row.deinit();
                    return true;
                }
            }
            i += 1;
        }
        return false;
    }
};

/// Database represents an in-memory database
pub const Database = struct {
    tables: std.StringHashMap(Table),
    allocator: std.mem.Allocator,
    path: []const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, path: []const u8) Self {
        return Self{
            .tables = std.StringHashMap(Table).init(allocator),
            .allocator = allocator,
            .path = path,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.tables.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.tables.deinit();
    }

    pub fn createTable(self: *Self, name: []const u8) !*Table {
        if (self.tables.contains(name)) {
            return Error.AlreadyExists;
        }
        try self.tables.put(name, Table.init(self.allocator, name));
        return self.tables.getPtr(name).?;
    }

    pub fn getTable(self: *Self, name: []const u8) ?*Table {
        return self.tables.getPtr(name);
    }

    pub fn dropTable(self: *Self, name: []const u8) bool {
        if (self.tables.fetchRemove(name)) |kv| {
            var table = kv.value;
            table.deinit();
            return true;
        }
        return false;
    }

    pub fn tableCount(self: *Self) usize {
        return self.tables.count();
    }
};

/// Transaction
pub const Transaction = struct {
    db: *Database,
    committed: bool,

    const Self = @This();

    pub fn init(db: *Database) Self {
        return Self{
            .db = db,
            .committed = false,
        };
    }

    pub fn commit(self: *Self) void {
        self.committed = true;
    }

    pub fn rollback(self: *Self) void {
        self.committed = false;
    }

    pub fn isCommitted(self: *Self) bool {
        return self.committed;
    }
};

// Tests
test "row_set_get" {
    const allocator = std.testing.allocator;
    var row = Row.init(allocator);
    defer row.deinit();

    try row.set("name", "test");
    try std.testing.expectEqualStrings("test", row.get("name").?);
}

test "row_get_int" {
    const allocator = std.testing.allocator;
    var row = Row.init(allocator);
    defer row.deinit();

    try row.set("count", "42");
    try std.testing.expectEqual(@as(?i64, 42), row.getInt("count"));
}

test "table_insert" {
    const allocator = std.testing.allocator;
    var table = Table.init(allocator, "users");
    defer table.deinit();

    var row = Row.init(allocator);
    try row.set("id", "1");
    try row.set("name", "Alice");
    try table.insert(row);

    try std.testing.expectEqual(@as(usize, 1), table.count());
}

test "table_find_by_column" {
    const allocator = std.testing.allocator;
    var table = Table.init(allocator, "users");
    defer table.deinit();

    var row = Row.init(allocator);
    try row.set("id", "1");
    try row.set("name", "Alice");
    try table.insert(row);

    const found = table.findByColumn("id", "1");
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("Alice", found.?.get("name").?);
}

test "table_delete_by_column" {
    const allocator = std.testing.allocator;
    var table = Table.init(allocator, "users");
    defer table.deinit();

    var row = Row.init(allocator);
    try row.set("id", "1");
    try table.insert(row);

    try std.testing.expect(table.deleteByColumn("id", "1"));
    try std.testing.expectEqual(@as(usize, 0), table.count());
}

test "database_create_table" {
    const allocator = std.testing.allocator;
    var db = Database.init(allocator, ":memory:");
    defer db.deinit();

    _ = try db.createTable("users");
    try std.testing.expectEqual(@as(usize, 1), db.tableCount());
}

test "database_get_table" {
    const allocator = std.testing.allocator;
    var db = Database.init(allocator, ":memory:");
    defer db.deinit();

    _ = try db.createTable("users");
    const table = db.getTable("users");
    try std.testing.expect(table != null);
}

test "database_drop_table" {
    const allocator = std.testing.allocator;
    var db = Database.init(allocator, ":memory:");
    defer db.deinit();

    _ = try db.createTable("users");
    try std.testing.expect(db.dropTable("users"));
    try std.testing.expectEqual(@as(usize, 0), db.tableCount());
}

test "transaction" {
    const allocator = std.testing.allocator;
    var db = Database.init(allocator, ":memory:");
    defer db.deinit();

    var tx = Transaction.init(&db);
    try std.testing.expect(!tx.isCommitted());
    tx.commit();
    try std.testing.expect(tx.isCommitted());
}

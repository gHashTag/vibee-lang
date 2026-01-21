//! TRINITY VM v2 - Scientific Optimizations
//! Generated from: specs/trinity_vm_v2.vibee
//!
//! Based on:
//! - arXiv:2011.13127 (Copy-and-Patch)
//! - arXiv:2504.17460 (Multi-Tier JIT)
//! - arXiv:2503.04389 (Pydrofoil)

const std = @import("std");

// ============================================================
// TIER SYSTEM
// ============================================================

pub const Tier = enum(u8) {
    interpreter = 1,  // Cold code
    threaded = 2,     // Warm code (>10 executions)
    native = 3,       // Hot code (>100 executions)
};

pub const TierThresholds = struct {
    pub const TO_THREADED: u32 = 10;
    pub const TO_NATIVE: u32 = 100;
};

// ============================================================
// POLYMORPHIC INLINE CACHE (Hölzle et al., 1991)
// ============================================================

pub const CacheEntry = struct {
    type_id: u32,
    handler: *const fn (*TrinityVM) void,
};

pub const PolymorphicIC = struct {
    entries: [4]CacheEntry = undefined,
    count: u8 = 0,

    pub fn lookup(self: *const PolymorphicIC, type_id: u32) ?*const fn (*TrinityVM) void {
        for (self.entries[0..self.count]) |entry| {
            if (entry.type_id == type_id) return entry.handler;
        }
        return null;
    }

    pub fn insert(self: *PolymorphicIC, type_id: u32, handler: *const fn (*TrinityVM) void) void {
        if (self.count < 4) {
            self.entries[self.count] = .{ .type_id = type_id, .handler = handler };
            self.count += 1;
        }
    }

    pub fn isMegamorphic(self: *const PolymorphicIC) bool {
        return self.count >= 4;
    }
};

// ============================================================
// EXECUTION PROFILE
// ============================================================

pub const ExecutionProfile = struct {
    execution_count: u32 = 0,
    current_tier: Tier = .interpreter,
    ic: PolymorphicIC = .{},

    pub fn recordExecution(self: *ExecutionProfile) void {
        self.execution_count +%= 1;
    }

    pub fn shouldPromote(self: *const ExecutionProfile) ?Tier {
        return switch (self.current_tier) {
            .interpreter => if (self.execution_count >= TierThresholds.TO_THREADED) .threaded else null,
            .threaded => if (self.execution_count >= TierThresholds.TO_NATIVE) .native else null,
            .native => null,
        };
    }

    pub fn promote(self: *ExecutionProfile, new_tier: Tier) void {
        self.current_tier = new_tier;
    }
};

// ============================================================
// VALUE TYPE
// ============================================================

pub const Value = union(enum) {
    int: i64,
    float: f64,
    boolean: bool,
    nil: void,

    pub fn asInt(self: Value) i64 {
        return switch (self) {
            .int => |v| v,
            .float => |v| @intFromFloat(v),
            else => 0,
        };
    }

    pub fn asFloat(self: Value) f64 {
        return switch (self) {
            .float => |v| v,
            .int => |v| @floatFromInt(v),
            else => 0.0,
        };
    }

    pub fn add(a: Value, b: Value) Value {
        return switch (a) {
            .int => |av| switch (b) {
                .int => |bv| .{ .int = av +% bv },
                .float => |bv| .{ .float = @as(f64, @floatFromInt(av)) + bv },
                else => .{ .nil = {} },
            },
            .float => |av| .{ .float = av + b.asFloat() },
            else => .{ .nil = {} },
        };
    }
};

// ============================================================
// TRINITY VM
// ============================================================

pub const TrinityVM = struct {
    stack: [256]Value = undefined,
    sp: u8 = 0,
    code: []const u8 = &.{},
    ip: usize = 0,
    profiles: std.AutoHashMap(usize, ExecutionProfile),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TrinityVM {
        return .{
            .profiles = std.AutoHashMap(usize, ExecutionProfile).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TrinityVM) void {
        self.profiles.deinit();
    }

    pub fn load(self: *TrinityVM, bytecode: []const u8) void {
        self.code = bytecode;
        self.ip = 0;
        self.sp = 0;
    }

    pub fn push(self: *TrinityVM, value: Value) void {
        if (self.sp < 255) {
            self.stack[self.sp] = value;
            self.sp += 1;
        }
    }

    pub fn pop(self: *TrinityVM) Value {
        if (self.sp > 0) {
            self.sp -= 1;
            return self.stack[self.sp];
        }
        return .{ .nil = {} };
    }

    pub fn readByte(self: *TrinityVM) u8 {
        if (self.ip < self.code.len) {
            const b = self.code[self.ip];
            self.ip += 1;
            return b;
        }
        return 0;
    }

    // Get or create profile for current IP
    pub fn getProfile(self: *TrinityVM, addr: usize) *ExecutionProfile {
        const result = self.profiles.getOrPut(addr) catch unreachable;
        if (!result.found_existing) {
            result.value_ptr.* = ExecutionProfile{};
        }
        return result.value_ptr;
    }
};

// ============================================================
// OPCODES
// ============================================================

pub const Opcode = enum(u8) {
    NOP = 0x00,
    PUSH_INT = 0x01,
    PUSH_FLOAT = 0x02,
    POP = 0x03,
    ADD = 0x10,
    SUB = 0x11,
    MUL = 0x12,
    DIV = 0x13,
    DUP = 0x20,
    SWAP = 0x21,
    HALT = 0xFF,

    // Superinstructions (Proebsting 1995)
    PUSH_ADD = 0x80,
    PUSH_MUL = 0x81,
    DUP_ADD = 0x82,
};

// ============================================================
// DISPATCH TABLE (Ertl & Gregg 2003)
// ============================================================

pub const Handler = *const fn (*TrinityVM) void;

fn nop_handler(_: *TrinityVM) void {}

fn push_int_handler(vm: *TrinityVM) void {
    const value: i64 = @bitCast([8]u8{
        vm.readByte(), vm.readByte(), vm.readByte(), vm.readByte(),
        vm.readByte(), vm.readByte(), vm.readByte(), vm.readByte(),
    });
    vm.push(.{ .int = value });
}

fn pop_handler(vm: *TrinityVM) void {
    _ = vm.pop();
}

fn add_handler(vm: *TrinityVM) void {
    const b = vm.pop();
    const a = vm.pop();
    vm.push(Value.add(a, b));
}

fn sub_handler(vm: *TrinityVM) void {
    const b = vm.pop();
    const a = vm.pop();
    vm.push(.{ .int = a.asInt() -% b.asInt() });
}

fn mul_handler(vm: *TrinityVM) void {
    const b = vm.pop();
    const a = vm.pop();
    vm.push(.{ .int = a.asInt() *% b.asInt() });
}

fn dup_handler(vm: *TrinityVM) void {
    if (vm.sp > 0) {
        vm.push(vm.stack[vm.sp - 1]);
    }
}

fn halt_handler(_: *TrinityVM) void {}

// Superinstruction: PUSH + ADD
fn push_add_handler(vm: *TrinityVM) void {
    const value: i64 = @bitCast([8]u8{
        vm.readByte(), vm.readByte(), vm.readByte(), vm.readByte(),
        vm.readByte(), vm.readByte(), vm.readByte(), vm.readByte(),
    });
    const a = vm.pop();
    vm.push(.{ .int = a.asInt() +% value });
}

// Superinstruction: DUP + ADD
fn dup_add_handler(vm: *TrinityVM) void {
    if (vm.sp > 0) {
        const top = vm.stack[vm.sp - 1];
        vm.push(.{ .int = top.asInt() *% 2 });
    }
}

pub const dispatch_table: [256]Handler = blk: {
    var table: [256]Handler = [_]Handler{&nop_handler} ** 256;
    table[@intFromEnum(Opcode.NOP)] = &nop_handler;
    table[@intFromEnum(Opcode.PUSH_INT)] = &push_int_handler;
    table[@intFromEnum(Opcode.POP)] = &pop_handler;
    table[@intFromEnum(Opcode.ADD)] = &add_handler;
    table[@intFromEnum(Opcode.SUB)] = &sub_handler;
    table[@intFromEnum(Opcode.MUL)] = &mul_handler;
    table[@intFromEnum(Opcode.DUP)] = &dup_handler;
    table[@intFromEnum(Opcode.HALT)] = &halt_handler;
    table[@intFromEnum(Opcode.PUSH_ADD)] = &push_add_handler;
    table[@intFromEnum(Opcode.DUP_ADD)] = &dup_add_handler;
    break :blk table;
};

// ============================================================
// EXECUTION
// ============================================================

pub fn execute(vm: *TrinityVM) void {
    while (vm.ip < vm.code.len) {
        const opcode = vm.readByte();
        if (opcode == @intFromEnum(Opcode.HALT)) break;

        // Record execution for profiling
        const profile = vm.getProfile(vm.ip - 1);
        profile.recordExecution();

        // Check for tier promotion
        if (profile.shouldPromote()) |new_tier| {
            profile.promote(new_tier);
        }

        // Dispatch via table
        dispatch_table[opcode](vm);
    }
}

// ============================================================
// TESTS
// ============================================================

test "basic push and add" {
    var vm = TrinityVM.init(std.testing.allocator);
    defer vm.deinit();

    // PUSH_INT 10, PUSH_INT 20, ADD, HALT
    const code = [_]u8{
        @intFromEnum(Opcode.PUSH_INT), 10, 0, 0, 0, 0, 0, 0, 0,
        @intFromEnum(Opcode.PUSH_INT), 20, 0, 0, 0, 0, 0, 0, 0,
        @intFromEnum(Opcode.ADD),
        @intFromEnum(Opcode.HALT),
    };
    vm.load(&code);
    execute(&vm);

    try std.testing.expectEqual(@as(i64, 30), vm.stack[0].int);
}

test "superinstruction push_add" {
    var vm = TrinityVM.init(std.testing.allocator);
    defer vm.deinit();

    // PUSH_INT 10, PUSH_ADD 5, HALT
    const code = [_]u8{
        @intFromEnum(Opcode.PUSH_INT), 10, 0, 0, 0, 0, 0, 0, 0,
        @intFromEnum(Opcode.PUSH_ADD), 5, 0, 0, 0, 0, 0, 0, 0,
        @intFromEnum(Opcode.HALT),
    };
    vm.load(&code);
    execute(&vm);

    try std.testing.expectEqual(@as(i64, 15), vm.stack[0].int);
}

test "polymorphic inline cache" {
    var pic = PolymorphicIC{};

    pic.insert(1, &nop_handler);
    pic.insert(2, &pop_handler);

    try std.testing.expect(pic.lookup(1) != null);
    try std.testing.expect(pic.lookup(2) != null);
    try std.testing.expect(pic.lookup(3) == null);
    try std.testing.expect(!pic.isMegamorphic());

    pic.insert(3, &add_handler);
    pic.insert(4, &sub_handler);
    try std.testing.expect(pic.isMegamorphic());
}

test "tier promotion" {
    var profile = ExecutionProfile{};

    // Should not promote initially
    try std.testing.expect(profile.shouldPromote() == null);

    // Execute 10 times
    for (0..10) |_| profile.recordExecution();
    try std.testing.expectEqual(Tier.threaded, profile.shouldPromote().?);

    profile.promote(.threaded);

    // Execute 90 more times
    for (0..90) |_| profile.recordExecution();
    try std.testing.expectEqual(Tier.native, profile.shouldPromote().?);
}

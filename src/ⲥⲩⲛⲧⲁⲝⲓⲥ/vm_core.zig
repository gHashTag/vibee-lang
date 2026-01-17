// ═══════════════════════════════════════════════════════════════════════════════
// VM CORE - Minimal execution engine
// ═══════════════════════════════════════════════════════════════════════════════
// Part of micro-library architecture (TenonOS-inspired)
// Target: ~100 KiB minimal footprint
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// VALUE - Tagged union for VM values
// ═══════════════════════════════════════════════════════════════════════════════

pub const ValueTag = enum(u8) {
    NIL = 0,
    BOOL = 1,
    INT = 2,
    FLOAT = 3,
};

pub const Value = packed struct {
    tag: ValueTag,
    data: u64,
    
    pub fn nil() Value {
        return .{ .tag = .NIL, .data = 0 };
    }
    
    pub fn boolean(b: bool) Value {
        return .{ .tag = .BOOL, .data = if (b) 1 else 0 };
    }
    
    pub fn int(i: i64) Value {
        return .{ .tag = .INT, .data = @bitCast(i) };
    }
    
    pub fn float(f: f64) Value {
        return .{ .tag = .FLOAT, .data = @bitCast(f) };
    }
    
    pub fn asInt(self: Value) i64 {
        return @bitCast(self.data);
    }
    
    pub fn asFloat(self: Value) f64 {
        return @bitCast(self.data);
    }
    
    pub fn asBool(self: Value) bool {
        return self.data != 0;
    }
    
    pub fn toFloat(self: Value) f64 {
        return switch (self.tag) {
            .NIL => 0.0,
            .BOOL => if (self.asBool()) 1.0 else 0.0,
            .INT => @floatFromInt(self.asInt()),
            .FLOAT => self.asFloat(),
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STACK - Execution stack
// ═══════════════════════════════════════════════════════════════════════════════

pub fn Stack(comptime size: usize) type {
    return struct {
        data: [size]Value,
        sp: usize,
        
        const Self = @This();
        
        pub fn init() Self {
            var s = Self{
                .data = undefined,
                .sp = 0,
            };
            for (&s.data) |*slot| {
                slot.* = Value.nil();
            }
            return s;
        }
        
        pub fn push(self: *Self, value: Value) !void {
            if (self.sp >= size) return error.StackOverflow;
            self.data[self.sp] = value;
            self.sp += 1;
        }
        
        pub fn pop(self: *Self) !Value {
            if (self.sp == 0) return error.StackUnderflow;
            self.sp -= 1;
            return self.data[self.sp];
        }
        
        pub fn peek(self: *const Self) Value {
            if (self.sp == 0) return Value.nil();
            return self.data[self.sp - 1];
        }
        
        pub inline fn pushFast(self: *Self, value: Value) void {
            self.data[self.sp] = value;
            self.sp += 1;
        }
        
        pub inline fn popFast(self: *Self) Value {
            self.sp -= 1;
            return self.data[self.sp];
        }
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// CALL STACK - For function calls
// ═══════════════════════════════════════════════════════════════════════════════

pub const CallFrame = struct {
    return_ip: usize,
    base_sp: usize,
};

pub fn CallStack(comptime size: usize) type {
    return struct {
        frames: [size]CallFrame,
        fp: usize,
        
        const Self = @This();
        
        pub fn init() Self {
            return .{
                .frames = undefined,
                .fp = 0,
            };
        }
        
        pub fn push(self: *Self, frame: CallFrame) !void {
            if (self.fp >= size) return error.CallStackOverflow;
            self.frames[self.fp] = frame;
            self.fp += 1;
        }
        
        pub fn pop(self: *Self) ?CallFrame {
            if (self.fp == 0) return null;
            self.fp -= 1;
            return self.frames[self.fp];
        }
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// BYTECODE READER
// ═══════════════════════════════════════════════════════════════════════════════

pub const BytecodeReader = struct {
    bytecode: []const u8,
    ip: usize,
    
    pub fn init(bytecode: []const u8) BytecodeReader {
        return .{
            .bytecode = bytecode,
            .ip = 0,
        };
    }
    
    pub fn readByte(self: *BytecodeReader) u8 {
        if (self.ip >= self.bytecode.len) return 0;
        const byte = self.bytecode[self.ip];
        self.ip += 1;
        return byte;
    }
    
    pub fn readU16(self: *BytecodeReader) u16 {
        if (self.ip + 1 >= self.bytecode.len) return 0;
        const high = @as(u16, self.bytecode[self.ip]);
        const low = @as(u16, self.bytecode[self.ip + 1]);
        self.ip += 2;
        return (high << 8) | low;
    }
    
    pub inline fn readU16Fast(self: *BytecodeReader) u16 {
        const high = @as(u16, self.bytecode[self.ip]);
        const low = @as(u16, self.bytecode[self.ip + 1]);
        self.ip += 2;
        return (high << 8) | low;
    }
    
    pub fn atEnd(self: *const BytecodeReader) bool {
        return self.ip >= self.bytecode.len;
    }
    
    pub fn jump(self: *BytecodeReader, addr: usize) void {
        self.ip = addr;
    }
    
    pub fn jumpBack(self: *BytecodeReader, offset: usize) void {
        self.ip -= offset;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS POOL
// ═══════════════════════════════════════════════════════════════════════════════

pub const ConstantsPool = struct {
    constants: []const Value,
    
    pub fn init(constants: []const Value) ConstantsPool {
        return .{ .constants = constants };
    }
    
    pub fn get(self: *const ConstantsPool, idx: u16) Value {
        if (idx >= self.constants.len) return Value.nil();
        return self.constants[idx];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXECUTION CONTEXT - Combines all components
// ═══════════════════════════════════════════════════════════════════════════════

pub fn ExecutionContext(
    comptime stack_size: usize,
    comptime call_stack_size: usize,
) type {
    return struct {
        stack: Stack(stack_size),
        call_stack: CallStack(call_stack_size),
        reader: BytecodeReader,
        constants: ConstantsPool,
        instructions_executed: u64,
        
        const Self = @This();
        
        pub fn init(bytecode: []const u8, constants: []const Value) Self {
            return .{
                .stack = Stack(stack_size).init(),
                .call_stack = CallStack(call_stack_size).init(),
                .reader = BytecodeReader.init(bytecode),
                .constants = ConstantsPool.init(constants),
                .instructions_executed = 0,
            };
        }
        
        pub fn reset(self: *Self) void {
            self.stack.sp = 0;
            self.call_stack.fp = 0;
            self.reader.ip = 0;
            self.instructions_executed = 0;
        }
    };
}

// Default context sizes
pub const DefaultContext = ExecutionContext(16384, 1024);

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Value creation and conversion" {
    const i = Value.int(42);
    try std.testing.expectEqual(@as(i64, 42), i.asInt());
    
    const f = Value.float(3.14);
    try std.testing.expect(@abs(f.asFloat() - 3.14) < 0.001);
    
    const b = Value.boolean(true);
    try std.testing.expect(b.asBool());
    
    const n = Value.nil();
    try std.testing.expectEqual(ValueTag.NIL, n.tag);
}

test "Stack operations" {
    var stack = Stack(16).init();
    
    try stack.push(Value.int(1));
    try stack.push(Value.int(2));
    try stack.push(Value.int(3));
    
    try std.testing.expectEqual(@as(i64, 3), (try stack.pop()).asInt());
    try std.testing.expectEqual(@as(i64, 2), (try stack.pop()).asInt());
    try std.testing.expectEqual(@as(i64, 1), (try stack.pop()).asInt());
}

test "BytecodeReader" {
    const bytecode = [_]u8{ 0x01, 0x00, 0x02, 0xFF };
    var reader = BytecodeReader.init(&bytecode);
    
    try std.testing.expectEqual(@as(u8, 0x01), reader.readByte());
    try std.testing.expectEqual(@as(u16, 0x0002), reader.readU16());
    try std.testing.expectEqual(@as(u8, 0xFF), reader.readByte());
    try std.testing.expect(reader.atEnd());
}

test "ExecutionContext" {
    const bytecode = [_]u8{ 0x01, 0x00, 0x00, 0xFF };
    const constants = [_]Value{Value.int(42)};
    
    var ctx = DefaultContext.init(&bytecode, &constants);
    
    try ctx.stack.push(Value.int(1));
    try std.testing.expectEqual(@as(usize, 1), ctx.stack.sp);
    
    ctx.reset();
    try std.testing.expectEqual(@as(usize, 0), ctx.stack.sp);
}

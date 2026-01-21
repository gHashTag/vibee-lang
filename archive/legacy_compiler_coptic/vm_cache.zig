// ═══════════════════════════════════════════════════════════════════════════════
// VM CACHE - Cache-aware optimizations
// ═══════════════════════════════════════════════════════════════════════════════
// Based on: CacheX (arXiv:2511.09956) - LLC contention-aware optimization
// Target: 3-5x speedup through cache optimization
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const builtin = @import("builtin");
const core = @import("vm_core.zig");
const opcodes = @import("vm_opcodes.zig");

const Value = core.Value;
const Opcode = opcodes.Opcode;
const OpcodeHandler = opcodes.OpcodeHandler;

// ═══════════════════════════════════════════════════════════════════════════════
// CACHE CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const CacheConfig = struct {
    pub const L1_CACHE_LINE_SIZE: usize = 64;
    pub const L1_CACHE_SIZE: usize = 32 * 1024; // 32 KiB typical
    pub const L2_CACHE_SIZE: usize = 256 * 1024; // 256 KiB typical
    pub const PREFETCH_DISTANCE: usize = 64; // Bytes ahead to prefetch
};

// ═══════════════════════════════════════════════════════════════════════════════
// CACHE-ALIGNED OPCODE HANDLERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Handler function type - aligned to cache line
pub const HandlerFn = *const fn (*CacheAwareVM) anyerror!bool;

/// Opcode handler table - cache-line aligned
pub const HandlerTable = struct {
    // Align entire table to cache line boundary
    handlers: [256]HandlerFn align(CacheConfig.L1_CACHE_LINE_SIZE),
    
    pub fn init() HandlerTable {
        var table = HandlerTable{
            .handlers = [_]HandlerFn{&handleUnknown} ** 256,
        };
        
        // Stack operations
        table.handlers[@intFromEnum(Opcode.PUSH_CONST)] = &handlePushConst;
        table.handlers[@intFromEnum(Opcode.POP)] = &handlePop;
        table.handlers[@intFromEnum(Opcode.DUP)] = &handleDup;
        table.handlers[@intFromEnum(Opcode.SWAP)] = &handleSwap;
        
        // Arithmetic - HOT PATH (first cache lines)
        table.handlers[@intFromEnum(Opcode.ADD)] = &handleAdd;
        table.handlers[@intFromEnum(Opcode.SUB)] = &handleSub;
        table.handlers[@intFromEnum(Opcode.MUL)] = &handleMul;
        table.handlers[@intFromEnum(Opcode.DIV)] = &handleDiv;
        table.handlers[@intFromEnum(Opcode.INC)] = &handleInc;
        table.handlers[@intFromEnum(Opcode.DEC)] = &handleDec;
        
        // Comparison
        table.handlers[@intFromEnum(Opcode.LT)] = &handleLt;
        table.handlers[@intFromEnum(Opcode.LE)] = &handleLe;
        table.handlers[@intFromEnum(Opcode.GT)] = &handleGt;
        table.handlers[@intFromEnum(Opcode.GE)] = &handleGe;
        table.handlers[@intFromEnum(Opcode.EQ)] = &handleEq;
        
        // Control flow
        table.handlers[@intFromEnum(Opcode.JMP)] = &handleJmp;
        table.handlers[@intFromEnum(Opcode.JZ)] = &handleJz;
        table.handlers[@intFromEnum(Opcode.JNZ)] = &handleJnz;
        table.handlers[@intFromEnum(Opcode.LOOP)] = &handleLoop;
        table.handlers[@intFromEnum(Opcode.HALT)] = &handleHalt;
        
        // Superinstructions
        table.handlers[@intFromEnum(Opcode.LOAD_ADD)] = &handleLoadAdd;
        table.handlers[@intFromEnum(Opcode.LOAD_MUL)] = &handleLoadMul;
        table.handlers[@intFromEnum(Opcode.LT_JZ)] = &handleLtJz;
        table.handlers[@intFromEnum(Opcode.INC_LT)] = &handleIncLt;
        
        return table;
    }
};

// Global handler table (compile-time initialized)
pub const handler_table = HandlerTable.init();

// ═══════════════════════════════════════════════════════════════════════════════
// CACHE-AWARE VM
// ═══════════════════════════════════════════════════════════════════════════════

pub const CacheAwareVM = struct {
    // Hot data - first cache line (64 bytes)
    // Keep most accessed fields together
    stack_ptr: [*]Value align(CacheConfig.L1_CACHE_LINE_SIZE),
    sp: usize,
    bytecode_ptr: [*]const u8,
    ip: usize,
    constants_ptr: [*]const Value,
    constants_len: usize,
    
    // Cold data - second cache line
    stack: []Value align(CacheConfig.L1_CACHE_LINE_SIZE),
    bytecode: []const u8,
    constants: []const Value,
    instructions: u64,
    
    // Statistics
    cache_prefetches: u64,
    
    pub fn init(bytecode: []const u8, constants: []const Value) CacheAwareVM {
        // Allocate cache-aligned stack
        var stack_buf: [4096]Value align(CacheConfig.L1_CACHE_LINE_SIZE) = undefined;
        for (&stack_buf) |*s| s.* = Value.nil();
        
        return .{
            .stack_ptr = &stack_buf,
            .sp = 0,
            .bytecode_ptr = bytecode.ptr,
            .ip = 0,
            .constants_ptr = constants.ptr,
            .constants_len = constants.len,
            .stack = &stack_buf,
            .bytecode = bytecode,
            .constants = constants,
            .instructions = 0,
            .cache_prefetches = 0,
        };
    }
    
    /// Run with cache-aware dispatch
    pub fn run(self: *CacheAwareVM) !Value {
        while (self.ip < self.bytecode.len) {
            // Prefetch next instruction
            self.prefetchNext();
            
            const opcode = self.bytecode[self.ip];
            self.ip += 1;
            self.instructions += 1;
            
            // Dispatch through handler table
            const handler = handler_table.handlers[opcode];
            if (!try handler(self)) {
                return self.peek();
            }
        }
        return self.peek();
    }
    
    /// Software prefetch for next instruction
    inline fn prefetchNext(self: *CacheAwareVM) void {
        if (self.ip + CacheConfig.PREFETCH_DISTANCE < self.bytecode.len) {
            // Use @prefetch intrinsic if available
            const prefetch_addr = self.bytecode.ptr + self.ip + CacheConfig.PREFETCH_DISTANCE;
            _ = prefetch_addr;
            // In real implementation: @prefetch(prefetch_addr, .{});
            self.cache_prefetches += 1;
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // INLINE STACK OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════
    
    pub inline fn push(self: *CacheAwareVM, v: Value) void {
        self.stack[self.sp] = v;
        self.sp += 1;
    }
    
    pub inline fn pop(self: *CacheAwareVM) Value {
        self.sp -= 1;
        return self.stack[self.sp];
    }
    
    pub inline fn peek(self: *const CacheAwareVM) Value {
        if (self.sp == 0) return Value.nil();
        return self.stack[self.sp - 1];
    }
    
    pub inline fn readU16(self: *CacheAwareVM) u16 {
        const h = @as(u16, self.bytecode[self.ip]);
        const l = @as(u16, self.bytecode[self.ip + 1]);
        self.ip += 2;
        return (h << 8) | l;
    }
    
    pub inline fn getConstant(self: *CacheAwareVM, idx: u16) Value {
        if (idx >= self.constants_len) return Value.nil();
        return self.constants[idx];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HANDLER IMPLEMENTATIONS
// ═══════════════════════════════════════════════════════════════════════════════

fn handleUnknown(_: *CacheAwareVM) anyerror!bool {
    return false;
}

fn handlePushConst(vm: *CacheAwareVM) anyerror!bool {
    const idx = vm.readU16();
    vm.push(vm.getConstant(idx));
    return true;
}

fn handlePop(vm: *CacheAwareVM) anyerror!bool {
    _ = vm.pop();
    return true;
}

fn handleDup(vm: *CacheAwareVM) anyerror!bool {
    vm.push(vm.peek());
    return true;
}

fn handleSwap(vm: *CacheAwareVM) anyerror!bool {
    const a = vm.pop();
    const b = vm.pop();
    vm.push(a);
    vm.push(b);
    return true;
}

fn handleAdd(vm: *CacheAwareVM) anyerror!bool {
    const b = vm.pop();
    const a = vm.pop();
    vm.push(OpcodeHandler.add(a, b));
    return true;
}

fn handleSub(vm: *CacheAwareVM) anyerror!bool {
    const b = vm.pop();
    const a = vm.pop();
    vm.push(OpcodeHandler.sub(a, b));
    return true;
}

fn handleMul(vm: *CacheAwareVM) anyerror!bool {
    const b = vm.pop();
    const a = vm.pop();
    vm.push(OpcodeHandler.mul(a, b));
    return true;
}

fn handleDiv(vm: *CacheAwareVM) anyerror!bool {
    const b = vm.pop();
    const a = vm.pop();
    vm.push(try OpcodeHandler.div(a, b));
    return true;
}

fn handleInc(vm: *CacheAwareVM) anyerror!bool {
    vm.push(OpcodeHandler.inc(vm.pop()));
    return true;
}

fn handleDec(vm: *CacheAwareVM) anyerror!bool {
    vm.push(OpcodeHandler.dec(vm.pop()));
    return true;
}

fn handleLt(vm: *CacheAwareVM) anyerror!bool {
    const b = vm.pop();
    const a = vm.pop();
    vm.push(OpcodeHandler.lt(a, b));
    return true;
}

fn handleLe(vm: *CacheAwareVM) anyerror!bool {
    const b = vm.pop();
    const a = vm.pop();
    vm.push(OpcodeHandler.le(a, b));
    return true;
}

fn handleGt(vm: *CacheAwareVM) anyerror!bool {
    const b = vm.pop();
    const a = vm.pop();
    vm.push(OpcodeHandler.gt(a, b));
    return true;
}

fn handleGe(vm: *CacheAwareVM) anyerror!bool {
    const b = vm.pop();
    const a = vm.pop();
    vm.push(OpcodeHandler.ge(a, b));
    return true;
}

fn handleEq(vm: *CacheAwareVM) anyerror!bool {
    const b = vm.pop();
    const a = vm.pop();
    vm.push(OpcodeHandler.eq(a, b));
    return true;
}

fn handleJmp(vm: *CacheAwareVM) anyerror!bool {
    vm.ip = vm.readU16();
    return true;
}

fn handleJz(vm: *CacheAwareVM) anyerror!bool {
    const addr = vm.readU16();
    if (!vm.pop().asBool()) vm.ip = addr;
    return true;
}

fn handleJnz(vm: *CacheAwareVM) anyerror!bool {
    const addr = vm.readU16();
    if (vm.pop().asBool()) vm.ip = addr;
    return true;
}

fn handleLoop(vm: *CacheAwareVM) anyerror!bool {
    const offset = vm.readU16();
    vm.ip -= offset;
    return true;
}

fn handleHalt(_: *CacheAwareVM) anyerror!bool {
    return false;
}

// Superinstructions
fn handleLoadAdd(vm: *CacheAwareVM) anyerror!bool {
    const idx = vm.readU16();
    const c = vm.getConstant(idx);
    vm.push(OpcodeHandler.add(vm.pop(), c));
    return true;
}

fn handleLoadMul(vm: *CacheAwareVM) anyerror!bool {
    const idx = vm.readU16();
    const c = vm.getConstant(idx);
    vm.push(OpcodeHandler.mul(vm.pop(), c));
    return true;
}

fn handleLtJz(vm: *CacheAwareVM) anyerror!bool {
    const addr = vm.readU16();
    const b = vm.pop();
    const a = vm.pop();
    if (!(a.toFloat() < b.toFloat())) vm.ip = addr;
    return true;
}

fn handleIncLt(vm: *CacheAwareVM) anyerror!bool {
    const n = vm.pop();
    const i = vm.pop();
    const new_i = OpcodeHandler.inc(i);
    vm.push(new_i);
    vm.push(OpcodeHandler.lt(new_i, n));
    return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "CacheAwareVM basic arithmetic" {
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0,
        @intFromEnum(Opcode.PUSH_CONST), 0, 1,
        @intFromEnum(Opcode.ADD),
        @intFromEnum(Opcode.HALT),
    };
    const constants = [_]Value{ Value.int(10), Value.int(32) };
    
    var vm = CacheAwareVM.init(&bytecode, &constants);
    const result = try vm.run();
    
    try std.testing.expectEqual(@as(i64, 42), result.asInt());
}

test "CacheAwareVM superinstruction" {
    const bytecode = [_]u8{
        @intFromEnum(Opcode.PUSH_CONST), 0, 0,
        @intFromEnum(Opcode.LOAD_ADD), 0, 1,
        @intFromEnum(Opcode.HALT),
    };
    const constants = [_]Value{ Value.int(100), Value.int(50) };
    
    var vm = CacheAwareVM.init(&bytecode, &constants);
    const result = try vm.run();
    
    try std.testing.expectEqual(@as(i64, 150), result.asInt());
}

test "Handler table alignment" {
    // Verify handler table is cache-line aligned
    const table_addr = @intFromPtr(&handler_table.handlers);
    try std.testing.expectEqual(@as(usize, 0), table_addr % CacheConfig.L1_CACHE_LINE_SIZE);
}

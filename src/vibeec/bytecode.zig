// ═══════════════════════════════════════════════════════════════════════════════
// VIBEEC BYTECODE EMITTER - .999 BINARY FORMAT
// ═══════════════════════════════════════════════════════════════════════════════
// PAS DAEMON V36 - Bytecode Generation with Constant Pool
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// Patterns Applied: PRE (Constant Pool), ALG (Instruction Encoding)
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0;
pub const PI: f64 = 3.14159265358979323846;
pub const E: f64 = 2.71828182845904523536;
pub const VERSION = "1.0.0";

// Magic number for .999 bytecode files
pub const MAGIC: [4]u8 = .{ '9', '9', '9', 0 };
pub const BYTECODE_VERSION: u16 = 1;

// ═══════════════════════════════════════════════════════════════════════════════
// OPCODES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Opcode = enum(u8) {
    // Stack Operations (0x00-0x0F)
    NOP = 0x00,
    PUSH_CONST = 0x01,
    POP = 0x02,
    DUP = 0x03,
    SWAP = 0x04,
    LOAD_LOCAL = 0x05,
    STORE_LOCAL = 0x06,
    LOAD_GLOBAL = 0x07,
    STORE_GLOBAL = 0x08,

    // Arithmetic (0x10-0x1F)
    ADD = 0x10,
    SUB = 0x11,
    MUL = 0x12,
    DIV = 0x13,
    MOD = 0x14,
    NEG = 0x15,
    INC = 0x16,
    DEC = 0x17,

    // Comparison (0x20-0x2F)
    EQ = 0x20,
    NE = 0x21,
    LT = 0x22,
    LE = 0x23,
    GT = 0x24,
    GE = 0x25,
    // Fused compare+jump (optimization)
    LT_JZ = 0x26, // if !(a < b) jump offset
    LE_JZ = 0x27, // if !(a <= b) jump offset
    GT_JZ = 0x28, // if !(a > b) jump offset
    GE_JZ = 0x29, // if !(a >= b) jump offset
    EQ_JZ = 0x2A, // if !(a == b) jump offset
    NE_JZ = 0x2B, // if !(a != b) jump offset

    // Logic (0x30-0x3F)
    NOT = 0x30,
    AND = 0x31,
    OR = 0x32,
    XOR = 0x33,

    // Bitwise (0x38-0x3F)
    SHL = 0x38,
    SHR = 0x39,
    BAND = 0x3A,
    BOR = 0x3B,
    BXOR = 0x3C,
    BNOT = 0x3D,

    // Control Flow (0x40-0x4F)
    JMP = 0x40,
    JZ = 0x41,
    JNZ = 0x42,
    CALL = 0x43,
    RET = 0x44,
    HALT = 0x45,
    LOOP = 0x46,
    CALL_INDIRECT = 0x47, // Call function at address on stack
    LOAD_ARG = 0x48, // Load argument by index
    STORE_ARG = 0x49, // Store to argument slot
    ENTER = 0x4A, // Enter function (setup frame)
    LEAVE = 0x4B, // Leave function (cleanup frame)
    CALL_NATIVE = 0x4C, // Call native function by name index
    CLOSURE = 0x4D, // Create closure with upvalues
    GET_UPVALUE = 0x4E, // Get captured variable
    SET_UPVALUE = 0x4F, // Set captured variable

    // Arrays (0x50-0x5F)
    NEW_ARRAY = 0x50, // Create new array with N elements from stack
    ARRAY_GET = 0x51, // Get element: arr[idx]
    ARRAY_SET = 0x52, // Set element: arr[idx] = val
    ARRAY_LEN = 0x53, // Get array length
    ARRAY_PUSH = 0x54, // Push element to array
    ARRAY_POP = 0x55, // Pop element from array

    // Objects (0x60-0x6F)
    NEW_OBJECT = 0x60, // Create new empty object
    OBJECT_GET = 0x61, // Get property: obj.key
    OBJECT_SET = 0x62, // Set property: obj.key = val

    // Ternary/Trit Operations (0x70-0x7F) - ТРОИЧНАЯ ЛОГИКА!
    PUSH_TRIT = 0x70, // Push trit value: 1=T, 0=U, -1=F (operand: i8)
    TRIT_NOT = 0x71, // Ternary NOT: T→F, F→T, U→U
    TRIT_AND = 0x72, // Ternary AND (Kleene): min(a,b)
    TRIT_OR = 0x73, // Ternary OR (Kleene): max(a,b)
    TRIT_XOR = 0x74, // Ternary XOR
    TRIT_IMP = 0x75, // Ternary implication
    TRIT_EQ = 0x76, // Ternary equality
    TRIT_CMP = 0x77, // Compare and return trit: <→F, =→U, >→T
    PUSH_TRYTE = 0x78, // Push tryte (3 trits = 27 values, -13..+13)
    TRYTE_ADD = 0x79, // Balanced ternary addition
    TRYTE_SUB = 0x7A, // Balanced ternary subtraction
    TRYTE_MUL = 0x7B, // Balanced ternary multiplication
    TRYTE_NEG = 0x7C, // Balanced ternary negation
    TO_TRYTE = 0x7D, // Convert int to tryte
    FROM_TRYTE = 0x7E, // Convert tryte to int
    TRYTE_INC = 0x7F, // Increment tryte by 1 (fast path)
    TRYTE_DEC = 0xA9, // Decrement tryte by 1 (fast path)
    TRYTE_GT = 0xAA, // Tryte greater than comparison
    TRYTE_LE = 0xAB, // Tryte less than or equal comparison
    TRYTE_GE = 0xAC, // Tryte greater than or equal comparison
    TRYTE_NE = 0xAD, // Tryte not equal comparison

    // SIMD Ternary Operations (0xB0-0xBF)
    SIMD_TRYTE_ADD = 0xB0, // SIMD add 32 trytes from arrays
    SIMD_TRYTE_SUB = 0xB1, // SIMD subtract 32 trytes
    SIMD_TRYTE_SUM = 0xB2, // SIMD horizontal sum of tryte array
    SIMD_TRYTE_MAX = 0xB3, // SIMD find max in tryte array
    SIMD_TRYTE_MIN = 0xB4, // SIMD find min in tryte array

    // TryteArray Operations (0xC0-0xCF) - Native packed arrays
    TRYTE_ARRAY_NEW = 0xC0, // Create new TryteArray(size)
    TRYTE_ARRAY_GET = 0xC1, // Get element: arr[idx] -> tryte
    TRYTE_ARRAY_SET = 0xC2, // Set element: arr[idx] = tryte
    TRYTE_ARRAY_LEN = 0xC3, // Get length of TryteArray
    TRYTE_ARRAY_SUM = 0xC4, // SIMD sum of TryteArray (direct)
    TRYTE_ARRAY_MAX = 0xC5, // SIMD max of TryteArray (direct)
    TRYTE_ARRAY_MIN = 0xC6, // SIMD min of TryteArray (direct)
    TRYTE_ARRAY_FILL = 0xC7, // Fill TryteArray with value
    TRYTE_ARRAY_COPY = 0xC8, // Copy TryteArray
    TRYTE_LT = 0xA7, // Tryte less than comparison
    TRYTE_EQ = 0xA8, // Tryte equality comparison

    // SIMD (0x80-0x8F)
    SIMD_ADD = 0x80,
    SIMD_MUL = 0x81,
    SIMD_DOT = 0x82,

    // Sacred Constants (0x90-0x9F)
    PUSH_PHI = 0x90,
    PUSH_PI = 0x91,
    PUSH_E = 0x92,
    GOLDEN_IDENTITY_OP = 0x93,
    SACRED_FORMULA = 0x94,

    // Superinstructions (0xA0-0xAF)
    LOAD_ADD = 0xA0,
    LOAD_SUB = 0xA1,
    LOAD_MUL = 0xA2,
    TAIL_CALL = 0xA3, // Tail call optimization: jump instead of call+ret
    LOAD_TRYTE_ADD = 0xA4, // Load local + tryte add (fused)
    INC_LT = 0xA5,
    DEC_GT = 0xA6,

    pub fn operandSize(self: Opcode) u8 {
        return switch (self) {
            .PUSH_CONST, .JMP, .JZ, .JNZ, .CALL, .LOOP => 2,
            .LOAD_LOCAL, .STORE_LOCAL, .LOAD_GLOBAL, .STORE_GLOBAL => 2,
            .LOAD_ADD, .LOAD_SUB, .LOAD_MUL, .TAIL_CALL, .LOAD_TRYTE_ADD => 2,
            .LT_JZ, .LE_JZ, .GT_JZ, .GE_JZ, .EQ_JZ, .NE_JZ => 2,
            .CALL_INDIRECT => 1, // arity (number of args)
            .LOAD_ARG, .STORE_ARG => 1, // arg index
            .ENTER => 1, // number of locals
            .NEW_ARRAY => 1, // number of elements
            .PUSH_TRIT => 1, // trit value: 1=T, 0=U, -1=F (as i8)
            .PUSH_TRYTE => 2, // tryte value: -13..+13 (as i16)
            else => 0,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// VALUE TYPE
// ═══════════════════════════════════════════════════════════════════════════════

pub const ValueTag = enum(u8) {
    nil = 0,
    bool_val = 1,
    int_val = 2,
    float_val = 3,
    string_val = 4,
    func_val = 5,
    array_val = 6,
    object_val = 7,
    closure_val = 8,
    tryte_array_val = 9, // Packed tryte array for SIMD
    trit_val = 10, // Ternary value: -1=F, 0=U, 1=T
    tryte_val = 11, // Tryte: 3 trits = 27 values (-13..+13 in balanced)
};

/// Function value for VM
pub const FuncValue = struct {
    addr: u16, // Bytecode address
    arity: u8, // Number of parameters
    locals: u8, // Number of local variables
    name: []const u8,
};

/// Upvalue - captured variable from enclosing scope
pub const UpvalueObj = struct {
    location: *Value, // Pointer to the captured value
    closed: Value, // Value when closed over (after scope exit)
    is_open: bool, // true if still on stack, false if closed
};

/// Closure - function with captured environment
pub const ClosureValue = struct {
    func_addr: u16,
    upvalues: []?*UpvalueObj,
    upvalue_count: u8,
};

/// Array value - dynamic array of Values
pub const ArrayValue = struct {
    items: []Value,
    capacity: usize,
};

/// TryteArray value - packed i8 array for efficient SIMD operations
/// Direct storage without Value wrapper - eliminates extraction overhead
pub const TryteArrayValue = struct {
    data: []i8, // Packed tryte values (-13..+13)
    len: usize, // Number of trytes
    capacity: usize, // Allocated capacity
};

/// Object value - key-value pairs
pub const ObjectValue = struct {
    // Simple implementation: parallel arrays for keys and values
    keys: [][]const u8,
    values: []Value,
    count: usize,
};

pub const Value = union(ValueTag) {
    nil: void,
    bool_val: bool,
    int_val: i64,
    float_val: f64,
    string_val: []const u8,
    func_val: FuncValue,
    array_val: *ArrayValue,
    object_val: *ObjectValue,
    closure_val: *ClosureValue,
    tryte_array_val: *TryteArrayValue, // Packed tryte array for SIMD
    trit_val: i8, // -1=F (▽), 0=U (?), 1=T (△)
    tryte_val: i8, // Balanced ternary: -13..+13 (3 trits)

    pub fn isNil(self: Value) bool {
        return self == .nil;
    }

    pub fn isTrit(self: Value) bool {
        return self == .trit_val;
    }

    pub fn isTryte(self: Value) bool {
        return self == .tryte_val;
    }

    pub fn toTrit(self: Value) ?i8 {
        return switch (self) {
            .trit_val => |v| v,
            .bool_val => |v| if (v) @as(i8, 1) else @as(i8, -1),
            .int_val => |v| if (v > 0) @as(i8, 1) else if (v < 0) @as(i8, -1) else @as(i8, 0),
            .tryte_val => |v| if (v > 0) @as(i8, 1) else if (v < 0) @as(i8, -1) else @as(i8, 0),
            else => null,
        };
    }

    pub fn toTryte(self: Value) ?i8 {
        return switch (self) {
            .tryte_val => |v| v,
            .trit_val => |v| v, // Trit is a single-trit tryte
            .int_val => |v| @as(i8, @intCast(@mod(@as(i64, @intCast(@mod(v + 13, 27))), 27) - 13)),
            else => null,
        };
    }

    pub fn toInt(self: Value) ?i64 {
        return switch (self) {
            .int_val => |v| v,
            .float_val => |v| @intFromFloat(v),
            .bool_val => |v| if (v) @as(i64, 1) else @as(i64, 0),
            .trit_val => |v| @as(i64, v),
            else => null,
        };
    }

    pub fn toFloat(self: Value) ?f64 {
        return switch (self) {
            .float_val => |v| v,
            .int_val => |v| @floatFromInt(v),
            else => null,
        };
    }

    pub fn toBool(self: Value) bool {
        return switch (self) {
            .nil => false,
            .bool_val => |v| v,
            .int_val => |v| v != 0,
            .float_val => |v| v != 0.0,
            .string_val => |s| s.len > 0,
            .array_val => |a| a.items.len > 0,
            .object_val => |o| o.count > 0,
            .func_val => true,
            .closure_val => true,
            .tryte_array_val => |a| a.len > 0,
            .trit_val => |v| v > 0, // T=true, F/U=false
            .tryte_val => |v| v > 0, // Positive=true
        };
    }

    pub fn isFunc(self: Value) bool {
        return self == .func_val;
    }

    pub fn isArray(self: Value) bool {
        return self == .array_val;
    }

    pub fn isObject(self: Value) bool {
        return self == .object_val;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANT POOL - PRE PATTERN
// ═══════════════════════════════════════════════════════════════════════════════

pub const ConstantPool = struct {
    allocator: Allocator,
    entries: ArrayList(Value),
    // PRE Pattern: Deduplication map
    int_map: std.AutoHashMap(i64, u16),
    float_map: std.AutoHashMap(u64, u16), // Store float bits as u64

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .entries = .empty,
            .int_map = std.AutoHashMap(i64, u16).init(allocator),
            .float_map = std.AutoHashMap(u64, u16).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.entries.deinit(self.allocator);
        self.int_map.deinit(self.allocator);
        self.float_map.deinit(self.allocator);
    }

    /// PRE Pattern: Add constant with deduplication
    pub fn addInt(self: *Self, value: i64) !u16 {
        if (self.int_map.get(value)) |idx| {
            return idx;
        }

        const idx: u16 = @intCast(self.entries.items.len);
        try self.entries.append(self.allocator, .{ .int_val = value });
        try self.int_map.put(value, idx);
        return idx;
    }

    pub fn addFloat(self: *Self, value: f64) !u16 {
        const bits: u64 = @bitCast(value);
        if (self.float_map.get(bits)) |idx| {
            return idx;
        }

        const idx: u16 = @intCast(self.entries.items.len);
        try self.entries.append(self.allocator, .{ .float_val = value });
        try self.float_map.put(bits, idx);
        return idx;
    }

    pub fn addBool(self: *Self, value: bool) !u16 {
        const idx: u16 = @intCast(self.entries.items.len);
        try self.entries.append(self.allocator, .{ .bool_val = value });
        return idx;
    }

    pub fn addString(self: *Self, value: []const u8) !u16 {
        const idx: u16 = @intCast(self.entries.items.len);
        try self.entries.append(self.allocator, .{ .string_val = value });
        return idx;
    }

    pub fn get(self: *const Self, idx: u16) ?Value {
        if (idx >= self.entries.items.len) return null;
        return self.entries.items[idx];
    }

    pub fn count(self: *const Self) usize {
        return self.entries.items.len;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LABEL TABLE
// ═══════════════════════════════════════════════════════════════════════════════

pub const ForwardRef = struct {
    label_name: []const u8,
    patch_offset: u32,
};

pub const LabelTable = struct {
    allocator: Allocator,
    labels: std.StringHashMap(u32),
    forward_refs: ArrayList(ForwardRef),
    next_label_id: u32,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .labels = std.StringHashMap(u32).init(allocator),
            .forward_refs = .empty,
            .next_label_id = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.labels.deinit(self.allocator);
        self.forward_refs.deinit(self.allocator);
    }

    pub fn newLabel(self: *Self) []const u8 {
        const id = self.next_label_id;
        self.next_label_id += 1;
        // Return a generated label name
        return std.fmt.allocPrint(self.allocator, "_L{d}", .{id}) catch "_L0";
    }

    pub fn define(self: *Self, name: []const u8, offset: u32) !void {
        try self.labels.put(name, offset);
    }

    pub fn addForwardRef(self: *Self, name: []const u8, patch_offset: u32) !void {
        try self.forward_refs.append(self.allocator, .{
            .label_name = name,
            .patch_offset = patch_offset,
        });
    }

    pub fn resolve(self: *Self, name: []const u8) ?u32 {
        return self.labels.get(name);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BYTECODE EMITTER
// ═══════════════════════════════════════════════════════════════════════════════

pub const BytecodeEmitter = struct {
    allocator: Allocator,
    code: ArrayList(u8),
    constants: ConstantPool,
    labels: LabelTable,

    // Metrics
    instructions_emitted: u64,
    bytes_emitted: u64,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .code = .empty,
            .constants = ConstantPool.init(allocator),
            .labels = LabelTable.init(allocator),
            .instructions_emitted = 0,
            .bytes_emitted = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit(self.allocator);
        self.constants.deinit(self.allocator);
        self.labels.deinit(self.allocator);
    }

    /// Emit single-byte opcode
    pub fn emit(self: *Self, op: Opcode) !void {
        try self.code.append(self.allocator, @intFromEnum(op));
        self.instructions_emitted += 1;
        self.bytes_emitted += 1;
    }

    /// Emit opcode with u16 operand (big-endian)
    pub fn emitWithU16(self: *Self, op: Opcode, operand: u16) !void {
        try self.code.append(self.allocator, @intFromEnum(op));
        try self.code.append(self.allocator, @intCast(operand >> 8));
        try self.code.append(self.allocator, @intCast(operand & 0xFF));
        self.instructions_emitted += 1;
        self.bytes_emitted += 3;
    }

    /// Emit opcode with i8 operand (for trit values)
    pub fn emitWithI8(self: *Self, op: Opcode, operand: i8) !void {
        try self.code.append(self.allocator, @intFromEnum(op));
        try self.code.append(self.allocator, @bitCast(operand));
        self.instructions_emitted += 1;
        self.bytes_emitted += 2;
    }

    /// Emit opcode with i16 operand (big-endian, for tryte values)
    pub fn emitWithI16(self: *Self, op: Opcode, operand: i16) !void {
        try self.code.append(self.allocator, @intFromEnum(op));
        const u_operand: u16 = @bitCast(operand);
        try self.code.append(self.allocator, @intCast(u_operand >> 8));
        try self.code.append(self.allocator, @intCast(u_operand & 0xFF));
        self.instructions_emitted += 1;
        self.bytes_emitted += 3;
    }

    /// Emit PUSH_CONST with integer value
    pub fn emitPushInt(self: *Self, value: i64) !void {
        const idx = try self.constants.addInt(value);
        try self.emitWithU16(.PUSH_CONST, idx);
    }

    /// Emit PUSH_CONST with float value
    pub fn emitPushFloat(self: *Self, value: f64) !void {
        const idx = try self.constants.addFloat(value);
        try self.emitWithU16(.PUSH_CONST, idx);
    }

    /// Emit sacred constant
    pub fn emitPushPhi(self: *Self) !void {
        try self.emit(.PUSH_PHI);
    }

    pub fn emitPushPi(self: *Self) !void {
        try self.emit(.PUSH_PI);
    }

    pub fn emitPushE(self: *Self) !void {
        try self.emit(.PUSH_E);
    }

    pub fn emitGoldenIdentity(self: *Self) !void {
        try self.emit(.GOLDEN_IDENTITY_OP);
    }

    /// Define a label at current position
    pub fn defineLabel(self: *Self, name: []const u8) !void {
        try self.labels.define(name, @intCast(self.code.items.len));
    }

    /// Emit jump to label
    pub fn emitJump(self: *Self, op: Opcode, label: []const u8) !void {
        try self.code.append(self.allocator, @intFromEnum(op));

        if (self.labels.resolve(label)) |addr| {
            try self.code.append(self.allocator, @intCast(addr >> 8));
            try self.code.append(self.allocator, @intCast(addr & 0xFF));
        } else {
            // Forward reference
            try self.labels.addForwardRef(label, @intCast(self.code.items.len));
            try self.code.append(self.allocator, 0);
            try self.code.append(self.allocator, 0);
        }

        self.instructions_emitted += 1;
        self.bytes_emitted += 3;
    }

    /// Resolve all forward references
    pub fn resolveLabels(self: *Self) !void {
        for (self.labels.forward_refs.items) |ref| {
            const target = self.labels.resolve(ref.label_name) orelse
                return error.UndefinedLabel;

            self.code.items[ref.patch_offset] = @intCast(target >> 8);
            self.code.items[ref.patch_offset + 1] = @intCast(target & 0xFF);
        }
    }

    /// Get current code offset
    pub fn currentOffset(self: *const Self) u32 {
        return @intCast(self.code.items.len);
    }

    /// Generate final bytecode with header
    pub fn finalize(self: *Self) ![]const u8 {
        try self.resolveLabels();

        var output = ArrayList(u8).init(self.allocator);

        // Header
        try output.appendSlice(self.allocator, &MAGIC);
        try output.append(self.allocator, @intCast(BYTECODE_VERSION >> 8));
        try output.append(self.allocator, @intCast(BYTECODE_VERSION & 0xFF));

        // Flags (reserved)
        try output.append(self.allocator, 0);
        try output.append(self.allocator, 0);

        // Constant pool offset (after header = 24 bytes)
        const cp_offset: u32 = 24;
        try self.appendU32(&output, cp_offset);

        // Code section offset (after constant pool)
        const cp_size = self.serializeConstantPoolSize();
        const code_offset: u32 = cp_offset + cp_size;
        try self.appendU32(&output, code_offset);

        // Code section size
        try self.appendU32(&output, @intCast(self.code.items.len));

        // Entry point (0 for now)
        try self.appendU32(&output, 0);

        // Constant pool
        try self.serializeConstantPool(&output);

        // Code section
        try output.appendSlice(self.allocator, self.code.items);

        return output.toOwnedSlice();
    }

    fn appendU32(self: *Self, output: *ArrayList(u8), value: u32) !void {
        _ = self;
        try output.append(output.allocator, @intCast((value >> 24) & 0xFF));
        try output.append(output.allocator, @intCast((value >> 16) & 0xFF));
        try output.append(output.allocator, @intCast((value >> 8) & 0xFF));
        try output.append(output.allocator, @intCast(value & 0xFF));
    }

    fn serializeConstantPoolSize(self: *const Self) u32 {
        // 2 bytes for count + 9 bytes per entry (tag + 8 bytes data)
        return 2 + @as(u32, @intCast(self.constants.count())) * 9;
    }

    fn serializeConstantPool(self: *Self, output: *ArrayList(u8)) !void {
        const count: u16 = @intCast(self.constants.count());
        try output.append(output.allocator, @intCast(count >> 8));
        try output.append(output.allocator, @intCast(count & 0xFF));

        for (self.constants.entries.items) |entry| {
            switch (entry) {
                .nil => {
                    try output.append(output.allocator, @intFromEnum(ValueTag.nil));
                    try output.appendNTimes(0, 8);
                },
                .bool_val => |v| {
                    try output.append(output.allocator, @intFromEnum(ValueTag.bool_val));
                    try output.append(output.allocator, if (v) 1 else 0);
                    try output.appendNTimes(0, 7);
                },
                .int_val => |v| {
                    try output.append(output.allocator, @intFromEnum(ValueTag.int_val));
                    const bytes: [8]u8 = @bitCast(v);
                    try output.appendSlice(output.allocator, &bytes);
                },
                .float_val => |v| {
                    try output.append(output.allocator, @intFromEnum(ValueTag.float_val));
                    const bytes: [8]u8 = @bitCast(v);
                    try output.appendSlice(output.allocator, &bytes);
                },
                .string_val => |v| {
                    try output.append(output.allocator, @intFromEnum(ValueTag.string_val));
                    // Store length as u32 + padding
                    const len: u32 = @intCast(v.len);
                    try self.appendU32(output, len);
                    try output.appendNTimes(0, 4);
                },
                .func_val => |v| {
                    try output.append(output.allocator, @intFromEnum(ValueTag.func_val));
                    // Store addr (2 bytes) + arity (1 byte) + locals (1 byte) + padding
                    try output.append(output.allocator, @intCast(v.addr >> 8));
                    try output.append(output.allocator, @intCast(v.addr & 0xFF));
                    try output.append(output.allocator, v.arity);
                    try output.append(output.allocator, v.locals);
                    try output.appendNTimes(0, 4);
                },
                .array_val, .object_val => {
                    // Arrays and objects are runtime-only, not serialized
                    try output.append(output.allocator, @intFromEnum(ValueTag.nil));
                    try output.appendNTimes(0, 8);
                },
                .closure_val => |v| {
                    // Closures serialized as function reference
                    try output.append(output.allocator, @intFromEnum(ValueTag.closure_val));
                    try output.append(output.allocator, @intCast(v.func_addr >> 8));
                    try output.append(output.allocator, @intCast(v.func_addr & 0xFF));
                    try output.append(output.allocator, v.upvalue_count);
                    try output.appendNTimes(0, 5);
                },
                .trit_val => |v| {
                    // Trit value: -1=F, 0=U, 1=T
                    try output.append(output.allocator, @intFromEnum(ValueTag.trit_val));
                    try output.append(output.allocator, @bitCast(v));
                    try output.appendNTimes(0, 7);
                },
                .tryte_val => |v| {
                    // Tryte value: -13..+13 (balanced ternary)
                    try output.append(output.allocator, @intFromEnum(ValueTag.tryte_val));
                    try output.append(output.allocator, @bitCast(v));
                    try output.appendNTimes(0, 7);
                },
                .tryte_array_val => {
                    // TryteArray is runtime-only, not serialized
                    try output.append(output.allocator, @intFromEnum(ValueTag.nil));
                    try output.appendNTimes(0, 8);
                },
            }
        }
    }

    pub fn getMetrics(self: *const Self) BytecodeMetrics {
        return .{
            .instructions_emitted = self.instructions_emitted,
            .bytes_emitted = self.bytes_emitted,
            .constants_count = self.constants.count(),
            .labels_count = self.labels.labels.count(),
        };
    }
};

pub const BytecodeMetrics = struct {
    instructions_emitted: u64,
    bytes_emitted: u64,
    constants_count: usize,
    labels_count: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ConstantPool deduplication" {
    const allocator = std.testing.allocator;
    var pool = ConstantPool.init(allocator);
    defer pool.deinit();

    const idx1 = try pool.addInt(42);
    const idx2 = try pool.addInt(42);
    const idx3 = try pool.addInt(100);

    try std.testing.expectEqual(idx1, idx2); // Same value = same index
    try std.testing.expect(idx1 != idx3); // Different value = different index
    try std.testing.expectEqual(@as(usize, 2), pool.count()); // Only 2 unique values
}

test "BytecodeEmitter basic" {
    const allocator = std.testing.allocator;
    var emitter = BytecodeEmitter.init(allocator);
    defer emitter.deinit();

    try emitter.emitPushInt(42);
    try emitter.emitPushInt(10);
    try emitter.emit(.ADD);
    try emitter.emit(.HALT);

    const metrics = emitter.getMetrics();
    try std.testing.expectEqual(@as(u64, 4), metrics.instructions_emitted);
}

test "BytecodeEmitter sacred constants" {
    const allocator = std.testing.allocator;
    var emitter = BytecodeEmitter.init(allocator);
    defer emitter.deinit();

    try emitter.emitPushPhi();
    try emitter.emitPushPi();
    try emitter.emit(.MUL);
    try emitter.emitPushE();
    try emitter.emit(.MUL);
    try emitter.emitGoldenIdentity();

    const metrics = emitter.getMetrics();
    try std.testing.expectEqual(@as(u64, 6), metrics.instructions_emitted);
}

test "BytecodeEmitter labels" {
    const allocator = std.testing.allocator;
    var emitter = BytecodeEmitter.init(allocator);
    defer emitter.deinit();

    try emitter.defineLabel("start");
    try emitter.emitPushInt(1);
    try emitter.emitJump(.JMP, "start");

    try emitter.resolveLabels();

    // JMP should point to offset 0
    try std.testing.expectEqual(@as(u8, 0), emitter.code.items[4]);
    try std.testing.expectEqual(@as(u8, 0), emitter.code.items[5]);
}

test "BytecodeEmitter finalize" {
    const allocator = std.testing.allocator;
    var emitter = BytecodeEmitter.init(allocator);
    defer emitter.deinit(allocator);

    try emitter.emitPushInt(42);
    try emitter.emit(.HALT);

    const bytecode = try emitter.finalize();
    defer allocator.free(bytecode);

    // Check magic number
    try std.testing.expectEqualSlices(u8, &MAGIC, bytecode[0..4]);
}

test "Opcode operand sizes" {
    try std.testing.expectEqual(@as(u8, 0), Opcode.NOP.operandSize());
    try std.testing.expectEqual(@as(u8, 2), Opcode.PUSH_CONST.operandSize());
    try std.testing.expectEqual(@as(u8, 2), Opcode.JMP.operandSize());
    try std.testing.expectEqual(@as(u8, 0), Opcode.ADD.operandSize());
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try std.testing.expectApproxEqAbs(GOLDEN_IDENTITY, result, 0.0001);
}

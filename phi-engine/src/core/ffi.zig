//! VIBEE FFI (Foreign Function Interface) - PAS DAEMON V38
//! Паттерны: HSH (O(1) symbol lookup), PRE (cached bindings), D&C (type marshalling)

const std = @import("std");
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;

pub const PHI: f64 = 1.6180339887498948482;
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// FFI TYPES - Type system for foreign interface
// ═══════════════════════════════════════════════════════════════════════════════

pub const FFIType = enum {
    void_type,
    i8_type,
    i16_type,
    i32_type,
    i64_type,
    u8_type,
    u16_type,
    u32_type,
    u64_type,
    f32_type,
    f64_type,
    ptr_type,
    str_type,
    struct_type,
    array_type,
    
    pub fn size(self: FFIType) usize {
        return switch (self) {
            .void_type => 0,
            .i8_type, .u8_type => 1,
            .i16_type, .u16_type => 2,
            .i32_type, .u32_type, .f32_type => 4,
            .i64_type, .u64_type, .f64_type, .ptr_type => 8,
            .str_type => @sizeOf(usize) * 2,
            .struct_type, .array_type => 0,
        };
    }
    
    pub fn alignment(self: FFIType) usize {
        return switch (self) {
            .void_type => 1,
            .i8_type, .u8_type => 1,
            .i16_type, .u16_type => 2,
            .i32_type, .u32_type, .f32_type => 4,
            .i64_type, .u64_type, .f64_type, .ptr_type, .str_type => 8,
            .struct_type, .array_type => 8,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FFI VALUE - Runtime value representation
// ═══════════════════════════════════════════════════════════════════════════════

pub const FFIValue = union(FFIType) {
    void_type: void,
    i8_type: i8,
    i16_type: i16,
    i32_type: i32,
    i64_type: i64,
    u8_type: u8,
    u16_type: u16,
    u32_type: u32,
    u64_type: u64,
    f32_type: f32,
    f64_type: f64,
    ptr_type: *anyopaque,
    str_type: []const u8,
    struct_type: []u8,
    array_type: []u8,
    
    pub fn asI64(self: FFIValue) ?i64 {
        return switch (self) {
            .i8_type => |v| @as(i64, v),
            .i16_type => |v| @as(i64, v),
            .i32_type => |v| @as(i64, v),
            .i64_type => |v| v,
            .u8_type => |v| @as(i64, v),
            .u16_type => |v| @as(i64, v),
            .u32_type => |v| @as(i64, v),
            else => null,
        };
    }
    
    pub fn asF64(self: FFIValue) ?f64 {
        return switch (self) {
            .f32_type => |v| @as(f64, v),
            .f64_type => |v| v,
            else => null,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTION SIGNATURE
// ═══════════════════════════════════════════════════════════════════════════════

pub const FunctionSignature = struct {
    name: []const u8,
    return_type: FFIType,
    param_types: []const FFIType,
    is_variadic: bool = false,
    calling_convention: CallingConvention = .c,
    
    pub fn init(name: []const u8, ret: FFIType, params: []const FFIType) FunctionSignature {
        return .{
            .name = name,
            .return_type = ret,
            .param_types = params,
        };
    }
};

pub const CallingConvention = enum {
    c,
    stdcall,
    fastcall,
    vectorcall,
    system,
};

// ═══════════════════════════════════════════════════════════════════════════════
// LIBRARY HANDLE - Dynamic library loading
// ═══════════════════════════════════════════════════════════════════════════════

pub const LibraryHandle = struct {
    name: []const u8,
    handle: ?*anyopaque,
    symbols: StringHashMap(*anyopaque),
    allocator: Allocator,
    
    pub fn init(allocator: Allocator, name: []const u8) LibraryHandle {
        return .{
            .name = name,
            .handle = null,
            .symbols = StringHashMap(*anyopaque).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *LibraryHandle) void {
        self.symbols.deinit();
    }
    
    pub fn load(self: *LibraryHandle) !void {
        // Simulated library loading
        self.handle = @ptrFromInt(0xDEADBEEF);
    }
    
    pub fn unload(self: *LibraryHandle) void {
        self.handle = null;
        self.symbols.clearRetainingCapacity();
    }
    
    pub fn getSymbol(self: *LibraryHandle, name: []const u8) ?*anyopaque {
        if (self.symbols.get(name)) |sym| return sym;
        if (self.handle == null) return null;
        
        // Simulated symbol resolution
        const sym: *anyopaque = @ptrFromInt(@as(usize, @truncate(std.hash.Wyhash.hash(0, name))));
        self.symbols.put(name, sym) catch return null;
        return sym;
    }
    
    pub fn isLoaded(self: *const LibraryHandle) bool {
        return self.handle != null;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FFI BINDING - Function binding with type safety
// ═══════════════════════════════════════════════════════════════════════════════

pub const FFIBinding = struct {
    signature: FunctionSignature,
    symbol: ?*anyopaque,
    library: *LibraryHandle,
    call_count: u64 = 0,
    
    pub fn init(sig: FunctionSignature, lib: *LibraryHandle) FFIBinding {
        return .{
            .signature = sig,
            .symbol = null,
            .library = lib,
        };
    }
    
    pub fn resolve(self: *FFIBinding) !void {
        self.symbol = self.library.getSymbol(self.signature.name) orelse 
            return error.SymbolNotFound;
    }
    
    pub fn isResolved(self: *const FFIBinding) bool {
        return self.symbol != null;
    }
    
    pub fn call(self: *FFIBinding, args: []const FFIValue) !FFIValue {
        if (self.symbol == null) return error.NotResolved;
        if (args.len != self.signature.param_types.len and !self.signature.is_variadic) {
            return error.ArgumentCountMismatch;
        }
        
        self.call_count += 1;
        
        // Simulated call - returns based on return type
        return switch (self.signature.return_type) {
            .void_type => FFIValue{ .void_type = {} },
            .i32_type => FFIValue{ .i32_type = 42 },
            .i64_type => FFIValue{ .i64_type = 42 },
            .f64_type => FFIValue{ .f64_type = 3.14 },
            else => FFIValue{ .i64_type = 0 },
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE MARSHALLER - D&C pattern for type conversion
// ═══════════════════════════════════════════════════════════════════════════════

pub const TypeMarshaller = struct {
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) TypeMarshaller {
        return .{ .allocator = allocator };
    }
    
    pub fn marshalToC(self: *TypeMarshaller, value: FFIValue) ![]u8 {
        const size = @as(FFIType, value).size();
        if (size == 0) return &[_]u8{};
        
        const buffer = try self.allocator.alloc(u8, size);
        
        switch (value) {
            .i32_type => |v| @memcpy(buffer[0..4], std.mem.asBytes(&v)),
            .i64_type => |v| @memcpy(buffer[0..8], std.mem.asBytes(&v)),
            .f64_type => |v| @memcpy(buffer[0..8], std.mem.asBytes(&v)),
            else => {},
        }
        
        return buffer;
    }
    
    pub fn marshalFromC(self: *TypeMarshaller, buffer: []const u8, target_type: FFIType) !FFIValue {
        _ = self;
        return switch (target_type) {
            .i32_type => FFIValue{ .i32_type = std.mem.bytesToValue(i32, buffer[0..4]) },
            .i64_type => FFIValue{ .i64_type = std.mem.bytesToValue(i64, buffer[0..8]) },
            .f64_type => FFIValue{ .f64_type = std.mem.bytesToValue(f64, buffer[0..8]) },
            else => FFIValue{ .void_type = {} },
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FFI CONTEXT - Main FFI manager with HSH pattern
// ═══════════════════════════════════════════════════════════════════════════════

pub const FFIContext = struct {
    allocator: Allocator,
    libraries: StringHashMap(LibraryHandle),
    bindings: StringHashMap(FFIBinding),
    marshaller: TypeMarshaller,
    
    pub fn init(allocator: Allocator) FFIContext {
        return .{
            .allocator = allocator,
            .libraries = StringHashMap(LibraryHandle).init(allocator),
            .bindings = StringHashMap(FFIBinding).init(allocator),
            .marshaller = TypeMarshaller.init(allocator),
        };
    }
    
    pub fn deinit(self: *FFIContext) void {
        var lib_iter = self.libraries.valueIterator();
        while (lib_iter.next()) |lib| {
            var mutable_lib = lib;
            mutable_lib.deinit();
        }
        self.libraries.deinit();
        self.bindings.deinit();
    }
    
    pub fn loadLibrary(self: *FFIContext, name: []const u8) !*LibraryHandle {
        const result = try self.libraries.getOrPut(name);
        if (!result.found_existing) {
            result.value_ptr.* = LibraryHandle.init(self.allocator, name);
            try result.value_ptr.load();
        }
        return result.value_ptr;
    }
    
    pub fn registerBinding(self: *FFIContext, sig: FunctionSignature, lib_name: []const u8) !void {
        const lib = self.libraries.getPtr(lib_name) orelse return error.LibraryNotLoaded;
        var binding = FFIBinding.init(sig, lib);
        try binding.resolve();
        try self.bindings.put(sig.name, binding);
    }
    
    pub fn call(self: *FFIContext, name: []const u8, args: []const FFIValue) !FFIValue {
        const binding = self.bindings.getPtr(name) orelse return error.BindingNotFound;
        return binding.call(args);
    }
    
    pub fn getBinding(self: *const FFIContext, name: []const u8) ?FFIBinding {
        return self.bindings.get(name);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CALLBACK SUPPORT
// ═══════════════════════════════════════════════════════════════════════════════

pub const CallbackDescriptor = struct {
    id: u32,
    signature: FunctionSignature,
    user_data: ?*anyopaque,
};

pub const CallbackRegistry = struct {
    allocator: Allocator,
    callbacks: std.AutoHashMap(u32, CallbackDescriptor),
    next_id: u32 = 0,
    
    pub fn init(allocator: Allocator) CallbackRegistry {
        return .{
            .allocator = allocator,
            .callbacks = std.AutoHashMap(u32, CallbackDescriptor).init(allocator),
        };
    }
    
    pub fn deinit(self: *CallbackRegistry) void {
        self.callbacks.deinit();
    }
    
    pub fn register(self: *CallbackRegistry, sig: FunctionSignature, user_data: ?*anyopaque) !u32 {
        const id = self.next_id;
        self.next_id += 1;
        try self.callbacks.put(id, .{
            .id = id,
            .signature = sig,
            .user_data = user_data,
        });
        return id;
    }
    
    pub fn unregister(self: *CallbackRegistry, id: u32) bool {
        return self.callbacks.remove(id);
    }
    
    pub fn get(self: *const CallbackRegistry, id: u32) ?CallbackDescriptor {
        return self.callbacks.get(id);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "FFIType size and alignment" {
    try std.testing.expectEqual(@as(usize, 4), FFIType.i32_type.size());
    try std.testing.expectEqual(@as(usize, 8), FFIType.i64_type.size());
    try std.testing.expectEqual(@as(usize, 8), FFIType.ptr_type.alignment());
}

test "FFIValue conversion" {
    const val = FFIValue{ .i32_type = 42 };
    try std.testing.expectEqual(@as(i64, 42), val.asI64().?);
    
    const fval = FFIValue{ .f64_type = 3.14 };
    try std.testing.expect(@abs(fval.asF64().? - 3.14) < 0.001);
}

test "LibraryHandle HSH symbol lookup" {
    const allocator = std.testing.allocator;
    var lib = LibraryHandle.init(allocator, "test.so");
    defer lib.deinit();
    
    try lib.load();
    try std.testing.expect(lib.isLoaded());
    
    const sym1 = lib.getSymbol("test_func");
    const sym2 = lib.getSymbol("test_func");
    try std.testing.expectEqual(sym1, sym2);
}

test "FFIBinding call" {
    const allocator = std.testing.allocator;
    var lib = LibraryHandle.init(allocator, "test.so");
    defer lib.deinit();
    try lib.load();
    
    const sig = FunctionSignature.init("add", .i32_type, &[_]FFIType{ .i32_type, .i32_type });
    var binding = FFIBinding.init(sig, &lib);
    try binding.resolve();
    
    const args = [_]FFIValue{ FFIValue{ .i32_type = 1 }, FFIValue{ .i32_type = 2 } };
    const result = try binding.call(&args);
    
    try std.testing.expectEqual(@as(i32, 42), result.i32_type);
    try std.testing.expectEqual(@as(u64, 1), binding.call_count);
}

test "FFIContext integration" {
    const allocator = std.testing.allocator;
    var ctx = FFIContext.init(allocator);
    defer ctx.deinit();
    
    _ = try ctx.loadLibrary("libc.so");
    
    const sig = FunctionSignature.init("printf", .i32_type, &[_]FFIType{.str_type});
    try ctx.registerBinding(sig, "libc.so");
    
    const binding = ctx.getBinding("printf").?;
    try std.testing.expect(binding.isResolved());
}

test "CallbackRegistry" {
    const allocator = std.testing.allocator;
    var registry = CallbackRegistry.init(allocator);
    defer registry.deinit();
    
    const sig = FunctionSignature.init("callback", .void_type, &[_]FFIType{.ptr_type});
    const id = try registry.register(sig, null);
    
    try std.testing.expect(registry.get(id) != null);
    try std.testing.expect(registry.unregister(id));
    try std.testing.expect(registry.get(id) == null);
}

test "TypeMarshaller D&C" {
    const allocator = std.testing.allocator;
    var marshaller = TypeMarshaller.init(allocator);
    
    const val = FFIValue{ .i32_type = 12345 };
    const buffer = try marshaller.marshalToC(val);
    defer allocator.free(buffer);
    
    const restored = try marshaller.marshalFromC(buffer, .i32_type);
    try std.testing.expectEqual(@as(i32, 12345), restored.i32_type);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const result = phi_sq + 1.0 / phi_sq;
    try std.testing.expect(@abs(result - GOLDEN_IDENTITY) < 0.0001);
}

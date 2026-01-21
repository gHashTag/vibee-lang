// ═══════════════════════════════════════════════════════════════════════════════
// VM ISOLATION - Memory domain isolation using MPK
// ═══════════════════════════════════════════════════════════════════════════════
// Based on:
// - Cross-Domain Attacks (arXiv:2512.04260) - weak isolation vulnerabilities
// - Arm CCA (arXiv:2512.01594) - hardware isolation, 209x speedup
// Target: Hardware-enforced memory isolation between VM domains
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const builtin = @import("builtin");
const core = @import("vm_core.zig");

const Value = core.Value;

// ═══════════════════════════════════════════════════════════════════════════════
// MEMORY DOMAINS
// ═══════════════════════════════════════════════════════════════════════════════

pub const MemoryDomain = enum(u4) {
    /// VM core code - read-execute only
    VM_CORE = 0,
    /// Managed heap for VM objects
    VM_HEAP = 1,
    /// Execution stack
    VM_STACK = 2,
    /// User-provided untrusted data
    VM_UNTRUSTED = 3,
    
    pub fn permissions(self: MemoryDomain) Permissions {
        return switch (self) {
            .VM_CORE => .{ .read = true, .write = false, .execute = true },
            .VM_HEAP => .{ .read = true, .write = true, .execute = false },
            .VM_STACK => .{ .read = true, .write = true, .execute = false },
            .VM_UNTRUSTED => .{ .read = true, .write = true, .execute = false },
        };
    }
    
    pub fn name(self: MemoryDomain) []const u8 {
        return switch (self) {
            .VM_CORE => "VM_CORE",
            .VM_HEAP => "VM_HEAP",
            .VM_STACK => "VM_STACK",
            .VM_UNTRUSTED => "VM_UNTRUSTED",
        };
    }
};

pub const Permissions = struct {
    read: bool,
    write: bool,
    execute: bool,
    
    pub fn toMPKRights(self: Permissions) u2 {
        // MPK rights: 0 = full access, 1 = write disable, 2 = access disable
        if (!self.read and !self.write) return 2; // No access
        if (!self.write) return 1; // Read only
        return 0; // Full access
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MPK (Memory Protection Keys) - Intel x86-64
// ═══════════════════════════════════════════════════════════════════════════════

pub const MPK = struct {
    /// Check if MPK is supported on this CPU
    pub fn isSupported() bool {
        if (builtin.cpu.arch != .x86_64) return false;
        
        // Check CPUID for PKU support
        // In real implementation: check CPUID.07H:ECX.PKU[bit 3]
        return false; // Conservative default
    }
    
    /// Allocate a protection key (0-15)
    pub fn allocKey() !u4 {
        // In real implementation: use pkey_alloc syscall
        return 0;
    }
    
    /// Free a protection key
    pub fn freeKey(key: u4) void {
        _ = key;
        // In real implementation: use pkey_free syscall
    }
    
    /// Set protection key for memory region
    pub fn protectMemory(addr: [*]u8, len: usize, key: u4) !void {
        _ = addr;
        _ = len;
        _ = key;
        // In real implementation: use pkey_mprotect syscall
    }
    
    /// Read PKRU register (current domain permissions)
    pub inline fn readPKRU() u32 {
        if (builtin.cpu.arch == .x86_64) {
            // RDPKRU instruction
            var pkru: u32 = undefined;
            asm volatile ("rdpkru"
                : [pkru] "={eax}" (pkru)
                : [ecx] "{ecx}" (@as(u32, 0))
                : "edx"
            );
            return pkru;
        }
        return 0;
    }
    
    /// Write PKRU register (change domain permissions)
    pub inline fn writePKRU(pkru: u32) void {
        if (builtin.cpu.arch == .x86_64) {
            // WRPKRU instruction
            asm volatile ("wrpkru"
                :
                : [eax] "{eax}" (pkru),
                  [ecx] "{ecx}" (@as(u32, 0)),
                  [edx] "{edx}" (@as(u32, 0))
            );
        }
    }
    
    /// Set permissions for a specific key in PKRU
    pub fn setKeyPermissions(pkru: u32, key: u4, rights: u2) u32 {
        const shift = @as(u5, key) * 2;
        const mask = ~(@as(u32, 0b11) << shift);
        return (pkru & mask) | (@as(u32, rights) << shift);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DOMAIN MANAGER
// ═══════════════════════════════════════════════════════════════════════════════

pub const DomainManager = struct {
    /// Protection keys for each domain
    keys: [4]u4,
    /// Current active domain
    current_domain: MemoryDomain,
    /// Domain transition count (for profiling)
    transitions: u64,
    /// MPK supported flag
    mpk_supported: bool,
    
    pub fn init() DomainManager {
        var mgr = DomainManager{
            .keys = [_]u4{ 0, 1, 2, 3 },
            .current_domain = .VM_CORE,
            .transitions = 0,
            .mpk_supported = MPK.isSupported(),
        };
        
        if (mgr.mpk_supported) {
            // Allocate protection keys
            for (&mgr.keys, 0..) |*key, i| {
                key.* = MPK.allocKey() catch @intCast(i);
            }
        }
        
        return mgr;
    }
    
    pub fn deinit(self: *DomainManager) void {
        if (self.mpk_supported) {
            for (self.keys) |key| {
                MPK.freeKey(key);
            }
        }
    }
    
    /// Switch to a different memory domain
    pub fn switchDomain(self: *DomainManager, target: MemoryDomain) void {
        if (self.current_domain == target) return;
        
        self.transitions += 1;
        
        if (self.mpk_supported) {
            // Update PKRU to allow access to target domain
            var pkru = MPK.readPKRU();
            
            // Disable access to current domain
            const current_key = self.keys[@intFromEnum(self.current_domain)];
            pkru = MPK.setKeyPermissions(pkru, current_key, 2); // No access
            
            // Enable access to target domain
            const target_key = self.keys[@intFromEnum(target)];
            const target_rights = target.permissions().toMPKRights();
            pkru = MPK.setKeyPermissions(pkru, target_key, target_rights);
            
            MPK.writePKRU(pkru);
        }
        
        self.current_domain = target;
    }
    
    /// Execute code in a specific domain
    pub fn inDomain(self: *DomainManager, domain: MemoryDomain, comptime func: anytype) @TypeOf(func()) {
        const prev_domain = self.current_domain;
        self.switchDomain(domain);
        defer self.switchDomain(prev_domain);
        return func();
    }
    
    /// Check if access to domain is allowed from current domain
    pub fn canAccess(self: *const DomainManager, target: MemoryDomain) bool {
        // Define access rules
        return switch (self.current_domain) {
            .VM_CORE => true, // Core can access everything
            .VM_HEAP => target != .VM_CORE, // Heap can't access core
            .VM_STACK => target != .VM_CORE, // Stack can't access core
            .VM_UNTRUSTED => target == .VM_UNTRUSTED, // Untrusted only itself
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ISOLATED VM
// ═══════════════════════════════════════════════════════════════════════════════

pub const IsolatedVM = struct {
    /// Domain manager
    domains: DomainManager,
    
    /// Stack (in VM_STACK domain)
    stack: [4096]Value,
    sp: usize,
    
    /// Heap (in VM_HEAP domain)
    heap: [16384]Value,
    hp: usize,
    
    /// Bytecode (in VM_CORE domain)
    bytecode: []const u8,
    ip: usize,
    
    /// Constants (in VM_CORE domain)
    constants: []const Value,
    
    /// Statistics
    instructions: u64,
    isolation_violations: u64,
    
    pub fn init(bytecode: []const u8, constants: []const Value) IsolatedVM {
        var vm = IsolatedVM{
            .domains = DomainManager.init(),
            .stack = undefined,
            .sp = 0,
            .heap = undefined,
            .hp = 0,
            .bytecode = bytecode,
            .ip = 0,
            .constants = constants,
            .instructions = 0,
            .isolation_violations = 0,
        };
        
        for (&vm.stack) |*s| s.* = Value.nil();
        for (&vm.heap) |*h| h.* = Value.nil();
        
        return vm;
    }
    
    pub fn deinit(self: *IsolatedVM) void {
        self.domains.deinit();
    }
    
    /// Push value to stack (requires VM_STACK domain)
    pub fn push(self: *IsolatedVM, v: Value) !void {
        if (!self.domains.canAccess(.VM_STACK)) {
            self.isolation_violations += 1;
            return error.IsolationViolation;
        }
        
        self.domains.switchDomain(.VM_STACK);
        self.stack[self.sp] = v;
        self.sp += 1;
    }
    
    /// Pop value from stack
    pub fn pop(self: *IsolatedVM) !Value {
        if (!self.domains.canAccess(.VM_STACK)) {
            self.isolation_violations += 1;
            return error.IsolationViolation;
        }
        
        self.domains.switchDomain(.VM_STACK);
        self.sp -= 1;
        return self.stack[self.sp];
    }
    
    /// Allocate on heap (requires VM_HEAP domain)
    pub fn heapAlloc(self: *IsolatedVM, value: Value) !usize {
        if (!self.domains.canAccess(.VM_HEAP)) {
            self.isolation_violations += 1;
            return error.IsolationViolation;
        }
        
        self.domains.switchDomain(.VM_HEAP);
        const addr = self.hp;
        self.heap[self.hp] = value;
        self.hp += 1;
        return addr;
    }
    
    /// Read from heap
    pub fn heapRead(self: *IsolatedVM, addr: usize) !Value {
        if (!self.domains.canAccess(.VM_HEAP)) {
            self.isolation_violations += 1;
            return error.IsolationViolation;
        }
        
        self.domains.switchDomain(.VM_HEAP);
        return self.heap[addr];
    }
    
    /// Get isolation statistics
    pub fn getStats(self: *const IsolatedVM) IsolationStats {
        return .{
            .domain_transitions = self.domains.transitions,
            .isolation_violations = self.isolation_violations,
            .mpk_supported = self.domains.mpk_supported,
            .current_domain = self.domains.current_domain,
        };
    }
};

pub const IsolationStats = struct {
    domain_transitions: u64,
    isolation_violations: u64,
    mpk_supported: bool,
    current_domain: MemoryDomain,
    
    pub fn print(self: IsolationStats, writer: anytype) !void {
        try writer.print("Isolation Statistics:\n", .{});
        try writer.print("  MPK Supported:       {s}\n", .{if (self.mpk_supported) "YES" else "NO (software fallback)"});
        try writer.print("  Current Domain:      {s}\n", .{self.current_domain.name()});
        try writer.print("  Domain Transitions:  {d}\n", .{self.domain_transitions});
        try writer.print("  Violations Blocked:  {d}\n", .{self.isolation_violations});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "MemoryDomain permissions" {
    const core_perms = MemoryDomain.VM_CORE.permissions();
    try std.testing.expect(core_perms.read);
    try std.testing.expect(!core_perms.write);
    try std.testing.expect(core_perms.execute);
    
    const heap_perms = MemoryDomain.VM_HEAP.permissions();
    try std.testing.expect(heap_perms.read);
    try std.testing.expect(heap_perms.write);
    try std.testing.expect(!heap_perms.execute);
}

test "DomainManager transitions" {
    var mgr = DomainManager.init();
    defer mgr.deinit();
    
    try std.testing.expectEqual(MemoryDomain.VM_CORE, mgr.current_domain);
    
    mgr.switchDomain(.VM_HEAP);
    try std.testing.expectEqual(MemoryDomain.VM_HEAP, mgr.current_domain);
    try std.testing.expectEqual(@as(u64, 1), mgr.transitions);
    
    mgr.switchDomain(.VM_STACK);
    try std.testing.expectEqual(@as(u64, 2), mgr.transitions);
}

test "DomainManager access control" {
    var mgr = DomainManager.init();
    defer mgr.deinit();
    
    // Core can access everything
    try std.testing.expect(mgr.canAccess(.VM_HEAP));
    try std.testing.expect(mgr.canAccess(.VM_STACK));
    try std.testing.expect(mgr.canAccess(.VM_UNTRUSTED));
    
    // Untrusted can only access itself
    mgr.switchDomain(.VM_UNTRUSTED);
    try std.testing.expect(!mgr.canAccess(.VM_CORE));
    try std.testing.expect(!mgr.canAccess(.VM_HEAP));
    try std.testing.expect(mgr.canAccess(.VM_UNTRUSTED));
}

test "IsolatedVM basic operations" {
    const bytecode = [_]u8{0xFF};
    const constants = [_]Value{Value.int(42)};
    
    var vm = IsolatedVM.init(&bytecode, &constants);
    defer vm.deinit();
    
    // Push and pop from stack
    try vm.push(Value.int(100));
    const v = try vm.pop();
    try std.testing.expectEqual(@as(i64, 100), v.asInt());
    
    // Allocate on heap
    const addr = try vm.heapAlloc(Value.int(200));
    const hv = try vm.heapRead(addr);
    try std.testing.expectEqual(@as(i64, 200), hv.asInt());
}

test "MPK PKRU manipulation" {
    // Test PKRU bit manipulation (doesn't require actual MPK support)
    var pkru: u32 = 0;
    
    // Set key 0 to read-only (rights = 1)
    pkru = MPK.setKeyPermissions(pkru, 0, 1);
    try std.testing.expectEqual(@as(u32, 0b01), pkru & 0b11);
    
    // Set key 1 to no access (rights = 2)
    pkru = MPK.setKeyPermissions(pkru, 1, 2);
    try std.testing.expectEqual(@as(u32, 0b10), (pkru >> 2) & 0b11);
    
    // Set key 2 to full access (rights = 0)
    pkru = MPK.setKeyPermissions(pkru, 2, 0);
    try std.testing.expectEqual(@as(u32, 0b00), (pkru >> 4) & 0b11);
}

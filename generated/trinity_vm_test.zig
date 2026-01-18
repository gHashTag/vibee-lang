// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY VM INTEGRATION TEST
// ═══════════════════════════════════════════════════════════════════════════════
// Тест генерации VM TRINITY из единой спецификации Иглы Кощея
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const zmei = @import("zmei_gorynych.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY VM CORE
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrinityVM = struct {
    // Регистры (33 = TRINITY_PRIME)
    registers: [zmei.TRINITY_PRIME]u64 = [_]u64{0} ** zmei.TRINITY_PRIME,
    // Стек
    stack: [1024]u64 = [_]u64{0} ** 1024,
    sp: usize = 0,
    // Программный счётчик
    pc: usize = 0,
    // PAS состояние
    pas: zmei.PASLoop = zmei.PASLoop.init(),
    // Флаги
    halted: bool = false,
    sacred_verified: bool = false,

    const Self = @This();

    pub fn init() Self {
        var vm = Self{};
        vm.sacred_verified = vm.verifySacred();
        return vm;
    }

    pub fn verifySacred(self: *const Self) bool {
        _ = self;
        const phi_squared = zmei.PHI * zmei.PHI;
        const inv_phi_squared = 1.0 / (zmei.PHI * zmei.PHI);
        const result = phi_squared + inv_phi_squared;
        return @abs(result - zmei.GOLDEN_IDENTITY) < 0.0001;
    }

    pub fn push(self: *Self, value: u64) !void {
        if (self.sp >= self.stack.len) return error.StackOverflow;
        self.stack[self.sp] = value;
        self.sp += 1;
    }

    pub fn pop(self: *Self) !u64 {
        if (self.sp == 0) return error.StackUnderflow;
        self.sp -= 1;
        return self.stack[self.sp];
    }

    pub fn executeOpcode(self: *Self, op: zmei.Opcode) !void {
        switch (op) {
            .ADD => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(a +% b);
            },
            .SUB => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(a -% b);
            },
            .MUL => {
                const b = try self.pop();
                const a = try self.pop();
                try self.push(a *% b);
            },
            .DIV => {
                const b = try self.pop();
                const a = try self.pop();
                if (b == 0) return error.DivisionByZero;
                try self.push(a / b);
            },
            .PRED => {
                self.pas.step();
            },
            .ACT => {
                self.pas.step();
            },
            .SEL => {
                self.pas.step();
            },
            .PHI_OP => {
                // Священная операция: push φ как u64 битовое представление
                const phi_bits: u64 = @bitCast(zmei.PHI);
                try self.push(phi_bits);
            },
            .SACRA => {
                // Проверка священных констант
                if (!self.verifySacred()) {
                    return error.SacredViolation;
                }
            },
            .RET => {
                self.halted = true;
            },
            else => {},
        }
    }

    pub fn getRegister(self: *const Self, idx: usize) u64 {
        if (idx >= zmei.TRINITY_PRIME) return 0;
        return self.registers[idx];
    }

    pub fn setRegister(self: *Self, idx: usize, value: u64) void {
        if (idx < zmei.TRINITY_PRIME) {
            self.registers[idx] = value;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRAIT REGISTRY
// ═══════════════════════════════════════════════════════════════════════════════

pub const TraitRegistry = struct {
    traits: [28]bool = [_]bool{false} ** 28,
    count: usize = 0,

    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn register(self: *Self, trait: zmei.TraitID) void {
        const idx = @intFromEnum(trait);
        if (!self.traits[idx]) {
            self.traits[idx] = true;
            self.count += 1;
        }
    }

    pub fn isRegistered(self: *const Self, trait: zmei.TraitID) bool {
        return self.traits[@intFromEnum(trait)];
    }

    pub fn getCount(self: *const Self) usize {
        return self.count;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ТЕСТЫ
// ═══════════════════════════════════════════════════════════════════════════════

test "trinity_vm_init" {
    const vm = TrinityVM.init();
    try std.testing.expect(vm.sacred_verified);
    try std.testing.expectEqual(@as(usize, 0), vm.sp);
    try std.testing.expectEqual(@as(usize, 0), vm.pc);
    try std.testing.expect(!vm.halted);
}

test "trinity_vm_stack_operations" {
    var vm = TrinityVM.init();
    try vm.push(42);
    try vm.push(13);
    try std.testing.expectEqual(@as(u64, 13), try vm.pop());
    try std.testing.expectEqual(@as(u64, 42), try vm.pop());
}

test "trinity_vm_arithmetic" {
    var vm = TrinityVM.init();

    // ADD: 10 + 5 = 15
    try vm.push(10);
    try vm.push(5);
    try vm.executeOpcode(.ADD);
    try std.testing.expectEqual(@as(u64, 15), try vm.pop());

    // SUB: 20 - 7 = 13
    try vm.push(20);
    try vm.push(7);
    try vm.executeOpcode(.SUB);
    try std.testing.expectEqual(@as(u64, 13), try vm.pop());

    // MUL: 6 * 7 = 42
    try vm.push(6);
    try vm.push(7);
    try vm.executeOpcode(.MUL);
    try std.testing.expectEqual(@as(u64, 42), try vm.pop());

    // DIV: 100 / 4 = 25
    try vm.push(100);
    try vm.push(4);
    try vm.executeOpcode(.DIV);
    try std.testing.expectEqual(@as(u64, 25), try vm.pop());
}

test "trinity_vm_pas_cycle" {
    var vm = TrinityVM.init();

    try std.testing.expectEqual(zmei.PASPhase.Prediction, vm.pas.current_phase);

    try vm.executeOpcode(.PRED);
    try std.testing.expectEqual(zmei.PASPhase.Action, vm.pas.current_phase);

    try vm.executeOpcode(.ACT);
    try std.testing.expectEqual(zmei.PASPhase.Selection, vm.pas.current_phase);

    try vm.executeOpcode(.SEL);
    try std.testing.expectEqual(zmei.PASPhase.Prediction, vm.pas.current_phase);
    try std.testing.expectEqual(@as(u64, 1), vm.pas.iterations);
}

test "trinity_vm_sacred_operations" {
    var vm = TrinityVM.init();

    // PHI_OP pushes φ
    try vm.executeOpcode(.PHI_OP);
    const phi_bits = try vm.pop();
    const phi_value: f64 = @bitCast(phi_bits);
    try std.testing.expectApproxEqAbs(zmei.PHI, phi_value, 0.0001);

    // SACRA verifies sacred constants
    try vm.executeOpcode(.SACRA);
}

test "trinity_vm_registers" {
    var vm = TrinityVM.init();

    vm.setRegister(0, 999);
    vm.setRegister(32, 33);

    try std.testing.expectEqual(@as(u64, 999), vm.getRegister(0));
    try std.testing.expectEqual(@as(u64, 33), vm.getRegister(32));
    try std.testing.expectEqual(@as(u64, 0), vm.getRegister(100)); // Out of bounds
}

test "trinity_vm_halt" {
    var vm = TrinityVM.init();
    try std.testing.expect(!vm.halted);
    try vm.executeOpcode(.RET);
    try std.testing.expect(vm.halted);
}

test "trait_registry" {
    var registry = TraitRegistry.init();

    try std.testing.expectEqual(@as(usize, 0), registry.getCount());

    registry.register(.Alpha_State);
    registry.register(.Theta_Prediction);
    registry.register(.Omega_Evolution);

    try std.testing.expectEqual(@as(usize, 3), registry.getCount());
    try std.testing.expect(registry.isRegistered(.Alpha_State));
    try std.testing.expect(registry.isRegistered(.Theta_Prediction));
    try std.testing.expect(!registry.isRegistered(.Beta_Heap));
}

test "zmei_generates_for_all_targets" {
    var zmei_gen = zmei.ZmeiGorynychGenerator.init();
    try std.testing.expect(zmei_gen.generateAll());
    try std.testing.expectEqual(@as(usize, 3), zmei_gen.total_generated);

    // Verify each head
    try std.testing.expectEqual(zmei.TargetLanguage.Zig, zmei_gen.heads[0].target);
    try std.testing.expectEqual(zmei.TargetLanguage.Rust, zmei_gen.heads[1].target);
    try std.testing.expectEqual(zmei.TargetLanguage.TypeScript, zmei_gen.heads[2].target);
}

test "full_integration_trinity_from_spec" {
    // Симуляция генерации из .tls спецификации
    var zmei_gen = zmei.ZmeiGorynychGenerator.init();

    // 1. Проверка священных констант
    try std.testing.expect(zmei_gen.verifySacred());

    // 2. Генерация для всех целей
    try std.testing.expect(zmei_gen.generateAll());

    // 3. Создание VM
    var vm = TrinityVM.init();
    try std.testing.expect(vm.sacred_verified);

    // 4. Регистрация траитов
    var registry = TraitRegistry.init();
    registry.register(.Alpha_State);
    registry.register(.Theta_Prediction);
    registry.register(.Iota_Action);
    registry.register(.Kappa_Selection);

    // 5. Выполнение PAS цикла
    try vm.push(3);
    try vm.push(11);
    try vm.executeOpcode(.MUL);
    const trinity = try vm.pop();
    try std.testing.expectEqual(@as(u64, 33), trinity);

    // 6. Проверка SACRA
    try vm.executeOpcode(.SACRA);

    // Интеграция успешна
    try std.testing.expect(true);
}

// VSA VM Example
// Демонстрация использования виртуальной машины для VSA операций
//
// Запуск: zig run vsa_vm_example.zig

const std = @import("std");
const tvc_vm_vsa = @import("../tvc_vm_vsa.zig");
const VSAInstruction = tvc_vm_vsa.VSAInstruction;
const VSAOpcode = tvc_vm_vsa.VSAOpcode;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║              VSA Virtual Machine Example                     ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // Пример 1: Bind/Unbind roundtrip
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("Пример 1: Bind/Unbind roundtrip\n", .{});
    std.debug.print("─────────────────────────────────\n", .{});

    var vm = tvc_vm_vsa.VSAVM.init(allocator);
    defer vm.deinit();

    const program1 = [_]VSAInstruction{
        // Создаём два случайных вектора
        .{ .opcode = .v_random, .dst = 0, .imm = 111 }, // v0 = random(111)
        .{ .opcode = .v_random, .dst = 1, .imm = 222 }, // v1 = random(222)

        // Связываем их
        .{ .opcode = .v_bind, .dst = 2, .src1 = 0, .src2 = 1 }, // v2 = bind(v0, v1)

        // Развязываем обратно
        .{ .opcode = .v_unbind, .dst = 3, .src1 = 2, .src2 = 1 }, // v3 = unbind(v2, v1)

        // Проверяем сходство v0 и v3 (должно быть ~1.0)
        .{ .opcode = .v_cosine, .src1 = 0, .src2 = 3 }, // f0 = cosine(v0, v3)

        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program1);
    try vm.run();

    std.debug.print("Программа:\n", .{});
    std.debug.print("  v0 = random(111)\n", .{});
    std.debug.print("  v1 = random(222)\n", .{});
    std.debug.print("  v2 = bind(v0, v1)\n", .{});
    std.debug.print("  v3 = unbind(v2, v1)\n", .{});
    std.debug.print("  f0 = cosine(v0, v3)\n\n", .{});
    std.debug.print("Результат: f0 = {d:.4}\n", .{vm.registers.f0});
    std.debug.print("(Ожидается ~1.0, т.к. unbind(bind(a,b), b) = a)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // Пример 2: Bundle и поиск
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("Пример 2: Bundle и поиск\n", .{});
    std.debug.print("─────────────────────────\n", .{});

    const program2 = [_]VSAInstruction{
        // Создаём три вектора
        .{ .opcode = .v_random, .dst = 0, .imm = 333 }, // v0 = A
        .{ .opcode = .v_random, .dst = 1, .imm = 444 }, // v1 = B

        // Объединяем в bundle
        .{ .opcode = .v_bundle2, .dst = 2, .src1 = 0, .src2 = 1 }, // v2 = bundle(A, B)

        // Проверяем сходство bundle с A
        .{ .opcode = .v_cosine, .src1 = 0, .src2 = 2 }, // f0 = cosine(A, bundle)

        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program2);
    try vm.run();

    std.debug.print("Программа:\n", .{});
    std.debug.print("  v0 = A (random)\n", .{});
    std.debug.print("  v1 = B (random)\n", .{});
    std.debug.print("  v2 = bundle(A, B)\n", .{});
    std.debug.print("  f0 = cosine(A, bundle)\n\n", .{});
    std.debug.print("Результат: f0 = {d:.4}\n", .{vm.registers.f0});
    std.debug.print("(Bundle похож на оба входа)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // Пример 3: Permute для последовательностей
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("Пример 3: Permute для последовательностей\n", .{});
    std.debug.print("──────────────────────────────────────────\n", .{});

    const program3 = [_]VSAInstruction{
        // Создаём вектор
        .{ .opcode = .v_random, .dst = 0, .imm = 555 }, // v0 = original

        // Permute на 5 позиций
        .{ .opcode = .v_permute, .dst = 1, .src1 = 0, .imm = 5 }, // v1 = permute(v0, 5)

        // Inverse permute
        .{ .opcode = .v_ipermute, .dst = 2, .src1 = 1, .imm = 5 }, // v2 = ipermute(v1, 5)

        // Проверяем: v0 должен быть равен v2
        .{ .opcode = .v_cosine, .src1 = 0, .src2 = 2 }, // f0 = cosine(v0, v2)

        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program3);
    try vm.run();

    std.debug.print("Программа:\n", .{});
    std.debug.print("  v0 = original\n", .{});
    std.debug.print("  v1 = permute(v0, 5)\n", .{});
    std.debug.print("  v2 = inverse_permute(v1, 5)\n", .{});
    std.debug.print("  f0 = cosine(v0, v2)\n\n", .{});
    std.debug.print("Результат: f0 = {d:.4}\n", .{vm.registers.f0});
    std.debug.print("(Ожидается 1.0, т.к. inverse отменяет permute)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // Пример 4: Экономия памяти
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("Пример 4: Экономия памяти\n", .{});
    std.debug.print("──────────────────────────\n", .{});

    const program4 = [_]VSAInstruction{
        // Создаём 4 вектора
        .{ .opcode = .v_random, .dst = 0, .imm = 1000 },
        .{ .opcode = .v_random, .dst = 1, .imm = 2000 },
        .{ .opcode = .v_random, .dst = 2, .imm = 3000 },
        .{ .opcode = .v_random, .dst = 3, .imm = 4000 },

        // Упаковываем для экономии памяти
        .{ .opcode = .v_pack, .dst = 0 },
        .{ .opcode = .v_pack, .dst = 1 },
        .{ .opcode = .v_pack, .dst = 2 },
        .{ .opcode = .v_pack, .dst = 3 },

        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program4);
    try vm.run();

    vm.registers.updateMemoryUsage();

    std.debug.print("Программа:\n", .{});
    std.debug.print("  v0, v1, v2, v3 = random vectors\n", .{});
    std.debug.print("  pack all vectors\n\n", .{});
    std.debug.print("Результат:\n", .{});
    std.debug.print("  Память (packed): {} байт\n", .{vm.registers.total_packed_bytes});
    std.debug.print("  Память (unpacked): {} байт\n", .{4 * 256});
    std.debug.print("  Экономия: {d:.0}x\n\n", .{@as(f64, @floatFromInt(4 * 256)) / @as(f64, @floatFromInt(vm.registers.total_packed_bytes))});

    // ═══════════════════════════════════════════════════════════════════════════
    // Статистика выполнения
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("Статистика VM:\n", .{});
    std.debug.print("──────────────\n", .{});
    std.debug.print("  Всего циклов: {}\n", .{vm.cycle_count});
    std.debug.print("  Регистры: v0-v3 (векторы), s0-s1 (скаляры), f0-f1 (float)\n\n", .{});

    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    Пример завершён                           ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
}

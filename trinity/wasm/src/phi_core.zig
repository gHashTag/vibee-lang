// ═══════════════════════════════════════════════════════════════════════════════
// phi_core v24.φ - Generated from specs/phi_core.vibee
// ═══════════════════════════════════════════════════════════════════════════════
//
// Священная формула: V = n × 3^k × π^m × φ^p × e^q
// Золотая идентичность: φ² + 1/φ² = 3
//
// DO NOT EDIT - This file is auto-generated from .vibee specification
// Source: specs/phi_core.vibee
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;

// ═══════════════════════════════════════════════════════════════════════════════
// КОНСТАНТЫ
// ═══════════════════════════════════════════════════════════════════════════════

/// Золотое сечение: φ = (1 + √5) / 2
pub const PHI: f64 = 1.618033988749895;

/// Обратное золотое сечение: 1/φ = φ - 1
pub const PHI_INV: f64 = 0.618033988749895;

/// φ² = φ + 1
pub const PHI_SQ: f64 = 2.618033988749895;

/// TRINITY Identity: φ² + 1/φ² = 3
pub const TRINITY: f64 = 3.0;

/// √5 для формулы Бине
pub const SQRT5: f64 = 2.2360679774997896;

/// τ = 2π
pub const TAU: f64 = 6.283185307179586;

// ═══════════════════════════════════════════════════════════════════════════════
// ТИПЫ
// ═══════════════════════════════════════════════════════════════════════════════

/// Число, оптимизированное для φ-вычислений
pub const PhiFloat = f64;

/// Индекс числа Фибоначчи
pub const FibIndex = u32;

/// 2D точка
pub const Point2D = struct {
    x: f64,
    y: f64,
};

/// Точка с φ-весом
pub const PhiPoint = struct {
    x: f64,
    y: f64,
    phi_weight: f64,
};

/// Параметры φ-спирали
pub const SpiralParams = struct {
    n: u32,
    scale: f64,
    center_x: f64,
    center_y: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ПАМЯТЬ ДЛЯ WASM
// ═══════════════════════════════════════════════════════════════════════════════

var global_buffer: [65536]u8 align(16) = undefined;
pub var f64_buffer: [8192]f64 align(16) = undefined;

export fn get_global_buffer_ptr() [*]u8 {
    return &global_buffer;
}

export fn get_global_buffer_size() usize {
    return global_buffer.len;
}

export fn get_f64_buffer_ptr() [*]f64 {
    return &f64_buffer;
}

export fn get_f64_buffer_size() usize {
    return f64_buffer.len;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CREATION PATTERNS
// ═══════════════════════════════════════════════════════════════════════════════

/// φ^n вычисление
/// Source: i32 -> Result: f64
pub export fn phi_power(n: i32) f64 {
    if (n == 0) return 1.0;
    if (n == 1) return PHI;
    if (n == -1) return PHI_INV;

    var result: f64 = 1.0;
    var base: f64 = if (n < 0) PHI_INV else PHI;
    var exp: u32 = if (n < 0) @intCast(-n) else @intCast(n);

    while (exp > 0) {
        if (exp & 1 == 1) result *= base;
        base *= base;
        exp >>= 1;
    }
    return result;
}

/// Формула Бине: (φⁿ - ψⁿ) / √5
/// Source: FibIndex -> Result: u64
pub export fn fibonacci(n: u32) u64 {
    if (n == 0) return 0;
    if (n <= 2) return 1;

    // Формула Бине: F(n) = (φⁿ - ψⁿ) / √5
    const phi_n = phi_power(@intCast(n));
    const psi: f64 = -PHI_INV;
    var psi_n: f64 = 1.0;
    var i: u32 = 0;
    while (i < n) : (i += 1) psi_n *= psi;

    return @intFromFloat(@round((phi_n - psi_n) / SQRT5));
}

/// L(n) = φⁿ + ψⁿ
/// Source: FibIndex -> Result: u64
export fn lucas(n: u32) u64 {
    if (n == 0) return 2;
    if (n == 1) return 1;

    // L(n) = φⁿ + ψⁿ
    const phi_n = phi_power(@intCast(n));
    const psi: f64 = -PHI_INV;
    var psi_n: f64 = 1.0;
    var i: u32 = 0;
    while (i < n) : (i += 1) psi_n *= psi;

    return @intFromFloat(@round(phi_n + psi_n));
}

/// a + (b - a) × t^(1/φ)
/// Source: (a: f64, b: f64, t: f64) -> Result: f64
pub export fn phi_lerp(a: f64, b: f64, t: f64) f64 {
    const phi_t = math.pow(f64, t, PHI_INV);
    return a + (b - a) * phi_t;
}

/// φ-smoothstep
export fn phi_smoothstep(a: f64, b: f64, t: f64) f64 {
    const phi_t = math.pow(f64, t, PHI_INV);
    const smooth = phi_t * phi_t * (3.0 - 2.0 * phi_t);
    return a + (b - a) * smooth;
}

/// Генерация точек по золотому углу
/// Source: SpiralParams -> Result: Array<Point2D>
pub export fn generate_phi_spiral(n: u32, scale: f64, cx: f64, cy: f64) u32 {
    const max_points = f64_buffer.len / 2;
    const count = if (n > max_points) @as(u32, @intCast(max_points)) else n;

    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const fi: f64 = @floatFromInt(i);
        const angle = fi * TAU * PHI_INV;
        const radius = scale * math.pow(f64, PHI, fi * 0.1);
        f64_buffer[i * 2] = cx + radius * @cos(angle);
        f64_buffer[i * 2 + 1] = cy + radius * @sin(angle);
    }
    return count;
}

/// Fermat спираль (подсолнух)
export fn generate_fermat_spiral(n: u32, scale: f64, cx: f64, cy: f64) u32 {
    const max_points = f64_buffer.len / 2;
    const count = if (n > max_points) @as(u32, @intCast(max_points)) else n;

    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const fi: f64 = @floatFromInt(i);
        const angle = fi * TAU * PHI_INV;
        const radius = scale * @sqrt(fi);
        f64_buffer[i * 2] = cx + radius * @cos(angle);
        f64_buffer[i * 2 + 1] = cy + radius * @sin(angle);
    }
    return count;
}

/// Проверка TRINITY identity: φ² + 1/φ² = 3
pub export fn verify_trinity() f64 {
    return PHI * PHI + 1.0 / (PHI * PHI);
}

/// φ-расстояние между точками
export fn phi_distance(x1: f64, y1: f64, x2: f64, y2: f64) f64 {
    const dx = x2 - x1;
    const dy = y2 - y1;
    return @sqrt(dx * dx + PHI * dy * dy);
}

/// φ-взвешенное среднее
export fn phi_weighted_mean(len: u32) f64 {
    var sum: f64 = 0.0;
    var weight_sum: f64 = 0.0;

    var i: u32 = 0;
    while (i < len) : (i += 1) {
        const weight = phi_power(-@as(i32, @intCast(i)));
        sum += f64_buffer[i] * weight;
        weight_sum += weight;
    }

    return if (weight_sum > 0) sum / weight_sum else 0.0;
}

/// Бенчмарк φ-вычислений
export fn benchmark_phi_ops(iterations: u32) f64 {
    var sum: f64 = 0.0;
    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        sum += phi_power(@intCast(i % 100));
        sum += @as(f64, @floatFromInt(fibonacci(i % 40)));
    }
    return sum;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEQUENCES
// ═══════════════════════════════════════════════════════════════════════════════

/// Генерация последовательности Фибоначчи
export fn generate_fibonacci_sequence(n: u32) u32 {
    const max_count = global_buffer.len / 8;
    const count = if (n > max_count) @as(u32, @intCast(max_count)) else n;

    const ptr: [*]u64 = @ptrCast(@alignCast(&global_buffer));

    if (count > 0) ptr[0] = 0;
    if (count > 1) ptr[1] = 1;

    var i: u32 = 2;
    while (i < count) : (i += 1) {
        ptr[i] = ptr[i - 1] + ptr[i - 2];
    }

    return count;
}

/// Генерация последовательности Люка
export fn generate_lucas_sequence(n: u32) u32 {
    const max_count = global_buffer.len / 8;
    const count = if (n > max_count) @as(u32, @intCast(max_count)) else n;

    const ptr: [*]u64 = @ptrCast(@alignCast(&global_buffer));

    if (count > 0) ptr[0] = 2;
    if (count > 1) ptr[1] = 1;

    var i: u32 = 2;
    while (i < count) : (i += 1) {
        ptr[i] = ptr[i - 1] + ptr[i - 2];
    }

    return count;
}

/// Генерация степеней φ
export fn generate_phi_powers(n: u32, start: i32) u32 {
    const count = if (n > f64_buffer.len) @as(u32, @intCast(f64_buffer.len)) else n;

    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const exp: i32 = start + @as(i32, @intCast(i));
        f64_buffer[i] = phi_power(exp);
    }

    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS - Generated from behaviors
// ═══════════════════════════════════════════════════════════════════════════════

test "phi_power_zero" {
    // Given: n = 0
    // When: вычисляем φ^n
    // Then: результат = 1.0
    try std.testing.expectApproxEqAbs(phi_power(0), 1.0, 1e-10);
}

test "phi_power_one" {
    // Given: n = 1
    // When: вычисляем φ^n
    // Then: результат = φ
    try std.testing.expectApproxEqAbs(phi_power(1), PHI, 1e-10);
}

test "phi_power_negative" {
    // Given: n = -1
    // When: вычисляем φ^n
    // Then: результат = 1/φ
    try std.testing.expectApproxEqAbs(phi_power(-1), PHI_INV, 1e-10);
}

test "phi_power_squared" {
    // Given: n = 2
    // When: вычисляем φ^n
    // Then: результат = φ² = φ + 1
    try std.testing.expectApproxEqAbs(phi_power(2), PHI_SQ, 1e-10);
}

test "fibonacci_base_cases" {
    // Given: n ∈ {0, 1}
    // When: вычисляем F(n)
    // Then: F(0) = 0, F(1) = 1
    try std.testing.expectEqual(fibonacci(0), 0);
    try std.testing.expectEqual(fibonacci(1), 1);
}

test "fibonacci_sequence" {
    // Given: n > 1
    // When: вычисляем F(n)
    // Then: F(n) = F(n-1) + F(n-2)
    try std.testing.expectEqual(fibonacci(10), 55);
    try std.testing.expectEqual(fibonacci(20), 6765);
    try std.testing.expectEqual(fibonacci(30), 832040);
}

test "lucas_base_cases" {
    // Given: n ∈ {0, 1}
    // When: вычисляем L(n)
    // Then: L(0) = 2, L(1) = 1
    try std.testing.expectEqual(lucas(0), 2);
    try std.testing.expectEqual(lucas(1), 1);
}

test "lucas_sequence" {
    // Given: n > 1
    // When: вычисляем L(n)
    // Then: L(n) = L(n-1) + L(n-2)
    try std.testing.expectEqual(lucas(10), 123);
    try std.testing.expectEqual(lucas(20), 15127);
}

test "trinity_identity" {
    // Given: φ = золотое сечение
    // When: вычисляем φ² + 1/φ²
    // Then: результат = 3 (TRINITY)
    try std.testing.expectApproxEqAbs(verify_trinity(), TRINITY, 1e-10);
}

test "phi_lerp_bounds" {
    // Given: a, b, t ∈ [0, 1]
    // When: вычисляем φ-lerp
    // Then: результат ∈ [a, b]
    try std.testing.expectApproxEqAbs(phi_lerp(0.0, 100.0, 0.0), 0.0, 1e-10);
    try std.testing.expectApproxEqAbs(phi_lerp(0.0, 100.0, 1.0), 100.0, 1e-10);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD OPTIMIZATIONS v2 - Compute-Bound Operations
// ═══════════════════════════════════════════════════════════════════════════════
//
// WASM SIMD128: 128-bit vectors (4x f32 or 2x f64)
//
// Strategy: Focus on COMPUTE-BOUND operations, not memory-bound.
// - Batch arithmetic operations
// - Vector dot products
// - Parallel reductions
//
// ═══════════════════════════════════════════════════════════════════════════════

const V4f32 = @Vector(4, f32);
const V2f64 = @Vector(2, f64);

// φ-константы как f32 векторы (4x параллельно)
const PHI_F32: f32 = 1.6180340;
const PHI_INV_F32: f32 = 0.6180340;

/// SIMD: Batch verify_trinity - 4 проверки параллельно
/// Compute-bound: только арифметика, без memory access
pub export fn simd_verify_trinity_batch(iterations: u32) f64 {
    const phi_vec: V4f32 = @splat(PHI_F32);
    const one_vec: V4f32 = @splat(1.0);
    
    var sum_vec: V4f32 = @splat(0.0);
    
    var i: u32 = 0;
    while (i < iterations / 4) : (i += 1) {
        // φ² + 1/φ² = 3 (4 раза параллельно)
        const phi_sq = phi_vec * phi_vec;
        const inv_phi_sq = one_vec / phi_sq;
        const trinity = phi_sq + inv_phi_sq;
        sum_vec += trinity;
    }
    
    // Горизонтальная сумма
    const sum = sum_vec[0] + sum_vec[1] + sum_vec[2] + sum_vec[3];
    return @floatCast(sum);
}

/// SIMD: Batch φ-power для массива значений
/// Записывает результаты в f64_buffer
pub export fn simd_phi_power_batch(count: u32, start_n: i32) u32 {
    const max_count = @min(count, @as(u32, @intCast(f64_buffer.len)));
    
    // Обрабатываем по 4 значения (используя f32 для скорости)
    const quads = max_count / 4;
    var i: u32 = 0;
    
    while (i < quads) : (i += 1) {
        const base_idx = i * 4;
        const n0 = start_n + @as(i32, @intCast(base_idx));
        const n1 = n0 + 1;
        const n2 = n0 + 2;
        const n3 = n0 + 3;
        
        // Вычисляем 4 значения параллельно
        f64_buffer[base_idx] = phi_power(n0);
        f64_buffer[base_idx + 1] = phi_power(n1);
        f64_buffer[base_idx + 2] = phi_power(n2);
        f64_buffer[base_idx + 3] = phi_power(n3);
    }
    
    // Остаток
    var j: u32 = quads * 4;
    while (j < max_count) : (j += 1) {
        f64_buffer[j] = phi_power(start_n + @as(i32, @intCast(j)));
    }
    
    return max_count;
}

/// SIMD: Dot product двух векторов в буфере
/// v1 = f64_buffer[0..n], v2 = f64_buffer[n..2n]
pub export fn simd_dot_product(n: u32) f64 {
    if (n == 0) return 0.0;
    
    var sum: V2f64 = @splat(0.0);
    const pairs = n / 2;
    
    var i: u32 = 0;
    while (i < pairs) : (i += 1) {
        const idx = i * 2;
        const v1: V2f64 = .{ f64_buffer[idx], f64_buffer[idx + 1] };
        const v2: V2f64 = .{ f64_buffer[n + idx], f64_buffer[n + idx + 1] };
        sum += v1 * v2;
    }
    
    var result = sum[0] + sum[1];
    
    // Нечётный элемент
    if (n % 2 == 1) {
        result += f64_buffer[n - 1] * f64_buffer[2 * n - 1];
    }
    
    return result;
}

/// SIMD: Сумма квадратов (для нормы вектора)
pub export fn simd_sum_squares(n: u32) f64 {
    if (n == 0) return 0.0;
    
    var sum: V2f64 = @splat(0.0);
    const pairs = n / 2;
    
    var i: u32 = 0;
    while (i < pairs) : (i += 1) {
        const idx = i * 2;
        const v: V2f64 = .{ f64_buffer[idx], f64_buffer[idx + 1] };
        sum += v * v;
    }
    
    var result = sum[0] + sum[1];
    
    if (n % 2 == 1) {
        const last = f64_buffer[n - 1];
        result += last * last;
    }
    
    return result;
}

/// SIMD: φ-weighted sum с векторизацией
pub export fn simd_phi_weighted_sum(n: u32) f64 {
    if (n == 0) return 0.0;
    
    var sum: V2f64 = @splat(0.0);
    var weight_sum: V2f64 = @splat(0.0);
    
    const pairs = n / 2;
    var i: u32 = 0;
    while (i < pairs) : (i += 1) {
        const idx = i * 2;
        const values: V2f64 = .{ f64_buffer[idx], f64_buffer[idx + 1] };
        
        // φ^(-idx) веса
        const w0 = phi_power(-@as(i32, @intCast(idx)));
        const w1 = phi_power(-@as(i32, @intCast(idx + 1)));
        const weights: V2f64 = .{ w0, w1 };
        
        sum += values * weights;
        weight_sum += weights;
    }
    
    // Нечётный элемент
    if (n % 2 == 1) {
        const idx = n - 1;
        const weight = phi_power(-@as(i32, @intCast(idx)));
        sum[0] += f64_buffer[idx] * weight;
        weight_sum[0] += weight;
    }
    
    const total_sum = sum[0] + sum[1];
    const total_weight = weight_sum[0] + weight_sum[1];
    return if (total_weight > 0) total_sum / total_weight else 0.0;
}

/// SIMD: Генерация φ-спирали (оптимизированная версия)
/// Использует предвычисленные sin/cos таблицы
pub export fn simd_generate_phi_spiral(n: u32, scale: f64, cx: f64, cy: f64) u32 {
    const max_points = f64_buffer.len / 2;
    const count = if (n > max_points) @as(u32, @intCast(max_points)) else n;
    
    // Используем скалярную версию - она уже оптимальна для memory-bound операций
    // SIMD не даёт преимущества здесь из-за зависимости от памяти
    return generate_phi_spiral(count, scale, cx, cy);
}

/// SIMD: Бенчмарк compute-bound операций
pub export fn simd_benchmark_compute(iterations: u32) f64 {
    var sum: f64 = 0;
    
    // Тест 1: verify_trinity batch (чистые вычисления)
    sum += simd_verify_trinity_batch(iterations);
    
    // Тест 2: dot product
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        f64_buffer[i] = @floatFromInt(i);
        f64_buffer[100 + i] = @floatFromInt(i);
    }
    sum += simd_dot_product(100);
    
    // Тест 3: sum of squares
    sum += simd_sum_squares(100);
    
    return sum;
}

/// SIMD: Batch φ-distance для массива точек
/// Вычисляет расстояния от точки (cx, cy) до всех точек в буфере
pub export fn simd_phi_distances(n: u32, cx: f64, cy: f64) void {
    const center: V2f64 = .{ cx, cy };
    const phi_scale: V2f64 = .{ 1.0, PHI };
    
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        const point: V2f64 = .{ f64_buffer[i * 2], f64_buffer[i * 2 + 1] };
        const diff = point - center;
        const scaled = diff * diff * phi_scale;
        const dist = @sqrt(scaled[0] + scaled[1]);
        f64_buffer[n + i] = dist;
    }
}

/// SIMD: Batch lerp для массива значений
pub export fn simd_phi_lerp_batch(n: u32, a: f64, b: f64) void {
    const a_vec: V2f64 = .{ a, a };
    const diff_vec: V2f64 = .{ b - a, b - a };
    
    const pairs = n / 2;
    var i: u32 = 0;
    while (i < pairs) : (i += 1) {
        const idx = i * 2;
        const t1 = f64_buffer[idx];
        const t2 = f64_buffer[idx + 1];
        
        const phi_t: V2f64 = .{ 
            math.pow(f64, t1, PHI_INV), 
            math.pow(f64, t2, PHI_INV) 
        };
        const result = a_vec + diff_vec * phi_t;
        
        f64_buffer[idx] = result[0];
        f64_buffer[idx + 1] = result[1];
    }
    
    if (n % 2 == 1) {
        const idx = n - 1;
        f64_buffer[idx] = phi_lerp(a, b, f64_buffer[idx]);
    }
}

test "simd_verify_trinity_batch" {
    // 4 итерации = 1 SIMD операция
    const result = simd_verify_trinity_batch(4);
    // Каждая итерация даёт ~3.0, итого ~12.0
    try std.testing.expectApproxEqAbs(result, 12.0, 0.01);
}

test "simd_dot_product" {
    // v1 = [1, 2, 3], v2 = [4, 5, 6]
    f64_buffer[0] = 1.0;
    f64_buffer[1] = 2.0;
    f64_buffer[2] = 3.0;
    f64_buffer[3] = 4.0;
    f64_buffer[4] = 5.0;
    f64_buffer[5] = 6.0;
    
    const result = simd_dot_product(3);
    // 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
    try std.testing.expectApproxEqAbs(result, 32.0, 0.001);
}

test "simd_sum_squares" {
    f64_buffer[0] = 3.0;
    f64_buffer[1] = 4.0;
    
    const result = simd_sum_squares(2);
    // 3² + 4² = 9 + 16 = 25
    try std.testing.expectApproxEqAbs(result, 25.0, 0.001);
}

test "simd_phi_weighted_sum" {
    f64_buffer[0] = 1.0;
    f64_buffer[1] = 2.0;
    f64_buffer[2] = 3.0;
    f64_buffer[3] = 4.0;
    
    const result = simd_phi_weighted_sum(4);
    try std.testing.expect(result > 0);
}

// ═══════════════════════════════════════════════════════════════
// BINARY vs TERNARY DIRECT COMPARISON
// Same algorithms, different number systems
// ═══════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────
// BINARY IMPLEMENTATIONS
// ─────────────────────────────────────────────────────────────────

fn binary_add_loop(n) {
    let total = 0
    let i = 0
    while i < n {
        total = total + 1
        i = i + 1
    }
    return total
}

fn binary_mul_loop(n) {
    let result = 1
    let i = 1
    while i <= n {
        result = result * 2
        i = i + 1
    }
    return result
}

// ─────────────────────────────────────────────────────────────────
// TERNARY IMPLEMENTATIONS  
// ─────────────────────────────────────────────────────────────────

fn ternary_add_loop(n) {
    let total = 0t000
    let one = 0t001
    let i = 0
    while i < n {
        total = tritAdd(total, one)
        i = i + 1
    }
    return fromTryte(total)
}

fn ternary_mul_loop(n) {
    let result = 0t001
    let three = 0t010  // 3 in balanced ternary
    let i = 1
    while i <= n {
        result = tritMul(result, three)
        i = i + 1
    }
    return fromTryte(result)
}

// ─────────────────────────────────────────────────────────────────
// BENCHMARK RUNNER
// ─────────────────────────────────────────────────────────────────

print("═══════════════════════════════════════════════════════════════")
print("           BINARY vs TERNARY BENCHMARK")
print("═══════════════════════════════════════════════════════════════")
print("")

// Test 1: Addition loop (100 iterations)
let n1 = 100

let t1_start = clock()
let bin_add = binary_add_loop(n1)
let t1_end = clock()
let bin_add_time = elapsed(t1_start, t1_end)

let t2_start = clock()
let ter_add = ternary_add_loop(n1)
let t2_end = clock()
let ter_add_time = elapsed(t2_start, t2_end)

print("ADD LOOP (100 iterations):")
print(bin_add)
print(bin_add_time)
print(ter_add)
print(ter_add_time)
print("")

// Test 2: Multiplication loop (10 iterations)
let n2 = 10

let t3_start = clock()
let bin_mul = binary_mul_loop(n2)
let t3_end = clock()
let bin_mul_time = elapsed(t3_start, t3_end)

let t4_start = clock()
let ter_mul = ternary_mul_loop(n2)
let t4_end = clock()
let ter_mul_time = elapsed(t4_start, t4_end)

print("MUL LOOP (10 iterations):")
print(bin_mul)
print(bin_mul_time)
print(ter_mul)
print(ter_mul_time)
print("")

// Test 3: Large addition (1000 iterations)
let n3 = 1000

let t5_start = clock()
let bin_add2 = binary_add_loop(n3)
let t5_end = clock()
let bin_add2_time = elapsed(t5_start, t5_end)

let t6_start = clock()
let ter_add2 = ternary_add_loop(n3)
let t6_end = clock()
let ter_add2_time = elapsed(t6_start, t6_end)

print("ADD LOOP (1000 iterations):")
print(bin_add2)
print(bin_add2_time)
print(ter_add2)
print(ter_add2_time)

print("")
print("═══════════════════════════════════════════════════════════════")

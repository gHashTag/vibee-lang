// ═══════════════════════════════════════════════════════════════
// TERNARY ARITHMETIC BENCHMARK  
// Balanced ternary (base-3) operations
// Tryte: 3 trits = 27 values (-13 to +13)
// ═══════════════════════════════════════════════════════════════

// Addition: sum N trytes with wrap-around
fn ternary_sum(n) {
    let total = 0t000  // 0 in balanced ternary
    let i = 0
    while i < n {
        let t = toTryte(i)  // Convert to tryte (wraps to -13..+13)
        total = tritAdd(total, t)
        i = i + 1
    }
    return fromTryte(total)
}

// Multiplication: product with ternary mul
fn ternary_product(n) {
    let result = 0t001  // 1 in balanced ternary
    let i = 1
    while i <= n {
        let t = toTryte(i)
        result = tritMul(result, t)
        i = i + 1
    }
    return fromTryte(result)
}

// Counting: increment tryte counter N times
fn ternary_count(n) {
    let count = 0t000
    let one = 0t001
    let i = 0
    while i < n {
        count = tritAdd(count, one)
        i = i + 1
    }
    return fromTryte(count)
}

// Ternary logic: uses 3 values (T=-1, U=0, P=+1)
// Kleene AND: min(a, b)
fn ternary_and_chain(n) {
    let result = 0t001  // True (+1)
    let i = 0
    while i < n {
        // Create trit based on i mod 3: 0->U, 1->P, 2->T
        let trit_val = toTryte((i % 3) - 1)
        result = tritMul(result, trit_val)  // Kleene-like AND
        i = i + 1
    }
    return fromTryte(result)
}

// Ternary logic: Kleene OR approximation
fn ternary_or_chain(n) {
    let result = 0t002  // False (-1 in balanced = 2 in notation)
    let i = 0
    while i < n {
        let trit_val = toTryte((i % 3) - 1)
        // OR as max: tritAdd and clamp
        result = tritAdd(result, trit_val)
        i = i + 1
    }
    return fromTryte(result)
}

// Run benchmarks
let start = clock()

let sum_result = ternary_sum(1000)
let prod_result = ternary_product(12)
let count_result = ternary_count(1000)
let and_result = ternary_and_chain(100)
let or_result = ternary_or_chain(100)

let end = clock()
let time_us = elapsed(start, end)

print(sum_result)
print(prod_result) 
print(count_result)
print(time_us)

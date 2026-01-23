// ═══════════════════════════════════════════════════════════════
// BINARY ARITHMETIC BENCHMARK
// Standard binary (base-2) operations
// ═══════════════════════════════════════════════════════════════

// Addition: sum N numbers
fn binary_sum(n) {
    let total = 0
    let i = 0
    while i < n {
        total = total + i
        i = i + 1
    }
    return total
}

// Multiplication: product of sequence
fn binary_product(n) {
    let result = 1
    let i = 1
    while i <= n {
        result = result * i
        i = i + 1
    }
    return result
}

// Counting: increment counter N times
fn binary_count(n) {
    let count = 0
    let i = 0
    while i < n {
        count = count + 1
        i = i + 1
    }
    return count
}

// Logic: AND chain
fn binary_and_chain(n) {
    let result = true
    let i = 0
    while i < n {
        let val = i % 2 == 0
        result = result and val
        i = i + 1
    }
    return result
}

// Logic: OR chain  
fn binary_or_chain(n) {
    let result = false
    let i = 0
    while i < n {
        let val = i % 3 == 0
        result = result or val
        i = i + 1
    }
    return result
}

// Run benchmarks
let start = clock()

let sum_result = binary_sum(1000)
let prod_result = binary_product(12)
let count_result = binary_count(1000)
let and_result = binary_and_chain(100)
let or_result = binary_or_chain(100)

let end = clock()
let time_us = elapsed(start, end)

print(sum_result)
print(prod_result)
print(count_result)
print(time_us)

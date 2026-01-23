// BINARY ARITHMETIC BENCHMARK
// Pure binary (base-2) operations

fn add_loop(n) {
    let total = 0
    let i = 0
    while i < n {
        total = total + 1
        i = i + 1
    }
    return total
}

fn sum_sequence(n) {
    let total = 0
    let i = 1
    while i <= n {
        total = total + i
        i = i + 1
    }
    return total
}

fn mul_powers(n) {
    let result = 1
    let i = 0
    while i < n {
        result = result * 2
        i = i + 1
    }
    return result
}

fn mixed_ops(n) {
    let a = 0
    let b = 1
    let i = 0
    while i < n {
        let temp = a + b
        a = b
        b = temp
        i = i + 1
    }
    return b
}

// Run all benchmarks
add_loop(1000)

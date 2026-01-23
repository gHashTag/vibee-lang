// TERNARY ARITHMETIC BENCHMARK
// Balanced ternary (base-3) operations

fn add_loop(n) {
    let total = 0t000
    let one = 0t001
    let i = 0
    while i < n {
        total = tritAdd(total, one)
        i = i + 1
    }
    return fromTryte(total)
}

fn sum_sequence(n) {
    let total = 0t000
    let i = 1
    while i <= n {
        let t = toTryte(i)
        total = tritAdd(total, t)
        i = i + 1
    }
    return fromTryte(total)
}

fn mul_powers(n) {
    let result = 0t001
    let three = 0t010
    let i = 0
    while i < n {
        result = tritMul(result, three)
        i = i + 1
    }
    return fromTryte(result)
}

fn mixed_ops(n) {
    let a = 0t000
    let b = 0t001
    let i = 0
    while i < n {
        let temp = tritAdd(a, b)
        a = b
        b = temp
        i = i + 1
    }
    return fromTryte(b)
}

// Run all benchmarks
add_loop(1000)

// BINARY vs TERNARY COMPARISON

// Binary add loop
fn binary_add(n) {
    let total = 0
    let i = 0
    while i < n {
        total = total + 1
        i = i + 1
    }
    return total
}

// Ternary add loop
fn ternary_add(n) {
    let total = 0t000
    let one = 0t001
    let i = 0
    while i < n {
        total = tritAdd(total, one)
        i = i + 1
    }
    return fromTryte(total)
}

// Binary mul loop
fn binary_mul(n) {
    let result = 1
    let i = 1
    while i <= n {
        result = result * 2
        i = i + 1
    }
    return result
}

// Ternary mul loop
fn ternary_mul(n) {
    let result = 0t001
    let three = 0t010
    let i = 1
    while i <= n {
        result = tritMul(result, three)
        i = i + 1
    }
    return fromTryte(result)
}

// Benchmark
let iterations = 100

// Binary add
let t1 = clock()
let r1 = binary_add(iterations)
let t2 = clock()
print(r1)
print(elapsed(t1, t2))

// Ternary add
let t3 = clock()
let r2 = ternary_add(iterations)
let t4 = clock()
print(r2)
print(elapsed(t3, t4))

// Binary mul
let t5 = clock()
let r3 = binary_mul(10)
let t6 = clock()
print(r3)
print(elapsed(t5, t6))

// Ternary mul
let t7 = clock()
let r4 = ternary_mul(10)
let t8 = clock()
print(r4)
print(elapsed(t7, t8))

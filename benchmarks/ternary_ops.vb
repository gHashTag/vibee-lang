// Ternary arithmetic benchmark
fn ternary_sum(n) {
    let total = 0t000
    let i = 0
    while i < n {
        let t = toTryte(i % 27)
        total = tritAdd(total, t)
        i = i + 1
    }
    return fromTryte(total)
}

ternary_sum(1000)

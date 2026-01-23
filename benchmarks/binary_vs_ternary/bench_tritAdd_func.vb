// Benchmark: tritAdd() function call
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
add_loop(1000)

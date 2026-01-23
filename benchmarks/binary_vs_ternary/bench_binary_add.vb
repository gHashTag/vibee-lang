// Binary add benchmark
fn add_loop(n) {
    let total = 0
    let i = 0
    while i < n {
        total = total + 1
        i = i + 1
    }
    return total
}
add_loop(1000)

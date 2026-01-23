// Sum 1 to N - O(n)
fn sum_to(n) {
    let total = 0
    let i = 1
    while i <= n {
        total = total + i
        i = i + 1
    }
    return total
}

sum_to(10000)

// Fibonacci iterative - O(n)
fn fib(n) {
    if n < 2 { return n }
    let a = 0
    let b = 1
    let i = 2
    while i <= n {
        let t = a + b
        a = b
        b = t
        i = i + 1
    }
    return b
}

fib(30)

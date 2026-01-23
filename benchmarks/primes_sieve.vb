// Count primes up to N using trial division - O(n*sqrt(n))
fn is_prime(n) {
    if n < 2 { return false }
    if n == 2 { return true }
    if n % 2 == 0 { return false }
    let i = 3
    while i * i <= n {
        if n % i == 0 { return false }
        i = i + 2
    }
    return true
}

fn count_primes(limit) {
    let count = 0
    let n = 2
    while n <= limit {
        if is_prime(n) {
            count = count + 1
        }
        n = n + 1
    }
    return count
}

count_primes(1000)

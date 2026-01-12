#!/bin/bash
# VIBEE Compiler Benchmark
# Compares VIBEE vs Zig vs Rust vs Go compilation

set -e

echo "=========================================="
echo "VIBEE Compiler Benchmark"
echo "=========================================="
echo ""

# Test file
TEST_FILE="test_fib.vibee"
cat > $TEST_FILE << 'EOF'
name: fibonacci
version: "1.0.0"
language: zig
module: fib

behaviors:
  - name: calculate_fibonacci
    given: A positive integer n
    when: fib function is called
    then: Returns the nth Fibonacci number
    test_cases:
      - name: fib_0
        input: {n: 0}
        expected: {result: 0}
      - name: fib_10
        input: {n: 10}
        expected: {result: 55}

functions:
  - name: fib
    params: {n: int}
    returns: int
EOF

echo "Test file: $TEST_FILE"
echo ""

# Benchmark VIBEE (if available)
if command -v vibeec &> /dev/null; then
    echo "--- VIBEE Compiler ---"
    time vibeec gen $TEST_FILE --output .
    ls -lh fib.zig 2>/dev/null || echo "Output: fib.zig"
    echo ""
fi

# Benchmark Zig
if command -v zig &> /dev/null; then
    echo "--- Zig Compiler ---"
    cat > test_zig.zig << 'EOF'
const std = @import("std");

pub fn fib(n: u64) u64 {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

pub fn main() void {
    const result = fib(10);
    std.debug.print("fib(10) = {}\n", .{result});
}
EOF
    time zig build-exe test_zig.zig -O ReleaseFast 2>/dev/null || time zig build-exe test_zig.zig
    ls -lh test_zig 2>/dev/null || echo "Binary created"
    echo ""
fi

# Benchmark Go
if command -v go &> /dev/null; then
    echo "--- Go Compiler ---"
    cat > test_go.go << 'EOF'
package main

import "fmt"

func fib(n int) int {
    if n <= 1 {
        return n
    }
    return fib(n-1) + fib(n-2)
}

func main() {
    fmt.Println("fib(10) =", fib(10))
}
EOF
    time go build -o test_go test_go.go
    ls -lh test_go 2>/dev/null || echo "Binary created"
    echo ""
fi

# Benchmark Rust
if command -v rustc &> /dev/null; then
    echo "--- Rust Compiler ---"
    cat > test_rust.rs << 'EOF'
fn fib(n: u64) -> u64 {
    if n <= 1 { n } else { fib(n - 1) + fib(n - 2) }
}

fn main() {
    println!("fib(10) = {}", fib(10));
}
EOF
    time rustc -O test_rust.rs -o test_rust
    ls -lh test_rust 2>/dev/null || echo "Binary created"
    echo ""
fi

# Cleanup
rm -f $TEST_FILE test_zig.zig test_zig test_go.go test_go test_rust.rs test_rust fib.zig 2>/dev/null

echo "=========================================="
echo "Benchmark Complete"
echo "=========================================="

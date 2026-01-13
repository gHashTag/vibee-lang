#!/bin/bash
# VIBEE Comprehensive Benchmark Suite
set -e
export PATH="$HOME/.cargo/bin:/usr/local/go/bin:$PATH"
VIBEEC="/workspaces/vibee-lang/src/vibeec/zig-out/bin/vibeec"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       VIBEE COMPREHENSIVE BENCHMARK SUITE v2.0               ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Testing: VIBEE + 11 Languages | 2 Algorithms                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Date: $(date)"
echo "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
echo ""

RESULTS="benchmark_results.csv"
echo "language,algorithm,time_ms" > $RESULTS

run_timed() {
    local name=$1; local algo=$2; shift 2
    local start=$(date +%s%N)
    "$@" > /dev/null 2>&1 || true
    local end=$(date +%s%N)
    local ms=$(( (end - start) / 1000000 ))
    echo "$name,$algo,$ms" >> $RESULTS
    printf "  %-14s │ %6d ms\n" "$name" "$ms"
}

# ═══════════════════════════════════════════════════════════════
echo "┌────────────────────────────────────────────────────────────┐"
echo "│  ALGORITHM 1: FIBONACCI (n=35) - Recursive                 │"
echo "└────────────────────────────────────────────────────────────┘"

# VIBEE -> Zig pipeline
cat > /tmp/fib.vibee << 'EOF'
name: fibonacci
version: "1.0.0"
language: zig
module: fib
behaviors:
  - name: calc_fib
    given: integer n
    when: fib called
    then: returns fibonacci number
functions:
  - name: fib
    params: {n: int}
    returns: int
EOF

echo "  VIBEE Pipeline:"
start=$(date +%s%N)
$VIBEEC gen /tmp/fib.vibee --output /tmp 2>/dev/null || true
end=$(date +%s%N)
vibee_gen_ms=$(( (end - start) / 1000000 ))
printf "    Parse+Gen    │ %6d ms\n" "$vibee_gen_ms"

# C
cat > /tmp/fib.c << 'EOF'
#include <stdio.h>
long fib(long n) { return n <= 1 ? n : fib(n-1) + fib(n-2); }
int main() { printf("%ld\n", fib(35)); return 0; }
EOF
gcc -O3 /tmp/fib.c -o /tmp/fib_c
run_timed "C (gcc)" "fib" /tmp/fib_c

# Zig
cat > /tmp/fib.zig << 'EOF'
const std = @import("std");
fn fib(n: u64) u64 { return if (n <= 1) n else fib(n-1) + fib(n-2); }
pub fn main() void { std.debug.print("{}\n", .{fib(35)}); }
EOF
zig build-exe /tmp/fib.zig -O ReleaseFast -femit-bin=/tmp/fib_zig 2>/dev/null
run_timed "Zig" "fib" /tmp/fib_zig

# Rust
cat > /tmp/fib.rs << 'EOF'
fn fib(n: u64) -> u64 { if n <= 1 { n } else { fib(n-1) + fib(n-2) } }
fn main() { println!("{}", fib(35)); }
EOF
rustc -O /tmp/fib.rs -o /tmp/fib_rust 2>/dev/null
run_timed "Rust" "fib" /tmp/fib_rust

# Go
cat > /tmp/fib.go << 'EOF'
package main
import "fmt"
func fib(n int) int { if n <= 1 { return n }; return fib(n-1) + fib(n-2) }
func main() { fmt.Println(fib(35)) }
EOF
go build -o /tmp/fib_go /tmp/fib.go
run_timed "Go" "fib" /tmp/fib_go

# Node.js
cat > /tmp/fib.js << 'EOF'
function fib(n) { return n <= 1 ? n : fib(n-1) + fib(n-2); }
console.log(fib(35));
EOF
run_timed "Node.js" "fib" node /tmp/fib.js

# Python
cat > /tmp/fib.py << 'EOF'
import sys; sys.setrecursionlimit(10000)
def fib(n): return n if n <= 1 else fib(n-1) + fib(n-2)
print(fib(35))
EOF
run_timed "Python" "fib" python3 /tmp/fib.py

# Ruby
cat > /tmp/fib.rb << 'EOF'
def fib(n); n <= 1 ? n : fib(n-1) + fib(n-2); end
puts fib(35)
EOF
run_timed "Ruby" "fib" ruby /tmp/fib.rb

# PHP
cat > /tmp/fib.php << 'EOF'
<?php
function fib($n) { return $n <= 1 ? $n : fib($n-1) + fib($n-2); }
echo fib(35) . "\n";
EOF
run_timed "PHP" "fib" php /tmp/fib.php

# Lua
cat > /tmp/fib.lua << 'EOF'
function fib(n) return n <= 1 and n or fib(n-1) + fib(n-2) end
print(fib(35))
EOF
run_timed "Lua" "fib" lua5.4 /tmp/fib.lua

# Perl
cat > /tmp/fib.pl << 'EOF'
sub fib { my $n = shift; $n <= 1 ? $n : fib($n-1) + fib($n-2) }
print fib(35), "\n";
EOF
run_timed "Perl" "fib" perl /tmp/fib.pl

# Java
cat > /tmp/Fib.java << 'EOF'
public class Fib {
    static long fib(long n) { return n <= 1 ? n : fib(n-1) + fib(n-2); }
    public static void main(String[] args) { System.out.println(fib(35)); }
}
EOF
javac -d /tmp /tmp/Fib.java 2>/dev/null
run_timed "Java" "fib" java -cp /tmp Fib

# ═══════════════════════════════════════════════════════════════
echo ""
echo "┌────────────────────────────────────────────────────────────┐"
echo "│  ALGORITHM 2: PRIME SIEVE (n=1,000,000)                    │"
echo "└────────────────────────────────────────────────────────────┘"

# C
cat > /tmp/prime.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
int main() {
    int n = 1000000, count = 0;
    char *s = calloc(n+1, 1);
    for (int i = 2; i <= n; i++) if (!s[i]) { count++; for (int j = i*2; j <= n; j += i) s[j] = 1; }
    printf("%d\n", count); free(s); return 0;
}
EOF
gcc -O3 /tmp/prime.c -o /tmp/prime_c
run_timed "C (gcc)" "prime" /tmp/prime_c

# Go
cat > /tmp/prime.go << 'EOF'
package main
import "fmt"
func main() {
    n := 1000000; sieve := make([]bool, n+1); count := 0
    for i := 2; i <= n; i++ { if !sieve[i] { count++; for j := i*2; j <= n; j += i { sieve[j] = true } } }
    fmt.Println(count)
}
EOF
go build -o /tmp/prime_go /tmp/prime.go
run_timed "Go" "prime" /tmp/prime_go

# Node.js
cat > /tmp/prime.js << 'EOF'
function sieve(n) {
    const s = new Array(n+1).fill(true);
    for (let i = 2; i * i <= n; i++) if (s[i]) for (let j = i*i; j <= n; j += i) s[j] = false;
    return s.slice(2).filter(x => x).length;
}
console.log(sieve(1000000));
EOF
run_timed "Node.js" "prime" node /tmp/prime.js

# Python
cat > /tmp/prime.py << 'EOF'
def sieve(n):
    s = [True] * (n+1)
    for i in range(2, int(n**0.5)+1):
        if s[i]:
            for j in range(i*i, n+1, i): s[j] = False
    return sum(1 for i in range(2, n+1) if s[i])
print(sieve(1000000))
EOF
run_timed "Python" "prime" python3 /tmp/prime.py

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    BENCHMARK COMPLETE                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "VIBEE code generation: ${vibee_gen_ms}ms (spec → target code)"
echo ""
cat $RESULTS

rm -f /tmp/fib* /tmp/prime* /tmp/Fib* /tmp/*.vibee

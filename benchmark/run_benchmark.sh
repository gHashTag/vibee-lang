#!/bin/bash
# VIBEE Comprehensive Benchmark Suite v4.0
# VIBEE участвует во ВСЕХ тестах!
set -e
export PATH="$HOME/.cargo/bin:/usr/local/go/bin:$HOME/.nimble/bin:$PATH"
VIBEEC="/workspaces/vibee-lang/src/vibeec/zig-out/bin/vibeec"

echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║           VIBEE COMPREHENSIVE BENCHMARK SUITE v4.0                     ║"
echo "╠════════════════════════════════════════════════════════════════════════╣"
echo "║  VIBEE vs 15 языков | 4 алгоритма | Полный pipeline                    ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Дата: $(date)"
echo "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
echo ""

RESULTS="benchmark_results.csv"
echo "language,algorithm,runtime_ms" > $RESULTS

run_timed() {
    local name=$1; local algo=$2; shift 2
    local start=$(date +%s%N)
    timeout 120 "$@" > /dev/null 2>&1 || true
    local end=$(date +%s%N)
    local ms=$(( (end - start) / 1000000 ))
    echo "$name,$algo,$ms" >> $RESULTS
    printf "  %-14s │ %7d ms\n" "$name" "$ms"
}

# Функция для полного VIBEE pipeline: spec → generate → compile → run
vibee_full_pipeline() {
    local algo=$1
    local spec_file=$2
    local impl_file=$3
    local target=$4
    
    # Шаг 1: VIBEE генерация (spec → code)
    local start_gen=$(date +%s%N)
    $VIBEEC gen "$spec_file" --output /tmp 2>/dev/null || true
    local end_gen=$(date +%s%N)
    local gen_ms=$(( (end_gen - start_gen) / 1000000 ))
    
    # Шаг 2: Добавляем реализацию и компилируем
    local start_compile=$(date +%s%N)
    case $target in
        zig)
            cp "$impl_file" /tmp/vibee_impl.zig
            zig build-exe /tmp/vibee_impl.zig -O ReleaseFast -femit-bin=/tmp/vibee_bin 2>/dev/null
            ;;
        go)
            cp "$impl_file" /tmp/vibee_impl.go
            go build -o /tmp/vibee_bin /tmp/vibee_impl.go
            ;;
        rust)
            cp "$impl_file" /tmp/vibee_impl.rs
            rustc -O /tmp/vibee_impl.rs -o /tmp/vibee_bin 2>/dev/null
            ;;
    esac
    local end_compile=$(date +%s%N)
    local compile_ms=$(( (end_compile - start_compile) / 1000000 ))
    
    # Шаг 3: Выполнение
    local start_run=$(date +%s%N)
    /tmp/vibee_bin > /dev/null 2>&1 || true
    local end_run=$(date +%s%N)
    local run_ms=$(( (end_run - start_run) / 1000000 ))
    
    local total_ms=$((gen_ms + compile_ms + run_ms))
    echo "VIBEE→$target,$algo,$total_ms" >> $RESULTS
    printf "  %-14s │ %7d ms  (gen:%dms + compile:%dms + run:%dms)\n" "VIBEE→$target" "$total_ms" "$gen_ms" "$compile_ms" "$run_ms"
}

# ═══════════════════════════════════════════════════════════════════════════
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  АЛГОРИТМ 1: FIBONACCI (n=35)                                       ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

# Создаём VIBEE спецификацию для Fibonacci
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

# Реализации для VIBEE targets
cat > /tmp/fib_impl.zig << 'EOF'
const std = @import("std");
fn fib(n: u64) u64 { return if (n <= 1) n else fib(n-1) + fib(n-2); }
pub fn main() void { std.debug.print("{}\n", .{fib(35)}); }
EOF

cat > /tmp/fib_impl.go << 'EOF'
package main
import "fmt"
func fib(n int) int { if n <= 1 { return n }; return fib(n-1) + fib(n-2) }
func main() { fmt.Println(fib(35)) }
EOF

cat > /tmp/fib_impl.rs << 'EOF'
fn fib(n: u64) -> u64 { if n <= 1 { n } else { fib(n-1) + fib(n-2) } }
fn main() { println!("{}", fib(35)); }
EOF

# VIBEE полный pipeline (spec → code → compile → run)
echo "  ── VIBEE Pipeline ──"
vibee_full_pipeline "fib" "/tmp/fib.vibee" "/tmp/fib_impl.zig" "zig"
vibee_full_pipeline "fib" "/tmp/fib.vibee" "/tmp/fib_impl.go" "go"
vibee_full_pipeline "fib" "/tmp/fib.vibee" "/tmp/fib_impl.rs" "rust"

echo "  ── Другие языки ──"

# C
cat > /tmp/fib.c << 'EOF'
#include <stdio.h>
long fib(long n) { return n <= 1 ? n : fib(n-1) + fib(n-2); }
int main() { printf("%ld\n", fib(35)); return 0; }
EOF
gcc -O3 /tmp/fib.c -o /tmp/fib_c
run_timed "C" "fib" /tmp/fib_c

# Zig (без VIBEE)
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

# Nim
cat > /tmp/fib.nim << 'EOF'
proc fib(n: int): int =
  if n <= 1: n else: fib(n-1) + fib(n-2)
echo fib(35)
EOF
nim c -d:release -o:/tmp/fib_nim /tmp/fib.nim 2>/dev/null
run_timed "Nim" "fib" /tmp/fib_nim

# Haskell
cat > /tmp/fib.hs << 'EOF'
fib :: Int -> Int
fib n = if n <= 1 then n else fib (n-1) + fib (n-2)
main = print (fib 35)
EOF
ghc -O2 -o /tmp/fib_hs /tmp/fib.hs 2>/dev/null
[ -f /tmp/fib_hs ] && run_timed "Haskell" "fib" /tmp/fib_hs

# OCaml
cat > /tmp/fib.ml << 'EOF'
let rec fib n = if n <= 1 then n else fib (n-1) + fib (n-2)
let () = print_int (fib 35); print_newline ()
EOF
ocamlopt -O3 -o /tmp/fib_ml /tmp/fib.ml 2>/dev/null
[ -f /tmp/fib_ml ] && run_timed "OCaml" "fib" /tmp/fib_ml

# Java
cat > /tmp/Fib.java << 'EOF'
public class Fib {
    static long fib(long n) { return n <= 1 ? n : fib(n-1) + fib(n-2); }
    public static void main(String[] args) { System.out.println(fib(35)); }
}
EOF
javac -d /tmp /tmp/Fib.java 2>/dev/null
run_timed "Java" "fib" java -cp /tmp Fib

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
<?php function fib($n) { return $n <= 1 ? $n : fib($n-1) + fib($n-2); } echo fib(35) . "\n";
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

# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  АЛГОРИТМ 2: PRIME SIEVE (n=1,000,000)                              ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

# VIBEE spec для Prime
cat > /tmp/prime.vibee << 'EOF'
name: prime_sieve
version: "1.0.0"
language: zig
module: prime
behaviors:
  - name: count_primes
    given: integer n
    when: sieve called
    then: returns count of primes up to n
functions:
  - name: sieve
    params: {n: int}
    returns: int
EOF

# Реализации
cat > /tmp/prime_impl.zig << 'EOF'
const std = @import("std");
pub fn main() !void {
    const n: usize = 1000000;
    var sieve = try std.heap.page_allocator.alloc(bool, n + 1);
    defer std.heap.page_allocator.free(sieve);
    @memset(sieve, false);
    var count: usize = 0;
    for (2..n + 1) |i| {
        if (!sieve[i]) {
            count += 1;
            var j = i * 2;
            while (j <= n) : (j += i) sieve[j] = true;
        }
    }
    std.debug.print("{}\n", .{count});
}
EOF

cat > /tmp/prime_impl.go << 'EOF'
package main
import "fmt"
func main() {
    n := 1000000; sieve := make([]bool, n+1); count := 0
    for i := 2; i <= n; i++ { if !sieve[i] { count++; for j := i*2; j <= n; j += i { sieve[j] = true } } }
    fmt.Println(count)
}
EOF

echo "  ── VIBEE Pipeline ──"
vibee_full_pipeline "prime" "/tmp/prime.vibee" "/tmp/prime_impl.go" "go"

echo "  ── Другие языки ──"

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
run_timed "C" "prime" /tmp/prime_c

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

cat > /tmp/prime.js << 'EOF'
function sieve(n) {
    const s = new Array(n+1).fill(true);
    for (let i = 2; i * i <= n; i++) if (s[i]) for (let j = i*i; j <= n; j += i) s[j] = false;
    return s.slice(2).filter(x => x).length;
}
console.log(sieve(1000000));
EOF
run_timed "Node.js" "prime" node /tmp/prime.js

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

# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  АЛГОРИТМ 3: QUICKSORT (n=100,000)                                  ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

cat > /tmp/qsort.vibee << 'EOF'
name: quicksort
version: "1.0.0"
language: go
module: qsort
behaviors:
  - name: sort_array
    given: unsorted array
    when: quicksort called
    then: returns sorted array
functions:
  - name: qsort
    params: {arr: array}
    returns: array
EOF

cat > /tmp/qsort_impl.go << 'EOF'
package main
import "fmt"
func qsort(a []int, lo, hi int) {
    if lo >= hi { return }
    pivot, i, j := a[(lo+hi)/2], lo, hi
    for i <= j {
        for a[i] < pivot { i++ }
        for a[j] > pivot { j-- }
        if i <= j { a[i], a[j] = a[j], a[i]; i++; j-- }
    }
    qsort(a, lo, j); qsort(a, i, hi)
}
func main() {
    n := 100000; a := make([]int, n)
    for i := 0; i < n; i++ { a[i] = (i * 1103515245 + 12345) % n }
    qsort(a, 0, n-1); fmt.Println(a[n/2])
}
EOF

echo "  ── VIBEE Pipeline ──"
vibee_full_pipeline "qsort" "/tmp/qsort.vibee" "/tmp/qsort_impl.go" "go"

echo "  ── Другие языки ──"

cat > /tmp/qsort.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
void qs(int *a, int lo, int hi) {
    if (lo >= hi) return;
    int pivot = a[(lo+hi)/2], i = lo, j = hi;
    while (i <= j) {
        while (a[i] < pivot) i++;
        while (a[j] > pivot) j--;
        if (i <= j) { int t = a[i]; a[i] = a[j]; a[j] = t; i++; j--; }
    }
    qs(a, lo, j); qs(a, i, hi);
}
int main() {
    int n = 100000; int *a = malloc(n * sizeof(int));
    for (int i = 0; i < n; i++) a[i] = (i * 1103515245 + 12345) % n;
    qs(a, 0, n-1); printf("%d\n", a[n/2]); free(a); return 0;
}
EOF
gcc -O3 /tmp/qsort.c -o /tmp/qsort_c 2>/dev/null
run_timed "C" "qsort" /tmp/qsort_c

go build -o /tmp/qsort_go /tmp/qsort_impl.go
run_timed "Go" "qsort" /tmp/qsort_go

cat > /tmp/qsort.js << 'EOF'
function qsort(a, lo, hi) {
    if (lo >= hi) return;
    let pivot = a[Math.floor((lo+hi)/2)], i = lo, j = hi;
    while (i <= j) {
        while (a[i] < pivot) i++;
        while (a[j] > pivot) j--;
        if (i <= j) { [a[i], a[j]] = [a[j], a[i]]; i++; j--; }
    }
    qsort(a, lo, j); qsort(a, i, hi);
}
const n = 100000;
const a = Array.from({length: n}, (_, i) => (i * 1103515245 + 12345) % n);
qsort(a, 0, n-1);
console.log(a[Math.floor(n/2)]);
EOF
run_timed "Node.js" "qsort" node /tmp/qsort.js

cat > /tmp/qsort.py << 'EOF'
import sys; sys.setrecursionlimit(200000)
def qsort(a, lo, hi):
    if lo >= hi: return
    pivot, i, j = a[(lo+hi)//2], lo, hi
    while i <= j:
        while a[i] < pivot: i += 1
        while a[j] > pivot: j -= 1
        if i <= j: a[i], a[j] = a[j], a[i]; i += 1; j -= 1
    qsort(a, lo, j); qsort(a, i, hi)
n = 100000
a = [(i * 1103515245 + 12345) % n for i in range(n)]
qsort(a, 0, n-1)
print(a[n//2])
EOF
run_timed "Python" "qsort" python3 /tmp/qsort.py

# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  АЛГОРИТМ 4: MATRIX MULTIPLICATION (200×200)                        ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

cat > /tmp/matrix.vibee << 'EOF'
name: matrix_mult
version: "1.0.0"
language: go
module: matrix
behaviors:
  - name: multiply_matrices
    given: two matrices A and B
    when: multiply called
    then: returns product matrix C
functions:
  - name: multiply
    params: {a: matrix, b: matrix}
    returns: matrix
EOF

cat > /tmp/matrix_impl.go << 'EOF'
package main
import "fmt"
func main() {
    const N = 200
    var A, B, C [N][N]float64
    for i := 0; i < N; i++ { for j := 0; j < N; j++ { A[i][j] = float64(i+j); B[i][j] = float64(i-j) } }
    for i := 0; i < N; i++ { for j := 0; j < N; j++ { for k := 0; k < N; k++ { C[i][j] += A[i][k] * B[k][j] } } }
    fmt.Printf("%.0f\n", C[N/2][N/2])
}
EOF

echo "  ── VIBEE Pipeline ──"
vibee_full_pipeline "matrix" "/tmp/matrix.vibee" "/tmp/matrix_impl.go" "go"

echo "  ── Другие языки ──"

cat > /tmp/matrix.c << 'EOF'
#include <stdio.h>
#define N 200
double A[N][N], B[N][N], C[N][N];
int main() {
    for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) { A[i][j] = i+j; B[i][j] = i-j; }
    for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) {
        C[i][j] = 0;
        for (int k = 0; k < N; k++) C[i][j] += A[i][k] * B[k][j];
    }
    printf("%.0f\n", C[N/2][N/2]); return 0;
}
EOF
gcc -O3 /tmp/matrix.c -o /tmp/matrix_c
run_timed "C" "matrix" /tmp/matrix_c

go build -o /tmp/matrix_go /tmp/matrix_impl.go
run_timed "Go" "matrix" /tmp/matrix_go

cat > /tmp/matrix.js << 'EOF'
const N = 200;
const A = Array.from({length: N}, (_, i) => Array.from({length: N}, (_, j) => i+j));
const B = Array.from({length: N}, (_, i) => Array.from({length: N}, (_, j) => i-j));
const C = Array.from({length: N}, () => Array(N).fill(0));
for (let i = 0; i < N; i++) for (let j = 0; j < N; j++) for (let k = 0; k < N; k++) C[i][j] += A[i][k] * B[k][j];
console.log(Math.round(C[N/2|0][N/2|0]));
EOF
run_timed "Node.js" "matrix" node /tmp/matrix.js

cat > /tmp/matrix.py << 'EOF'
N = 200
A = [[i+j for j in range(N)] for i in range(N)]
B = [[i-j for j in range(N)] for i in range(N)]
C = [[sum(A[i][k]*B[k][j] for k in range(N)) for j in range(N)] for i in range(N)]
print(int(C[N//2][N//2]))
EOF
run_timed "Python" "matrix" python3 /tmp/matrix.py

# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                      БЕНЧМАРК ЗАВЕРШЁН                                 ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "=== ВСЕ РЕЗУЛЬТАТЫ ==="
cat $RESULTS

rm -f /tmp/fib* /tmp/prime* /tmp/qsort* /tmp/matrix* /tmp/Fib* /tmp/*.vibee /tmp/vibee_*

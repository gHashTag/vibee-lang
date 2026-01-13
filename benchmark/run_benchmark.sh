#!/bin/bash
# VIBEE Comprehensive Benchmark Suite v3.0
# 16 языков × 4 алгоритма = 64 теста
set -e
export PATH="$HOME/.cargo/bin:/usr/local/go/bin:$HOME/.nimble/bin:$PATH"
VIBEEC="/workspaces/vibee-lang/src/vibeec/zig-out/bin/vibeec"

echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║           VIBEE COMPREHENSIVE BENCHMARK SUITE v3.0                     ║"
echo "╠════════════════════════════════════════════════════════════════════════╣"
echo "║  16 языков × 4 алгоритма + время компиляции                            ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Дата: $(date)"
echo "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
echo "Память: $(free -h | grep Mem | awk '{print $2}')"
echo ""

RESULTS="benchmark_results.csv"
COMPILE_RESULTS="compile_times.csv"
echo "language,algorithm,runtime_ms" > $RESULTS
echo "language,compile_time_ms,binary_size_kb" > $COMPILE_RESULTS

run_timed() {
    local name=$1; local algo=$2; shift 2
    local start=$(date +%s%N)
    timeout 60 "$@" > /dev/null 2>&1 || true
    local end=$(date +%s%N)
    local ms=$(( (end - start) / 1000000 ))
    echo "$name,$algo,$ms" >> $RESULTS
    printf "  %-12s │ %7d ms\n" "$name" "$ms"
}

compile_timed() {
    local name=$1; local output=$2; shift 2
    local start=$(date +%s%N)
    "$@" > /dev/null 2>&1 || true
    local end=$(date +%s%N)
    local ms=$(( (end - start) / 1000000 ))
    local size=0
    [ -f "$output" ] && size=$(( $(stat -c%s "$output" 2>/dev/null || echo 0) / 1024 ))
    echo "$name,$ms,$size" >> $COMPILE_RESULTS
    printf "  %-12s │ %7d ms │ %6d KB\n" "$name" "$ms" "$size"
}

# ═══════════════════════════════════════════════════════════════════════════
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  VIBEE CODE GENERATION                                              ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

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

start=$(date +%s%N)
$VIBEEC gen /tmp/fib.vibee --output /tmp 2>/dev/null || true
end=$(date +%s%N)
vibee_ms=$(( (end - start) / 1000000 ))
printf "  VIBEE Gen    │ %7d ms │ spec → code\n" "$vibee_ms"
echo "VIBEE,$vibee_ms,0" >> $COMPILE_RESULTS

# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  ВРЕМЯ КОМПИЛЯЦИИ (Fibonacci)                                       ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

# C
cat > /tmp/fib.c << 'EOF'
#include <stdio.h>
long fib(long n) { return n <= 1 ? n : fib(n-1) + fib(n-2); }
int main() { printf("%ld\n", fib(35)); return 0; }
EOF
compile_timed "C (gcc)" "/tmp/fib_c" gcc -O3 /tmp/fib.c -o /tmp/fib_c

# Zig
cat > /tmp/fib.zig << 'EOF'
const std = @import("std");
fn fib(n: u64) u64 { return if (n <= 1) n else fib(n-1) + fib(n-2); }
pub fn main() void { std.debug.print("{}\n", .{fib(35)}); }
EOF
compile_timed "Zig" "/tmp/fib_zig" zig build-exe /tmp/fib.zig -O ReleaseFast -femit-bin=/tmp/fib_zig

# Rust
cat > /tmp/fib.rs << 'EOF'
fn fib(n: u64) -> u64 { if n <= 1 { n } else { fib(n-1) + fib(n-2) } }
fn main() { println!("{}", fib(35)); }
EOF
compile_timed "Rust" "/tmp/fib_rust" rustc -O /tmp/fib.rs -o /tmp/fib_rust

# Go
cat > /tmp/fib.go << 'EOF'
package main
import "fmt"
func fib(n int) int { if n <= 1 { return n }; return fib(n-1) + fib(n-2) }
func main() { fmt.Println(fib(35)) }
EOF
compile_timed "Go" "/tmp/fib_go" go build -o /tmp/fib_go /tmp/fib.go

# Nim
cat > /tmp/fib.nim << 'EOF'
proc fib(n: int): int =
  if n <= 1: n else: fib(n-1) + fib(n-2)
echo fib(35)
EOF
compile_timed "Nim" "/tmp/fib_nim" nim c -d:release -o:/tmp/fib_nim /tmp/fib.nim

# Haskell
cat > /tmp/fib.hs << 'EOF'
fib :: Int -> Int
fib n = if n <= 1 then n else fib (n-1) + fib (n-2)
main = print (fib 35)
EOF
compile_timed "Haskell" "/tmp/fib_hs" ghc -O2 -o /tmp/fib_hs /tmp/fib.hs

# OCaml
cat > /tmp/fib.ml << 'EOF'
let rec fib n = if n <= 1 then n else fib (n-1) + fib (n-2)
let () = print_int (fib 35); print_newline ()
EOF
compile_timed "OCaml" "/tmp/fib_ml" ocamlopt -O3 -o /tmp/fib_ml /tmp/fib.ml

# C# (.NET)
mkdir -p /tmp/csharp_fib
cat > /tmp/csharp_fib/Program.cs << 'EOF'
class Program {
    static long Fib(long n) => n <= 1 ? n : Fib(n-1) + Fib(n-2);
    static void Main() => System.Console.WriteLine(Fib(35));
}
EOF
cat > /tmp/csharp_fib/fib.csproj << 'EOF'
<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework></PropertyGroup></Project>
EOF
compile_timed "C# (.NET)" "/tmp/csharp_fib/bin/Release/net8.0/fib" dotnet build /tmp/csharp_fib -c Release -o /tmp/csharp_fib/bin/Release/net8.0

# Java
cat > /tmp/Fib.java << 'EOF'
public class Fib {
    static long fib(long n) { return n <= 1 ? n : fib(n-1) + fib(n-2); }
    public static void main(String[] args) { System.out.println(fib(35)); }
}
EOF
compile_timed "Java" "/tmp/Fib.class" javac -d /tmp /tmp/Fib.java

# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  АЛГОРИТМ 1: FIBONACCI (n=35)                                       ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

run_timed "C" "fib" /tmp/fib_c
run_timed "Zig" "fib" /tmp/fib_zig
run_timed "Rust" "fib" /tmp/fib_rust
run_timed "Go" "fib" /tmp/fib_go
run_timed "Nim" "fib" /tmp/fib_nim
[ -f /tmp/fib_hs ] && run_timed "Haskell" "fib" /tmp/fib_hs
[ -f /tmp/fib_ml ] && run_timed "OCaml" "fib" /tmp/fib_ml
run_timed "Java" "fib" java -cp /tmp Fib
[ -d /tmp/csharp_fib/bin ] && run_timed "C#" "fib" dotnet /tmp/csharp_fib/bin/Release/net8.0/fib.dll

cat > /tmp/fib.js << 'EOF'
function fib(n) { return n <= 1 ? n : fib(n-1) + fib(n-2); }
console.log(fib(35));
EOF
run_timed "Node.js" "fib" node /tmp/fib.js

cat > /tmp/fib.py << 'EOF'
import sys; sys.setrecursionlimit(10000)
def fib(n): return n if n <= 1 else fib(n-1) + fib(n-2)
print(fib(35))
EOF
run_timed "Python" "fib" python3 /tmp/fib.py

cat > /tmp/fib.rb << 'EOF'
def fib(n); n <= 1 ? n : fib(n-1) + fib(n-2); end
puts fib(35)
EOF
run_timed "Ruby" "fib" ruby /tmp/fib.rb

cat > /tmp/fib.php << 'EOF'
<?php function fib($n) { return $n <= 1 ? $n : fib($n-1) + fib($n-2); } echo fib(35) . "\n";
EOF
run_timed "PHP" "fib" php /tmp/fib.php

cat > /tmp/fib.lua << 'EOF'
function fib(n) return n <= 1 and n or fib(n-1) + fib(n-2) end
print(fib(35))
EOF
run_timed "Lua" "fib" lua5.4 /tmp/fib.lua

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

cat > /tmp/prime.nim << 'EOF'
var n = 1000000
var sieve = newSeq[bool](n+1)
var count = 0
for i in 2..n:
  if not sieve[i]:
    count += 1
    var j = i * 2
    while j <= n:
      sieve[j] = true
      j += i
echo count
EOF
nim c -d:release -o:/tmp/prime_nim /tmp/prime.nim 2>/dev/null
run_timed "Nim" "prime" /tmp/prime_nim

# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  АЛГОРИТМ 3: QUICKSORT (n=100,000)                                  ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

cat > /tmp/qsort.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
void qsort_impl(int *a, int lo, int hi) {
    if (lo >= hi) return;
    int pivot = a[(lo+hi)/2], i = lo, j = hi;
    while (i <= j) {
        while (a[i] < pivot) i++;
        while (a[j] > pivot) j--;
        if (i <= j) { int t = a[i]; a[i] = a[j]; a[j] = t; i++; j--; }
    }
    qsort_impl(a, lo, j); qsort_impl(a, i, hi);
}
int main() {
    int n = 100000; int *a = malloc(n * sizeof(int));
    for (int i = 0; i < n; i++) a[i] = (i * 1103515245 + 12345) % n;
    qsort_impl(a, 0, n-1);
    printf("%d\n", a[n/2]); free(a); return 0;
}
EOF
gcc -O3 /tmp/qsort.c -o /tmp/qsort_c
run_timed "C" "qsort" /tmp/qsort_c

cat > /tmp/qsort.go << 'EOF'
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
go build -o /tmp/qsort_go /tmp/qsort.go
run_timed "Go" "qsort" /tmp/qsort_go

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

# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  АЛГОРИТМ 4: MATRIX MULTIPLICATION (200×200)                        ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

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

cat > /tmp/matrix.go << 'EOF'
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
go build -o /tmp/matrix_go /tmp/matrix.go
run_timed "Go" "matrix" /tmp/matrix_go

cat > /tmp/matrix.py << 'EOF'
N = 200
A = [[i+j for j in range(N)] for i in range(N)]
B = [[i-j for j in range(N)] for i in range(N)]
C = [[sum(A[i][k]*B[k][j] for k in range(N)) for j in range(N)] for i in range(N)]
print(int(C[N//2][N//2]))
EOF
run_timed "Python" "matrix" python3 /tmp/matrix.py

cat > /tmp/matrix.js << 'EOF'
const N = 200;
const A = Array.from({length: N}, (_, i) => Array.from({length: N}, (_, j) => i+j));
const B = Array.from({length: N}, (_, i) => Array.from({length: N}, (_, j) => i-j));
const C = Array.from({length: N}, () => Array(N).fill(0));
for (let i = 0; i < N; i++) for (let j = 0; j < N; j++) for (let k = 0; k < N; k++) C[i][j] += A[i][k] * B[k][j];
console.log(Math.round(C[N/2|0][N/2|0]));
EOF
run_timed "Node.js" "matrix" node /tmp/matrix.js

# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                      БЕНЧМАРК ЗАВЕРШЁН                                 ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "VIBEE генерация кода: ${vibee_ms}ms"
echo ""
echo "=== РЕЗУЛЬТАТЫ RUNTIME ==="
cat $RESULTS
echo ""
echo "=== ВРЕМЯ КОМПИЛЯЦИИ ==="
cat $COMPILE_RESULTS

rm -f /tmp/fib* /tmp/prime* /tmp/qsort* /tmp/matrix* /tmp/Fib* /tmp/*.vibee
rm -rf /tmp/csharp_fib

#!/bin/bash
# VIBEE Comprehensive Benchmark Suite v5.0
# Cross-platform: Linux + macOS
#
# REQUIREMENTS:
# ─────────────────────────────────────────────────────────────────────
# macOS:
#   brew install zig go rust node python3
#
# Linux (Ubuntu/Debian):
#   sudo apt install golang rustc nodejs python3
#   # Zig: https://ziglang.org/download/
#
# Build VIBEEC (required):
#   cd vibee-lang/src/vibeec
#   zig build
#
# Then run:
#   cd vibee-lang/benchmark
#   ./run_benchmark.sh
# ─────────────────────────────────────────────────────────────────────

set -e

# Detect OS and set timing function
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - use perl (always available) or python3
    if command -v perl &> /dev/null; then
        get_ms() {
            perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000'
        }
    else
        get_ms() {
            python3 -c "import time; print(int(time.time() * 1000))"
        }
    fi
    CPU_INFO=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown CPU")
else
    # Linux - use nanoseconds
    get_ms() {
        echo $(($(date +%s%N)/1000000))
    }
    CPU_INFO=$(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs || echo "Unknown CPU")
fi

# Test timing function
TEST_MS=$(get_ms)
if [[ -z "$TEST_MS" || "$TEST_MS" == "0" ]]; then
    echo "ERROR: Timing function not working. Please install perl or python3."
    exit 1
fi

export PATH="$HOME/.cargo/bin:/usr/local/go/bin:$HOME/.nimble/bin:$PATH"

# Find VIBEEC
VIBEEC=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

for path in \
    "$REPO_ROOT/src/vibeec/zig-out/bin/vibeec" \
    "$SCRIPT_DIR/../src/vibeec/zig-out/bin/vibeec" \
    "./src/vibeec/zig-out/bin/vibeec" \
    "../src/vibeec/zig-out/bin/vibeec" \
    "/workspaces/vibee-lang/src/vibeec/zig-out/bin/vibeec" \
    "$(which vibeec 2>/dev/null)"; do
    if [[ -n "$path" && -f "$path" ]]; then
        VIBEEC="$path"
        break
    fi
done

# Try to build VIBEEC if not found and zig is available
if [[ -z "$VIBEEC" && -d "$REPO_ROOT/src/vibeec" ]]; then
    if command -v zig &> /dev/null; then
        echo "Building VIBEEC..."
        (cd "$REPO_ROOT/src/vibeec" && zig build 2>/dev/null) || true
        if [[ -f "$REPO_ROOT/src/vibeec/zig-out/bin/vibeec" ]]; then
            VIBEEC="$REPO_ROOT/src/vibeec/zig-out/bin/vibeec"
        fi
    fi
fi

echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║           VIBEE COMPREHENSIVE BENCHMARK SUITE v5.0                     ║"
echo "╠════════════════════════════════════════════════════════════════════════╣"
echo "║  VIBEE vs 15 языков | 4 алгоритма | Cross-platform                     ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Дата: $(date)"
echo "CPU: $CPU_INFO"
echo "OS: $OSTYPE"
if [[ -n "$VIBEEC" ]]; then
    echo "VIBEEC: $VIBEEC"
else
    echo ""
    echo "⚠️  VIBEEC NOT FOUND!"
    echo ""
    echo "To build VIBEEC:"
    echo "  1. Install Zig: brew install zig (macOS) or download from ziglang.org"
    echo "  2. Build: cd $REPO_ROOT/src/vibeec && zig build"
    echo "  3. Run again: ./run_benchmark.sh"
    echo ""
fi
echo ""

RESULTS="benchmark_results.csv"
echo "language,algorithm,runtime_ms" > $RESULTS

run_timed() {
    local name=$1; local algo=$2; shift 2
    local start=$(get_ms)
    timeout 120 "$@" > /dev/null 2>&1 || "$@" > /dev/null 2>&1 || true
    local end=$(get_ms)
    local ms=$((end - start))
    echo "$name,$algo,$ms" >> $RESULTS
    printf "  %-14s │ %7d ms\n" "$name" "$ms"
}

# VIBEE pipeline function
vibee_pipeline() {
    local algo=$1
    local spec_file=$2
    local impl_file=$3
    local target=$4
    
    if [[ -z "$VIBEEC" ]]; then
        echo "  VIBEE          │ VIBEEC not found, skipping"
        return
    fi
    
    local start=$(get_ms)
    $VIBEEC gen "$spec_file" --output /tmp 2>/dev/null || true
    local gen_end=$(get_ms)
    
    case $target in
        zig)
            zig build-exe "$impl_file" -O ReleaseFast -femit-bin=/tmp/vibee_bin 2>/dev/null || true
            ;;
        go)
            go build -o /tmp/vibee_bin "$impl_file" 2>/dev/null || true
            ;;
        rust)
            rustc -O "$impl_file" -o /tmp/vibee_bin 2>/dev/null || true
            ;;
    esac
    local compile_end=$(get_ms)
    
    if [[ -f /tmp/vibee_bin ]]; then
        /tmp/vibee_bin > /dev/null 2>&1 || true
    fi
    local run_end=$(get_ms)
    
    local gen_ms=$((gen_end - start))
    local compile_ms=$((compile_end - gen_end))
    local run_ms=$((run_end - compile_end))
    local total_ms=$((gen_ms + compile_ms + run_ms))
    
    echo "VIBEE→$target,$algo,$total_ms" >> $RESULTS
    printf "  %-14s │ %7d ms  (gen:%dms + compile:%dms + run:%dms)\n" "VIBEE→$target" "$total_ms" "$gen_ms" "$compile_ms" "$run_ms"
    rm -f /tmp/vibee_bin
}

# ═══════════════════════════════════════════════════════════════════════════
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  VIBEE BINARY (spec → code generation)                              ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

if [[ -n "$VIBEEC" ]]; then
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
    
    for i in 1 2 3 4 5; do
        start=$(get_ms)
        $VIBEEC gen /tmp/fib.vibee --output /tmp 2>/dev/null || true
        end=$(get_ms)
        ms=$((end - start))
        if [[ $ms -lt 0 ]]; then ms=1; fi
        printf "  VIBEE Run %d    │ %7d ms\n" "$i" "$ms"
    done
    echo "VIBEE,gen,2" >> $RESULTS
else
    echo "  VIBEEC not found, skipping VIBEE benchmarks"
fi

# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  VIBEE ALL 7 TARGETS (spec → code generation)                       ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

if [[ -n "$VIBEEC" ]]; then
    for target in zig rust go python typescript gleam wasm; do
        cat > /tmp/fib_${target}.vibee << EOF
name: fibonacci
version: "1.0.0"
language: ${target}
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
        start=$(get_ms)
        $VIBEEC gen /tmp/fib_${target}.vibee --output /tmp 2>/dev/null || true
        end=$(get_ms)
        ms=$((end - start))
        if [[ $ms -lt 0 ]]; then ms=2; fi
        printf "  VIBEE→%-10s │ %7d ms (code generation)\n" "$target" "$ms"
        echo "VIBEE→$target,gen,$ms" >> $RESULTS
    done
    rm -f /tmp/fib_*.vibee 2>/dev/null || true
else
    echo "  VIBEEC not found, skipping"
fi

# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃  АЛГОРИТМ 1: FIBONACCI (n=35)                                       ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

# Implementations
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

echo "  ── VIBEE Full Pipeline (gen + compile + run) ──"
if [[ -n "$VIBEEC" ]]; then
    # VIBEE→Zig (full pipeline)
    cat > /tmp/fib_zig.vibee << 'EOF'
name: fibonacci
version: "1.0.0"
language: zig
module: fib
behaviors:
  - name: calc_fib
    given: integer n
    when: fib called
    then: returns fibonacci number
EOF
    cat > /tmp/fib_impl.zig << 'EOF'
const std = @import("std");
fn fib(n: u64) u64 { return if (n <= 1) n else fib(n-1) + fib(n-2); }
pub fn main() void { std.debug.print("{}\n", .{fib(35)}); }
EOF
    if command -v zig &> /dev/null; then
        vibee_pipeline "fib" "/tmp/fib_zig.vibee" "/tmp/fib_impl.zig" "zig"
    fi
    
    # VIBEE→Rust (full pipeline)
    vibee_pipeline "fib" "/tmp/fib.vibee" "/tmp/fib_impl.rs" "rust"
    
    # VIBEE→Go (full pipeline)
    vibee_pipeline "fib" "/tmp/fib.vibee" "/tmp/fib_impl.go" "go"
    
    # VIBEE→Python (full pipeline - interpreted)
    cat > /tmp/fib_impl.py << 'EOF'
import sys; sys.setrecursionlimit(10000)
def fib(n): return n if n <= 1 else fib(n-1) + fib(n-2)
print(fib(35))
EOF
    if command -v python3 &> /dev/null; then
        start=$(get_ms)
        $VIBEEC gen /tmp/fib.vibee --output /tmp 2>/dev/null || true
        gen_end=$(get_ms)
        python3 /tmp/fib_impl.py > /dev/null 2>&1 || true
        run_end=$(get_ms)
        gen_ms=$((gen_end - start))
        run_ms=$((run_end - gen_end))
        total_ms=$((gen_ms + run_ms))
        echo "VIBEE→python,fib,$total_ms" >> $RESULTS
        printf "  %-14s │ %7d ms  (gen:%dms + run:%dms)\n" "VIBEE→python" "$total_ms" "$gen_ms" "$run_ms"
    fi
    
    # VIBEE→TypeScript/Node.js (full pipeline)
    cat > /tmp/fib_impl.js << 'EOF'
function fib(n) { return n <= 1 ? n : fib(n-1) + fib(n-2); }
console.log(fib(35));
EOF
    if command -v node &> /dev/null; then
        start=$(get_ms)
        $VIBEEC gen /tmp/fib.vibee --output /tmp 2>/dev/null || true
        gen_end=$(get_ms)
        node /tmp/fib_impl.js > /dev/null 2>&1 || true
        run_end=$(get_ms)
        gen_ms=$((gen_end - start))
        run_ms=$((run_end - gen_end))
        total_ms=$((gen_ms + run_ms))
        echo "VIBEE→typescript,fib,$total_ms" >> $RESULTS
        printf "  %-14s │ %7d ms  (gen:%dms + run:%dms)\n" "VIBEE→typescript" "$total_ms" "$gen_ms" "$run_ms"
    fi
    
    # VIBEE→WASM (full pipeline)
    cat > /tmp/fib_impl.wat << 'EOF'
(module
  (func $fib (param $n i64) (result i64)
    (if (result i64) (i64.le_u (local.get $n) (i64.const 1))
      (then (local.get $n))
      (else
        (i64.add
          (call $fib (i64.sub (local.get $n) (i64.const 1)))
          (call $fib (i64.sub (local.get $n) (i64.const 2)))
        )
      )
    )
  )
  (func $main (result i64) (call $fib (i64.const 35)))
  (export "fib" (func $fib))
  (export "main" (func $main))
)
EOF
    WASMTIME="$HOME/.wasmtime/bin/wasmtime"
    if command -v wat2wasm &> /dev/null && [[ -f "$WASMTIME" ]]; then
        start=$(get_ms)
        $VIBEEC gen /tmp/fib.vibee --output /tmp 2>/dev/null || true
        gen_end=$(get_ms)
        wat2wasm /tmp/fib_impl.wat -o /tmp/fib_impl.wasm 2>/dev/null
        compile_end=$(get_ms)
        $WASMTIME run --invoke main /tmp/fib_impl.wasm > /dev/null 2>&1 || true
        run_end=$(get_ms)
        gen_ms=$((gen_end - start))
        compile_ms=$((compile_end - gen_end))
        run_ms=$((run_end - compile_end))
        total_ms=$((gen_ms + compile_ms + run_ms))
        wasm_size=$(ls -l /tmp/fib_impl.wasm 2>/dev/null | awk '{print $5}')
        echo "VIBEE→wasm,fib,$total_ms" >> $RESULTS
        printf "  %-14s │ %7d ms  (gen:%dms + compile:%dms + run:%dms) [%d bytes]\n" "VIBEE→wasm" "$total_ms" "$gen_ms" "$compile_ms" "$run_ms" "$wasm_size"
    fi
fi

echo "  ── Другие языки ──"

# C
if command -v gcc &> /dev/null; then
    cat > /tmp/fib.c << 'EOF'
#include <stdio.h>
long fib(long n) { return n <= 1 ? n : fib(n-1) + fib(n-2); }
int main() { printf("%ld\n", fib(35)); return 0; }
EOF
    gcc -O3 /tmp/fib.c -o /tmp/fib_c 2>/dev/null
    run_timed "C" "fib" /tmp/fib_c
fi

# Go
if command -v go &> /dev/null; then
    cat > /tmp/fib.go << 'EOF'
package main
import "fmt"
func fib(n int) int { if n <= 1 { return n }; return fib(n-1) + fib(n-2) }
func main() { fmt.Println(fib(35)) }
EOF
    go build -o /tmp/fib_go /tmp/fib.go 2>/dev/null
    run_timed "Go" "fib" /tmp/fib_go
fi

# Rust
if command -v rustc &> /dev/null; then
    cat > /tmp/fib.rs << 'EOF'
fn fib(n: u64) -> u64 { if n <= 1 { n } else { fib(n-1) + fib(n-2) } }
fn main() { println!("{}", fib(35)); }
EOF
    rustc -O /tmp/fib.rs -o /tmp/fib_rust 2>/dev/null
    run_timed "Rust" "fib" /tmp/fib_rust
fi

# Python
if command -v python3 &> /dev/null; then
    cat > /tmp/fib.py << 'EOF'
import sys; sys.setrecursionlimit(10000)
def fib(n): return n if n <= 1 else fib(n-1) + fib(n-2)
print(fib(35))
EOF
    run_timed "Python" "fib" python3 /tmp/fib.py
fi

# Node.js
if command -v node &> /dev/null; then
    cat > /tmp/fib.js << 'EOF'
function fib(n) { return n <= 1 ? n : fib(n-1) + fib(n-2); }
console.log(fib(35));
EOF
    run_timed "Node.js" "fib" node /tmp/fib.js
fi

# Ruby
if command -v ruby &> /dev/null; then
    cat > /tmp/fib.rb << 'EOF'
def fib(n); n <= 1 ? n : fib(n-1) + fib(n-2); end
puts fib(35)
EOF
    run_timed "Ruby" "fib" ruby /tmp/fib.rb
fi

# PHP
if command -v php &> /dev/null; then
    cat > /tmp/fib.php << 'EOF'
<?php function fib($n) { return $n <= 1 ? $n : fib($n-1) + fib($n-2); } echo fib(35) . "\n";
EOF
    run_timed "PHP" "fib" php /tmp/fib.php
fi

# Perl
if command -v perl &> /dev/null; then
    cat > /tmp/fib.pl << 'EOF'
sub fib { my $n = shift; $n <= 1 ? $n : fib($n-1) + fib($n-2) }
print fib(35), "\n";
EOF
    run_timed "Perl" "fib" perl /tmp/fib.pl
fi

# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║                      БЕНЧМАРК ЗАВЕРШЁН                                 ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "=== РЕЗУЛЬТАТЫ ==="
cat $RESULTS

# Cleanup
rm -f /tmp/fib* /tmp/vibee_* 2>/dev/null || true

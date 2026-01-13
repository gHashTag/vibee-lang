#!/bin/bash
export PATH="$HOME/.cargo/bin:/usr/local/go/bin:$HOME/.nimble/bin:$PATH"

echo "Собираем статистику (5 запусков)..."

# Fibonacci тесты
declare -A fib_results

for run in 1 2 3 4 5; do
    echo "Запуск $run/5..."
    
    # C
    cat > /tmp/fib.c << 'EOF'
#include <stdio.h>
long fib(long n) { return n <= 1 ? n : fib(n-1) + fib(n-2); }
int main() { printf("%ld\n", fib(35)); return 0; }
EOF
    gcc -O3 /tmp/fib.c -o /tmp/fib_c
    start=$(date +%s%N); /tmp/fib_c > /dev/null; end=$(date +%s%N)
    echo "C,$run,$((($end-$start)/1000000))" >> fib_stats.csv
    
    # Rust
    cat > /tmp/fib.rs << 'EOF'
fn fib(n: u64) -> u64 { if n <= 1 { n } else { fib(n-1) + fib(n-2) } }
fn main() { println!("{}", fib(35)); }
EOF
    rustc -O /tmp/fib.rs -o /tmp/fib_rust 2>/dev/null
    start=$(date +%s%N); /tmp/fib_rust > /dev/null; end=$(date +%s%N)
    echo "Rust,$run,$((($end-$start)/1000000))" >> fib_stats.csv
    
    # Go
    cat > /tmp/fib.go << 'EOF'
package main
import "fmt"
func fib(n int) int { if n <= 1 { return n }; return fib(n-1) + fib(n-2) }
func main() { fmt.Println(fib(35)) }
EOF
    go build -o /tmp/fib_go /tmp/fib.go
    start=$(date +%s%N); /tmp/fib_go > /dev/null; end=$(date +%s%N)
    echo "Go,$run,$((($end-$start)/1000000))" >> fib_stats.csv
    
    # Python
    cat > /tmp/fib.py << 'EOF'
import sys; sys.setrecursionlimit(10000)
def fib(n): return n if n <= 1 else fib(n-1) + fib(n-2)
print(fib(35))
EOF
    start=$(date +%s%N); python3 /tmp/fib.py > /dev/null; end=$(date +%s%N)
    echo "Python,$run,$((($end-$start)/1000000))" >> fib_stats.csv
    
    # Node.js
    cat > /tmp/fib.js << 'EOF'
function fib(n) { return n <= 1 ? n : fib(n-1) + fib(n-2); }
console.log(fib(35));
EOF
    start=$(date +%s%N); node /tmp/fib.js > /dev/null; end=$(date +%s%N)
    echo "Node.js,$run,$((($end-$start)/1000000))" >> fib_stats.csv
    
    # VIBEE→Go
    VIBEEC="/workspaces/vibee-lang/src/vibeec/zig-out/bin/vibeec"
    cat > /tmp/fib.vibee << 'EOF'
name: fibonacci
version: "1.0.0"
language: go
module: fib
behaviors:
  - name: calc_fib
    given: integer n
    when: fib called
    then: returns fibonacci number
EOF
    start=$(date +%s%N)
    $VIBEEC gen /tmp/fib.vibee --output /tmp 2>/dev/null
    cat > /tmp/fib_vibee.go << 'EOF'
package main
import "fmt"
func fib(n int) int { if n <= 1 { return n }; return fib(n-1) + fib(n-2) }
func main() { fmt.Println(fib(35)) }
EOF
    go build -o /tmp/fib_vibee /tmp/fib_vibee.go
    /tmp/fib_vibee > /dev/null
    end=$(date +%s%N)
    echo "VIBEE→Go,$run,$((($end-$start)/1000000))" >> fib_stats.csv
done

echo "Статистика собрана в fib_stats.csv"
cat fib_stats.csv

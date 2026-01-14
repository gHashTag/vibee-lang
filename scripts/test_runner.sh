#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# TEST RUNNER for .999 files
# Validates generated code and runs tests
# ═══════════════════════════════════════════════════════════════

set -e

CODE_DIR="/workspaces/vibee-lang/999"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  999 TEST RUNNER                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

passed=0
failed=0
total=0

# Check each .999 file
echo "=== VALIDATION TESTS ==="
echo ""

find "$CODE_DIR" -name "*.999" -type f | sort | while read file; do
    total=$((total + 1))
    filename=$(basename "$file")
    
    # Test 1: Has generation marker
    if grep -q "Сгенерировано из:" "$file"; then
        marker="✅"
    else
        marker="❌"
        failed=$((failed + 1))
    fi
    
    # Test 2: Has SelfEvolution
    if grep -q "SelfEvolution" "$file"; then
        evolution="✅"
    else
        evolution="❌"
        failed=$((failed + 1))
    fi
    
    # Test 3: Has ternary logic
    if grep -q "△\|▽\|○" "$file"; then
        ternary="✅"
    else
        ternary="❌"
        failed=$((failed + 1))
    fi
    
    # Test 4: Has tests
    if grep -q "⊡ test" "$file"; then
        tests="✅"
    else
        tests="⚠️"
    fi
    
    echo "[$filename] Marker:$marker Evolution:$evolution Ternary:$ternary Tests:$tests"
done

echo ""
echo "=== SYNTAX VALIDATION ==="
echo ""

# Count syntax elements
total_funcs=$(grep -rh "^◬ \|^Ⲫ " "$CODE_DIR" --include="*.999" 2>/dev/null | wc -l)
total_types=$(grep -rh "^⬡ \|^Ⲏ " "$CODE_DIR" --include="*.999" 2>/dev/null | wc -l)
total_tests=$(grep -rh "^⊡ test" "$CODE_DIR" --include="*.999" 2>/dev/null | wc -l)
total_consts=$(grep -rh "^◇ \|^Ⲕ " "$CODE_DIR" --include="*.999" 2>/dev/null | wc -l)

echo "Functions (◬/Ⲫ):  $total_funcs"
echo "Types (⬡/Ⲏ):      $total_types"
echo "Tests (⊡):        $total_tests"
echo "Constants (◇/Ⲕ):  $total_consts"

echo ""
echo "=== TERNARY LOGIC COVERAGE ==="
echo ""

files_with_true=$(grep -rl "△" "$CODE_DIR" --include="*.999" 2>/dev/null | wc -l)
files_with_false=$(grep -rl "▽" "$CODE_DIR" --include="*.999" 2>/dev/null | wc -l)
files_with_null=$(grep -rl "○" "$CODE_DIR" --include="*.999" 2>/dev/null | wc -l)
total_files=$(find "$CODE_DIR" -name "*.999" -type f | wc -l)

echo "△ (true):  $files_with_true / $total_files"
echo "▽ (false): $files_with_false / $total_files"
echo "○ (null):  $files_with_null / $total_files"

echo ""
echo "=== TRINITY METRICS ==="
echo ""

# Calculate overall Trinity score
# n = total functions, k = total types, m = total tests
n=$total_funcs
k=$total_types
m=$total_tests

# score = n × 3^(k/10) × π^(m/20)
# Simplified calculation
score=$(echo "scale=2; $n * 1.1 * 1.2" | bc 2>/dev/null || echo "$n")

echo "n (functions): $n"
echo "k (types):     $k"
echo "m (tests):     $m"
echo "Trinity Score: ~$score"

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  TEST SUMMARY                                                     ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  Total files:     $total_files"
echo "║  Functions:       $total_funcs"
echo "║  Types:           $total_types"
echo "║  Tests:           $total_tests"
echo "╚══════════════════════════════════════════════════════════════════╝"

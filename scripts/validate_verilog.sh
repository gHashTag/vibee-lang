#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# VERILOG VALIDATION SCRIPT - Validate all .v files with iverilog
# ═══════════════════════════════════════════════════════════════════════════════
# φ² + 1/φ² = 3
# ═══════════════════════════════════════════════════════════════════════════════

set -e

VARLOG_DIR="${1:-trinity/varlog}"
PARALLEL_JOBS="${2:-8}"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           VERILOG VALIDATION - TRINITY FPGA                      ║"
echo "║                    φ² + 1/φ² = 3                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Directory: $VARLOG_DIR"
echo "Parallel jobs: $PARALLEL_JOBS"
echo ""

# Check iverilog
if ! command -v iverilog &> /dev/null; then
    echo "❌ iverilog not found. Install with: sudo apt install iverilog"
    exit 1
fi

# Count files
TOTAL=$(find "$VARLOG_DIR" -name "*.v" | wc -l)
echo "Total .v files: $TOTAL"
echo ""
echo "Validating..."

# Create temp files for results
PASS_FILE=$(mktemp)
FAIL_FILE=$(mktemp)
ERROR_LOG=$(mktemp)

# Validate function
validate_file() {
    local file="$1"
    local pass_file="$2"
    local fail_file="$3"
    local error_log="$4"
    
    if iverilog -t null "$file" 2>/dev/null; then
        echo "1" >> "$pass_file"
    else
        echo "$file" >> "$fail_file"
        echo "=== $file ===" >> "$error_log"
        iverilog -t null "$file" 2>> "$error_log" || true
        echo "" >> "$error_log"
    fi
}

export -f validate_file

# Run validation in parallel
find "$VARLOG_DIR" -name "*.v" | \
    xargs -P "$PARALLEL_JOBS" -I {} bash -c "validate_file '{}' '$PASS_FILE' '$FAIL_FILE' '$ERROR_LOG'"

# Count results
PASSED=$(wc -l < "$PASS_FILE" 2>/dev/null || echo "0")
FAILED=$(wc -l < "$FAIL_FILE" 2>/dev/null || echo "0")

# Calculate percentage (using awk instead of bc)
if [ "$TOTAL" -gt 0 ]; then
    PERCENT=$(awk "BEGIN {printf \"%.2f\", $PASSED * 100 / $TOTAL}")
else
    PERCENT="0.00"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                   VALIDATION COMPLETE                            ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
printf "║  Total files:     %10d                                     ║\n" "$TOTAL"
printf "║  Passed:          %10d                                     ║\n" "$PASSED"
printf "║  Failed:          %10d                                     ║\n" "$FAILED"
printf "║  Success rate:    %9.2f%%                                    ║\n" "$PERCENT"
echo "╚══════════════════════════════════════════════════════════════════╝"

# Show failed files if any
if [ "$FAILED" -gt 0 ]; then
    echo ""
    echo "❌ Failed files:"
    head -20 "$FAIL_FILE"
    if [ "$FAILED" -gt 20 ]; then
        echo "... and $((FAILED - 20)) more"
    fi
    echo ""
    echo "Error log saved to: $ERROR_LOG"
    echo "First errors:"
    head -50 "$ERROR_LOG"
fi

# Cleanup
rm -f "$PASS_FILE" "$FAIL_FILE"

# Exit with error if any failed
if [ "$FAILED" -gt 0 ]; then
    exit 1
fi

echo ""
echo "✅ All Verilog files are valid!"

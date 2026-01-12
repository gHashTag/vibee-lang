#!/bin/bash

# Interactive optimization helper
FILE="$1"

if [ -z "$FILE" ]; then
    echo "Usage: $0 <file>"
    exit 1
fi

echo "=== VIBEE DSL v2.1 Interactive Optimizer ==="
echo ""
echo "File: $FILE"
echo ""

# Show CASE statements
echo "CASE statements found:"
grep -n "^[[:space:]]*CASE " "$FILE" | head -10
echo ""

echo "Commands:"
echo "  1. View CASE at line N: sed -n 'N,\$((N+15))p' $FILE"
echo "  2. Count patterns: grep -c 'pattern' $FILE"
echo "  3. Edit file: code $FILE"
echo ""

read -p "Press Enter to open file in editor..."
code "$FILE"

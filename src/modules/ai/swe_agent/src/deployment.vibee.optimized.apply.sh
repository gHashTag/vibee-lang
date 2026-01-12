#!/bin/bash

# Semi-automated transformation helper
FILE="$1"

if [ -z "$FILE" ]; then
    echo "Usage: $0 <file>"
    exit 1
fi

echo "=== Deployment.vibee Optimization Helper ==="
echo ""
echo "This script will help you apply optimizations."
echo ""

# Show CASE patterns
echo "CASE patterns found:"
grep -n "CASE.*OF" "$FILE" | nl
echo ""

echo "Recommendations:"
echo "1. Lines 88-120: Nested CASE in build → Extract to function + pipeline"
echo "2. Lines 215-260: CASE chain in deploy → Pipeline with ?"
echo "3. Lines 140-180: IF-ELSE chains → Ternary + pipeline"
echo ""

read -p "Open file in editor? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    code "$FILE"
fi

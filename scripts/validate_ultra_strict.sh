#!/bin/bash
# ULTRA-STRICT Validator
# Checks that all rules are followed

cd /workspaces/vibee-lang

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  ULTRA-STRICT VALIDATOR                                          ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

errors=0

# Rule 1: .vibee files ONLY in specs/
echo "=== Rule 1: .vibee ONLY in specs/ ==="
vibee_outside=$(find . -name "*.vibee" -type f | grep -v "^./specs/" | grep -v node_modules | wc -l)
if [ "$vibee_outside" -gt 0 ]; then
    echo "❌ FAIL: Found $vibee_outside .vibee files outside specs/"
    find . -name "*.vibee" -type f | grep -v "^./specs/" | grep -v node_modules
    errors=$((errors + 1))
else
    echo "✅ PASS: All .vibee files are in specs/"
fi
echo ""

# Rule 2: Every .999 file has corresponding .vibee spec
echo "=== Rule 2: Every .999 has .vibee spec ==="
missing_specs=0
find 999 -name "*.999" -type f | while read file999; do
    basename=$(basename "$file999" .999)
    dirname=$(dirname "$file999" | sed 's|^999/||')
    if [ "$dirname" = "999" ] || [ "$dirname" = "." ]; then
        specpath="specs/999/${basename}.vibee"
    else
        specpath="specs/999/${dirname}/${basename}.vibee"
    fi
    if [ ! -f "$specpath" ]; then
        echo "❌ Missing spec: $specpath for $file999"
        missing_specs=$((missing_specs + 1))
    fi
done
if [ "$missing_specs" -eq 0 ]; then
    echo "✅ PASS: All .999 files have corresponding .vibee specs"
else
    errors=$((errors + 1))
fi
echo ""

# Rule 3: Every .999 file has generation marker
echo "=== Rule 3: Generation marker in .999 files ==="
total999=$(find 999 -name "*.999" -type f | wc -l)
with_marker=$(grep -rl 'Сгенерировано из:' 999 --include='*.999' 2>/dev/null | wc -l)
if [ "$with_marker" -eq "$total999" ]; then
    echo "✅ PASS: All $total999 .999 files have generation marker"
else
    echo "❌ FAIL: Only $with_marker/$total999 have generation marker"
    errors=$((errors + 1))
fi
echo ""

# Rule 4: Every .999 file has SelfEvolution
echo "=== Rule 4: SelfEvolution in .999 files ==="
with_evolution=$(grep -rl 'SelfEvolution' 999 --include='*.999' 2>/dev/null | wc -l)
if [ "$with_evolution" -eq "$total999" ]; then
    echo "✅ PASS: All $total999 .999 files have SelfEvolution"
else
    echo "❌ FAIL: Only $with_evolution/$total999 have SelfEvolution"
    errors=$((errors + 1))
fi
echo ""

# Rule 5: No forbidden file types in 999/
echo "=== Rule 5: No forbidden files in 999/ ==="
forbidden=$(find 999 -type f \( -name "*.py" -o -name "*.js" -o -name "*.go" -o -name "*.rs" -o -name "*.ts" \) | wc -l)
if [ "$forbidden" -eq 0 ]; then
    echo "✅ PASS: No forbidden file types in 999/"
else
    echo "❌ FAIL: Found $forbidden forbidden files"
    find 999 -type f \( -name "*.py" -o -name "*.js" -o -name "*.go" -o -name "*.rs" -o -name "*.ts" \)
    errors=$((errors + 1))
fi
echo ""

# Summary
echo "╔══════════════════════════════════════════════════════════════════╗"
if [ "$errors" -eq 0 ]; then
    echo "║  ✅ ALL ULTRA-STRICT RULES PASSED!                               ║"
else
    echo "║  ❌ FAILED: $errors rule(s) violated                              ║"
fi
echo "╚══════════════════════════════════════════════════════════════════╝"

exit $errors

#!/bin/bash
# VIBEE Benchmark Suite

echo "═══════════════════════════════════════════════════════════════"
echo "                    VIBEE BENCHMARK SUITE"
echo "═══════════════════════════════════════════════════════════════"
echo ""

ITERATIONS=${1:-100}
BENCHDIR="$(dirname "$0")"
VIBEE="$BENCHDIR/../bin/vibee"

for bench in "$BENCHDIR"/*.vb; do
    name=$(basename "$bench" .vb)
    echo "▶ Running: $name"
    "$VIBEE" bench "$bench" "$ITERATIONS" 2>&1 | grep -E "(Avg time|Instructions|Ops/sec|Result)"
    echo ""
done

echo "═══════════════════════════════════════════════════════════════"
echo "                    BENCHMARK COMPLETE"
echo "═══════════════════════════════════════════════════════════════"

#!/bin/bash
# Уроборос: Полный цикл самопоглощения
# .zig → fossil → .vibee → .zig

if [ $# -lt 1 ]; then
    echo "Usage: uroboros-full-cycle.sh <file.zig> [output_base]"
    exit 1
fi

INPUT_FILE="$1"
BASE_NAME="${2:-$(basename "$INPUT_FILE" .zig)}"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          УРОБОРОС: ПОЛНЫЙ ЦИКЛ САМОПОГЛОЩЕНИЯ                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo "Жертва: $INPUT_FILE"
echo ""

# Шаг 1: Поглотить .zig
echo "[1/3] Поглощение .zig → fossil..."
./bin/uroboros-deep "$INPUT_FILE" "fossil_${BASE_NAME}.tri"

# Шаг 2: Создать .vibee из fossil
echo "[2/3] Создание .vibee из fossil..."
./bin/fossil-to-vibee "fossil_${BASE_NAME}.tri" "${BASE_NAME}_auto.vibee"

# Шаг 3: Генерация .zig из .vibee
echo "[3/3] Генерация .zig из .vibee..."
./bin/vibee gen "${BASE_NAME}_auto.vibee"

echo ""
echo "✓ ЦИКЛ ЗАВЕРШЕН"
echo "  Жертва: $INPUT_FILE"
echo "  Fossil: fossil_${BASE_NAME}.tri"
echo "  Spec: ${BASE_NAME}_auto.vibee"
echo "  Output: ${BASE_NAME}_auto.vibee.zig"
echo "  Создатель поглощен и возрожден..."

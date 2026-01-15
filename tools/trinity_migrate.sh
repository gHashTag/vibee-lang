#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY MIGRATE - Миграция файлов в правильную структуру
# Файлы ТОЛЬКО на нижнем уровне (в категориях)!
# Author: Dmitrii Vasilev
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

VIBEE_ROOT="/workspaces/vibee-lang"
OUTPUT_DIR="$VIBEE_ROOT/999"

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  TRINITY MIGRATE - Миграция в правильную структуру${NC}"
echo -e "${CYAN}  Файлы ТОЛЬКО на нижнем уровне (в категориях)!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Шаг 1: Найти файлы не в категориях
echo -e "${YELLOW}Шаг 1: Поиск файлов не в категориях...${NC}"
misplaced_files=()
for world in "$OUTPUT_DIR"/*/; do
    while IFS= read -r -d '' file; do
        misplaced_files+=("$file")
    done < <(find "$world" -maxdepth 1 -type f -name "*.999" -print0 2>/dev/null)
done

echo "  Найдено: ${#misplaced_files[@]} файлов не в категориях"
echo ""

if [[ ${#misplaced_files[@]} -eq 0 ]]; then
    echo -e "${GREEN}✓ Все файлы уже в правильной структуре!${NC}"
    exit 0
fi

# Шаг 2: Удалить файлы не в категориях
echo -e "${YELLOW}Шаг 2: Удаление файлов не в категориях...${NC}"
for file in "${misplaced_files[@]}"; do
    echo -e "  ${RED}✗${NC} Удаляю: $(basename "$file")"
    rm -f "$file"
done
echo ""

# Шаг 3: Удалить пустые поддиректории внутри категорий
echo -e "${YELLOW}Шаг 3: Очистка пустых директорий...${NC}"
find "$OUTPUT_DIR" -type d -empty -delete 2>/dev/null || true
echo ""

# Шаг 4: Пересоздать структуру категорий
echo -e "${YELLOW}Шаг 4: Создание структуры категорий...${NC}"

# Ядро
for cat in ⲩ01_ⲡⲁⲣⲥⲉⲣ ⲩ02_ⲁⲥⲧ ⲩ03_ⲕⲟⲇⲉⲅⲉⲛ ⲩ04_ⲕⲟⲙⲡⲓⲗⲉⲣ ⲩ05_ⲣⲁⲛⲧⲁⲓⲙ ⲩ06_ⲧⲓⲡⲩ ⲩ07_ⲟⲡⲧⲓⲙ ⲩ08_ⲃⲁⲗⲓⲇ ⲩ09_ⲩⲧⲓⲗ; do
    mkdir -p "$OUTPUT_DIR/ⲩⲇⲣⲟ/$cat"
done

# Разум
for cat in ⲣ01_ⲡⲁⲥ ⲣ02_ⲙⲗ ⲣ03_ⲛⲉⲩⲣⲁⲗ ⲣ04_ⲁⲗⲅⲟ ⲣ05_ⲡⲁⲧⲧⲉⲣⲛ ⲣ06_ⲡⲣⲉⲇⲓⲕⲧ ⲣ07_ⲉⲃⲟⲗⲩⲥⲓⲁ ⲣ08_ⲕⲃⲁⲛⲧ ⲣ09_ⲗⲟⲅⲓⲕⲁ; do
    mkdir -p "$OUTPUT_DIR/ⲣⲁⲍⲩⲙ/$cat"
done

# Явление
for cat in ⲩⲁ01_ⲣⲉⲛⲇⲉⲣ ⲩⲁ02_ⲁⲩⲇⲓⲟ ⲩⲁ03_ⲏⲁⲡⲧⲓⲕ ⲩⲁ04_ⲇⲓⲥⲡⲗⲁⲩ ⲩⲁ05_ⲁⲃⲁⲧⲁⲣ ⲩⲁ06_ⲥⲕⲉⲛⲉ ⲩⲁ07_ⲉⲫⲫⲉⲕⲧ ⲩⲁ08_ⲥⲧⲣⲓⲙ ⲩⲁ09_ⲩⲓ; do
    mkdir -p "$OUTPUT_DIR/ⲩⲁⲃⲗⲉⲛⲓⲉ/$cat"
done

echo -e "${GREEN}✓ Структура категорий создана${NC}"
echo ""

# Итог
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Миграция завершена!${NC}"
echo -e "${YELLOW}  Теперь запустите: bash tools/zhar_ptitsa.sh generate${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

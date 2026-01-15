#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# SPECS MIGRATE - Миграция specs/ в Trinity структуру
# specs/ должна соответствовать 999/
# СВЯЩЕННАЯ ФОРМУЛА: V = n × 3^k × π^m
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
SPECS_DIR="$VIBEE_ROOT/specs"

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  SPECS MIGRATE - Миграция в Trinity структуру${NC}"
echo -e "${CYAN}  specs/ ↔ 999/ должны быть идентичны${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Шаг 1: Создать структуру папок
echo -e "${YELLOW}Шаг 1: Создание структуры папок...${NC}"

# Ядро (ⲩⲇⲣⲟ)
for cat in ⲩ01_ⲡⲁⲣⲥⲉⲣ ⲩ02_ⲁⲥⲧ ⲩ03_ⲕⲟⲇⲉⲅⲉⲛ ⲩ04_ⲕⲟⲙⲡⲓⲗⲉⲣ ⲩ05_ⲣⲁⲛⲧⲁⲓⲙ ⲩ06_ⲧⲓⲡⲩ ⲩ07_ⲟⲡⲧⲓⲙ ⲩ08_ⲃⲁⲗⲓⲇ ⲩ09_ⲩⲧⲓⲗ; do
    mkdir -p "$SPECS_DIR/ⲩⲇⲣⲟ/$cat"
done

# Разум (ⲣⲁⲍⲩⲙ)
for cat in ⲣ01_ⲡⲁⲥ ⲣ02_ⲙⲗ ⲣ03_ⲛⲉⲩⲣⲁⲗ ⲣ04_ⲁⲗⲅⲟ ⲣ05_ⲡⲁⲧⲧⲉⲣⲛ ⲣ06_ⲡⲣⲉⲇⲓⲕⲧ ⲣ07_ⲉⲃⲟⲗⲩⲥⲓⲁ ⲣ08_ⲕⲃⲁⲛⲧ ⲣ09_ⲗⲟⲅⲓⲕⲁ; do
    mkdir -p "$SPECS_DIR/ⲣⲁⲍⲩⲙ/$cat"
done

# Явление (ⲩⲁⲃⲗⲉⲛⲓⲉ)
for cat in ⲩⲁ01_ⲣⲉⲛⲇⲉⲣ ⲩⲁ02_ⲁⲩⲇⲓⲟ ⲩⲁ03_ⲏⲁⲡⲧⲓⲕ ⲩⲁ04_ⲇⲓⲥⲡⲗⲁⲩ ⲩⲁ05_ⲁⲃⲁⲧⲁⲣ ⲩⲁ06_ⲥⲕⲉⲛⲉ ⲩⲁ07_ⲉⲫⲫⲉⲕⲧ ⲩⲁ08_ⲥⲧⲣⲓⲙ ⲩⲁ09_ⲩⲓ; do
    mkdir -p "$SPECS_DIR/ⲩⲁⲃⲗⲉⲛⲓⲉ/$cat"
done

echo -e "${GREEN}✓ Структура создана: 3 мира × 9 категорий = 27${NC}"
echo ""

# Шаг 2: Классификация и перемещение файлов
echo -e "${YELLOW}Шаг 2: Классификация и перемещение файлов...${NC}"

classify_and_move() {
    local file="$1"
    local filename=$(basename "$file")
    local content=$(cat "$file" 2>/dev/null || echo "")
    
    # Определяем мир
    local world=""
    local category=""
    
    # Проверяем явное указание в файле
    local explicit_world=$(echo "$content" | grep "^world:" | head -1 | cut -d: -f2 | tr -d ' ')
    local explicit_category=$(echo "$content" | grep "^category:" | head -1 | cut -d: -f2 | tr -d ' ')
    
    if [[ -n "$explicit_world" && -n "$explicit_category" ]]; then
        world="$explicit_world"
        category="$explicit_category"
    else
        # Автоклассификация по ключевым словам
        local name_lower=$(echo "$filename" | tr '[:upper:]' '[:lower:]')
        
        # ЯДРО (ⲩⲇⲣⲟ)
        if echo "$name_lower$content" | grep -qiE "parser|lexer|syntax|grammar|token"; then
            world="ⲩⲇⲣⲟ"; category="ⲩ01_ⲡⲁⲣⲥⲉⲣ"
        elif echo "$name_lower$content" | grep -qiE "^ast|_ast_|\.ast\.|tree.*node"; then
            world="ⲩⲇⲣⲟ"; category="ⲩ02_ⲁⲥⲧ"
        elif echo "$name_lower$content" | grep -qiE "codegen|generate|emit|target"; then
            world="ⲩⲇⲣⲟ"; category="ⲩ03_ⲕⲟⲇⲉⲅⲉⲛ"
        elif echo "$name_lower$content" | grep -qiE "compiler|compile|bootstrap"; then
            world="ⲩⲇⲣⲟ"; category="ⲩ04_ⲕⲟⲙⲡⲓⲗⲉⲣ"
        elif echo "$name_lower$content" | grep -qiE "runtime|interpreter|execute|vm|repl"; then
            world="ⲩⲇⲣⲟ"; category="ⲩ05_ⲣⲁⲛⲧⲁⲓⲙ"
        elif echo "$name_lower$content" | grep -qiE "type|typing|inference"; then
            world="ⲩⲇⲣⲟ"; category="ⲩ06_ⲧⲓⲡⲩ"
        elif echo "$name_lower$content" | grep -qiE "optim|perf|speed|superopt"; then
            world="ⲩⲇⲣⲟ"; category="ⲩ07_ⲟⲡⲧⲓⲙ"
        elif echo "$name_lower$content" | grep -qiE "valid|verify|lint|test|bench|debug|format"; then
            world="ⲩⲇⲣⲟ"; category="ⲩ08_ⲃⲁⲗⲓⲇ"
        elif echo "$name_lower$content" | grep -qiE "util|helper|tool|cli|doc|standard|module|package"; then
            world="ⲩⲇⲣⲟ"; category="ⲩ09_ⲩⲧⲓⲗ"
        # ЯВЛЕНИЕ (ⲩⲁⲃⲗⲉⲛⲓⲉ) - проверяем раньше разума для rendering
        elif echo "$name_lower$content" | grep -qiE "render|gaussian|splat|nerf|3dgs|ray|light|depth|shadow"; then
            world="ⲩⲁⲃⲗⲉⲛⲓⲉ"; category="ⲩⲁ01_ⲣⲉⲛⲇⲉⲣ"
        elif echo "$name_lower$content" | grep -qiE "audio|sound|acoustic|spatial.*audio|voice|speech|tts"; then
            world="ⲩⲁⲃⲗⲉⲛⲓⲉ"; category="ⲩⲁ02_ⲁⲩⲇⲓⲟ"
        elif echo "$name_lower$content" | grep -qiE "haptic|touch|tactile|vibration|force"; then
            world="ⲩⲁⲃⲗⲉⲛⲓⲉ"; category="ⲩⲁ03_ⲏⲁⲡⲧⲓⲕ"
        elif echo "$name_lower$content" | grep -qiE "display|screen|holographic|vr|ar|xr"; then
            world="ⲩⲁⲃⲗⲉⲛⲓⲉ"; category="ⲩⲁ04_ⲇⲓⲥⲡⲗⲁⲩ"
        elif echo "$name_lower$content" | grep -qiE "avatar|face|body|pose|gesture|expression|human|mesh|smpl"; then
            world="ⲩⲁⲃⲗⲉⲛⲓⲉ"; category="ⲩⲁ05_ⲁⲃⲁⲧⲁⲣ"
        elif echo "$name_lower$content" | grep -qiE "scene|world|environment|living.*screen"; then
            world="ⲩⲁⲃⲗⲉⲛⲓⲉ"; category="ⲩⲁ06_ⲥⲕⲉⲛⲉ"
        elif echo "$name_lower$content" | grep -qiE "effect|particle|fog|matting|style.*transfer"; then
            world="ⲩⲁⲃⲗⲉⲛⲓⲉ"; category="ⲩⲁ07_ⲉⲫⲫⲉⲕⲧ"
        elif echo "$name_lower$content" | grep -qiE "stream|video|compress|codec|bandwidth"; then
            world="ⲩⲁⲃⲗⲉⲛⲓⲉ"; category="ⲩⲁ08_ⲥⲧⲣⲓⲙ"
        elif echo "$name_lower$content" | grep -qiE "ui|interface|interact|input|gaze|eye.*track|hand.*track|gui"; then
            world="ⲩⲁⲃⲗⲉⲛⲓⲉ"; category="ⲩⲁ09_ⲩⲓ"
        # РАЗУМ (ⲣⲁⲍⲩⲙ)
        elif echo "$name_lower$content" | grep -qiE "pas|algorithmic.*system|discovery.*pattern"; then
            world="ⲣⲁⲍⲩⲙ"; category="ⲣ01_ⲡⲁⲥ"
        elif echo "$name_lower$content" | grep -qiE "ml|machine.*learn|train|model|federat"; then
            world="ⲣⲁⲍⲩⲙ"; category="ⲣ02_ⲙⲗ"
        elif echo "$name_lower$content" | grep -qiE "neural|network|deep|attention|transformer|diffusion|autograd"; then
            world="ⲣⲁⲍⲩⲙ"; category="ⲣ03_ⲛⲉⲩⲣⲁⲗ"
        elif echo "$name_lower$content" | grep -qiE "algorithm|sort|search|graph|merkle|aho.*corasick"; then
            world="ⲣⲁⲍⲩⲙ"; category="ⲣ04_ⲁⲗⲅⲟ"
        elif echo "$name_lower$content" | grep -qiE "pattern|design|architecture|modular"; then
            world="ⲣⲁⲍⲩⲙ"; category="ⲣ05_ⲡⲁⲧⲧⲉⲣⲛ"
        elif echo "$name_lower$content" | grep -qiE "predict|forecast|estimate"; then
            world="ⲣⲁⲍⲩⲙ"; category="ⲣ06_ⲡⲣⲉⲇⲓⲕⲧ"
        elif echo "$name_lower$content" | grep -qiE "evol|genetic|mutation|fitness|self.*improv"; then
            world="ⲣⲁⲍⲩⲙ"; category="ⲣ07_ⲉⲃⲟⲗⲩⲥⲓⲁ"
        elif echo "$name_lower$content" | grep -qiE "quantum|qubit"; then
            world="ⲣⲁⲍⲩⲙ"; category="ⲣ08_ⲕⲃⲁⲛⲧ"
        elif echo "$name_lower$content" | grep -qiE "reason|logic|inference|proof|theorem|symbolic"; then
            world="ⲣⲁⲍⲩⲙ"; category="ⲣ09_ⲗⲟⲅⲓⲕⲁ"
        else
            # По умолчанию - Разум/Логика
            world="ⲣⲁⲍⲩⲙ"; category="ⲣ09_ⲗⲟⲅⲓⲕⲁ"
        fi
    fi
    
    # Перемещаем файл
    local dest_dir="$SPECS_DIR/$world/$category"
    if [[ -d "$dest_dir" ]]; then
        mv "$file" "$dest_dir/"
        echo -e "  ${GREEN}✓${NC} $filename → $world/$category/"
    else
        echo -e "  ${RED}✗${NC} $filename - категория не найдена: $world/$category"
    fi
}

# Обрабатываем все файлы в корне specs/
count=0
for file in "$SPECS_DIR"/*.vibee; do
    if [[ -f "$file" ]]; then
        classify_and_move "$file"
        ((count++))
    fi
done

echo ""
echo -e "${GREEN}✓ Перемещено файлов: $count${NC}"
echo ""

# Шаг 3: Статистика
echo -e "${YELLOW}Шаг 3: Статистика...${NC}"
echo ""
echo "Распределение по мирам:"
for world in "$SPECS_DIR"/*/; do
    if [[ -d "$world" ]]; then
        world_name=$(basename "$world")
        total=$(find "$world" -name "*.vibee" | wc -l)
        echo "  $world_name: $total файлов"
    fi
done

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Миграция specs/ завершена!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

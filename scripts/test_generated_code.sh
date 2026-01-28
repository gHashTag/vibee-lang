#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE GENERATED CODE TESTER
# ═══════════════════════════════════════════════════════════════════════════════
# Запускает zig test на всех сгенерированных .zig файлах
# φ² + 1/φ² = 3
# ═══════════════════════════════════════════════════════════════════════════════

set -e

OUTPUT_DIR="trinity/output"
REPORT_FILE="generated_code_test_report.txt"
JSON_REPORT="generated_code_test_report.json"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Метрики
TOTAL_FILES=0
PASSED_FILES=0
FAILED_FILES=0
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
TOTAL_TIME_MS=0

# Массивы для хранения результатов
declare -a PASSED_FILES_LIST=()
declare -a FAILED_FILES_LIST=()
declare -a FAILED_ERRORS=()

# ═══════════════════════════════════════════════════════════════════════════════
# ШАГ 1: Проверка директории
# ═══════════════════════════════════════════════════════════════════════════════

if [ ! -d "$OUTPUT_DIR" ]; then
    echo -e "${RED}❌ Ошибка: Директория $OUTPUT_DIR не найдена${NC}"
    echo -e "${YELLOW}   Сначала сгенерируйте код: ./bin/vibeec gen specs/tri/core/*.vibee --no-type-check${NC}"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  VIBEE GENERATED CODE TESTER                                     ║${NC}"
echo -e "${BLUE}║  Тестирование всех .zig файлов в trinity/output/               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# ШАГ 2: Сбор всех .zig файлов (без подкаталогов)
# ═══════════════════════════════════════════════════════════════════════════════

ZIG_FILES=($(ls -1 "$OUTPUT_DIR"/*.zig 2>/dev/null | sort))
TOTAL_FILES=${#ZIG_FILES[@]}

if [ $TOTAL_FILES -eq 0 ]; then
    echo -e "${RED}❌ Ошибка: Не найдено .zig файлов в $OUTPUT_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Найдено $TOTAL_FILES .zig файлов${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# ШАГ 3: Тестирование каждого файла
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${BLUE}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}НАЧИНАЕМ ТЕСТИРОВАНИЕ${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════════════${NC}"
echo ""

CURRENT=0
for zig_file in "${ZIG_FILES[@]}"; do
    CURRENT=$((CURRENT + 1))
    filename=$(basename "$zig_file")
    progress=$((CURRENT * 100 / TOTAL_FILES))
    
    echo -ne "\r${BLUE}[${CURRENT}/${TOTAL_FILES}]${NC} ${filename} (${progress}%)... "
    
    # Запуск zig test
    start_time=$(python3 -c "import time; print(int(time.time() * 1000))")
    if output=$(zig test "$zig_file" 2>&1); then
        # Успех
        PASSED_FILES=$((PASSED_FILES + 1))
        PASSED_FILES_LIST+=("$filename")

        # Парсинг количества тестов
        test_count=$(echo "$output" | grep -oE "All [0-9]+ tests passed" | grep -oE "[0-9]+" || echo "0")
        TOTAL_TESTS=$((TOTAL_TESTS + test_count))
        PASSED_TESTS=$((PASSED_TESTS + test_count))

        end_time=$(python3 -c "import time; print(int(time.time() * 1000))")
        elapsed_ms=$((end_time - start_time))
        TOTAL_TIME_MS=$((TOTAL_TIME_MS + elapsed_ms))

        echo -e "${GREEN}✓ OK${NC} (${test_count} тестов, ${elapsed_ms}мс)"
    else
        # Ошибка
        FAILED_FILES=$((FAILED_FILES + 1))
        FAILED_FILES_LIST+=("$filename")

        # Сохраняем ошибку (берём первые непустые строки)
        error_line=$(echo "$output" | grep -v "^$" | head -3 | tail -1)
        FAILED_ERRORS+=("$error_line")

        echo -e "${RED}✗ FAILED${NC}"
    fi
done

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# ШАГ 4: Генерация отчёта (текст)
# ═══════════════════════════════════════════════════════════════════════════════

cat > "$REPORT_FILE" << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    VIBEE GENERATED CODE TEST REPORT                         ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Date: PLACEHOLDER_DATE                                                      ║
║  φ² + 1/φ² = 3                                                               ║
╚══════════════════════════════════════════════════════════════════════════════╝

═══════════════════════════════════════════════════════════════════════════════
ОБЩИЕ МЕТРИКИ
═══════════════════════════════════════════════════════════════════════════════

Всего файлов:             PLACEHOLDER_TOTAL_FILES
Успешно протестировано:   PLACEHOLDER_PASSED_FILES (PLACEHOLDER_SUCCESS_RATE%)
Неудачно:                  PLACEHOLDER_FAILED_FILES (PLACEHOLDER_FAILURE_RATE%)

Всего тестов:             PLACEHOLDER_TOTAL_TESTS
Прошло:                   PLACEHOLDER_PASSED_TESTS
Не прошло:                PLACEHOLDER_FAILED_TESTS

Общее время:              PLACEHOLDER_TOTAL_TIME_S секунд
Среднее время на файл:    PLACEHOLDER_AVG_TIME_MS мс

═══════════════════════════════════════════════════════════════════════════════
УСПЕШНО ПРОТЕСТИРОВАННЫЕ ФАЙЛЫ (PLACEHOLDER_PASSED_COUNT)
═══════════════════════════════════════════════════════════════════════════════
PLACEHOLDER_PASSED_FILES_LIST

═══════════════════════════════════════════════════════════════════════════════
НЕУДАЧНЫЕ ФАЙЛЫ (PLACEHOLDER_FAILED_COUNT)
═══════════════════════════════════════════════════════════════════════════════
PLACEHOLDER_FAILED_FILES_WITH_ERRORS

═══════════════════════════════════════════════════════════════════════════════
РЕЗЮМЕ
═══════════════════════════════════════════════════════════════════════════════

Качество генерации кода: PLACEHOLDER_QUALITY

EOF

# Подстановка значений
DATE=$(date "+%Y-%m-%d %H:%M:%S")
SUCCESS_RATE=$((PASSED_FILES * 100 / TOTAL_FILES))
FAILURE_RATE=$((FAILED_FILES * 100 / TOTAL_FILES))
FAILED_TESTS=$((TOTAL_TESTS - PASSED_TESTS))
TOTAL_TIME_S=$((TOTAL_TIME_MS / 1000))
AVG_TIME_MS=$((TOTAL_TIME_MS / TOTAL_FILES))

# Определение качества
if [ $SUCCESS_RATE -eq 100 ]; then
    QUALITY="✓ ОТЛИЧНО (все файлы генерируют валидный код)"
elif [ $SUCCESS_RATE -ge 90 ]; then
    QUALITY="▲ ХОРОШО (большинство файлов валидны)"
elif [ $SUCCESS_RATE -ge 70 ]; then
    QUALITY="○ УДОВЛЕТВОРИТЕЛЬНО (некоторые файлы имеют ошибки)"
else
    QUALITY="▼ ПЛОХО (многие файлы генерируют сломанный код)"
fi

# Формирование списков
PASSED_LIST=""
for file in "${PASSED_FILES_LIST[@]}"; do
    PASSED_LIST+="  ✓ $file\n"
done

FAILED_LIST=""
for i in "${!FAILED_FILES_LIST[@]}"; do
    file="${FAILED_FILES_LIST[$i]}"
    error="${FAILED_ERRORS[$i]}"
    FAILED_LIST+="  ✗ $file\n     Ошибка: $error\n"
done

# Подстановка в файл
sed -i.bak \
    -e "s/PLACEHOLDER_DATE/$DATE/g" \
    -e "s/PLACEHOLDER_TOTAL_FILES/$TOTAL_FILES/g" \
    -e "s/PLACEHOLDER_PASSED_FILES/$PASSED_FILES/g" \
    -e "s/PLACEHOLDER_SUCCESS_RATE/$SUCCESS_RATE/g" \
    -e "s/PLACEHOLDER_FAILED_FILES/$FAILED_FILES/g" \
    -e "s/PLACEHOLDER_FAILURE_RATE/$FAILURE_RATE/g" \
    -e "s/PLACEHOLDER_TOTAL_TESTS/$TOTAL_TESTS/g" \
    -e "s/PLACEHOLDER_PASSED_TESTS/$PASSED_TESTS/g" \
    -e "s/PLACEHOLDER_FAILED_TESTS/$FAILED_TESTS/g" \
    -e "s/PLACEHOLDER_TOTAL_TIME_S/$TOTAL_TIME_S/g" \
    -e "s/PLACEHOLDER_AVG_TIME_MS/$AVG_TIME_MS/g" \
    -e "s/PLACEHOLDER_PASSED_COUNT/$PASSED_FILES/g" \
    -e "s/PLACEHOLDER_FAILED_COUNT/$FAILED_FILES/g" \
    -e "s/PLACEHOLDER_QUALITY/$QUALITY/g" \
    -e "s/PLACEHOLDER_PASSED_FILES_LIST/$PASSED_LIST/g" \
    -e "s/PLACEHOLDER_FAILED_FILES_WITH_ERRORS/$FAILED_LIST/g" \
    "$REPORT_FILE"

rm "${REPORT_FILE}.bak"

# ═══════════════════════════════════════════════════════════════════════════════
# ШАГ 5: Генерация отчёта (JSON)
# ═══════════════════════════════════════════════════════════════════════════════

cat > "$JSON_REPORT" << EOF
{
  "date": "$DATE",
  "summary": {
    "total_files": $TOTAL_FILES,
    "passed_files": $PASSED_FILES,
    "failed_files": $FAILED_FILES,
    "success_rate": $SUCCESS_RATE,
    "failure_rate": $FAILURE_RATE
  },
  "tests": {
    "total_tests": $TOTAL_TESTS,
    "passed_tests": $PASSED_TESTS,
    "failed_tests": $FAILED_TESTS
  },
  "performance": {
    "total_time_ms": $TOTAL_TIME_MS,
    "total_time_s": $TOTAL_TIME_S,
    "avg_time_per_file_ms": $AVG_TIME_MS
  },
  "quality": "$QUALITY",
  "passed_files": [
$(for file in "${PASSED_FILES_LIST[@]}"; do echo "    \"$file\","; done | head -n -1)
  ],
  "failed_files": [
$(for i in "${!FAILED_FILES_LIST[@]}"; do
    file="${FAILED_FILES_LIST[$i]}"
    error="${FAILED_ERRORS[$i]}"
    error_json=$(echo "$error" | sed 's/"/\\"/g' | sed 's/\\\\/\\/g')
    echo "    {\"file\": \"$file\", \"error\": \"$error_json\"},"
done | head -n -1)
  ]
}
EOF

# ═══════════════════════════════════════════════════════════════════════════════
# ШАГ 6: Вывод результатов
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${BLUE}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "Всего файлов:          ${BLUE}$TOTAL_FILES${NC}"
echo -e "Успешно:               ${GREEN}$PASSED_FILES files${NC} (${GREEN}$SUCCESS_RATE%${NC})"
echo -e "Неудачно:              ${RED}$FAILED_FILES files${NC} (${RED}$FAILURE_RATE%${NC})"
echo ""

echo -e "Всего тестов:          ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Прошло:                ${GREEN}$PASSED_TESTS tests${NC}"
echo -e "Не прошло:             ${RED}$FAILED_TESTS tests${NC}"
echo ""

echo -e "Общее время:           ${BLUE}${TOTAL_TIME_S} сек${NC}"
echo -e "Среднее время/файл:    ${BLUE}${AVG_TIME_MS} мс${NC}"
echo ""

echo -e "Качество: ${QUALITY}"
echo ""

if [ $FAILED_FILES -gt 0 ]; then
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}НЕУДАЧНЫЕ ФАЙЛЫ ($FAILED_FILES)${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    for i in "${!FAILED_FILES_LIST[@]}"; do
        file="${FAILED_FILES_LIST[$i]}"
        error="${FAILED_ERRORS[$i]}"
        echo -e "  ${RED}✗${NC} $file"
        echo -e "     ${YELLOW}Ошибка:${NC} $error"
        echo ""
    done
fi

echo -e "${BLUE}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Отчёты сохранены:${NC}"
echo -e "  - $REPORT_FILE"
echo -e "  - $JSON_REPORT"
echo -e "${BLUE}══════════════════════════════════════════════════════════════════${NC}"
echo ""

# Выход с кодом ошибки, если есть неудачные файлы
if [ $FAILED_FILES -gt 0 ]; then
    exit 1
else
    exit 0
fi

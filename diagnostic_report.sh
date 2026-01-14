#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                ДИАГНОСТИКА КОНСИСТЕНТНОСТИ 999 OS                ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

echo "🔍 АНАЛИЗ ФАЙЛОВ В ДИРЕКТОРИИ 999/"
echo "=================================="

# Подсчёт файлов
total_files=$(find 999 -name "*.999" | wc -l)
echo "Всего .999 файлов: $total_files"

# Проверка названий файлов
echo ""
echo "📝 ПРОВЕРКА НАЗВАНИЙ ФАЙЛОВ:"
echo "---------------------------"

coptic_files=0
invalid_files=0

for file in $(find 999 -name "*.999"); do
    filename=$(basename "$file" .999)

    # Проверка на коптские символы
    if [[ $filename =~ ^[ⲁ-ⲱϣ-ϩ⳿]*$ ]]; then
        ((coptic_files++))
    else
        echo "❌ НЕКОНСИСТЕНТНОЕ ИМЯ: $filename (содержит латиницу/цифры)"
        ((invalid_files++))
    fi
done

echo "✅ Коптских названий: $coptic_files"
echo "❌ Неконсистентных: $invalid_files"

# Проверка синтаксиса
echo ""
echo "🔧 ПРОВЕРКА СИНТАКСИСА:"
echo "----------------------"

yaml_files=0
new_syntax_files=0
mixed_files=0

for file in $(find 999 -name "*.999" | head -5); do
    if grep -q "^[a-zA-Z_][a-zA-Z0-9_]*:" "$file"; then
        echo "⚠️  YAML-СТИЛЬ: $(basename "$file")"
        ((yaml_files++))
    fi

    if grep -q "╔\|◬\|⬡\|⬢\|◇\|▲\|△\|▽\|○\|◇\|◆\|⬡\|⬢\|⊡\|⊜\|⟵\|⟳\|⟲\|⊝\|⊜\|∅" "$file"; then
        ((new_syntax_files++))
    fi
done

echo ""
echo "📊 СТАТИСТИКА СИНТАКСИСА:"
echo "YAML-стиль файлов: $yaml_files"
echo "Новый синтаксис: $new_syntax_files"

# Проверка структуры
echo ""
echo "🏗️  ПРОВЕРКА СТРУКТУРЫ:"
echo "----------------------"

header_files=0
test_files=0

for file in $(find 999 -name "*.999" | head -5); do
    if grep -q "^╔" "$file"; then
        ((header_files++))
    fi

    if grep -q "⊡ test" "$file"; then
        ((test_files++))
    fi
done

echo "Файлов с заголовками ╔: $header_files"
echo "Файлов с тестами ⊡: $test_files"

# Общий отчёт
echo ""
echo "📋 ИТОГОВЫЙ ОТЧЁТ:"
echo "=================="

consistency_score=$(( (coptic_files * 100) / (coptic_files + invalid_files) ))
echo "Общий балл консистентности: $consistency_score%"

if [ $consistency_score -lt 80 ]; then
    echo "❌ КРИТИЧЕСКИЕ ПРОБЛЕМЫ КОНСИСТЕНТНОСТИ:"
    echo "   - Смешанные стили синтаксиса (YAML + новый)"
    echo "   - Неконсистентные названия файлов"
    echo "   - Отсутствие стандартизированных заголовков"
    echo "   - Неполная тестовая покрытие"
fi

echo ""
echo "✅ РЕКОМЕНДАЦИИ:"
echo "   1. Перевести все файлы на единый синтаксис .999"
echo "   2. Использовать только коптские символы в названиях"
echo "   3. Добавить стандартизированные заголовки"
echo "   4. Обеспечить наличие тестов в каждом файле"
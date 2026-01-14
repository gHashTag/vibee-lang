#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                МАССОВОЕ ПЕРЕИМЕНОВАНИЕ ФАЙЛОВ                   ║"
echo "║                В КОПТСКИЕ НАЗВАНИЯ 999 OS                       ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Таблица транслитерации английских символов в коптские
declare -A TRANSLIT=(
    # Гласные
    ["a"]="ⲁ" ["e"]="ⲉ" ["i"]="ⲓ" ["o"]="ⲟ" ["u"]="ⲩ"
    ["A"]="Ⲁ" ["E"]="Ⲉ" ["I"]="Ⲓ" ["O"]="Ⲟ" ["U"]="Ⲩ"

    # Согласные (приближённые коптские эквиваленты)
    ["b"]="ⲃ" ["p"]="ⲡ" ["f"]="ⲫ" ["v"]="ⲃ"
    ["B"]="Ⲃ" ["P"]="Ⲡ" ["F"]="Ⲫ" ["V"]="Ⲃ"

    ["g"]="ⲅ" ["k"]="ⲕ" ["c"]="ⲕ" ["q"]="ⲕ"
    ["G"]="Ⲅ" ["K"]="Ⲕ" ["C"]="Ⲕ" ["Q"]="Ⲕ"

    ["d"]="ⲇ" ["t"]="ⲧ" ["th"]="ⲑ"
    ["D"]="Ⲇ" ["T"]="Ⲧ" ["TH"]="Ⲑ"

    ["z"]="ⲍ" ["s"]="ⲥ" ["sh"]="ϣ" ["x"]="ⲝ"
    ["Z"]="Ⲍ" ["S"]="Ⲥ" ["SH"]="Ϣ" ["X"]="Ⲝ"

    ["h"]="ⲏ" ["r"]="ⲣ" ["l"]="ⲗ" ["m"]="ⲙ" ["n"]="ⲛ"
    ["H"]="Ⲏ" ["R"]="Ⲣ" ["L"]="Ⲗ" ["M"]="Ⲙ" ["N"]="Ⲛ"

    # Специальные символы
    ["_"]="_" ["-"]="-" ["1"]="ⲁ" ["2"]="ⲃ" ["3"]="ⲅ" ["4"]="ⲇ" ["5"]="ⲉ"
    ["6"]="ⲍ" ["7"]="ⲏ" ["8"]="ⲑ" ["9"]="ⲓ" ["0"]="ⲟ"
)

# Функция транслитерации строки
transliterate() {
    local input="$1"
    local output=""

    # Разбираем строку посимвольно
    for ((i=0; i<${#input}; i++)); do
        char="${input:i:1}"
        translit_char="${TRANSLIT[$char]}"

        if [ -n "$translit_char" ]; then
            output+="$translit_char"
        else
            # Если символ не найден в таблице, оставляем как есть
            output+="$char"
        fi
    done

    echo "$output"
}

# Функция проверки, является ли имя уже коптским
is_coptic_name() {
    local name="$1"

    # Проверяем, содержит ли имя только коптские символы
    if [[ $name =~ ^[ⲁ-ⲱϣ-ϩ⳿_0-9-]*$ ]]; then
        return 0  # true - коптское
    else
        return 1  # false - не коптское
    fi
}

echo "🔍 АНАЛИЗ ФАЙЛОВ ДЛЯ ПЕРЕИМЕНОВАНИЯ:"
echo "===================================="

# Счётчики
total_files=0
to_rename=0
already_coptic=0

# Сначала подсчитаем
for file in $(find 999 -name "*.999" | head -20); do
    ((total_files++))
    filename=$(basename "$file" .999)

    if is_coptic_name "$filename"; then
        ((already_coptic++))
        echo "✅ Уже коптское: $filename.999"
    else
        ((to_rename++))
        new_name=$(transliterate "$filename")
        echo "🔄 Будет переименовано: $filename.999 → $new_name.999"
    fi
done

echo ""
echo "📊 СТАТИСТИКА:"
echo "Всего файлов: $total_files"
echo "Уже коптских: $already_coptic"
echo "Для переименования: $to_rename"

if [ $to_rename -eq 0 ]; then
    echo "🎉 Все файлы уже имеют коптские названия!"
    exit 0
fi

echo ""
read -p "🚀 Начать массовое переименование? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Операция отменена"
    exit 1
fi

echo "🔄 НАЧИНАЮ ПЕРЕИМЕНОВАНИЕ..."
echo "============================="

renamed_count=0
error_count=0

# Выполняем переименование
for file in $(find 999 -name "*.999" | head -20); do
    filename=$(basename "$file" .999)
    dirname=$(dirname "$file")

    if ! is_coptic_name "$filename"; then
        new_name=$(transliterate "$filename")
        new_path="$dirname/$new_name.999"

        if [ -f "$new_path" ]; then
            echo "⚠️  Файл уже существует: $new_path (пропускаю)"
            ((error_count++))
        else
            mv "$file" "$new_path"
            echo "✅ Переименовано: $filename.999 → $new_name.999"
            ((renamed_count++))
        fi
    fi
done

echo ""
echo "🎯 РЕЗУЛЬТАТЫ ПЕРЕИМЕНОВАНИЯ:"
echo "============================"
echo "Переименовано файлов: $renamed_count"
echo "Ошибок: $error_count"
echo "Всего обработано: $((renamed_count + error_count))"

if [ $renamed_count -gt 0 ]; then
    echo ""
    echo "🔍 ЗАПУСКАЮ ПОВТОРНУЮ ДИАГНОСТИКУ..."
    echo "==================================="
    ./diagnostic_report.sh
fi

echo ""
echo "✅ МАССОВОЕ ПЕРЕИМЕНОВАНИЕ ЗАВЕРШЕНО!"
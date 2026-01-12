#!/bin/bash
# Codegen Guard - перехватывает команды создания генераторов

# Перехватываем cat > generate.sh
function cat() {
  if [[ "$*" == *"generate.sh"* ]]; then
    echo "❌ ОШИБКА: Нельзя создавать generate.sh!"
    echo ""
    echo "Используй: make generate PLUGIN=path/to/plugin"
    echo ""
    return 1
  fi
  command cat "$@"
}

# Перехватываем touch generate.sh
function touch() {
  if [[ "$*" == *"generate.sh"* ]]; then
    echo "❌ ОШИБКА: Нельзя создавать generate.sh!"
    echo ""
    echo "Используй: make generate PLUGIN=path/to/plugin"
    echo ""
    return 1
  fi
  command touch "$@"
}

# Перехватываем vim/nano generate.sh
function vim() {
  if [[ "$*" == *"generate.sh"* ]]; then
    echo "❌ ОШИБКА: Нельзя создавать generate.sh!"
    echo ""
    echo "Используй: make generate PLUGIN=path/to/plugin"
    echo ""
    return 1
  fi
  command vim "$@"
}

function nano() {
  if [[ "$*" == *"generate.sh"* ]]; then
    echo "❌ ОШИБКА: Нельзя создавать generate.sh!"
    echo ""
    echo "Используй: make generate PLUGIN=path/to/plugin"
    echo ""
    return 1
  fi
  command nano "$@"
}

# Показываем подсказку при входе
echo "🛡️ Codegen Guard активен"
echo "Используй: make generate PLUGIN=path/to/plugin"

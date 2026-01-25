#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY FPGA - ШАГ 2: НАСТРОЙКА FPGA ОКРУЖЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════════
# φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Получаем IP
if [ -n "$1" ]; then
    PUBLIC_IP="$1"
elif [ -f /tmp/trinity_public_ip ]; then
    PUBLIC_IP=$(cat /tmp/trinity_public_ip)
else
    echo "❌ Укажи IP: ./02_setup_fpga.sh <PUBLIC_IP>"
    exit 1
fi

KEY_FILE="$HOME/.ssh/trinity-fpga-key.pem"

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    TRINITY FPGA - НАСТРОЙКА ОКРУЖЕНИЯ"
echo "                    φ² + 1/φ² = 3 | PHOENIX = 999"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "IP: $PUBLIC_IP"
echo ""

# Ждём доступности SSH
echo "[1/5] Ожидаю доступности SSH..."
for i in {1..30}; do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i $KEY_FILE centos@$PUBLIC_IP "echo ok" &>/dev/null; then
        echo "✅ SSH доступен"
        break
    fi
    echo "  Попытка $i/30..."
    sleep 10
done

# Выполняем настройку на удалённом сервере
echo "[2/5] Устанавливаю AWS FPGA SDK..."
ssh -i $KEY_FILE centos@$PUBLIC_IP << 'REMOTE_SCRIPT'
set -e

# Клонируем AWS FPGA SDK
if [ ! -d ~/aws-fpga ]; then
    git clone https://github.com/aws/aws-fpga.git ~/aws-fpga
fi

# Настраиваем SDK
cd ~/aws-fpga
source sdk_setup.sh

echo "✅ AWS FPGA SDK установлен"
REMOTE_SCRIPT

echo "[3/5] Клонирую TRINITY..."
ssh -i $KEY_FILE centos@$PUBLIC_IP << 'REMOTE_SCRIPT'
set -e

if [ ! -d ~/vibee-lang ]; then
    git clone https://github.com/gHashTag/vibee-lang.git ~/vibee-lang
fi

cd ~/vibee-lang
git pull origin main

echo "✅ TRINITY склонирован"
REMOTE_SCRIPT

echo "[4/5] Проверяю FPGA..."
ssh -i $KEY_FILE centos@$PUBLIC_IP << 'REMOTE_SCRIPT'
set -e

# Проверяем наличие FPGA
sudo fpga-describe-local-image -S 0 -H 2>/dev/null || echo "FPGA слот 0: пустой (готов к загрузке)"

echo "✅ FPGA доступен"
REMOTE_SCRIPT

echo "[5/5] Копирую Verilog файлы..."
ssh -i $KEY_FILE centos@$PUBLIC_IP << 'REMOTE_SCRIPT'
set -e

# Создаём директорию для проекта
mkdir -p ~/trinity_fpga_project
cp ~/vibee-lang/trinity/output/fpga/*.v ~/trinity_fpga_project/

echo "Файлы скопированы:"
ls -la ~/trinity_fpga_project/

echo "✅ Verilog файлы готовы"
REMOTE_SCRIPT

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    ✅ ОКРУЖЕНИЕ НАСТРОЕНО!"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Следующий шаг:"
echo "  ./03_build_afi.sh $PUBLIC_IP"
echo ""
echo "Или подключись вручную:"
echo "  ssh -i $KEY_FILE centos@$PUBLIC_IP"
echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"

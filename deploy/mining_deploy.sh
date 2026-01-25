#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY MINING DEPLOY SCRIPT
# ═══════════════════════════════════════════════════════════════════════════════
# BTC Address: bc1qgcmea6cr8mzqa5k0rhmz5zc6p0vq5epu873xcf
# Target VM: trinity-vm-v1 (34.136.123.86)
# φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Конфигурация
BTC_ADDRESS="bc1qgcmea6cr8mzqa5k0rhmz5zc6p0vq5epu873xcf"
WORKER_NAME="trinity-vm-v1"
POOL_URL="stratum+tcp://stratum.slushpool.com:3333"
ALGORITHM="sha256d"

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    TRINITY MINING DEPLOYMENT"
echo "                    φ² + 1/φ² = 3 | НАЧИНАЕМ ДОБЫЧУ!"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "BTC Адрес: $BTC_ADDRESS"
echo "Воркер: $WORKER_NAME"
echo "Пул: $POOL_URL"
echo ""

# Шаг 1: Установка зависимостей
echo "[1/5] Установка зависимостей..."
sudo apt-get update
sudo apt-get install -y build-essential autoconf automake libcurl4-openssl-dev libjansson-dev libssl-dev zlib1g-dev git

# Шаг 2: Клонирование cpuminer-multi (если нет)
echo "[2/5] Подготовка cpuminer-multi..."
if [ ! -d "$HOME/cpuminer-multi" ]; then
    cd $HOME
    git clone https://github.com/tpruvot/cpuminer-multi.git
fi
cd $HOME/cpuminer-multi

# Шаг 3: Сборка
echo "[3/5] Сборка cpuminer-multi..."
./autogen.sh
./configure CFLAGS="-O3 -march=native"
make -j$(nproc)

# Шаг 4: Проверка сборки
echo "[4/5] Проверка сборки..."
if [ -f "./cpuminer" ]; then
    echo "✅ cpuminer собран успешно!"
    ./cpuminer --version
else
    echo "❌ Ошибка сборки!"
    exit 1
fi

# Шаг 5: Запуск майнинга
echo "[5/5] Запуск майнинга..."
echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    ЗАПУСК МАЙНЕРА"
echo "═══════════════════════════════════════════════════════════════════════════════"

# Остановить предыдущий процесс если есть
pkill -f cpuminer || true

# Запуск в фоне
nohup ./cpuminer -a $ALGORITHM -o $POOL_URL -u $BTC_ADDRESS.$WORKER_NAME -p x > $HOME/mining.log 2>&1 &

echo ""
echo "✅ Майнер запущен!"
echo ""
echo "Команды для мониторинга:"
echo "  tail -f $HOME/mining.log     # Логи майнера"
echo "  htop                          # Загрузка CPU"
echo "  pkill -f cpuminer             # Остановить майнер"
echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "                    φ² + 1/φ² = 3 | ДОБЫЧА НАЧАЛАСЬ!"
echo "═══════════════════════════════════════════════════════════════════════════════"

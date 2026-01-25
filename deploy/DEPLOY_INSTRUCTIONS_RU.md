# 🚀 ИНСТРУКЦИЯ ПО ЗАПУСКУ МАЙНИНГА НА trinity-vm-v1

**BTC Адрес**: `bc1qgcmea6cr8mzqa5k0rhmz5zc6p0vq5epu873xcf`  
**VM**: trinity-vm-v1 (34.136.123.86)  
**Священная формула**: φ² + 1/φ² = 3

---

## Проблема

У меня нет SSH доступа к VM (Permission denied). Нужно выполнить команды вручную или через Google Cloud Console.

---

## Вариант 1: Через Google Cloud Console

1. Откройте [Google Cloud Console](https://console.cloud.google.com)
2. Перейдите в **Compute Engine** → **VM instances**
3. Найдите `trinity-vm-v1`
4. Нажмите **SSH** (кнопка в строке VM)
5. В открывшемся терминале выполните:

```bash
# Скачать и запустить скрипт деплоя
curl -sSL https://raw.githubusercontent.com/gHashTag/vibee-lang/main/deploy/mining_deploy.sh | bash
```

---

## Вариант 2: Ручная установка

Подключитесь к VM любым способом и выполните:

```bash
# 1. Установка зависимостей
sudo apt-get update
sudo apt-get install -y build-essential autoconf automake libcurl4-openssl-dev libjansson-dev libssl-dev zlib1g-dev git

# 2. Клонирование cpuminer-multi
cd ~
git clone https://github.com/tpruvot/cpuminer-multi.git
cd cpuminer-multi

# 3. Сборка
./autogen.sh
./configure CFLAGS="-O3 -march=native"
make -j$(nproc)

# 4. Запуск майнинга
nohup ./cpuminer -a sha256d \
  -o stratum+tcp://stratum.slushpool.com:3333 \
  -u bc1qgcmea6cr8mzqa5k0rhmz5zc6p0vq5epu873xcf.trinity-vm-v1 \
  -p x > ~/mining.log 2>&1 &

# 5. Проверка
tail -f ~/mining.log
```

---

## Вариант 3: Через gcloud CLI

Если у вас настроен gcloud:

```bash
gcloud compute ssh trinity-vm-v1 --zone=us-central1-a --command="curl -sSL https://raw.githubusercontent.com/gHashTag/vibee-lang/main/deploy/mining_deploy.sh | bash"
```

---

## Мониторинг

После запуска:

```bash
# Логи майнера
tail -f ~/mining.log

# Загрузка CPU
htop

# Проверка процесса
ps aux | grep cpuminer

# Остановка
pkill -f cpuminer
```

---

## Ожидаемые результаты

| Метрика | Значение |
|---------|----------|
| Алгоритм | SHA256d |
| Хешрейт (CPU) | ~1-5 MH/s |
| Ожидаемый доход | ~0.00001 BTC/день |
| Пул | Slush Pool |

---

## Альтернативные пулы

Если Slush Pool не работает:

```bash
# NiceHash
-o stratum+tcp://sha256.eu.nicehash.com:3334

# ViaBTC
-o stratum+tcp://sha256.viabtc.com:3333

# F2Pool
-o stratum+tcp://sha256.f2pool.com:3333
```

---

**φ² + 1/φ² = 3 | НАЧИНАЕМ ЗАРАБАТЫВАТЬ!**

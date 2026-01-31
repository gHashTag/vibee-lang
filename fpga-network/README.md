# FPGA.Network Agent

**Децентрализованная сеть BitNet LLM Inference на FPGA**

## Быстрый старт для провайдеров

```bash
# 1. Установка
curl -sSL https://fpga.network/install.sh | bash

# 2. Регистрация в сети
fpga-agent register --wallet <YOUR_SOLANA_WALLET>

# 3. Запуск
fpga-agent start
```

## Структура проекта

```
fpga-network/
├── agent/              # Агент для провайдеров
│   ├── main.py         # Точка входа
│   ├── config.py       # Конфигурация
│   ├── fpga.py         # Работа с FPGA
│   ├── inference.py    # BitNet inference
│   └── network.py      # Сетевое взаимодействие
├── server/             # Координирующий сервер
│   ├── api.py          # REST API
│   ├── matcher.py      # Matching requestor ↔ provider
│   └── settlement.py   # Расчёты в $FPGA
├── client/             # SDK для requestors
│   ├── python/
│   └── javascript/
├── bitstreams/         # Готовые bitstreams
│   └── README.md
└── scripts/            # Скрипты установки
    └── install.sh
```

## Требования

### Для провайдеров:
- FPGA: Alveo U50/U55C/U280 или Arty A7
- OS: Ubuntu 20.04+ / Debian 11+
- RAM: 8GB+
- Vivado Runtime (для Xilinx)
- Python 3.10+
- Solana wallet с минимум 10,000 $FPGA для staking

### Поддерживаемые FPGA:

| Плата | Модели | Статус |
|-------|--------|--------|
| Alveo U55C | BitNet 1B-13B | ✅ Full Support |
| Alveo U50 | BitNet 1B-7B | ✅ Full Support |
| Alveo U280 | BitNet 1B-30B | ✅ Full Support |
| Arty A7-35T | BitNet Demo | ⚠️ Demo Only |

## Документация

- [Установка](docs/installation.md)
- [Конфигурация](docs/configuration.md)
- [API Reference](docs/api.md)
- [Troubleshooting](docs/troubleshooting.md)

## Лицензия

MIT License

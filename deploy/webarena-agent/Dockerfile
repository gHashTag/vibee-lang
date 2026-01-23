FROM python:3.11-slim

WORKDIR /app

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    chromium \
    chromium-driver \
    && rm -rf /var/lib/apt/lists/*

# Установка Python зависимостей
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Установка Playwright
RUN pip install playwright && playwright install chromium

# Копирование кода агента
COPY . .

# Порт для API
EXPOSE 8080

# Запуск
CMD ["python", "agent_server.py"]

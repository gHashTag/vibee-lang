# 🚀 Деплой Moltbot на Elest.io

## Шаг 1: Подключение репозитория

1. Открой: https://dash.elest.io/15632/default-project/ci-cd/creation?&social=Github
2. Выбери опцию **"Connect GitHub"**
3. Найди и выбери: **gHashTag/moltbot**
4. Нажми **"Connect"**

## Шаг 2: Выбор типа сервиса

1. В списке появится `moltbot`
2. Выбери его для деплоя
3. Elest.io автоматически найдёт `render.yaml`

## Шаг 3: Настройка (если нужно)

```
Service Name: moltbot
Repository: gHashTag/moltbot
Branch: main
Runtime: Docker
Dockerfile: ./Dockerfile
Command: node dist/index.js
Port: 8080

Environment Variables:
  - PORT=8080
  - CLAWDBOT_STATE_DIR=/data/.clawdbot
  - CLAWDBOT_WORKSPACE_DIR=/data/workspace
  - CLAWDBOT_PREFER_PNPM=1
  - NODE_ENV=production
```

## Шаг 4: Создание

1. Нажми **"Create Service"**
2. Подожди 3-5 минут
3. Получи URL: `https://moltbot-xxxx.elest.io`

## ✅ Готово!

Молтбот задеплоен на Elest.io бесплатно с $10 кредитами!

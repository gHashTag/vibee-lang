# 🔗 Discord: Webhook vs Bot Token - что нужно?

## ❌ Webhook - НЕ НУЖЕН для Moltbot

Discord Webhook - это для **отправки сообщений**, но НЕ для **управления ботом**.

**Для Moltbot нужен Discord Bot Token!**

---

## ✅ Что нужно для Discord Bot:

### 1. Discord Bot Token (ОБЯЗАТЕЛЬНО)

**Где взять:**
1. Открой https://discord.com/developers/applications
2. Выбери или создай приложение
3. Перейди в **"Bot"** → **"Reset Token"** → **"Copy"**
4. Сохрани токен!

### 2. Intents (Права доступа)

**Где включить:**
1. Настройки приложения → **"Bot"**
2. **Message Content Intent** = ✅ (Enable)
3. **Server Members Intent** = ✅ (Enable, если нужно)

### 3. Инвайт бота

**Где получить:**
1. Настройки приложения → **"OAuth2"** → **"URL Generator"**
2. Выбери scopes: **`bot`**
3. Выбери permissions: **`Messages Read`, `Send Messages`, `Read Message History`, `Embed Links`**
4. Нажми **"Generate URL"**
5. Скопируй и отправь в Discord

---

## 🔧 Как подключить Discord в Moltbot:

### Вариант 1: Через moltbot onboard

```bash
export PATH="/opt/homebrew/bin:$PATH"
/opt/homebrew/bin/moltbot onboard
```

**Инструкция на экране:**
1. Нажми `y`
2. Выбери Discord
3. Вставь Bot Token
4. Получи Инвайт URL
5. Отправь в Discord

### Вариант 2: Ручная настройка

```json5
{
  "channels": {
    "discord": {
      "enabled": true,
      "token": "ВАШ_DISCORD_BOT_TOKEN"
    }
  }
}
```

**Или через environment variable:**

```bash
export DISCORD_BOT_TOKEN="ВАШ_BOT_TOKEN"
```

---

## ⚠️ Разница: Webhook vs Bot Token

| Тип | Для чего нужен | Нужно для Moltbot |
|-----|----------------|-------------------|
| **Bot Token** | Управление ботом, чаты, DM | ✅ **НУЖЕН** |
| **Webhook** | Отправка сообщений в канал | ❌ НЕ НУЖЕН |
| **Invite URL** | Доступ бота к серверу | ✅ НУЖЕН |

---

## 🎯 Твой webhook (не нужен!):

```
https://discord.com/api/webhooks/809096135040827433/jjn5PWkddIw-wr5UUD3A3PA4lrIuH-MxQotRIn1_KPWHoMP7wJR13hRWkOaB13IahAWA
```

Это **вебхук для отправки сообщений**, но не для управления ботом.

**Нужен:**
- ✅ Discord Bot Token (получить на discord.com/developers/applications)
- ✅ Инвайт URL (отправить в Discord чат)
- ✅ Включенные Intents

---

## 🚀 Быстрая инструкция:

### 1. Получить Bot Token
```
https://discord.com/developers/applications
→ New Application
→ Bot
→ Reset Token
→ Copy
```

### 2. Включить Intents
```
Настройки Bot
→ Message Content Intent: ✅
→ Server Members Intent: ✅
```

### 3. Получить Инвайт URL
```
Настройки OAuth2
→ URL Generator
→ Scopes: ✅ bot
→ Permissions: ✅ Messages Read, Send Messages, Read Message History, Embed Links
→ Generate URL
→ Скопировать
```

### 4. Инвайт в Discord
- Отправь полученный URL в любой Discord чат
- Бот присоединится к серверу

### 5. Подключить в Moltbot
```bash
export PATH="/opt/homebrew/bin:$PATH"
/opt/homebrew/bin/moltbot onboard
```

---

## ✅ Что дальше:

1. Получи Bot Token на https://discord.com/developers/applications
2. Включи Intents
3. Получи Инвайт URL
4. Инвайт бота в Discord
5. Запусти `/opt/homebrew/bin/moltbot onboard` и подключи Discord

**Webhook не нужен!** Нужен Bot Token!

---

**Файл создан:** `DISCORD_GUIDE.md`

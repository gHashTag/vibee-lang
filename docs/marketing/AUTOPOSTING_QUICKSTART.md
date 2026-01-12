# VIBEE Autoposting - Quick Start Guide

**Дата**: 2026-01-11  
**Статус**: ✅ Ready to use  
**Время setup**: ~30 минут

---

## 🚀 Quick Start (3 шага)

### 1. Получить credentials (15 минут)

**Twitter** (если нужен):
1. [developer.twitter.com](https://developer.twitter.com) → Sign up
2. Apply for Elevated access
3. Create App → Get API Keys
4. Save to password manager

**Telegram** (обязательно):
1. Open Telegram → @BotFather
2. `/newbot` → Follow instructions
3. Save bot token
4. Create channel → Add bot as admin

### 2. Настроить локально (5 минут)

```bash
# Clone repo
git clone https://github.com/gHashTag/vibee-lang.git
cd vibee-lang

# Create .env from example
cp .env.example .env

# Edit .env with your credentials
nano .env
```

**В .env**:
```bash
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_CHAT_ID=@your_channel_here

# Twitter (optional)
TWITTER_API_KEY=your_key_here
TWITTER_API_SECRET=your_secret_here
TWITTER_ACCESS_TOKEN=your_token_here
TWITTER_ACCESS_TOKEN_SECRET=your_token_secret_here
```

### 3. Протестировать (5 минут)

```bash
# Load environment
source .env

# Test Telegram bot
./scripts/test-telegram-safe.sh

# Test full autoposting (dry run)
cd gleam && gleam run -m vibee_autoposting
```

**Expected output**:
```
🐝 VIBEE Autoposting Service
============================

📋 Loading configuration...
✅ Configuration loaded

🚀 Starting scheduler...
✅ Scheduler started

📅 Scheduled posts:
  • post_1_release at 2026-01-12T09:00:00Z
  • post_2_origin at 2026-01-13T09:00:00Z
  ...

⏰ Checking every 60 seconds
```

---

## 📦 Что включено

### Source Code
- ✅ Twitter API client (OAuth 1.0a)
- ✅ Telegram Bot API client
- ✅ OTP scheduler (fault-tolerant)
- ✅ 10 готовых постов
- ✅ Environment-based config

### Deployment
- ✅ Dockerfile
- ✅ Fly.io config
- ✅ Deploy script

### Documentation
- ✅ Setup guide
- ✅ Security guide
- ✅ Troubleshooting

### Testing
- ✅ Safe test scripts
- ✅ No hardcoded tokens

---

## 🔒 Безопасность

**ВАЖНО**: Никогда не коммить токены в git!

**Где хранить**:
- ✅ `.env` файл (в `.gitignore`)
- ✅ Fly.io secrets
- ✅ Password manager

**Проверка**:
```bash
# Check .env is ignored
git check-ignore .env

# Should output: .env
```

**Подробнее**: См. `docs/SECURITY_SETUP.md`

---

## 🚀 Production Deploy

### Option 1: Fly.io (Recommended)

```bash
# Deploy with interactive setup
./scripts/deploy-autoposting.sh

# Or manual
fly apps create vibee-autoposting
fly secrets set TELEGRAM_BOT_TOKEN="..." -a vibee-autoposting
fly secrets set TELEGRAM_CHAT_ID="@..." -a vibee-autoposting
fly deploy -a vibee-autoposting --config fly.autoposting.toml
```

### Option 2: Docker

```bash
# Build
docker build -f Dockerfile.autoposting -t vibee-autoposting .

# Run
docker run -e TELEGRAM_BOT_TOKEN="..." \
           -e TELEGRAM_CHAT_ID="@..." \
           vibee-autoposting
```

---

## 📊 Мониторинг

### Fly.io

```bash
# Check status
fly status -a vibee-autoposting

# View logs
fly logs -a vibee-autoposting --follow

# Restart
fly apps restart vibee-autoposting
```

### Expected logs

**When posting**:
```
📤 Posting: post_1_release - 🚀 VIBEE v1.0.0 Released!...
  🐦 Posting to Twitter...
  ✈️  Posting to Telegram...
  ✅ Posted successfully to all platforms
```

**When waiting**:
```
⏰ Checking every 60 seconds
🐝 VIBEE Autoposting Scheduler started
```

---

## 🎯 Customization

### Добавить посты

Edit `gleam/src/vibee_autoposting.gleam`:

```gleam
fn get_default_posts(telegram_chat_id: String) -> List(scheduler.Post) {
  [
    // Existing posts...
    
    scheduler.Post(
      id: "post_11_custom",
      text: "Your custom post...",
      scheduled_at: "2026-01-22T09:00:00Z",
      platforms: [scheduler.Twitter, scheduler.Telegram(telegram_chat_id)],
      status: scheduler.Pending,
    ),
  ]
}
```

### Изменить расписание

```gleam
scheduled_at: "2026-01-22T15:30:00Z",  // Jan 22, 3:30 PM UTC
```

### Изменить интервал проверки

```gleam
check_interval_ms: 30_000,  // Check every 30 seconds
```

---

## 💰 Стоимость

### Twitter API
- **Basic tier**: $100/month (для постинга)
- **Free tier**: Read-only

### Telegram API
- **Free**: Unlimited messages

### Fly.io
- **Free tier**: 256MB RAM (достаточно)
- **Paid**: $1.94/month (если нужно больше)

### Total
- **С Twitter**: $100/month
- **Только Telegram**: $0/month

---

## 🐛 Troubleshooting

### "Environment variable not set"

```bash
# Check
echo $TELEGRAM_BOT_TOKEN

# Set
export TELEGRAM_BOT_TOKEN="your_token"

# Or load from .env
source .env
```

### "Bot token is invalid"

1. Check token is correct
2. Revoke and regenerate via @BotFather
3. Update `.env` and Fly.io secrets

### "Chat not found"

1. Check chat_id format (@channel or -1001234567890)
2. Make sure bot is admin in channel
3. Try sending to personal chat first

### "Rate limit exceeded"

- Twitter: Wait 15 minutes
- Telegram: Reduce frequency
- Check API limits

---

## 📚 Документация

### Основные файлы
- `AUTOPOSTING_COMPLETE.md` - Полная документация
- `docs/AUTOPOSTING_SETUP.md` - Детальный setup
- `docs/SECURITY_SETUP.md` - Безопасность
- `docs/AUTOPOSTING_RESEARCH.md` - API research

### Скрипты
- `scripts/test-telegram-safe.sh` - Безопасный тест
- `scripts/deploy-autoposting.sh` - Deploy на Fly.io
- `scripts/test-autoposting.sh` - Полный тест

---

## ✅ Checklist

### Setup
- [ ] Получить Telegram bot token
- [ ] Создать Telegram channel
- [ ] Добавить бота как admin
- [ ] Создать `.env` файл
- [ ] Заполнить credentials
- [ ] Протестировать локально

### Deploy
- [ ] Установить Fly CLI
- [ ] Login to Fly.io
- [ ] Создать app
- [ ] Установить secrets
- [ ] Deploy
- [ ] Проверить логи

### Monitoring
- [ ] Проверять логи ежедневно
- [ ] Отслеживать ошибки
- [ ] Верифицировать посты
- [ ] Обновлять расписание

---

## 🎊 Готово!

Автопостинг настроен и готов к использованию!

**Следующие шаги**:
1. Получить credentials
2. Настроить `.env`
3. Протестировать
4. Задеплоить
5. Мониторить

**Первый пост**: 2026-01-12 09:00 UTC

**Вопросы?** См. документацию или создай issue на GitHub.

---

**Created BY AI, FOR AI developers** 🤖🐝  
**Let's automate!** 🚀

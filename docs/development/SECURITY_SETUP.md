# VIBEE Autoposting - Security Setup

**Дата**: 2026-01-11  
**Приоритет**: 🔴 КРИТИЧЕСКИЙ  
**Цель**: Безопасное хранение credentials

---

## ⚠️ ВАЖНО: Безопасность токенов

**НИКОГДА не коммить в git**:
- ❌ API keys
- ❌ Bot tokens
- ❌ Access tokens
- ❌ Secrets
- ❌ Passwords

**Где хранить**:
- ✅ Environment variables
- ✅ `.env` файл (в `.gitignore`)
- ✅ Fly.io secrets
- ✅ Password manager (1Password, LastPass)

---

## 1. Локальная разработка

### Шаг 1: Создать .env файл

```bash
# Copy example
cp .env.example .env

# Edit with your credentials
nano .env
```

### Шаг 2: Заполнить credentials

```bash
# .env
TWITTER_API_KEY=your_actual_key_here
TWITTER_API_SECRET=your_actual_secret_here
TWITTER_ACCESS_TOKEN=your_actual_token_here
TWITTER_ACCESS_TOKEN_SECRET=your_actual_token_secret_here

TELEGRAM_BOT_TOKEN=your_actual_bot_token_here
TELEGRAM_CHAT_ID=@your_channel_here
```

### Шаг 3: Загрузить в environment

```bash
# Load variables
source .env

# Verify (masked)
echo "Twitter API Key: ${TWITTER_API_KEY:0:10}...${TWITTER_API_KEY: -4}"
echo "Telegram Token: ${TELEGRAM_BOT_TOKEN:0:10}...${TELEGRAM_BOT_TOKEN: -4}"
```

### Шаг 4: Проверить .gitignore

```bash
# Check .env is ignored
git check-ignore .env

# Should output: .env
```

---

## 2. Production (Fly.io)

### Шаг 1: Установить secrets

```bash
# Set secrets (one by one)
fly secrets set TWITTER_API_KEY="your_key" -a vibee-autoposting
fly secrets set TWITTER_API_SECRET="your_secret" -a vibee-autoposting
fly secrets set TWITTER_ACCESS_TOKEN="your_token" -a vibee-autoposting
fly secrets set TWITTER_ACCESS_TOKEN_SECRET="your_token_secret" -a vibee-autoposting
fly secrets set TELEGRAM_BOT_TOKEN="your_bot_token" -a vibee-autoposting
fly secrets set TELEGRAM_CHAT_ID="@your_channel" -a vibee-autoposting
```

### Шаг 2: Проверить secrets

```bash
# List secrets (values are hidden)
fly secrets list -a vibee-autoposting
```

**Output**:
```
NAME                            DIGEST          CREATED AT
TELEGRAM_BOT_TOKEN              abc123...       2024-01-11
TELEGRAM_CHAT_ID                def456...       2024-01-11
TWITTER_ACCESS_TOKEN            ghi789...       2024-01-11
TWITTER_ACCESS_TOKEN_SECRET     jkl012...       2024-01-11
TWITTER_API_KEY                 mno345...       2024-01-11
TWITTER_API_SECRET              pqr678...       2024-01-11
```

### Шаг 3: Удалить secret (если нужно)

```bash
# Remove secret
fly secrets unset TELEGRAM_BOT_TOKEN -a vibee-autoposting

# Set new value
fly secrets set TELEGRAM_BOT_TOKEN="new_token" -a vibee-autoposting
```

---

## 3. Получение credentials

### Twitter API

**Шаг 1: Создать Developer Account**
1. Go to [developer.twitter.com](https://developer.twitter.com)
2. Sign up
3. Apply for Elevated access
4. Wait for approval (1-2 days)

**Шаг 2: Создать App**
1. Developer Portal → Projects & Apps
2. Create App
3. Name: "VIBEE Autoposting"
4. Description: "Automated posting for VIBEE language"

**Шаг 3: Получить Keys**
1. App Settings → Keys and tokens
2. Generate:
   - API Key and Secret
   - Access Token and Secret
3. **Save immediately** (показываются только один раз!)

**Шаг 4: Сохранить в password manager**
```
Service: Twitter API - VIBEE Autoposting
API Key: abc123...
API Secret: def456...
Access Token: ghi789...
Access Token Secret: jkl012...
```

### Telegram Bot

**Шаг 1: Создать бота**
1. Open Telegram
2. Search @BotFather
3. Send `/newbot`
4. Follow instructions
5. **Save token immediately**

**Шаг 2: Настроить бота**
1. Send `/mybots`
2. Select your bot
3. Edit Bot → Description
4. Edit Bot → About
5. Edit Bot → Profile Photo

**Шаг 3: Создать канал**
1. Create new channel
2. Name: "VIBEE Updates"
3. Username: @vibee_dev (or similar)
4. Add bot as admin
5. Give posting permissions

**Шаг 4: Получить chat_id**

**Option A: Channel username**
```bash
TELEGRAM_CHAT_ID=@vibee_dev
```

**Option B: Numeric ID**
1. Send message to channel
2. Forward to @userinfobot
3. Get chat_id: `-1001234567890`

```bash
TELEGRAM_CHAT_ID=-1001234567890
```

---

## 4. Ротация токенов

### Когда менять токены

**Немедленно**:
- ❌ Токен случайно закоммичен в git
- ❌ Токен показан в логах
- ❌ Токен отправлен в чат/email
- ❌ Подозрение на компрометацию

**Регулярно**:
- 🔄 Каждые 90 дней (best practice)
- 🔄 При смене команды
- 🔄 После увольнения сотрудника

### Как поменять токены

**Twitter**:
1. Developer Portal → App → Keys and tokens
2. Regenerate → API Key and Secret
3. Regenerate → Access Token and Secret
4. Update `.env` and Fly.io secrets

**Telegram**:
1. @BotFather → `/mybots`
2. Select bot → API Token
3. Revoke current token
4. Get new token
5. Update `.env` and Fly.io secrets

---

## 5. Проверка безопасности

### Checklist

**Локально**:
- [ ] `.env` в `.gitignore`
- [ ] `.env` не закоммичен
- [ ] Токены не в скриптах
- [ ] Токены не в конфигах
- [ ] Токены в password manager

**Git**:
- [ ] `git log` не содержит токенов
- [ ] `git diff` не показывает токены
- [ ] `.gitignore` актуален

**Fly.io**:
- [ ] Secrets установлены
- [ ] Secrets не в логах
- [ ] Secrets не в переменных окружения (видимых)

**Команда**:
- [ ] Все знают правила безопасности
- [ ] Токены не шарятся в чатах
- [ ] Используется password manager

### Команды для проверки

```bash
# Check .env is ignored
git check-ignore .env

# Check no secrets in git history
git log --all --full-history --source --pretty=format:"%h %s" -- .env

# Check no secrets in current changes
git diff | grep -i "token\|key\|secret" || echo "No secrets found"

# Check Fly.io secrets
fly secrets list -a vibee-autoposting
```

---

## 6. Что делать если токен утек

### Немедленные действия

**1. Отозвать токен** (в течение 5 минут):

**Twitter**:
```bash
# Go to Developer Portal
# App → Keys and tokens → Regenerate
```

**Telegram**:
```bash
# @BotFather → /mybots → API Token → Revoke
```

**2. Удалить из git** (если закоммичен):

```bash
# Remove from current commit
git reset HEAD~1
git add .
git commit -m "Remove sensitive data"

# Remove from history (DANGEROUS!)
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch .env" \
  --prune-empty --tag-name-filter cat -- --all

# Force push (if already pushed)
git push origin --force --all
```

**3. Обновить везде**:

```bash
# Update .env
nano .env

# Update Fly.io
fly secrets set TELEGRAM_BOT_TOKEN="new_token" -a vibee-autoposting

# Redeploy
fly deploy -a vibee-autoposting
```

**4. Уведомить команду**:
- Сообщить о инциденте
- Объяснить что произошло
- Подтвердить что токен отозван

**5. Проверить логи**:
- Проверить нет ли подозрительной активности
- Проверить Twitter/Telegram на несанкционированные посты

---

## 7. Best Practices

### DO ✅

- ✅ Используй `.env` для локальной разработки
- ✅ Используй Fly.io secrets для production
- ✅ Используй password manager для хранения
- ✅ Маскируй токены в логах: `${TOKEN:0:10}...${TOKEN: -4}`
- ✅ Проверяй `.gitignore` перед коммитом
- ✅ Ротируй токены каждые 90 дней
- ✅ Используй разные токены для dev/prod

### DON'T ❌

- ❌ Не коммить `.env` в git
- ❌ Не хардкодить токены в коде
- ❌ Не отправлять токены в чаты/email
- ❌ Не логировать токены
- ❌ Не шарить токены с командой напрямую
- ❌ Не использовать один токен для всего
- ❌ Не игнорировать security warnings

---

## 8. Тестирование

### Безопасный тест

```bash
# Set environment variables
export TELEGRAM_BOT_TOKEN="your_token"
export TELEGRAM_CHAT_ID="@your_channel"

# Run safe test (reads from env only)
./scripts/test-telegram-safe.sh
```

**Output**:
```
🐝 Testing Telegram Bot (Safe)
==============================

✅ Token found: 1234567890...ABCD

📋 Test 1: Getting bot info...
✅ Bot is active!
   Username: @your_bot
   Name: Your Bot Name

📋 Test 2: Checking webhook...
✅ No webhook active

📋 Test 3: Sending test message...
   Chat: @your_channel
✅ Message sent successfully!
   Message ID: 123

Check your Telegram to see the message!

🎉 Test complete!
```

---

## 9. Мониторинг

### Что отслеживать

**Telegram Bot**:
- Количество отправленных сообщений
- Ошибки API
- Rate limits
- Подозрительная активность

**Twitter API**:
- Количество твитов
- Rate limit usage
- API errors
- Billing (Basic tier $100/month)

### Алерты

**Setup alerts**:
- Email при ошибках API
- Slack при rate limit
- SMS при подозрительной активности

---

## 10. Compliance

### GDPR / Privacy

- Не храни личные данные пользователей
- Не логируй чувствительную информацию
- Удаляй старые логи (>30 дней)

### Terms of Service

**Twitter**:
- Не спамь
- Не автоматизируй лайки/ретвиты
- Соблюдай rate limits
- Не нарушай правила сообщества

**Telegram**:
- Не спамь
- Не отправляй unsolicited messages
- Соблюдай rate limits
- Не нарушай ToS

---

## Заключение

**Безопасность - это не опция, это требование.**

Следуй этим правилам и твои токены будут в безопасности.

**Если сомневаешься - спроси!**

---

**Created BY AI, FOR AI developers** 🤖🐝  
**Security first!** 🔒

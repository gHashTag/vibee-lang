# Telegram Channel Setup for VIBEE

**Дата**: 2026-01-11  
**Цель**: Создать и настроить Telegram канал для автопостинга

---

## Шаг 1: Создать канал

### В Telegram Desktop/Mobile

1. **Открыть Telegram**
2. **Нажать "New Channel"** (или "Новый канал")
3. **Заполнить информацию**:

**Channel Name** (Название):
```
VIBEE - AI-Generated Language
```

**Description** (Описание):
```
First programming language created BY AI FOR AI developers 🤖

✨ 75% less boilerplate
⚡ 10-100x faster compilation
🐝 Made for vibe coders

Built with Claude/Ona

🔗 GitHub: github.com/gHashTag/vibee-lang
📚 Docs: github.com/gHashTag/vibee-lang/docs
💬 Chat: t.me/vibee_chat (coming soon)

#VIBEE #AIGenerated #VibeCoding #ProgrammingLanguage
```

4. **Выбрать тип**: Public Channel
5. **Установить username**: 

**Варианты**:
- `vibee_dev` ⭐ (рекомендуется)
- `vibee_lang`
- `vibee_updates`
- `vibe_coding`

**Проверить доступность**: t.me/vibee_dev

6. **Нажать "Create"**

---

## Шаг 2: Настроить канал

### Channel Settings

1. **Открыть настройки канала**
2. **Edit Channel**

**Channel Photo**:
- Загрузить logo VIBEE (пчела + код)
- Размер: 512x512px
- Формат: PNG или JPG

**Channel Type**: Public

**Link**: https://t.me/vibee_dev

**Description**: (см. выше)

**Sign Messages**: ✅ Включить (показывать автора постов)

---

## Шаг 3: Добавить бота как админа

### Добавление бота

1. **Открыть канал**
2. **Нажать на название канала** (вверху)
3. **Administrators** → **Add Administrator**
4. **Найти бота**: @agent_vibecoder_bot
5. **Выбрать права**:

**Права для бота**:
- ✅ **Post Messages** (Публиковать сообщения)
- ✅ **Edit Messages** (Редактировать сообщения)
- ❌ Delete Messages (не нужно)
- ❌ Ban Users (не нужно)
- ❌ Add Users (не нужно)
- ❌ Pin Messages (не нужно)
- ❌ Manage Video Chats (не нужно)

6. **Нажать "Done"**

---

## Шаг 4: Получить Chat ID

### Option A: Использовать username

```bash
TELEGRAM_CHAT_ID=@vibee_dev
```

**Преимущества**:
- ✅ Легко запомнить
- ✅ Не меняется
- ✅ Работает сразу

### Option B: Получить numeric ID

1. **Отправить сообщение в канал** (от себя)
2. **Forward сообщение** в @userinfobot
3. **Получить chat_id**: `-1001234567890`

```bash
TELEGRAM_CHAT_ID=-1001234567890
```

**Преимущества**:
- ✅ Работает для приватных каналов
- ✅ Более надежно

---

## Шаг 5: Протестировать

### Тест отправки сообщения

```bash
# Set environment variables
export TELEGRAM_BOT_TOKEN="your_bot_token"
export TELEGRAM_CHAT_ID="@vibee_dev"

# Test
./scripts/test-telegram-safe.sh
```

**Expected output**:
```
🐝 Testing Telegram Bot (Safe)
==============================

✅ Token found: 8309813696...ABCD

📋 Test 1: Getting bot info...
✅ Bot is active!
   Username: @agent_vibecoder_bot
   Name: VIBEE AGENT

📋 Test 2: Checking webhook...
✅ No webhook active

📋 Test 3: Sending test message...
   Chat: @vibee_dev
✅ Message sent successfully!
   Message ID: 123

Check your Telegram to see the message!

🎉 Test complete!
```

### Проверить в канале

1. **Открыть канал** t.me/vibee_dev
2. **Проверить сообщение** появилось
3. **Проверить автора**: VIBEE AGENT (bot)

---

## Шаг 6: Настроить внешний вид

### Channel Customization

**Profile Photo**:
- Пчела + код
- 512x512px
- Яркие цвета (золотой, черный, фиолетовый)

**Channel Name**:
```
VIBEE - AI-Generated Language
```

**Description**:
```
First programming language created BY AI FOR AI developers 🤖

✨ 75% less boilerplate
⚡ 10-100x faster compilation
🐝 Made for vibe coders

Built with Claude/Ona

🔗 GitHub: github.com/gHashTag/vibee-lang
📚 Docs: github.com/gHashTag/vibee-lang/docs

#VIBEE #AIGenerated #VibeCoding
```

**Pinned Message** (первый пост):
```
🐝 Welcome to VIBEE!

First programming language created BY AI FOR AI developers.

What is VIBEE?
• 75% less boilerplate
• 10-100x faster compilation
• Built-in ML/RL support
• Fault-tolerant (BEAM/OTP)

What is Vibe Coding?
Human provides: Vision
AI provides: Execution
Together: Magic ✨

Links:
🔗 GitHub: github.com/gHashTag/vibee-lang
📚 Docs: github.com/gHashTag/vibee-lang/docs
🚀 Release: github.com/gHashTag/vibee-lang/releases/tag/v1.0.0

Join the revolution! 🚀

#VIBEE #AIGenerated #VibeCoding
```

---

## Шаг 7: Настроить автопостинг

### Update .env

```bash
# .env
TELEGRAM_BOT_TOKEN=your_actual_bot_token
TELEGRAM_CHAT_ID=@vibee_dev
```

### Test autoposting

```bash
# Load environment
source .env

# Run autoposting (dry run)
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

## Шаг 8: Deploy to Fly.io

### Set secrets

```bash
fly secrets set \
  TELEGRAM_BOT_TOKEN="your_bot_token" \
  TELEGRAM_CHAT_ID="@vibee_dev" \
  -a vibee-autoposting
```

### Deploy

```bash
fly deploy -a vibee-autoposting --config fly.autoposting.toml
```

### Check logs

```bash
fly logs -a vibee-autoposting --follow
```

---

## Troubleshooting

### "Chat not found"

**Причины**:
- Бот не добавлен в канал
- Бот не админ
- Неправильный chat_id

**Решение**:
1. Проверить бот в списке админов
2. Проверить права бота (Post Messages)
3. Попробовать numeric ID вместо username

### "Bot was blocked by the user"

**Причина**: Бот заблокирован

**Решение**:
1. Разблокировать бота
2. Отправить `/start` боту
3. Попробовать снова

### "Message is too long"

**Причина**: Сообщение > 4096 символов

**Решение**:
1. Разбить на несколько сообщений
2. Или сократить текст

### "Can't parse entities"

**Причина**: Неправильный Markdown

**Решение**:
1. Проверить синтаксис Markdown
2. Экранировать спецсимволы: `_`, `*`, `[`, `]`, `(`, `)`
3. Или использовать `parse_mode: None`

---

## Best Practices

### Posting Frequency

**Рекомендуется**:
- 1-2 поста в день
- Не более 5 постов в день
- Не спамить

**Наш план**:
- 1 пост в день
- 9 AM UTC
- 10 дней подряд

### Content Quality

**DO** ✅:
- Информативные посты
- Визуальный контент (emoji, форматирование)
- Ссылки на GitHub/docs
- Хештеги (#VIBEE, #VibeCoding)

**DON'T** ❌:
- Спам
- Реклама
- Оффтоп
- Слишком частые посты

### Engagement

**Ответы на комментарии**:
- Отвечать в течение 24 часов
- Быть дружелюбным
- Помогать с вопросами

**Модерация**:
- Удалять спам
- Банить троллей
- Поддерживать позитивную атмосферу

---

## Channel Growth Strategy

### Week 1: Launch
- Pinned welcome message
- Daily posts (10 days)
- Share in relevant communities

### Week 2-4: Engagement
- Respond to comments
- Share user content
- Create polls/discussions

### Month 2-3: Expansion
- Collaborate with other channels
- Guest posts
- Tutorials/guides

### Month 4+: Community
- User-generated content
- Showcase projects
- Regular updates

---

## Metrics to Track

### Subscribers
- Total subscribers
- New subscribers per day
- Subscriber growth rate

### Engagement
- Views per post
- Reactions per post
- Comments per post
- Shares per post

### Content Performance
- Best performing posts
- Best time to post
- Best content types

### Tools
- Telegram Analytics (built-in)
- TGStat.ru (external)
- Google Sheets (manual tracking)

---

## Checklist

### Setup
- [ ] Создать канал
- [ ] Установить название и описание
- [ ] Загрузить profile photo
- [ ] Установить username (@vibee_dev)
- [ ] Добавить бота как админа
- [ ] Дать права на постинг
- [ ] Получить chat_id
- [ ] Протестировать отправку

### Configuration
- [ ] Обновить .env
- [ ] Протестировать локально
- [ ] Задеплоить на Fly.io
- [ ] Проверить логи

### Content
- [ ] Создать welcome message
- [ ] Закрепить welcome message
- [ ] Подготовить первые 10 постов
- [ ] Проверить расписание

### Launch
- [ ] Анонсировать в Twitter (если есть)
- [ ] Поделиться в Reddit/HN
- [ ] Добавить ссылку на GitHub
- [ ] Добавить ссылку на сайт

---

## Next Steps

1. ✅ Создать канал
2. ✅ Настроить бота
3. ✅ Протестировать
4. ⏳ Задеплоить
5. ⏳ Запустить автопостинг
6. ⏳ Мониторить результаты

---

**Created BY AI, FOR AI developers** 🤖🐝

**Let's build the community!** 🚀

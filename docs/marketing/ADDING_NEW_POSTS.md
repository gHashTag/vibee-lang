# Adding New Posts to VIBEE Autoposting

**Дата**: 2026-01-11  
**Цель**: Научиться добавлять новые посты в автопостинг

---

## Quick Start

### 1. Открыть файл с постами

```bash
nano gleam/src/vibee_autoposting.gleam
```

### 2. Найти функцию `get_default_posts`

```gleam
fn get_default_posts(telegram_chat_id: String) -> List(scheduler.Post) {
  [
    // Existing posts...
  ]
}
```

### 3. Добавить новый пост

```gleam
scheduler.Post(
  id: "post_11_custom",
  text: "Your post text here...",
  scheduled_at: "2026-01-22T09:00:00Z",
  platforms: [scheduler.Twitter, scheduler.Telegram(telegram_chat_id)],
  status: scheduler.Pending,
),
```

### 4. Пересобрать и задеплоить

```bash
cd gleam && gleam build
fly deploy -a vibee-autoposting
```

---

## Post Structure

### Обязательные поля

```gleam
scheduler.Post(
  id: "unique_post_id",              // Уникальный ID
  text: "Post content...",            // Текст поста
  scheduled_at: "2026-01-22T09:00:00Z",  // Время публикации (ISO 8601 UTC)
  platforms: [scheduler.Twitter, scheduler.Telegram(chat_id)],  // Платформы
  status: scheduler.Pending,          // Статус (всегда Pending для новых)
)
```

### Поля в деталях

**id** (String):
- Уникальный идентификатор поста
- Формат: `post_N_description`
- Примеры: `post_11_announcement`, `post_12_tutorial`

**text** (String):
- Текст поста
- Максимум: 4096 символов (Telegram), 280 символов (Twitter)
- Поддерживает Markdown (Telegram)
- Поддерживает emoji

**scheduled_at** (String):
- Время публикации в формате ISO 8601 UTC
- Формат: `YYYY-MM-DDTHH:MM:SSZ`
- Примеры:
  - `2026-01-22T09:00:00Z` - 22 января 2026, 9:00 AM UTC
  - `2026-01-22T15:30:00Z` - 22 января 2026, 3:30 PM UTC

**platforms** (List):
- Список платформ для публикации
- Варианты:
  - `[scheduler.Twitter]` - только Twitter
  - `[scheduler.Telegram(chat_id)]` - только Telegram
  - `[scheduler.Twitter, scheduler.Telegram(chat_id)]` - обе платформы

**status** (PostStatus):
- Статус поста
- Всегда `scheduler.Pending` для новых постов
- Автоматически меняется на `Posted` или `Failed` после публикации

---

## Formatting Guide

### Telegram Markdown

**Bold**:
```
**bold text**
```

**Italic**:
```
_italic text_
```

**Code**:
```
`inline code`
```

**Links**:
```
[Link text](https://example.com)
```

**Lists**:
```
• Item 1
• Item 2
• Item 3
```

### Twitter

**Hashtags**:
```
#VIBEE #VibeCoding
```

**Mentions**:
```
@vibee_dev
```

**Links**:
```
https://github.com/gHashTag/vibee-lang
```

---

## Examples

### Example 1: Simple Announcement

```gleam
scheduler.Post(
  id: "post_11_announcement",
  text: "🎉 **New Feature Released!**\n\nVIBEE now supports async/await!\n\nCheck it out: https://github.com/gHashTag/vibee-lang\n\n_#VIBEE #NewFeature_",
  scheduled_at: "2026-01-22T09:00:00Z",
  platforms: [scheduler.Twitter, scheduler.Telegram(telegram_chat_id)],
  status: scheduler.Pending,
),
```

### Example 2: Tutorial

```gleam
scheduler.Post(
  id: "post_12_tutorial",
  text: "📚 **VIBEE Tutorial: Getting Started**\n\n1. Install Gleam\n2. Clone repo\n3. Run `gleam build`\n4. Start coding!\n\nFull guide: https://github.com/gHashTag/vibee-lang/docs\n\n_#VIBEE #Tutorial_",
  scheduled_at: "2026-01-23T09:00:00Z",
  platforms: [scheduler.Twitter, scheduler.Telegram(telegram_chat_id)],
  status: scheduler.Pending,
),
```

### Example 3: Community Highlight

```gleam
scheduler.Post(
  id: "post_13_community",
  text: "🌟 **Community Highlight**\n\n@user built an amazing AI agent with VIBEE!\n\nCheck it out: https://github.com/user/project\n\nShare your projects with us!\n\n_#VIBEE #Community_",
  scheduled_at: "2026-01-24T09:00:00Z",
  platforms: [scheduler.Twitter, scheduler.Telegram(telegram_chat_id)],
  status: scheduler.Pending,
),
```

### Example 4: Telegram Only

```gleam
scheduler.Post(
  id: "post_14_telegram_only",
  text: "📢 **Telegram Exclusive**\n\nJoin our chat to discuss VIBEE!\n\nLink: https://t.me/vibee_chat\n\n_#VIBEE_",
  scheduled_at: "2026-01-25T09:00:00Z",
  platforms: [scheduler.Telegram(telegram_chat_id)],  // Only Telegram
  status: scheduler.Pending,
),
```

---

## Time Zones

### UTC to Local Time

**UTC** (Coordinated Universal Time):
- Используется в коде
- Формат: `2026-01-22T09:00:00Z`

**Конвертация**:
- UTC → Moscow: +3 часа
- UTC → New York: -5 часов (EST) / -4 часа (EDT)
- UTC → Los Angeles: -8 часов (PST) / -7 часов (PDT)

**Примеры**:
- `09:00 UTC` = `12:00 Moscow` = `04:00 New York` = `01:00 Los Angeles`
- `15:00 UTC` = `18:00 Moscow` = `10:00 New York` = `07:00 Los Angeles`

**Tools**:
- [timeanddate.com](https://www.timeanddate.com/worldclock/converter.html)
- [worldtimebuddy.com](https://www.worldtimebuddy.com/)

---

## Best Practices

### Content

**DO** ✅:
- Информативные посты
- Визуальный контент (emoji, форматирование)
- Ссылки на GitHub/docs
- Хештеги в конце (Telegram: в _italic_)
- Короткие параграфы

**DON'T** ❌:
- Спам
- Слишком длинные посты (>1000 символов)
- Слишком много хештегов (>5)
- Caps lock
- Агрессивный тон

### Scheduling

**Рекомендуемое время** (UTC):
- `09:00` - Утро в Европе
- `15:00` - Утро в США
- `21:00` - Вечер в Европе, день в США

**Частота**:
- 1-2 поста в день (оптимально)
- Не более 5 постов в день
- Минимум 4 часа между постами

### Testing

**Перед добавлением**:
1. Проверить текст на опечатки
2. Проверить ссылки работают
3. Проверить Markdown форматирование
4. Проверить длину (Telegram: 4096, Twitter: 280)

**После добавления**:
1. Пересобрать: `gleam build`
2. Протестировать локально
3. Задеплоить
4. Проверить логи

---

## Workflow

### 1. Написать пост

```bash
# Create draft
cat > /tmp/new_post.txt << 'EOF'
🎉 **New Feature!**

VIBEE now supports X!

Check it out: https://...

_#VIBEE #NewFeature_
EOF
```

### 2. Проверить длину

```bash
# Check length
wc -c /tmp/new_post.txt

# Should be < 4096 for Telegram, < 280 for Twitter
```

### 3. Добавить в код

```bash
# Edit file
nano gleam/src/vibee_autoposting.gleam

# Add post to get_default_posts()
```

### 4. Пересобрать

```bash
cd gleam && gleam build
```

### 5. Протестировать

```bash
# Test locally (dry run)
source .env
gleam run -m vibee_autoposting
```

### 6. Задеплоить

```bash
# Deploy to Fly.io
fly deploy -a vibee-autoposting
```

### 7. Проверить логи

```bash
# Check logs
fly logs -a vibee-autoposting --follow
```

---

## Troubleshooting

### "Message is too long"

**Причина**: Сообщение > 4096 символов (Telegram) или > 280 (Twitter)

**Решение**:
1. Сократить текст
2. Разбить на несколько постов
3. Или отправить только в Telegram (если > 280)

### "Can't parse entities"

**Причина**: Неправильный Markdown

**Решение**:
1. Проверить синтаксис: `**bold**`, `_italic_`, `[link](url)`
2. Экранировать спецсимволы: `\_`, `\*`, `\[`, `\]`
3. Протестировать в @BotFather

### "Post not posting"

**Причина**: Неправильное время или статус

**Решение**:
1. Проверить `scheduled_at` в будущем
2. Проверить формат ISO 8601: `YYYY-MM-DDTHH:MM:SSZ`
3. Проверить `status: scheduler.Pending`
4. Проверить логи: `fly logs -a vibee-autoposting`

---

## Advanced

### Dynamic Content

**Использовать переменные**:
```gleam
let version = "1.0.0"
let release_url = "https://github.com/gHashTag/vibee-lang/releases/tag/v" <> version

scheduler.Post(
  id: "post_release",
  text: "🚀 VIBEE v" <> version <> " Released!\n\n" <> release_url,
  // ...
)
```

### Conditional Platforms

**Отправлять только в Telegram если длинный текст**:
```gleam
let text = "Very long text..."
let platforms = case string.length(text) > 280 {
  True -> [scheduler.Telegram(telegram_chat_id)]
  False -> [scheduler.Twitter, scheduler.Telegram(telegram_chat_id)]
}

scheduler.Post(
  id: "post_conditional",
  text: text,
  platforms: platforms,
  // ...
)
```

### Recurring Posts

**Еженедельный пост**:
```gleam
// Week 1
scheduler.Post(id: "weekly_1", scheduled_at: "2026-01-22T09:00:00Z", ...),
// Week 2
scheduler.Post(id: "weekly_2", scheduled_at: "2026-01-29T09:00:00Z", ...),
// Week 3
scheduler.Post(id: "weekly_3", scheduled_at: "2026-02-05T09:00:00Z", ...),
```

---

## Checklist

### Before Adding
- [ ] Написать текст поста
- [ ] Проверить длину (<4096 Telegram, <280 Twitter)
- [ ] Проверить Markdown форматирование
- [ ] Проверить ссылки работают
- [ ] Выбрать время публикации (UTC)
- [ ] Выбрать платформы

### Adding
- [ ] Открыть `gleam/src/vibee_autoposting.gleam`
- [ ] Добавить пост в `get_default_posts()`
- [ ] Установить уникальный `id`
- [ ] Установить `scheduled_at` (ISO 8601 UTC)
- [ ] Установить `platforms`
- [ ] Установить `status: scheduler.Pending`

### After Adding
- [ ] Пересобрать: `gleam build`
- [ ] Протестировать локально
- [ ] Задеплоить: `fly deploy`
- [ ] Проверить логи: `fly logs`
- [ ] Дождаться публикации
- [ ] Проверить в Telegram/Twitter

---

**Status**: ✅ Ready to use  
**Next**: Добавить свой первый пост!

**Created BY AI, FOR AI developers** 🤖🐝

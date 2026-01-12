# Автопостинг в Twitter и Telegram - Research

**Дата**: 2026-01-11  
**Цель**: Настроить автоматический постинг по расписанию

---

## Twitter API v2

### Требования

**API Access**:
- Twitter Developer Account (бесплатно)
- App создан в Developer Portal
- API Keys: API Key, API Secret, Access Token, Access Token Secret
- OAuth 2.0 для user context

**Тарифы** (2024):
- **Free**: 1,500 tweets/month, read-only
- **Basic** ($100/month): 3,000 tweets/month, write access
- **Pro** ($5,000/month): 300,000 tweets/month

**Для автопостинга нужен**: Basic tier ($100/month)

### Endpoints

**POST /2/tweets** - Создать tweet
```http
POST https://api.twitter.com/2/tweets
Authorization: Bearer <ACCESS_TOKEN>
Content-Type: application/json

{
  "text": "Hello world!"
}
```

**Response**:
```json
{
  "data": {
    "id": "1234567890",
    "text": "Hello world!"
  }
}
```

### Rate Limits

- **User context**: 200 tweets per 15 minutes
- **App context**: 300 tweets per 15 minutes

### Authentication

**OAuth 2.0 User Context**:
1. Получить Authorization Code
2. Обменять на Access Token
3. Использовать Access Token для API calls

**OAuth 1.0a** (проще для автопостинга):
1. API Key + API Secret
2. Access Token + Access Token Secret
3. Подписать запрос HMAC-SHA1

---

## Telegram Bot API

### Требования

**Bot Creation**:
- Создать бота через @BotFather
- Получить Bot Token
- Добавить бота в канал/группу
- Дать права на постинг

**Тарифы**: Бесплатно!

### Endpoints

**sendMessage** - Отправить сообщение
```http
POST https://api.telegram.org/bot<TOKEN>/sendMessage
Content-Type: application/json

{
  "chat_id": "@vibee_dev",
  "text": "Hello world!",
  "parse_mode": "Markdown"
}
```

**Response**:
```json
{
  "ok": true,
  "result": {
    "message_id": 123,
    "chat": {
      "id": -1001234567890,
      "title": "VIBEE Channel",
      "type": "channel"
    },
    "text": "Hello world!"
  }
}
```

### Rate Limits

- **Messages**: 30 messages per second per bot
- **Same chat**: 1 message per second

### Features

**Markdown/HTML**:
```markdown
*bold* _italic_ `code` [link](url)
```

**Buttons**:
```json
{
  "reply_markup": {
    "inline_keyboard": [[
      {"text": "GitHub", "url": "https://github.com/..."}
    ]]
  }
}
```

---

## Gleam Integration

### Existing Code

**У нас уже есть**:
- `honeycomb/telegram/bot.gleam` - Telegram Bot API
- `honeycomb/telegram/types.gleam` - Telegram types
- `honeycomb/mcp/telegram_*.gleam` - MCP tools для Telegram

**Нужно добавить**:
- Twitter API client
- Scheduler для автопостинга
- Configuration для постов

### Dependencies

**HTTP Client**:
```toml
# gleam.toml
[dependencies]
gleam_http = "~> 3.6"
gleam_httpc = "~> 2.1"
gleam_json = "~> 1.0"
```

**Scheduling**:
```toml
# Erlang :timer module (built-in)
# Или использовать OTP gen_server
```

**OAuth**:
```toml
# Нужно реализовать OAuth 1.0a signing
# Или использовать Erlang :crypto module
```

---

## Architecture

### Option 1: Simple Scheduler (Recommended)

```gleam
// honeycomb/autoposting/scheduler.gleam

import gleam/erlang/process
import gleam/list
import gleam/result

pub type Post {
  Post(
    text: String,
    scheduled_at: String,  // ISO 8601
    platforms: List(Platform),
    status: PostStatus,
  )
}

pub type Platform {
  Twitter
  Telegram
}

pub type PostStatus {
  Pending
  Posted
  Failed(String)
}

pub fn start_scheduler() {
  process.start(fn() {
    schedule_loop()
  }, True)
}

fn schedule_loop() {
  // Check every minute
  process.sleep(60_000)
  
  // Get pending posts
  let posts = get_pending_posts()
  
  // Post if time matches
  list.each(posts, fn(post) {
    case should_post(post) {
      True -> post_to_platforms(post)
      False -> Nil
    }
  })
  
  schedule_loop()
}
```

### Option 2: Cron-like Scheduler

```gleam
// honeycomb/autoposting/cron.gleam

pub type Schedule {
  Daily(hour: Int, minute: Int)
  Weekly(day: Int, hour: Int, minute: Int)
  Custom(cron: String)
}

pub fn schedule(schedule: Schedule, action: fn() -> Result(Nil, String)) {
  // Parse cron expression
  // Schedule with OTP timer
  // Execute action at specified time
}
```

### Option 3: Queue-based (Most Robust)

```gleam
// honeycomb/autoposting/queue.gleam

pub type PostQueue {
  PostQueue(
    posts: List(Post),
    processing: Bool,
  )
}

pub fn enqueue(post: Post) {
  // Add to queue
  // Persist to database
}

pub fn process_queue() {
  // Get next post
  // Check if time to post
  // Post to platforms
  // Mark as posted
  // Repeat
}
```

---

## Implementation Plan

### Phase 1: Twitter API Client

**File**: `honeycomb/social/twitter.gleam`

```gleam
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/json
import gleam/result

pub type TwitterClient {
  TwitterClient(
    api_key: String,
    api_secret: String,
    access_token: String,
    access_token_secret: String,
  )
}

pub fn new(
  api_key: String,
  api_secret: String,
  access_token: String,
  access_token_secret: String,
) -> TwitterClient {
  TwitterClient(api_key, api_secret, access_token, access_token_secret)
}

pub fn post_tweet(
  client: TwitterClient,
  text: String,
) -> Result(String, String) {
  // 1. Build request
  let url = "https://api.twitter.com/2/tweets"
  let body = json.object([
    #("text", json.string(text))
  ])
  
  // 2. Sign request (OAuth 1.0a)
  let signature = sign_request(client, "POST", url, body)
  
  // 3. Send request
  let req = request.new()
    |> request.set_method(http.Post)
    |> request.set_host("api.twitter.com")
    |> request.set_path("/2/tweets")
    |> request.set_header("Authorization", signature)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(json.to_string(body))
  
  // 4. Execute
  case httpc.send(req) {
    Ok(resp) -> {
      case resp.status {
        201 -> Ok("Tweet posted")
        _ -> Error("Failed to post tweet")
      }
    }
    Error(e) -> Error("HTTP error")
  }
}

fn sign_request(
  client: TwitterClient,
  method: String,
  url: String,
  body: json.Json,
) -> String {
  // OAuth 1.0a signature
  // TODO: Implement HMAC-SHA1 signing
  "OAuth ..."
}
```

### Phase 2: Telegram API Client

**File**: `honeycomb/social/telegram.gleam`

```gleam
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/result

pub type TelegramClient {
  TelegramClient(bot_token: String)
}

pub fn new(bot_token: String) -> TelegramClient {
  TelegramClient(bot_token)
}

pub fn send_message(
  client: TelegramClient,
  chat_id: String,
  text: String,
) -> Result(String, String) {
  let url = "https://api.telegram.org/bot" <> client.bot_token <> "/sendMessage"
  
  let body = json.object([
    #("chat_id", json.string(chat_id)),
    #("text", json.string(text)),
    #("parse_mode", json.string("Markdown")),
  ])
  
  let req = request.new()
    |> request.set_method(http.Post)
    |> request.set_host("api.telegram.org")
    |> request.set_path("/bot" <> client.bot_token <> "/sendMessage")
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(json.to_string(body))
  
  case httpc.send(req) {
    Ok(resp) -> {
      case resp.status {
        200 -> Ok("Message sent")
        _ -> Error("Failed to send message")
      }
    }
    Error(e) -> Error("HTTP error")
  }
}
```

### Phase 3: Scheduler

**File**: `honeycomb/autoposting/scheduler.gleam`

```gleam
import gleam/erlang/process
import gleam/list
import gleam/result
import gleam/string
import honeycomb/social/twitter
import honeycomb/social/telegram

pub type Post {
  Post(
    id: String,
    text: String,
    scheduled_at: String,  // "2026-01-11T09:00:00Z"
    platforms: List(Platform),
    status: PostStatus,
  )
}

pub type Platform {
  Twitter
  Telegram(chat_id: String)
}

pub type PostStatus {
  Pending
  Posted
  Failed(String)
}

pub fn start(
  twitter_client: twitter.TwitterClient,
  telegram_client: telegram.TelegramClient,
  posts: List(Post),
) {
  process.start(fn() {
    schedule_loop(twitter_client, telegram_client, posts)
  }, True)
}

fn schedule_loop(
  twitter_client: twitter.TwitterClient,
  telegram_client: telegram.TelegramClient,
  posts: List(Post),
) {
  // Sleep 1 minute
  process.sleep(60_000)
  
  // Get current time
  let now = get_current_time()
  
  // Check each post
  let updated_posts = list.map(posts, fn(post) {
    case post.status {
      Pending -> {
        case should_post(post, now) {
          True -> post_to_platforms(post, twitter_client, telegram_client)
          False -> post
        }
      }
      _ -> post
    }
  })
  
  // Continue loop
  schedule_loop(twitter_client, telegram_client, updated_posts)
}

fn should_post(post: Post, now: String) -> Bool {
  // Compare scheduled_at with now
  post.scheduled_at <= now
}

fn post_to_platforms(
  post: Post,
  twitter_client: twitter.TwitterClient,
  telegram_client: telegram.TelegramClient,
) -> Post {
  // Post to each platform
  let results = list.map(post.platforms, fn(platform) {
    case platform {
      Twitter -> twitter.post_tweet(twitter_client, post.text)
      Telegram(chat_id) -> telegram.send_message(telegram_client, chat_id, post.text)
    }
  })
  
  // Update status
  case list.all(results, result.is_ok) {
    True -> Post(..post, status: Posted)
    False -> Post(..post, status: Failed("Some platforms failed"))
  }
}

fn get_current_time() -> String {
  // Get current UTC time in ISO 8601 format
  // TODO: Use Erlang :calendar module
  "2026-01-11T09:00:00Z"
}
```

### Phase 4: Configuration

**File**: `config/posts.json`

```json
{
  "posts": [
    {
      "id": "post_1",
      "text": "🚀 VIBEE v1.0.0 Released!\n\nFirst programming language created BY AI FOR AI developers\n\n✨ 75% less boilerplate\n⚡ 10-100x faster compilation\n🤖 99% AI-generated code\n🐝 Made for vibe coders\n\nBuilt by @vibee_dev with Claude/Ona\n\nRelease notes & download:\nhttps://github.com/gHashTag/vibee-lang/releases/tag/v1.0.0\n\n#VIBEE #AIGenerated #VibeCoding #ReleaseDay",
      "scheduled_at": "2026-01-11T09:00:00Z",
      "platforms": ["twitter", "telegram"]
    },
    {
      "id": "post_2",
      "text": "🤖 How VIBEE was born\n\nMe: \"Claude, let's create a language for AI agents\"\nClaude: \"Let's start with the architecture...\"\n\n2 years later:\n• 310K+ lines of code\n• 1,144 commits\n• 99% AI-generated\n• Production-ready v1.0.0\n\nThis is the future of programming.\nAI doesn't just help - it creates.\n\n#VIBEE #AIGenerated #VibeCoding",
      "scheduled_at": "2026-01-12T09:00:00Z",
      "platforms": ["twitter", "telegram"]
    }
  ],
  "twitter": {
    "api_key": "${TWITTER_API_KEY}",
    "api_secret": "${TWITTER_API_SECRET}",
    "access_token": "${TWITTER_ACCESS_TOKEN}",
    "access_token_secret": "${TWITTER_ACCESS_TOKEN_SECRET}"
  },
  "telegram": {
    "bot_token": "${TELEGRAM_BOT_TOKEN}",
    "chat_id": "@vibee_dev"
  }
}
```

---

## Environment Variables

```bash
# .env
TWITTER_API_KEY=your_api_key
TWITTER_API_SECRET=your_api_secret
TWITTER_ACCESS_TOKEN=your_access_token
TWITTER_ACCESS_TOKEN_SECRET=your_access_token_secret

TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_ID=@vibee_dev
```

---

## Deployment

### Fly.io

**Dockerfile**:
```dockerfile
FROM ghcr.io/gleam-lang/gleam:v1.0.0-erlang-alpine

WORKDIR /app

COPY gleam.toml gleam.toml
COPY manifest.toml manifest.toml
COPY src src
COPY honeycomb honeycomb
COPY config config

RUN gleam build

CMD ["gleam", "run", "-m", "autoposting"]
```

**fly.toml**:
```toml
app = "vibee-autoposting"

[build]
  dockerfile = "Dockerfile"

[env]
  VIBEE_MODE = "autoposting"

[[services]]
  internal_port = 8080
  protocol = "tcp"
```

**Deploy**:
```bash
# Set secrets
fly secrets set TWITTER_API_KEY=...
fly secrets set TWITTER_API_SECRET=...
fly secrets set TWITTER_ACCESS_TOKEN=...
fly secrets set TWITTER_ACCESS_TOKEN_SECRET=...
fly secrets set TELEGRAM_BOT_TOKEN=...
fly secrets set TELEGRAM_CHAT_ID=@vibee_dev

# Deploy
fly deploy -a vibee-autoposting
```

---

## Testing

### Manual Test

```bash
# Test Twitter
gleam run -m autoposting test twitter "Hello from VIBEE!"

# Test Telegram
gleam run -m autoposting test telegram "Hello from VIBEE!"

# Test scheduler (dry run)
gleam run -m autoposting test scheduler
```

### Integration Test

```gleam
// test/autoposting_test.gleam

import gleeunit
import gleeunit/should
import honeycomb/social/twitter
import honeycomb/social/telegram
import honeycomb/autoposting/scheduler

pub fn main() {
  gleeunit.main()
}

pub fn twitter_post_test() {
  let client = twitter.new("key", "secret", "token", "token_secret")
  let result = twitter.post_tweet(client, "Test tweet")
  result |> should.be_ok
}

pub fn telegram_send_test() {
  let client = telegram.new("bot_token")
  let result = telegram.send_message(client, "@vibee_dev", "Test message")
  result |> should.be_ok
}

pub fn scheduler_test() {
  let posts = [
    scheduler.Post(
      id: "test_1",
      text: "Test post",
      scheduled_at: "2026-01-11T09:00:00Z",
      platforms: [scheduler.Twitter, scheduler.Telegram("@vibee_dev")],
      status: scheduler.Pending,
    )
  ]
  
  // Test should_post logic
  let should_post = scheduler.should_post(posts.0, "2026-01-11T09:01:00Z")
  should_post |> should.be_true
}
```

---

## Alternatives

### Option 1: Use Existing Services

**Zapier** ($20-50/month):
- Connect RSS feed → Twitter + Telegram
- No coding required
- Limited customization

**Buffer** ($6-12/month):
- Schedule posts
- Analytics
- Multi-platform

**IFTTT** (Free):
- Simple automation
- Limited features

**Pros**: No coding, quick setup  
**Cons**: Monthly cost, less control

### Option 2: GitHub Actions

```yaml
# .github/workflows/autopost.yml
name: Autopost

on:
  schedule:
    - cron: '0 9 * * *'  # 9 AM UTC daily

jobs:
  post:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Post to Twitter
        env:
          TWITTER_API_KEY: ${{ secrets.TWITTER_API_KEY }}
        run: |
          # Post using curl or Python script
          
      - name: Post to Telegram
        env:
          TELEGRAM_BOT_TOKEN: ${{ secrets.TELEGRAM_BOT_TOKEN }}
        run: |
          # Post using curl
```

**Pros**: Free, integrated with GitHub  
**Cons**: Limited scheduling, not real-time

### Option 3: Gleam + OTP (Recommended)

**Pros**:
- Full control
- Real-time scheduling
- Fault-tolerant (OTP supervision)
- Integrated with existing VIBEE codebase
- Free (except Twitter API $100/month)

**Cons**:
- More coding
- Need to maintain

---

## Recommendation

**Use Gleam + OTP** for autoposting:

1. **Twitter API Client** - OAuth 1.0a signing
2. **Telegram Bot API Client** - Simple HTTP requests
3. **Scheduler** - OTP gen_server with timer
4. **Configuration** - JSON file with posts
5. **Deployment** - Fly.io with secrets

**Cost**:
- Twitter API: $100/month (Basic tier)
- Telegram API: Free
- Fly.io: Free tier (256MB RAM enough)
- **Total**: $100/month

**Time to implement**: 4-8 hours

---

**Next Steps**:
1. Create Twitter Developer Account
2. Create Telegram Bot via @BotFather
3. Implement Twitter API client
4. Implement Telegram API client
5. Implement scheduler
6. Test locally
7. Deploy to Fly.io


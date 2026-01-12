# VIBEE Autoposting Setup Guide

**Дата**: 2026-01-11  
**Статус**: ✅ Ready to use  
**Цель**: Настроить автоматический постинг в Twitter и Telegram

---

## Overview

VIBEE Autoposting Service автоматически публикует посты в Twitter и Telegram по расписанию.

**Features**:
- ✅ Twitter API v2 integration (OAuth 1.0a)
- ✅ Telegram Bot API integration
- ✅ Scheduler with configurable interval
- ✅ Multiple platforms per post
- ✅ Fault-tolerant (OTP supervision)
- ✅ Environment-based configuration

---

## Prerequisites

### 1. Twitter Developer Account

**Create Account**:
1. Go to [developer.twitter.com](https://developer.twitter.com)
2. Sign up with your Twitter account
3. Apply for Elevated access (required for posting)
4. Wait for approval (usually 1-2 days)

**Create App**:
1. Go to Developer Portal
2. Create new App
3. Get API Keys:
   - API Key
   - API Secret
   - Access Token
   - Access Token Secret

**Cost**: $100/month (Basic tier) for write access

### 2. Telegram Bot

**Create Bot**:
1. Open Telegram
2. Search for @BotFather
3. Send `/newbot`
4. Follow instructions
5. Get Bot Token

**Create Channel**:
1. Create new channel (e.g., @vibee_dev)
2. Add bot as admin
3. Give posting permissions

**Cost**: Free!

---

## Installation

### 1. Clone Repository

```bash
git clone https://github.com/gHashTag/vibee-lang.git
cd vibee-lang
```

### 2. Install Dependencies

```bash
cd gleam
gleam deps download
```

### 3. Set Environment Variables

```bash
# Twitter API credentials
export TWITTER_API_KEY="your_api_key"
export TWITTER_API_SECRET="your_api_secret"
export TWITTER_ACCESS_TOKEN="your_access_token"
export TWITTER_ACCESS_TOKEN_SECRET="your_access_token_secret"

# Telegram Bot credentials
export TELEGRAM_BOT_TOKEN="your_bot_token"
export TELEGRAM_CHAT_ID="@vibee_dev"  # or channel ID like -1001234567890
```

**Tip**: Add to `.env` file:

```bash
# .env
TWITTER_API_KEY=your_api_key
TWITTER_API_SECRET=your_api_secret
TWITTER_ACCESS_TOKEN=your_access_token
TWITTER_ACCESS_TOKEN_SECRET=your_access_token_secret
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_ID=@vibee_dev
```

Then load:
```bash
source .env
```

---

## Configuration

### Posts Configuration

Edit `gleam/src/vibee_autoposting.gleam` to add/modify posts:

```gleam
fn get_default_posts(telegram_chat_id: String) -> List(scheduler.Post) {
  [
    scheduler.Post(
      id: "post_1",
      text: "Your post text here...",
      scheduled_at: "2026-01-12T09:00:00Z",  // ISO 8601 UTC
      platforms: [scheduler.Twitter, scheduler.Telegram(telegram_chat_id)],
      status: scheduler.Pending,
    ),
    // Add more posts...
  ]
}
```

**Date Format**: ISO 8601 UTC
- `2026-01-12T09:00:00Z` = January 12, 2026 at 9:00 AM UTC
- Use [timeanddate.com](https://www.timeanddate.com/worldclock/converter.html) for conversion

**Platforms**:
- `scheduler.Twitter` - Post to Twitter
- `scheduler.Telegram(chat_id)` - Post to Telegram
- Both: `[scheduler.Twitter, scheduler.Telegram(chat_id)]`

### Scheduler Configuration

Edit `gleam/src/vibee_autoposting.gleam`:

```gleam
check_interval_ms: 60_000,  // Check every 60 seconds (1 minute)
```

**Recommended**: 60 seconds (1 minute) for near-real-time posting

---

## Usage

### Local Testing

**1. Test Twitter API**:
```bash
# Set environment variables
export TWITTER_API_KEY="..."
export TWITTER_API_SECRET="..."
export TWITTER_ACCESS_TOKEN="..."
export TWITTER_ACCESS_TOKEN_SECRET="..."

# Test posting
cd gleam
gleam run -m vibee_autoposting
```

**2. Test Telegram API**:
```bash
# Set environment variables
export TELEGRAM_BOT_TOKEN="..."
export TELEGRAM_CHAT_ID="@vibee_dev"

# Test posting
cd gleam
gleam run -m vibee_autoposting
```

**3. Test Full Scheduler**:
```bash
# Set all environment variables
source .env

# Run scheduler
./scripts/test-autoposting.sh
```

**Output**:
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

🐝 VIBEE Autoposting Scheduler started
```

### Production Deployment (Fly.io)

**1. Create Fly App**:
```bash
fly apps create vibee-autoposting
```

**2. Set Secrets**:
```bash
fly secrets set \
  TWITTER_API_KEY="your_api_key" \
  TWITTER_API_SECRET="your_api_secret" \
  TWITTER_ACCESS_TOKEN="your_access_token" \
  TWITTER_ACCESS_TOKEN_SECRET="your_access_token_secret" \
  TELEGRAM_BOT_TOKEN="your_bot_token" \
  TELEGRAM_CHAT_ID="@vibee_dev" \
  -a vibee-autoposting
```

**3. Create Dockerfile**:
```dockerfile
# Dockerfile.autoposting
FROM ghcr.io/gleam-lang/gleam:v1.0.0-erlang-alpine

WORKDIR /app

COPY gleam/gleam.toml gleam/gleam.toml
COPY gleam/manifest.toml gleam/manifest.toml
COPY gleam/src gleam/src
COPY honeycomb honeycomb

WORKDIR /app/gleam

RUN gleam build

CMD ["gleam", "run", "-m", "vibee_autoposting"]
```

**4. Create fly.toml**:
```toml
app = "vibee-autoposting"

[build]
  dockerfile = "Dockerfile.autoposting"

[env]
  VIBEE_MODE = "autoposting"

[[services]]
  internal_port = 8080
  protocol = "tcp"
```

**5. Deploy**:
```bash
fly deploy -a vibee-autoposting --dockerfile Dockerfile.autoposting
```

**6. Check Logs**:
```bash
fly logs -a vibee-autoposting
```

---

## Monitoring

### Check Status

```bash
# Fly.io
fly status -a vibee-autoposting

# Logs
fly logs -a vibee-autoposting --follow
```

### Expected Output

**When post is scheduled**:
```
📤 Posting: post_1_release - 🚀 VIBEE v1.0.0 Released!...
  🐦 Posting to Twitter...
  ✈️  Posting to Telegram...
  ✅ Posted successfully to all platforms
```

**When post fails**:
```
📤 Posting: post_1_release - 🚀 VIBEE v1.0.0 Released!...
  🐦 Posting to Twitter...
  ❌ Failed: Twitter: Rate limit exceeded
```

### Metrics

Track in Google Sheets or similar:
- Date/Time
- Post ID
- Status (Posted/Failed)
- Platforms
- Error (if any)

---

## Troubleshooting

### Problem: "Environment variable not set"

**Solution**:
```bash
# Check if variables are set
echo $TWITTER_API_KEY
echo $TELEGRAM_BOT_TOKEN

# Set them
export TWITTER_API_KEY="..."
export TELEGRAM_BOT_TOKEN="..."

# Or load from .env
source .env
```

### Problem: "Twitter: Auth error"

**Solution**:
- Check API keys are correct
- Check Twitter Developer Portal for app status
- Verify Elevated access is approved
- Check if Basic tier ($100/month) is active

### Problem: "Telegram: Invalid response"

**Solution**:
- Check bot token is correct
- Check bot is admin in channel
- Check chat_id format (@vibee_dev or -1001234567890)
- Test with @BotFather: `/mybots` → select bot → check token

### Problem: "Rate limit exceeded"

**Solution**:
- Twitter: Wait 15 minutes, then retry
- Reduce posting frequency
- Check Twitter API limits in Developer Portal

### Problem: "Post not posting at scheduled time"

**Solution**:
- Check system time is correct (UTC)
- Check scheduled_at format (ISO 8601)
- Check scheduler is running (`fly logs`)
- Verify check_interval_ms is set correctly

---

## Architecture

### Components

```
vibee_autoposting.gleam (Entry point)
    ↓
scheduler.gleam (Scheduler loop)
    ↓
    ├─→ twitter.gleam (Twitter API client)
    │       ↓
    │   twitter_ffi.erl (OAuth signing)
    │
    └─→ telegram.gleam (Telegram API client)
```

### Flow

1. **Load config** from environment variables
2. **Create clients** (Twitter, Telegram)
3. **Start scheduler** with posts list
4. **Loop every 60 seconds**:
   - Get current time
   - Check each post
   - If `scheduled_at <= now` and status is `Pending`:
     - Post to Twitter
     - Post to Telegram
     - Update status to `Posted` or `Failed`
5. **Continue** until all posts are done

### OTP Supervision

The scheduler runs in an OTP process:
- Fault-tolerant (restarts on crash)
- Isolated (doesn't affect other services)
- Monitored (logs all activity)

---

## Cost Analysis

### Twitter API
- **Basic tier**: $100/month
- **Includes**: 3,000 tweets/month, write access
- **For 10 posts**: $100/month

### Telegram API
- **Free**: Unlimited messages
- **Rate limit**: 30 messages/second

### Fly.io
- **Free tier**: 256MB RAM, 1 shared CPU
- **Enough for**: Autoposting service
- **Cost**: $0/month

### Total
- **Monthly**: $100 (Twitter API only)
- **Yearly**: $1,200

---

## Alternatives

### Option 1: Buffer ($6-12/month)
- **Pros**: No coding, analytics, multi-platform
- **Cons**: Less control, monthly cost, no Telegram

### Option 2: Zapier ($20-50/month)
- **Pros**: No coding, many integrations
- **Cons**: Monthly cost, limited customization

### Option 3: GitHub Actions (Free)
- **Pros**: Free, integrated with GitHub
- **Cons**: Limited scheduling, not real-time

### Option 4: VIBEE Autoposting (Recommended)
- **Pros**: Full control, real-time, fault-tolerant, integrated
- **Cons**: Need Twitter API ($100/month), more coding

---

## Next Steps

1. ✅ Create Twitter Developer Account
2. ✅ Create Telegram Bot
3. ✅ Set environment variables
4. ✅ Test locally
5. ⏳ Deploy to Fly.io
6. ⏳ Monitor logs
7. ⏳ Track metrics

---

## Support

**Issues**: [github.com/gHashTag/vibee-lang/issues](https://github.com/gHashTag/vibee-lang/issues)  
**Docs**: [github.com/gHashTag/vibee-lang/docs](https://github.com/gHashTag/vibee-lang/tree/main/docs)  
**Twitter**: [@vibee_dev](https://twitter.com/vibee_dev)  
**Telegram**: [@vibee_dev](https://t.me/vibee_dev)

---

**Created BY AI, FOR AI developers** 🤖🐝

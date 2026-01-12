import gleam/erlang/process
import gleam/list
import gleam/result
import gleam/string
import gleam/io
import gleam/option.{type Option, None, Some}
import honeycomb/social/twitter
import honeycomb/social/telegram

pub type Post {
  Post(
    id: String,
    text: String,
    scheduled_at: String,  // ISO 8601: "2026-01-11T09:00:00Z"
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
  Posted(at: String)
  Failed(reason: String, at: String)
}

pub type SchedulerConfig {
  SchedulerConfig(
    twitter_client: Option(twitter.TwitterClient),
    telegram_client: Option(telegram.TelegramClient),
    posts: List(Post),
    check_interval_ms: Int,  // How often to check (default: 60000 = 1 minute)
  )
}

pub fn start(config: SchedulerConfig) -> process.Subject(Nil) {
  process.start(fn() {
    io.println("🐝 VIBEE Autoposting Scheduler started")
    schedule_loop(config)
  }, True)
}

fn schedule_loop(config: SchedulerConfig) {
  // Sleep for check interval
  process.sleep(config.check_interval_ms)
  
  // Get current time
  let now = get_current_time()
  
  // Check each post
  let updated_posts = list.map(config.posts, fn(post) {
    case post.status {
      Pending -> {
        case should_post(post, now) {
          True -> {
            io.println("📤 Posting: " <> post.id <> " - " <> string.slice(post.text, 0, 50) <> "...")
            post_to_platforms(post, config.twitter_client, config.telegram_client, now)
          }
          False -> post
        }
      }
      _ -> post
    }
  })
  
  // Update config with new posts
  let new_config = SchedulerConfig(..config, posts: updated_posts)
  
  // Check if all posts are done
  let all_done = list.all(updated_posts, fn(post) {
    case post.status {
      Pending -> False
      _ -> True
    }
  })
  
  case all_done {
    True -> {
      io.println("✅ All posts completed!")
      Nil
    }
    False -> schedule_loop(new_config)
  }
}

fn should_post(post: Post, now: String) -> Bool {
  // Compare scheduled_at with now
  // ISO 8601 strings can be compared lexicographically
  post.scheduled_at <= now
}

fn post_to_platforms(
  post: Post,
  twitter_client: Option(twitter.TwitterClient),
  telegram_client: Option(telegram.TelegramClient),
  now: String,
) -> Post {
  // Post to each platform
  let results = list.map(post.platforms, fn(platform) {
    case platform {
      Twitter -> {
        case twitter_client {
          Some(client) -> {
            io.println("  🐦 Posting to Twitter...")
            twitter.post_tweet(client, post.text)
            |> result.map(fn(_) { "Twitter" })
            |> result.map_error(fn(e) { "Twitter: " <> describe_twitter_error(e) })
          }
          None -> Error("Twitter: Client not configured")
        }
      }
      Telegram(chat_id) -> {
        case telegram_client {
          Some(client) -> {
            io.println("  ✈️  Posting to Telegram...")
            telegram.send_message(client, chat_id, post.text)
            |> result.map(fn(_) { "Telegram" })
            |> result.map_error(fn(e) { "Telegram: " <> describe_telegram_error(e) })
          }
          None -> Error("Telegram: Client not configured")
        }
      }
    }
  })
  
  // Check if all succeeded
  let all_ok = list.all(results, result.is_ok)
  let errors = list.filter_map(results, fn(r) {
    case r {
      Error(e) -> Ok(e)
      Ok(_) -> Error(Nil)
    }
  })
  
  case all_ok {
    True -> {
      io.println("  ✅ Posted successfully to all platforms")
      Post(..post, status: Posted(at: now))
    }
    False -> {
      let error_msg = string.join(errors, "; ")
      io.println("  ❌ Failed: " <> error_msg)
      Post(..post, status: Failed(reason: error_msg, at: now))
    }
  }
}

fn describe_twitter_error(error: twitter.TwitterError) -> String {
  case error {
    twitter.HttpError(msg) -> "HTTP error: " <> msg
    twitter.AuthError(msg) -> "Auth error: " <> msg
    twitter.RateLimitError -> "Rate limit exceeded"
    twitter.InvalidResponse(msg) -> "Invalid response: " <> msg
  }
}

fn describe_telegram_error(error: telegram.TelegramError) -> String {
  case error {
    telegram.HttpError(msg) -> "HTTP error: " <> msg
    telegram.InvalidResponse(msg) -> "Invalid response: " <> msg
    telegram.ApiError(code, msg) -> "API error " <> int.to_string(code) <> ": " <> msg
  }
}

@external(erlang, "scheduler_ffi", "get_current_time")
fn get_current_time() -> String

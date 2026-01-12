import gleam/json
import gleam/result
import gleam/list
import gleam/string
import gleam/option.{type Option, None, Some}
import gleam/dynamic
import simplifile
import honeycomb/autoposting/scheduler
import honeycomb/social/twitter
import honeycomb/social/telegram

pub type Config {
  Config(
    posts: List(PostConfig),
    twitter: TwitterConfig,
    telegram: TelegramConfig,
    scheduler: SchedulerConfigData,
  )
}

pub type PostConfig {
  PostConfig(
    id: String,
    text: String,
    scheduled_at: String,
    platforms: List(String),
  )
}

pub type TwitterConfig {
  TwitterConfig(
    enabled: Bool,
    api_key_env: String,
    api_secret_env: String,
    access_token_env: String,
    access_token_secret_env: String,
  )
}

pub type TelegramConfig {
  TelegramConfig(
    enabled: Bool,
    bot_token_env: String,
    chat_id: String,
  )
}

pub type SchedulerConfigData {
  SchedulerConfigData(
    check_interval_ms: Int,
    timezone: String,
  )
}

pub fn load_config(path: String) -> Result(Config, String) {
  case simplifile.read(path) {
    Ok(content) -> parse_config(content)
    Error(_) -> Error("Failed to read config file: " <> path)
  }
}

fn parse_config(content: String) -> Result(Config, String) {
  // TODO: Implement proper JSON parsing with gleam/json
  // For now, return a placeholder
  Error("JSON parsing not implemented yet")
}

pub fn build_scheduler_config(
  config: Config,
) -> Result(scheduler.SchedulerConfig, String) {
  // Build Twitter client
  let twitter_client = case config.twitter.enabled {
    True -> {
      case get_twitter_credentials(config.twitter) {
        Ok(#(api_key, api_secret, access_token, access_token_secret)) -> {
          Some(twitter.new(api_key, api_secret, access_token, access_token_secret))
        }
        Error(_) -> None
      }
    }
    False -> None
  }
  
  // Build Telegram client
  let telegram_client = case config.telegram.enabled {
    True -> {
      case get_telegram_credentials(config.telegram) {
        Ok(bot_token) -> Some(telegram.new(bot_token))
        Error(_) -> None
      }
    }
    False -> None
  }
  
  // Convert posts
  let posts = list.map(config.posts, fn(post_config) {
    scheduler.Post(
      id: post_config.id,
      text: post_config.text,
      scheduled_at: post_config.scheduled_at,
      platforms: convert_platforms(post_config.platforms, config.telegram.chat_id),
      status: scheduler.Pending,
    )
  })
  
  Ok(scheduler.SchedulerConfig(
    twitter_client: twitter_client,
    telegram_client: telegram_client,
    posts: posts,
    check_interval_ms: config.scheduler.check_interval_ms,
  ))
}

fn convert_platforms(
  platform_names: List(String),
  telegram_chat_id: String,
) -> List(scheduler.Platform) {
  list.filter_map(platform_names, fn(name) {
    case string.lowercase(name) {
      "twitter" -> Ok(scheduler.Twitter)
      "telegram" -> Ok(scheduler.Telegram(telegram_chat_id))
      _ -> Error(Nil)
    }
  })
}

fn get_twitter_credentials(
  config: TwitterConfig,
) -> Result(#(String, String, String, String), String) {
  case get_env(config.api_key_env) {
    Ok(api_key) -> {
      case get_env(config.api_secret_env) {
        Ok(api_secret) -> {
          case get_env(config.access_token_env) {
            Ok(access_token) -> {
              case get_env(config.access_token_secret_env) {
                Ok(access_token_secret) -> {
                  Ok(#(api_key, api_secret, access_token, access_token_secret))
                }
                Error(e) -> Error(e)
              }
            }
            Error(e) -> Error(e)
          }
        }
        Error(e) -> Error(e)
      }
    }
    Error(e) -> Error(e)
  }
}

fn get_telegram_credentials(
  config: TelegramConfig,
) -> Result(String, String) {
  get_env(config.bot_token_env)
}

@external(erlang, "config_ffi", "get_env")
fn get_env(name: String) -> Result(String, String)

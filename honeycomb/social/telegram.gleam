import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/json
import gleam/result
import gleam/string
import gleam/int

pub type TelegramClient {
  TelegramClient(bot_token: String)
}

pub type TelegramError {
  HttpError(String)
  InvalidResponse(String)
  ApiError(Int, String)
}

pub type SendMessageOptions {
  SendMessageOptions(
    parse_mode: Option(String),
    disable_web_page_preview: Option(Bool),
    disable_notification: Option(Bool),
    reply_markup: Option(json.Json),
  )
}

pub fn new(bot_token: String) -> TelegramClient {
  TelegramClient(bot_token)
}

pub fn send_message(
  client: TelegramClient,
  chat_id: String,
  text: String,
) -> Result(String, TelegramError) {
  send_message_with_options(
    client,
    chat_id,
    text,
    SendMessageOptions(
      parse_mode: Some("Markdown"),
      disable_web_page_preview: None,
      disable_notification: None,
      reply_markup: None,
    ),
  )
}

pub fn send_message_with_options(
  client: TelegramClient,
  chat_id: String,
  text: String,
  options: SendMessageOptions,
) -> Result(String, TelegramError) {
  let url = "https://api.telegram.org/bot" <> client.bot_token <> "/sendMessage"
  
  let body = build_send_message_body(chat_id, text, options)
  let body_string = json.to_string(body)
  
  case build_request(client, "/sendMessage", body_string) {
    Ok(req) -> {
      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            200 -> parse_send_message_response(resp.body)
            _ -> Error(InvalidResponse("Status: " <> int.to_string(resp.status)))
          }
        }
        Error(_) -> Error(HttpError("Failed to send request"))
      }
    }
    Error(e) -> Error(e)
  }
}

pub fn send_message_with_button(
  client: TelegramClient,
  chat_id: String,
  text: String,
  button_text: String,
  button_url: String,
) -> Result(String, TelegramError) {
  let reply_markup = json.object([
    #("inline_keyboard", json.array([
      json.array([
        json.object([
          #("text", json.string(button_text)),
          #("url", json.string(button_url)),
        ])
      ])
    ]))
  ])
  
  send_message_with_options(
    client,
    chat_id,
    text,
    SendMessageOptions(
      parse_mode: Some("Markdown"),
      disable_web_page_preview: None,
      disable_notification: None,
      reply_markup: Some(reply_markup),
    ),
  )
}

fn build_send_message_body(
  chat_id: String,
  text: String,
  options: SendMessageOptions,
) -> json.Json {
  let base_fields = [
    #("chat_id", json.string(chat_id)),
    #("text", json.string(text)),
  ]
  
  let with_parse_mode = case options.parse_mode {
    Some(mode) -> list.append(base_fields, [#("parse_mode", json.string(mode))])
    None -> base_fields
  }
  
  let with_preview = case options.disable_web_page_preview {
    Some(disable) -> list.append(with_parse_mode, [
      #("disable_web_page_preview", json.bool(disable))
    ])
    None -> with_parse_mode
  }
  
  let with_notification = case options.disable_notification {
    Some(disable) -> list.append(with_preview, [
      #("disable_notification", json.bool(disable))
    ])
    None -> with_preview
  }
  
  let with_markup = case options.reply_markup {
    Some(markup) -> list.append(with_notification, [
      #("reply_markup", markup)
    ])
    None -> with_notification
  }
  
  json.object(with_markup)
}

fn build_request(
  client: TelegramClient,
  method: String,
  body: String,
) -> Result(request.Request(String), TelegramError) {
  let path = "/bot" <> client.bot_token <> method
  
  Ok(
    request.new()
    |> request.set_method(http.Post)
    |> request.set_host("api.telegram.org")
    |> request.set_path(path)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(body)
  )
}

fn parse_send_message_response(body: String) -> Result(String, TelegramError) {
  // Parse JSON response
  // TODO: Implement proper JSON parsing
  // For now, just check if "ok":true
  case string.contains(body, "\"ok\":true") {
    True -> Ok("Message sent successfully")
    False -> {
      // Try to extract error description
      case extract_error(body) {
        Ok(#(code, description)) -> Error(ApiError(code, description))
        Error(_) -> Error(InvalidResponse("Failed to parse response"))
      }
    }
  }
}

fn extract_error(body: String) -> Result(#(Int, String), Nil) {
  // TODO: Implement proper JSON parsing
  // For now, return generic error
  Error(Nil)
}

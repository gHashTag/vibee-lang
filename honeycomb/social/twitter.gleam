import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/json
import gleam/result
import gleam/string
import gleam/list
import gleam/int
import gleam/crypto

pub type TwitterClient {
  TwitterClient(
    api_key: String,
    api_secret: String,
    access_token: String,
    access_token_secret: String,
  )
}

pub type TwitterError {
  HttpError(String)
  AuthError(String)
  RateLimitError
  InvalidResponse(String)
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
) -> Result(String, TwitterError) {
  let url = "https://api.twitter.com/2/tweets"
  let body = json.object([
    #("text", json.string(text))
  ])
  
  let body_string = json.to_string(body)
  
  case build_request(client, "POST", url, body_string) {
    Ok(req) -> {
      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            201 -> parse_tweet_response(resp.body)
            429 -> Error(RateLimitError)
            _ -> Error(InvalidResponse("Status: " <> int.to_string(resp.status)))
          }
        }
        Error(_) -> Error(HttpError("Failed to send request"))
      }
    }
    Error(e) -> Error(e)
  }
}

fn build_request(
  client: TwitterClient,
  method: String,
  url: String,
  body: String,
) -> Result(request.Request(String), TwitterError) {
  case sign_request(client, method, url, body) {
    Ok(auth_header) -> {
      Ok(
        request.new()
        |> request.set_method(http.Post)
        |> request.set_host("api.twitter.com")
        |> request.set_path("/2/tweets")
        |> request.set_header("Authorization", auth_header)
        |> request.set_header("Content-Type", "application/json")
        |> request.set_body(body)
      )
    }
    Error(e) -> Error(e)
  }
}

fn sign_request(
  client: TwitterClient,
  method: String,
  url: String,
  body: String,
) -> Result(String, TwitterError) {
  // OAuth 1.0a signature
  // For now, return a placeholder
  // TODO: Implement full OAuth 1.0a signing with HMAC-SHA1
  
  let timestamp = get_timestamp()
  let nonce = generate_nonce()
  
  let oauth_params = [
    #("oauth_consumer_key", client.api_key),
    #("oauth_token", client.access_token),
    #("oauth_signature_method", "HMAC-SHA1"),
    #("oauth_timestamp", timestamp),
    #("oauth_nonce", nonce),
    #("oauth_version", "1.0"),
  ]
  
  // Build signature base string
  let signature_base = build_signature_base(method, url, oauth_params)
  
  // Sign with HMAC-SHA1
  let signing_key = client.api_secret <> "&" <> client.access_token_secret
  
  case hmac_sha1(signing_key, signature_base) {
    Ok(signature) -> {
      let auth_header = build_auth_header(oauth_params, signature)
      Ok(auth_header)
    }
    Error(_) -> Error(AuthError("Failed to sign request"))
  }
}

fn build_signature_base(
  method: String,
  url: String,
  params: List(#(String, String)),
) -> String {
  let sorted_params = list.sort(params, fn(a, b) {
    string.compare(a.0, b.0)
  })
  
  let param_string = list.map(sorted_params, fn(p) {
    percent_encode(p.0) <> "=" <> percent_encode(p.1)
  })
  |> string.join("&")
  
  string.uppercase(method) <> "&" <>
  percent_encode(url) <> "&" <>
  percent_encode(param_string)
}

fn build_auth_header(
  params: List(#(String, String)),
  signature: String,
) -> String {
  let all_params = list.append(params, [#("oauth_signature", signature)])
  
  let param_string = list.map(all_params, fn(p) {
    percent_encode(p.0) <> "=\"" <> percent_encode(p.1) <> "\""
  })
  |> string.join(", ")
  
  "OAuth " <> param_string
}

@external(erlang, "twitter_ffi", "hmac_sha1")
fn hmac_sha1(key: String, message: String) -> Result(String, Nil)

@external(erlang, "twitter_ffi", "percent_encode")
fn percent_encode(s: String) -> String

@external(erlang, "twitter_ffi", "get_timestamp")
fn get_timestamp() -> String

@external(erlang, "twitter_ffi", "generate_nonce")
fn generate_nonce() -> String

fn parse_tweet_response(body: String) -> Result(String, TwitterError) {
  // Parse JSON response
  // TODO: Implement JSON parsing
  Ok("Tweet posted successfully")
}

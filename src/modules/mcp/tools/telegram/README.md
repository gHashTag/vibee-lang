# Telegram MCP Tools

Telegram integration tools for VIBEE MCP plugin.

**Status:** ✅ Phase 2.1 Complete (4 core tools)  
**Language:** VIBEE

## Tools Implemented

### 1. telegram_send_message

Send text messages to Telegram chats, groups, or channels.

**Parameters:**
- `session_id` (required) - Telegram session ID
- `chat_id` (required) - Target chat ID
- `message` (required) - Message text
- `parse_mode` (optional) - Formatting: "markdown", "html", "none"
- `disable_notification` (optional) - Send silently

**Example:**
```json
{
  "session_id": "session-123",
  "chat_id": "@username",
  "message": "Hello from VIBEE!",
  "parse_mode": "markdown"
}
```

### 2. telegram_get_dialogs

Get list of chats, groups, and channels.

**Parameters:**
- `session_id` (required) - Telegram session ID
- `limit` (optional) - Max dialogs to return (default: 100)
- `type_filter` (optional) - Filter by type: "all", "users", "groups", "channels", "bots"
- `archived` (optional) - Include archived (default: false)

**Example:**
```json
{
  "session_id": "session-123",
  "limit": 50,
  "type_filter": "groups"
}
```

### 3. telegram_get_history

Get message history from a chat.

**Parameters:**
- `session_id` (required) - Telegram session ID
- `chat_id` (required) - Target chat ID
- `limit` (optional) - Max messages (default: 50)
- `offset_id` (optional) - Message ID for pagination
- `reverse` (optional) - Oldest first (default: false)

**Example:**
```json
{
  "session_id": "session-123",
  "chat_id": "@username",
  "limit": 100
}
```

### 4. telegram_search_history

Search through message history.

**Parameters:**
- `session_id` (required) - Telegram session ID
- `query` (required) - Search keywords
- `chat_id` (optional) - Limit to specific chat
- `from_user` (optional) - Filter by sender
- `limit` (optional) - Max results (default: 20)
- `min_date` (optional) - Minimum date (Unix timestamp)
- `max_date` (optional) - Maximum date (Unix timestamp)

**Example:**
```json
{
  "session_id": "session-123",
  "query": "AI model",
  "limit": 10
}
```

## File Structure

```
telegram/
├── README.md                    # This file
├── send_message.vibee          # Send messages (180 lines)
├── get_dialogs.vibee           # Get chat list (200 lines)
├── get_history.vibee           # Get message history (220 lines)
└── search_history.vibee        # Search messages (260 lines)
└── telegram_tools_test.gleam   # Tests (40 tests)
```

## Usage

### Registering Tools

```vibee
import mcp/core/tool_registry
import mcp/tools/telegram/send_message
import mcp/tools/telegram/get_dialogs
import mcp/tools/telegram/get_history
import mcp/tools/telegram/search_history

// Create registry
let registry = tool_registry.create()

// Register telegram tools
let registry = registry
  |> tool_registry.register(send_message.get_tool())
  |> tool_registry.register(get_dialogs.get_tool())
  |> tool_registry.register(get_history.get_tool())
  |> tool_registry.register(search_history.get_tool())
```

### Executing Tools

```vibee
// Send message
let params = json.object([
  #("session_id", json.string("session-123")),
  #("chat_id", json.string("@username")),
  #("message", json.string("Hello!"))
])

let result = tool_registry.execute(
  registry,
  "telegram_send_message",
  params
)
```

## Implementation Status

| Tool | Lines | Status | Tests |
|------|-------|--------|-------|
| send_message | 180 | ✅ Complete | 6 |
| get_dialogs | 200 | ✅ Complete | 7 |
| get_history | 220 | ✅ Complete | 6 |
| search_history | 260 | ✅ Complete | 8 |
| **TOTAL** | **860** | **✅** | **27** |

## TODO: Additional Tools

The following Telegram tools are planned for Phase 2.2:

- [ ] telegram_send_photo (send images)
- [ ] telegram_send_buttons (interactive buttons)
- [ ] telegram_download_media (download files)
- [ ] telegram_get_me (get current user info)
- [ ] telegram_get_user (get user details)
- [ ] telegram_subscribe_updates (real-time updates)
- [ ] telegram_forward_message (forward messages)
- [ ] telegram_delete_message (delete messages)
- [ ] telegram_edit_message (edit sent messages)
- [ ] telegram_pin_message (pin messages)

**Estimated:** ~2,000 more lines

## Testing

```bash
cd honeycomb/mcp/tools/telegram
gleam test --module telegram_tools_test
```

## Dependencies

- `mcp/types/mcp_types` - Core MCP types
- Telegram Bridge API (external service)

## Notes

- All tools use mock data currently
- Real Telegram API integration requires telegram-bridge service
- Session management handled by MCP core
- All code in VIBEE syntax

## See Also

- [../../README.md](../../README.md) - MCP plugin overview
- [../../core/](../../core/) - Core MCP functionality
- [../../types/](../../types/) - Type definitions

# MCP Plugin

Model Context Protocol (MCP) implementation for VIBEE.

**Status:** 🟡 In Progress (Phase 1 - Core Types)  
**Priority:** 🔴 CRITICAL  
**Language:** VIBEE

## Overview

The MCP plugin provides the foundation for AI agent communication in VIBEE. It implements the Model Context Protocol specification, enabling tools, sessions, and context management.

## Structure

```
mcp/
├── manifest.json           # Plugin metadata
├── README.md              # This file
├── core/                  # Core functionality
│   ├── tool_registry.vibee    # Tool registration and execution
│   ├── session_manager.vibee  # Session and context management
│   └── protocol.vibee         # MCP protocol encoding/decoding
├── types/                 # Type definitions
│   └── mcp_types.vibee        # Core MCP types
├── tools/                 # Tool implementations (TODO)
│   ├── telegram_tools.vibee
│   ├── github_tools.vibee
│   ├── ai_tools.vibee
│   └── ...
└── handlers/              # Request handlers (TODO)
    ├── tool_handler.vibee
    └── session_handler.vibee
```

## Features

### ✅ Implemented (Phase 1)

- **Core Types** (`types/mcp_types.vibee`)
  - Tool, ToolResult, Content types
  - Session, Context, Message types
  - Request, Response, Error types
  - 32 tool categories
  - Category detection from tool names

- **Tool Registry** (`core/tool_registry.vibee`)
  - Register/unregister tools
  - Get tool by name
  - List tools (all, by category)
  - Execute tools
  - Validate registry

- **Session Manager** (`core/session_manager.vibee`)
  - Create/reset sessions
  - Manage context (variables, history)
  - Add messages to history
  - Track session age and idle time
  - Session expiration checks

- **Protocol Handler** (`core/protocol.vibee`)
  - Encode/decode requests
  - Encode/decode responses
  - Standard error codes
  - Request/response validation

### ⏳ TODO (Phase 2-4)

- **Tool Implementations** (51K lines to migrate)
  - telegram_tools (3.7K lines)
  - github_tools (3.7K lines)
  - ai_tools (1K lines)
  - sales_tools (1.4K lines)
  - remotion_tools (1.2K lines)
  - +13 more tool categories

- **Request Handlers**
  - Tool execution handler
  - Session management handler
  - Event handlers

- **Advanced Features**
  - Tool validation
  - Permission system
  - Rate limiting
  - Caching
  - Telemetry

## Usage

### Tool Registry

```vibee
import mcp/core/tool_registry
import mcp/types/mcp_types

// Create registry
let registry = tool_registry.create()

// Register a tool
let tool = mcp_types.tool_new(
  "hello_world",
  "Says hello",
  schema,
  fn(params) {
    mcp_types.tool_result_success([
      mcp_types.text_content("Hello, World!")
    ])
  }
)

let registry = tool_registry.register(registry, tool)

// Execute tool
let result = tool_registry.execute(registry, "hello_world", json.null())
```

### Session Management

```vibee
import mcp/core/session_manager

// Create session
let session = session_manager.create("session-123")

// Add message
let session = session_manager.add_message(
  session,
  "user",
  "Hello!"
)

// Set variable
let session = session_manager.set_variable(
  session,
  "user_id",
  json.string("user-456")
)

// Get history
let history = session_manager.get_history(session)
```

### Protocol

```vibee
import mcp/core/protocol

// Create request
let request = protocol.create_request(
  "tools/execute",
  json.object([
    #("tool", json.string("hello_world")),
    #("params", json.null())
  ]),
  Some("req-1")
)

// Encode to JSON
let json_data = protocol.encode_request(request)

// Decode response
let response = protocol.decode_response(response_json)
```

## Tool Categories

The MCP plugin supports 32 tool categories:

| Category | Prefix | Example Tools |
|----------|--------|---------------|
| Telegram | `telegram_` | telegram_send_message |
| Knowledge | `knowledge_` | knowledge_search |
| File | `file_` | file_read, file_write |
| GitHub | `github_` | github_create_pr |
| AI | `ai_` | ai_generate_image |
| Payment | `payment_` | payment_create_invoice |
| Task | `task_` | task_create, task_list |
| ... | ... | ... |

See `types/mcp_types.vibee` for complete list.

## Migration Status

**From:** `gleam/src/vibee_backup/dsl/infra/mcp/` (51,946 lines, 84 files)  
**To:** `honeycomb/mcp/` (VIBEE syntax)

### Phase 1: Core Types ✅ (Complete)
- [x] mcp_types.vibee (200 lines)
- [x] tool_registry.vibee (150 lines)
- [x] session_manager.vibee (150 lines)
- [x] protocol.vibee (150 lines)

**Total Phase 1:** 650 lines migrated

### Phase 2: Tool Implementations (TODO)
- [ ] telegram_tools.vibee (3,717 lines)
- [ ] github_tools.vibee (3,717 lines)
- [ ] ai_tools.vibee (1,041 lines)
- [ ] sales_tools.vibee (1,467 lines)
- [ ] remotion_tools.vibee (1,266 lines)
- [ ] config_tools.vibee (978 lines)
- [ ] content_tools.vibee (857 lines)
- [ ] permission_tools.vibee (764 lines)
- [ ] rag_tools.vibee (752 lines)
- [ ] task_tools.vibee (290 lines)
- [ ] storage_tools.vibee (288 lines)
- [ ] graphql_tools.vibee (259 lines)
- [ ] twin_tools.vibee (212 lines)
- [ ] notification_tools.vibee (118 lines)

**Total Phase 2:** ~16,000 lines

### Phase 3: Core Infrastructure (TODO)
- [ ] decoders.vibee (2,882 lines)
- [ ] ai_handlers.vibee (1,900 lines)
- [ ] session_manager_full.vibee (1,155 lines)
- [ ] super_agent.vibee (1,171 lines)
- [ ] rainbow_types.vibee (958 lines)
- [ ] session.vibee (910 lines)
- [ ] telemetry.vibee (756 lines)
- [ ] types.vibee (620 lines)
- [ ] autonomous.vibee (581 lines)
- [ ] websocket.vibee (575 lines)

**Total Phase 3:** ~12,000 lines

### Phase 4: Supporting Features (TODO)
- [ ] smart_analyzer.vibee (527 lines)
- [ ] validation.vibee (384 lines)
- [ ] shell.vibee (368 lines)
- [ ] task_store.vibee (356 lines)
- [ ] decision.vibee (341 lines)
- [ ] +20 more files

**Total Phase 4:** ~23,000 lines

## Testing

Tests will be added in Phase 2.

```bash
# Run tests (TODO)
cd honeycomb
gleam test --module mcp_test
```

## Dependencies

- None (core plugin)

## License

MIT

## Authors

- VIBEE Team

## See Also

- [MIGRATION_AUDIT_REPORT.md](../../MIGRATION_AUDIT_REPORT.md) - Full migration plan
- [PLUGINS_NEEDED.md](../../PLUGINS_NEEDED.md) - All 39 plugins
- [honeycomb/core/](../core/) - Plugin system infrastructure

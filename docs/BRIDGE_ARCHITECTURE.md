# Zig-Node.js Playwright Bridge Architecture

## Overview

Bridge enabling Zig code to control browsers via Node.js Playwright.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         ZIG APPLICATION                                  │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    HIGH-LEVEL APIs                               │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │   │
│  │  │ Browser │ │  Page   │ │ Element │ │ Network │ │ Storage │   │   │
│  │  │   API   │ │   API   │ │   API   │ │   API   │ │   API   │   │   │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                              │                                          │
│                              ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                  PLAYWRIGHT CLIENT                               │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │   │
│  │  │   Request    │  │   Response   │  │    Error     │          │   │
│  │  │   Handler    │  │   Parser     │  │   Handler    │          │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘          │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                              │                                          │
│                              ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    IPC LAYER                                     │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │   │
│  │  │  Protocol    │  │   Message    │  │    Async     │          │   │
│  │  │  (JSON-RPC)  │  │    Types     │  │   Executor   │          │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘          │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                              │                                          │
│                              ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                  PROCESS LAYER                                   │   │
│  │  ┌──────────────┐  ┌──────────────┐                             │   │
│  │  │    Node      │  │  Connection  │                             │   │
│  │  │   Process    │  │    Pool      │                             │   │
│  │  └──────────────┘  └──────────────┘                             │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                              │                                          │
└──────────────────────────────┼──────────────────────────────────────────┘
                               │ stdin/stdout (JSON-RPC)
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       NODE.JS PROCESS                                    │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    PLAYWRIGHT                                    │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐              │   │
│  │  │ Browser │ │ Context │ │  Page   │ │ Element │              │   │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘              │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                              │                                          │
└──────────────────────────────┼──────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         BROWSER                                          │
│                    (Chromium/Firefox/WebKit)                             │
└─────────────────────────────────────────────────────────────────────────┘
```

## Communication Flow

```
Zig                          Node.js                      Browser
 │                              │                            │
 │  1. JSON-RPC Request         │                            │
 │  ─────────────────────────►  │                            │
 │  {"method":"click",          │                            │
 │   "params":{"selector":"#x"}}│                            │
 │                              │  2. Playwright call        │
 │                              │  ─────────────────────────►│
 │                              │  page.click("#x")          │
 │                              │                            │
 │                              │  3. Action result          │
 │                              │  ◄─────────────────────────│
 │                              │                            │
 │  4. JSON-RPC Response        │                            │
 │  ◄─────────────────────────  │                            │
 │  {"result":{"success":true}} │                            │
 │                              │                            │
```

## Module Summary

### IPC Layer (4 modules)
| Module | Tests | Description |
|--------|-------|-------------|
| bridge_ipc_protocol | 9 | JSON-RPC 2.0 protocol |
| bridge_message_types | 9 | Request/response types |
| bridge_request_handler | 9 | Request queue/dispatch |
| bridge_response_parser | 9 | Response parsing |

### Process Layer (3 modules)
| Module | Tests | Description |
|--------|-------|-------------|
| bridge_node_process | 10 | Node.js subprocess |
| bridge_connection_pool | 9 | Connection pooling |
| bridge_async_executor | 9 | Async task execution |

### Client Layer (2 modules)
| Module | Tests | Description |
|--------|-------|-------------|
| bridge_playwright_client | 10 | High-level client |
| bridge_error_handler | 10 | Error recovery |

### API Layer (6 modules)
| Module | Tests | Description |
|--------|-------|-------------|
| bridge_browser_api | 9 | Browser control |
| bridge_page_api | 10 | Page operations |
| bridge_element_api | 13 | Element interactions |
| bridge_network_api | 9 | Network interception |
| bridge_screenshot_api | 7 | Visual capture |
| bridge_storage_api | 9 | Cookies/storage |

**Total: 15 modules, 140 tests**

## JSON-RPC Protocol

### Request Format
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "browser.launch",
  "params": {
    "browserType": "chromium",
    "headless": true
  }
}
```

### Response Format
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "browserId": "browser_123",
    "version": "120.0.0"
  }
}
```

### Error Format
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32000,
    "message": "Element not found",
    "data": {"selector": "#missing"}
  }
}
```

## Error Handling

```
Error → Classify → Should Retry? → Retry with Backoff → Success/Fail
                        │
                        └─► No → Return Error
```

### Error Types
- **Connection Error**: Reconnect with backoff
- **Timeout Error**: Increase timeout, retry
- **Element Not Found**: Retry with wait
- **Protocol Error**: Log and fail

---
*VIBEE Bridge Architecture v1.0 | φ² + 1/φ² = 3*

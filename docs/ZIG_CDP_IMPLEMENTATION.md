# Zig CDP Implementation - v14

Pure Zig implementation of Chrome DevTools Protocol for browser automation.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    BROWSER AUTOMATION STACK                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    browser.zig                           │   │
│  │              High-level automation API                   │   │
│  │    goto(), click(), typeText(), screenshot()             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   cdp_client.zig                         │   │
│  │              CDP protocol methods                        │   │
│  │    Page.navigate, Input.dispatchMouseEvent, etc.         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   websocket.zig                          │   │
│  │              RFC 6455 WebSocket client                   │   │
│  │    Frame encoding/decoding, masking, handshake           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   std.net.Stream                         │   │
│  │              TCP socket (Zig stdlib)                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Files

| File | Purpose |
|------|---------|
| `src/vibeec/websocket.zig` | WebSocket client (RFC 6455) |
| `src/vibeec/cdp_client.zig` | CDP protocol implementation |
| `src/vibeec/browser.zig` | High-level browser API |
| `src/vibeec/http_client.zig` | HTTP client for target discovery |
| `src/vibeec/json_parser.zig` | JSON parsing for CDP messages |

## Usage

```zig
const std = @import("std");
const Browser = @import("browser.zig").Browser;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize browser
    var browser = Browser.init(allocator, .{
        .host = "localhost",
        .port = 9222,
        .headless = true,
    });
    defer browser.deinit();

    // Connect to Chrome (must be running with --remote-debugging-port=9222)
    try browser.connect();

    // Navigate
    try browser.goto("https://example.com");

    // Get title
    const title = try browser.getTitle();
    std.debug.print("Title: {s}\n", .{title});

    // Click
    try browser.click(100, 200);

    // Type
    try browser.typeText("Hello VIBEE");

    // Screenshot
    const screenshot = try browser.screenshot();
    _ = screenshot;

    // Close
    browser.close();
}
```

## Running Chrome

```bash
# Headless mode
chromium-browser --headless --remote-debugging-port=9222

# With GUI
chromium-browser --remote-debugging-port=9222
```

## Test Results

| Module | Tests | Status |
|--------|-------|--------|
| websocket.zig | 9 | ✅ Pass |
| cdp_client.zig | 20 | ✅ Pass |
| browser.zig | 27 | ✅ Pass |

Run tests:
```bash
zig test src/vibeec/browser.zig
```

## CDP Methods Implemented

### Page Domain
- `Page.enable` - Enable page events
- `Page.navigate` - Navigate to URL
- `Page.captureScreenshot` - Take screenshot

### DOM Domain
- `DOM.enable` - Enable DOM events
- `DOM.getDocument` - Get document root

### Input Domain
- `Input.dispatchMouseEvent` - Mouse clicks
- `Input.insertText` - Type text

### Runtime Domain
- `Runtime.enable` - Enable runtime events
- `Runtime.evaluate` - Execute JavaScript

## Performance

- JSON parsing: ~55,000 ops/s
- Path queries: ~15M queries/s
- Zero external dependencies
- Pure Zig implementation

---

**φ² + 1/φ² = 3**

# Chrome Headless Browser - VIBEE

Complete Chrome DevTools Protocol (CDP) automation with headless mode support.

## 📁 Files

- `src/vibeec/chrome_launcher.zig` - Chrome process launcher
- `src/vibeec/cdp_client.zig` - Chrome DevTools Protocol client
- `src/vibeec/browser.zig` - High-level browser automation API
- `src/vibeec/chrome_headless_demo.zig` - Demo application

## 🚀 Features

- ✅ Launch Chrome in headless mode
- ✅ Connect to Chrome DevTools Protocol
- ✅ Navigate to URLs
- ✅ Take screenshots (base64 PNG)
- ✅ Execute JavaScript
- ✅ Click elements
- ✅ Type text
- ✅ Get page information
- ✅ Automatic cleanup

## 🧪 Testing

Run all tests:

```bash
# Test Chrome launcher
zig test src/vibeec/chrome_launcher.zig

# Test CDP client
zig test src/vibeec/cdp_client.zig

# Test Browser module
zig test src/vibeec/browser.zig

# Run all tests
./test_chrome_headless.sh
```

## 💻 Usage Example

```zig
const std = @import("std");
const chrome_launcher = @import("chrome_launcher.zig");
const browser = @import("browser.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Configure Chrome
    const config = chrome_launcher.ChromeConfig{
        .headless = true,
        .viewport_width = 1280,
        .viewport_height = 720,
        .remote_debugging_port = 9222,
    };
    
    // Initialize launcher
    var launcher = chrome_launcher.ChromeLauncher.init(allocator, config);
    defer launcher.deinit();
    
    // Launch Chrome
    var chrome_process = try launcher.launch();
    defer launcher.terminate(&chrome_process);
    
    // Connect to Chrome
    var b = try launcher.createBrowser(chrome_process);
    defer b.deinit();
    
    // Navigate to URL
    try b.goto("https://example.com");
    
    // Take screenshot
    const screenshot = try b.screenshot();
    
    // Save screenshot
    // ... decode base64 and write to file
}
```

## 🔧 Chrome Config Options

- `headless` - Run Chrome in headless mode (default: true)
- `viewport_width` - Viewport width in pixels (default: 1280)
- `viewport_height` - Viewport height in pixels (default: 720)
- `user_agent` - Custom user agent string (default: null)
- `remote_debugging_port` - CDP port (default: 9222)
- `user_data_dir` - User data directory (default: temp dir)
- `disable_gpu` - Disable GPU (default: true for headless)
- `disable_sandbox` - Disable sandbox (default: false)
- `timeout_ms` - Startup timeout in milliseconds (default: 30000)

## 📋 Browser API

### Navigation

```zig
// Navigate to URL
try browser.goto("https://example.com");
```

### Screenshots

```zig
// Take screenshot (returns base64 PNG)
const screenshot = try browser.screenshot();
```

### JavaScript

```zig
// Execute JavaScript
const result = try browser.evaluate("document.title");
```

### Interactions

```zig
// Click at coordinates
try browser.click(x, y);

// Click element by selector
try browser.clickSelector("#button");

// Type text
try browser.typeText("Hello World");
```

### Information

```zig
// Get page title
const title = try browser.getTitle();
```

## 🔑 CDP Methods

The browser module provides high-level wrappers for CDP commands:

- `Page.navigate`
- `Page.captureScreenshot`
- `Runtime.evaluate`
- `Input.dispatchMouseEvent`
- `Input.insertText`

## 📝 Generated Specs

Specifications in `specs/tri/`:

- `chrome_headless_cdp.vibee` - Chrome headless with CDP
- `chrome_headless_real.vibee` - Complete implementation spec

Generate code:

```bash
./bin/vibee gen specs/tri/chrome_headless_cdp.vibee
./bin/vibee gen specs/tri/chrome_headless_real.vibee
```

## 🧬 Architecture

```
chrome_launcher.zig
    └─> Launch Chrome process
        └─> Wait for CDP port to be available
            └─> Return ChromeProcess

browser.zig
    └─> Uses cdp_client.zig
        └─> WebSocket connection to Chrome CDP
            └─> JSON-RPC protocol
                └─> Execute CDP commands
```

## 🔮 Future Work

- [ ] WebSocket connection pooling
- [ ] Event subscriptions (DOMContentLoaded, Console events)
- [ ] Multiple tab support
- [ ] Cookie and storage management
- [ ] Network interception
- [ ] PDF generation
- [ ] Performance metrics
- [ ] Coverage of more CDP domains

## 📊 Testing Status

✅ All tests passing:
- chrome_launcher: 3/3 tests
- cdp_client: 20/20 tests  
- browser: 27/27 tests

## 🎯 Golden Identity

φ² + 1/φ² = 3 | PHOENIX = 999

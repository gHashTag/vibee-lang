# 🌐 VIBEE Browser API

**Version:** 162.0.0  
**φ² + 1/φ² = 3 | PHOENIX = 999**

---

## Quick Start

```bash
# 1. Launch Chromium with CDP
chromium --remote-debugging-port=9222 --headless

# 2. Use vibee-agent
./bin/vibee-agent "Open google.com and search for weather"
```

---

## Modules

### WebSocket Client (v156)
```zig
const ws = WebSocketClient.connect("ws://localhost:9222/...");
ws.sendText("{\"method\": \"Page.navigate\"}");
const response = ws.receive();
ws.close();
```

### CDP Client (v157)
```zig
const cdp = CDPClient.connect(ws);
const result = cdp.page_navigate("https://google.com");
const screenshot = cdp.page_screenshot(.{ .format = "png" });
```

### Chromium Integration (v158)
```zig
const browser = ChromiumIntegration.launch(.{ .headless = true });
const endpoint = browser.getWsEndpoint();
browser.kill();
```

### Parallel Tabs (v159)
```zig
const pool = ParallelTabs.createPool(10);
pool.runParallel(tasks);
const results = pool.collectResults();
```

### Network Interception (v160)
```zig
const interceptor = NetworkInterception.enable("*.js");
interceptor.addRule(.{ .action = "block" });
interceptor.mockResponse(.{ .status = 200, .body = "{}" });
```

### Mobile Emulation (v161)
```zig
const emulator = MobileEmulation.emulateDevice("iPhone 14");
emulator.setViewport(390, 844);
emulator.setGeolocation(55.75, 37.62);
```

### PDF Generation (v162)
```zig
const pdf = PDFGeneration.generate(.{ .format = "A4" });
pdf.save("output.pdf");
```

---

## Test Results

| Module | Tests | Status |
|--------|-------|--------|
| websocket_client_v156 | 17 | ✅ |
| cdp_client_v157 | 25 | ✅ |
| chromium_integration_v158 | 7 | ✅ |
| parallel_tabs_v159 | 7 | ✅ |
| network_interception_v160 | 7 | ✅ |
| mobile_emulation_v161 | 7 | ✅ |
| pdf_generation_v162 | 7 | ✅ |
| **TOTAL** | **77** | ✅ |

---

## CDP Domains

| Domain | Methods |
|--------|---------|
| Browser | getVersion, close |
| Target | getTargets, createTarget, closeTarget |
| Page | navigate, reload, screenshot, printToPDF |
| DOM | getDocument, querySelector |
| Runtime | evaluate, callFunctionOn |
| Input | dispatchMouseEvent, dispatchKeyEvent |
| Network | enable, getCookies, setCookie |
| Fetch | enable, continueRequest, fulfillRequest |
| Emulation | setDeviceMetricsOverride, setGeolocationOverride |

---

## Device Profiles

| Device | Width | Height | Scale |
|--------|-------|--------|-------|
| iPhone 14 | 390 | 844 | 3 |
| iPhone 14 Pro Max | 430 | 932 | 3 |
| Pixel 7 | 412 | 915 | 2.625 |
| iPad Pro | 1024 | 1366 | 2 |

---

## Paper Sizes

| Size | Width | Height |
|------|-------|--------|
| Letter | 8.5" | 11" |
| Legal | 8.5" | 14" |
| A4 | 8.27" | 11.69" |
| A3 | 11.69" | 16.54" |

---

## φ² + 1/φ² = 3 | PHOENIX = 999

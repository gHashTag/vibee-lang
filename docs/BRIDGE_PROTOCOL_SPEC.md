# Bridge Protocol Specification

## Protocol: JSON-RPC 2.0

### Transport
- **Channel**: stdin/stdout pipes
- **Encoding**: UTF-8
- **Framing**: Length-prefixed messages

### Message Frame
```
[4 bytes: length][payload]
```

## Methods

### Browser Methods

#### browser.launch
```json
{
  "method": "browser.launch",
  "params": {
    "browserType": "chromium|firefox|webkit",
    "headless": true,
    "slowMo": 0,
    "args": []
  }
}
```

#### browser.close
```json
{
  "method": "browser.close",
  "params": {
    "browserId": "string"
  }
}
```

### Page Methods

#### page.create
```json
{
  "method": "page.create",
  "params": {
    "browserId": "string",
    "url": "string (optional)"
  }
}
```

#### page.goto
```json
{
  "method": "page.goto",
  "params": {
    "pageId": "string",
    "url": "string",
    "waitUntil": "load|domcontentloaded|networkidle",
    "timeout": 30000
  }
}
```

#### page.content
```json
{
  "method": "page.content",
  "params": {
    "pageId": "string"
  }
}
```

### Element Methods

#### element.click
```json
{
  "method": "element.click",
  "params": {
    "pageId": "string",
    "selector": "string",
    "button": "left|right|middle",
    "clickCount": 1,
    "timeout": 30000
  }
}
```

#### element.fill
```json
{
  "method": "element.fill",
  "params": {
    "pageId": "string",
    "selector": "string",
    "value": "string"
  }
}
```

#### element.type
```json
{
  "method": "element.type",
  "params": {
    "pageId": "string",
    "selector": "string",
    "text": "string",
    "delay": 0
  }
}
```

#### element.getText
```json
{
  "method": "element.getText",
  "params": {
    "pageId": "string",
    "selector": "string"
  }
}
```

### Screenshot Methods

#### screenshot.page
```json
{
  "method": "screenshot.page",
  "params": {
    "pageId": "string",
    "fullPage": false,
    "format": "png|jpeg",
    "quality": 80
  }
}
```

### Storage Methods

#### storage.getCookies
```json
{
  "method": "storage.getCookies",
  "params": {
    "contextId": "string",
    "domain": "string (optional)"
  }
}
```

#### storage.setCookies
```json
{
  "method": "storage.setCookies",
  "params": {
    "contextId": "string",
    "cookies": [...]
  }
}
```

## Error Codes

| Code | Message | Description |
|------|---------|-------------|
| -32700 | Parse error | Invalid JSON |
| -32600 | Invalid Request | Invalid JSON-RPC |
| -32601 | Method not found | Unknown method |
| -32602 | Invalid params | Invalid parameters |
| -32603 | Internal error | Server error |
| -32000 | Element not found | Selector failed |
| -32001 | Timeout | Operation timeout |
| -32002 | Navigation failed | Page load failed |
| -32003 | Browser closed | Browser disconnected |

## Timeouts

| Operation | Default | Max |
|-----------|---------|-----|
| Launch | 30s | 60s |
| Navigation | 30s | 120s |
| Click | 30s | 60s |
| Type | 30s | 60s |
| Screenshot | 30s | 60s |

---
*VIBEE Bridge Protocol v1.0*

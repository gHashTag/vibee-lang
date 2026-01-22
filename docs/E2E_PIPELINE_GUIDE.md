# E2E Pipeline Guide v21

End-to-end testing pipeline for Chrome CDP + HuggingFace integration.

## Quick Start

```bash
# 1. Start Chrome with CDP
google-chrome --headless=new --disable-gpu --remote-debugging-port=9222 \
  --no-sandbox --disable-dev-shm-usage about:blank &

# 2. Verify CDP
curl -s http://localhost:9222/json/version

# 3. Navigate to URL
curl -s -X PUT "http://localhost:9222/json/new?https://example.com"

# 4. Get observation
curl -s http://localhost:9222/json/list
```

## Specifications

| Spec | Purpose |
|------|---------|
| `specs/tri/e2e_pipeline_v21.vibee` | Full E2E pipeline types and behaviors |
| `specs/tri/e2e_simple_task_v21.vibee` | Simple navigate + get title task |

## Generated Code

```bash
./bin/vibee gen specs/tri/e2e_pipeline_v21.vibee
./bin/vibee gen specs/tri/e2e_simple_task_v21.vibee
zig test trinity/output/e2e_pipeline_v21.zig
zig test trinity/output/e2e_simple_task_v21.zig
```

## Latency Benchmarks (v21)

| Operation | Latency |
|-----------|---------|
| CDP Check | ~5ms |
| Navigation | ~12ms |
| Observation | ~5ms |
| HuggingFace API | ~44ms |
| **Total** | **~66ms** |

## CDP Endpoints

- `GET /json/version` - Browser version info
- `PUT /json/new?{url}` - Create new page with URL
- `GET /json/list` - List all pages (observation)
- `ws://localhost:9222/devtools/page/{id}` - WebSocket for CDP commands

## Types

```
E2EConfig: chrome_host, chrome_port, huggingface_endpoint, timeout_ms
BrowserState: url, title, dom_snapshot, screenshot_base64
NavigationResult: success, load_time_ms, final_url, error
ObservationResult: title, url, dom_text, accessibility_tree, timestamp
```

---
φ² + 1/φ² = 3 | PHOENIX = 999

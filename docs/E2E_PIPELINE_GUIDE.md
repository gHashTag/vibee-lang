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

## HuggingFace LLM Integration (v21.1)

### Specification

`specs/tri/huggingface_llm_v21.vibee` - LLM client for browser automation

### Types

```
HFConfig: api_key, model, base_url, max_tokens, temperature, timeout_ms
ChatMessage: role, content
ChatRequest: model, messages, max_tokens, temperature, stream
ChatResponse: content, model, finish_reason, prompt_tokens, completion_tokens, latency_ms
BrowserAction: thought, action, input
```

### Supported Models

| Model | ID | Latency | Quality |
|-------|-----|---------|---------|
| Qwen 2.5 72B | `Qwen/Qwen2.5-72B-Instruct` | ~300ms | Best |
| Llama 3.3 70B | `meta-llama/Llama-3.3-70B-Instruct` | ~284ms | Fast |
| Mistral 7B | `mistralai/Mistral-7B-Instruct-v0.3` | ~100ms | Light |

### Usage

```bash
# Set API key
export HF_TOKEN=hf_your_token_here

# Generate and test
./bin/vibee gen specs/tri/huggingface_llm_v21.vibee
zig test trinity/output/huggingface_llm_v21.zig
```

### Browser Action Format

LLM responses are parsed into:
```
Thought: [reasoning about the task]
Action: [goto|click|type|scroll|extract]
Input: [action parameters]
```

---
φ² + 1/φ² = 3 | PHOENIX = 999

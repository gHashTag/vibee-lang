# BOTTLENECK ANALYSIS v10

## Discovery

Existing working components in `vibee-electron/src/`:
- `agent.js` - VIBEEAgent with ReAct loop
- `llm-interface.js` - OpenAI/Anthropic/Local LLM support
- `cdp-client.js` - Chrome DevTools Protocol client
- `tools.js` - Browser automation tools

## Problem

90+ .vibee specs generate .zig code, but:
1. No bridge between Zig and existing JS runtime
2. Generated Zig is isolated from working agent
3. Specs describe interfaces, not connected implementation

## Solution: Bottleneck Specs

Created specs for actual performance bottlenecks:

| Spec | Purpose |
|------|---------|
| `bottleneck_zig_json.vibee` | SIMD JSON parsing for LLM responses |
| `bottleneck_zig_http.vibee` | Low-latency HTTP client |
| `bottleneck_zig_process.vibee` | Fast process spawning |
| `bottleneck_node_bridge.vibee` | N-API Zig↔Node.js bridge |
| `bottleneck_llm_client.vibee` | Unified LLM client |
| `bottleneck_cdp_client.vibee` | CDP WebSocket client |
| `bottleneck_browser_runtime.vibee` | Browser lifecycle |
| `bottleneck_node_server.vibee` | HTTP server interface |
| `bottleneck_webarena_docker.vibee` | Docker deployment |
| `bottleneck_benchmark_harness.vibee` | Performance measurement |
| `bottleneck_metrics_collector.vibee` | Metrics collection |
| `bottleneck_integration_layer.vibee` | Component integration |

## MVP Specs

| Spec | Purpose |
|------|---------|
| `mvp_minimal_agent.vibee` | Minimum working agent |
| `mvp_single_task.vibee` | Single task execution |
| `mvp_end_to_end.vibee` | E2E verification |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     VIBEE Agent Architecture                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   .vibee    │───▶│  vibeec     │───▶│    .zig     │         │
│  │   specs     │    │  compiler   │    │   output    │         │
│  └─────────────┘    └─────────────┘    └──────┬──────┘         │
│                                               │                 │
│                                               ▼                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   Node.js   │◀───│  N-API      │◀───│    Zig      │         │
│  │   Runtime   │    │  Bridge     │    │   Native    │         │
│  └──────┬──────┘    └─────────────┘    └─────────────┘         │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   agent.js  │───▶│  CDP Client │───▶│  Browser    │         │
│  │   (ReAct)   │    │             │    │  (Electron) │         │
│  └──────┬──────┘    └─────────────┘    └─────────────┘         │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────┐                                                │
│  │  LLM API    │                                                │
│  │  (OpenAI)   │                                                │
│  └─────────────┘                                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Next Steps

1. Implement N-API bridge (`bottleneck_node_bridge`)
2. Connect Zig JSON parser to JS runtime
3. Run WebArena benchmark with hybrid architecture

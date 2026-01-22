# VIBEE v22 Browser Agent Modules

## Overview

Version 22 introduces a complete browser automation agent stack with phi-optimized architecture.

## Module List (17 modules, 185 tests)

| Module | Tests | Description |
|--------|-------|-------------|
| agent_integrated_v22 | 11 | Main agent orchestrator |
| cdp_session_manager_v22 | 13 | Chrome DevTools session management |
| cdp_websocket_client_v22 | 11 | WebSocket communication |
| cdp_dom_parser_v22 | 12 | DOM parsing and querying |
| cdp_element_extractor_v22 | 11 | Element extraction |
| cdp_click_action_v22 | 11 | Click actions |
| cdp_type_action_v22 | 11 | Keyboard input |
| cdp_screenshot_v22 | 11 | Screenshot capture |
| ollama_client_v22 | 11 | Ollama LLM client |
| action_executor_v22 | 11 | Action execution |
| observation_builder_v22 | 11 | Observation building |
| prompt_builder_v22 | 12 | Prompt construction |
| vision_observation_v22 | 11 | Visual observations |
| webarena_benchmark_v22 | 11 | WebArena benchmarking |
| webarena_task_v22 | 11 | Task management |
| zig_agent_core_v22 | 11 | Core agent logic |
| zig_http_client_v22 | 11 | HTTP client |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  agent_integrated_v22                        │
│                    (Orchestrator)                            │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ observation │  │   prompt    │  │   action    │         │
│  │  _builder   │  │  _builder   │  │  _executor  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐                          │
│  │   ollama    │  │    cdp      │                          │
│  │   _client   │  │  _session   │                          │
│  └─────────────┘  └─────────────┘                          │
└─────────────────────────────────────────────────────────────┘
```

## Phi Constants

All modules use phi-aligned constants:
- PHI = 1.618033988749895
- Fibonacci timeouts: 233, 377, 610, 987, 1597 ms
- Buffer sizes: 4181, 6765, 10946 bytes

## Usage

```bash
# Generate all v22 modules
for f in specs/tri/*_v22.vibee; do ./bin/vibee gen "$f"; done

# Test all v22 modules
for f in trinity/output/*_v22.zig; do zig test "$f"; done
```

## Benchmark Results

- Total modules: 17
- Total tests: 185
- Average test time: 1.8 sec/module
- Total suite time: ~31 sec

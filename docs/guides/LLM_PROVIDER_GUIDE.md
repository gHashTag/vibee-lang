# LLM Provider Integration Guide

## Overview

Unified interface for multiple LLM providers with Context Engineering integration.

## Supported Providers

| Provider | Models | Features | Cost (1M tokens) |
|----------|--------|----------|------------------|
| **OpenAI** | GPT-4o, o1, o3 | Tools, Vision, JSON mode | $2.5-10 |
| **Anthropic** | Claude 4, 3.5 | Computer Use, Extended Thinking | $3-15 |
| **Gemini** | 2.0, 2.5 Pro | Multimodal, Grounding | $0.5-1.5 |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CONTEXT ENGINEERING                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Templates  │  │  Variables  │  │  Iteration  │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
│         └────────────────┼────────────────┘                 │
│                          ▼                                  │
│              ┌───────────────────────┐                      │
│              │   LLM CONTEXT BRIDGE  │                      │
│              └───────────┬───────────┘                      │
└──────────────────────────┼──────────────────────────────────┘
                           ▼
┌──────────────────────────────────────────────────────────────┐
│                    LLM PROVIDER CORE                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │  OpenAI  │  │Anthropic │  │  Gemini  │  │ Fallback │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
└──────────────────────────────────────────────────────────────┘
```

## Modules

### llm_provider_core.vibee
Core interface for all providers:
- Unified request/response types
- Credential validation
- Rate limit handling
- Cost estimation

### llm_provider_openai.vibee
OpenAI-specific implementation:
- Chat completions
- Tool calling
- Embeddings
- Streaming

### llm_provider_anthropic.vibee
Anthropic-specific implementation:
- Messages API
- Computer Use tools
- Extended thinking
- Content blocks

### llm_provider_gemini.vibee
Google Gemini implementation:
- Generate content
- Multimodal (image, audio, video)
- Grounding with search
- Function calling

### llm_context_bridge.vibee
Bridge between Context Engineering and LLM:
- Context to prompt compilation
- Provider selection
- A/B testing execution
- Cost tracking

## Usage Flow

```
1. Define context template
   └─> context_templates.vibee

2. Set runtime variables
   └─> context_variables.vibee

3. Compile to prompt
   └─> llm_context_bridge.compile_context_to_prompt()

4. Execute with provider
   └─> llm_context_bridge.execute_with_provider()

5. Collect feedback
   └─> llm_context_bridge.collect_iteration_feedback()

6. Iterate
   └─> context_iteration.vibee
```

## Provider Selection

```
Task Requirements → select_provider_for_task() → Optimal Provider

Factors:
- Cost budget
- Latency requirements
- Required capabilities (vision, tools, etc.)
- Context window needs
```

## Fallback Chain

```
Primary (Anthropic) → Fallback 1 (OpenAI) → Fallback 2 (Gemini)
         ↓                    ↓                    ↓
      Timeout?            Rate limit?          Success!
```

## Cost Tracking

```zig
const tracker = CostTracker{
    .budget_limit_usd = 100.0,
    .total_cost_usd = 0.0,
};

// After each execution
track_costs(execution_result);

// Check budget
if (tracker.total_cost_usd > tracker.budget_limit_usd * 0.8) {
    // Switch to cheaper provider
}
```

## Generated Modules

| Module | Tests | Description |
|--------|-------|-------------|
| `llm_provider_core.zig` | 9 | Core interface |
| `llm_provider_openai.zig` | 9 | OpenAI implementation |
| `llm_provider_anthropic.zig` | 9 | Anthropic implementation |
| `llm_provider_gemini.zig` | 9 | Gemini implementation |
| `llm_context_bridge.zig` | 9 | Context bridge |

## Environment Variables

```bash
# OpenAI
export OPENAI_API_KEY="sk-..."

# Anthropic
export ANTHROPIC_API_KEY="sk-ant-..."

# Gemini
export GOOGLE_API_KEY="..."
```

---
*VIBEE LLM Provider Integration v1.0 | φ² + 1/φ² = 3*

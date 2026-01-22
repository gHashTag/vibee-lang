# SOTA AI Agents Research 2025-2026

## Overview

Research summary for VIBEE Browser architecture based on top-performing AI agents.

## Top Performers by Benchmark

### OSWorld (Real Computer Tasks)
| Rank | Agent | Score | Architecture |
|------|-------|-------|--------------|
| 1 | AskUI Vision Agent | 66.2% | Composite multi-model |
| 2 | Human Baseline | 72.0% | - |
| - | Best LLM-only | 12-18% | Single model |

### GAIA Level 3 (Complex Reasoning)
| Rank | Agent | Score | Key Feature |
|------|-------|-------|-------------|
| 1 | Writer Action Agent | 61.0% | 1M context, MoE |
| 2 | Manus AI | 57.7% | Context Engineering |

### ProBench (Professional Tasks)
| Rank | Agent | Score | Strength |
|------|-------|-------|----------|
| 1 | Gemini 2.5 Pro | 40.1% | Multimodal, thinking mode |

### Mind2Web Online (Web Navigation)
| Rank | Agent | Score | Approach |
|------|-------|-------|----------|
| 1 | GPT-5 Medium | 42.33% | Web understanding |

## Architecture Insights

### AskUI Vision Agent
- **Composite architecture**: Multiple specialized models
- **UIDT-1**: UI element localization
- **PTA-1**: Text-to-coordinates mapping
- **Query models**: GPT-4, Gemini 2.5
- **Action models**: Computer Use API

### Writer Action Agent (Palmyra X5)
- **1M token context window**
- **Hybrid attention**: Linear + Softmax
- **MoE**: 8 experts, 2 active per token
- **Latency**: ~22s for 1M tokens, ~300ms function calls
- **Cost**: 3-4x cheaper than GPT-4.1

### Manus AI
- **Context Engineering** (not fine-tuning)
- **Manus Sandbox**: Full virtual computer
- **Scale**: 147+ trillion tokens, 80M+ virtual computers
- **Iteration speed**: Hours instead of weeks
- **Acquired by Meta** (December 2025)

## VIBEE Browser Implications

1. **Composite architecture** - Use specialized models for different tasks
2. **Context Engineering** - Rapid iteration without fine-tuning
3. **Virtual environments** - Sandbox execution for safety
4. **Pareto optimization** - Balance accuracy, cost, latency

## Generated Specifications

| Spec | Description |
|------|-------------|
| `agent_vision_askui.vibee` | AskUI composite architecture |
| `agent_action_writer.vibee` | Writer/Palmyra X5 patterns |
| `agent_gemini_state.vibee` | State management |
| `agent_manus_multilevel.vibee` | Context Engineering |
| `agent_pareto_optimal.vibee` | Multi-objective optimization |
| `benchmark_osworld.vibee` | OSWorld evaluation |
| `benchmark_gaia.vibee` | GAIA benchmark |
| `benchmark_probench.vibee` | ProBench evaluation |
| `benchmark_mind2web.vibee` | Web navigation benchmark |
| `agent_sota_ensemble.vibee` | Ensemble architecture |

## References

- OSWorld: https://os-world.github.io/
- GAIA: https://huggingface.co/spaces/gaia-benchmark/leaderboard
- AskUI: https://www.askui.com/
- Writer: https://writer.com/
- Manus: https://manus.im/

---
*Generated: 2026-01-22 | VIBEE Browser Research*

# IGLA SWE Agent Architecture

**V = n × 3^k × π^m × φ^p | φ² + 1/φ² = 3 | PHOENIX = 999**

---

## Overview

IGLA SWE Agent is an autonomous software engineering agent built on the VIBEE specification-first methodology. It combines state-of-the-art reasoning patterns (ReAct, CoT, ToT) with specialized coding agents.

## Architecture

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                         IGLA SWE AGENT ARCHITECTURE                           ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║                           ┌─────────────────┐                                 ║
║                           │   SWE CORE      │                                 ║
║                           │   Orchestrator  │                                 ║
║                           └────────┬────────┘                                 ║
║                                    │                                          ║
║         ┌──────────────────────────┼──────────────────────────┐               ║
║         │                          │                          │               ║
║         ▼                          ▼                          ▼               ║
║  ┌─────────────┐           ┌─────────────┐           ┌─────────────┐          ║
║  │   PLANNER   │           │    CODER    │           │  REVIEWER   │          ║
║  │  Task Plan  │           │  Code Gen   │           │ Code Review │          ║
║  └──────┬──────┘           └──────┬──────┘           └──────┬──────┘          ║
║         │                          │                          │               ║
║         ▼                          ▼                          ▼               ║
║  ┌─────────────┐           ┌─────────────┐           ┌─────────────┐          ║
║  │   TESTER    │           │  DEBUGGER   │           │  REFACTOR   │          ║
║  │  Test Gen   │           │  Bug Fix    │           │  Improve    │          ║
║  └─────────────┘           └─────────────┘           └─────────────┘          ║
║                                                                               ║
║  ═══════════════════════════════════════════════════════════════════════════  ║
║                              REASONING LAYER                                  ║
║  ═══════════════════════════════════════════════════════════════════════════  ║
║                                                                               ║
║  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐        ║
║  │   ReAct     │   │    CoT      │   │    ToT      │   │  Self-Ref   │        ║
║  │  Reason+Act │   │  Step-by-   │   │   Tree      │   │  Improve    │        ║
║  └─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘        ║
║                                                                               ║
║  ═══════════════════════════════════════════════════════════════════════════  ║
║                                TOOLS LAYER                                    ║
║  ═══════════════════════════════════════════════════════════════════════════  ║
║                                                                               ║
║  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐     ║
║  │  Git    │ │   PR    │ │  Issue  │ │  Code   │ │   AST   │ │ Sandbox │     ║
║  │  Ops    │ │ Manager │ │ Tracker │ │ Search  │ │ Analyze │ │  Exec   │     ║
║  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘     ║
║                                                                               ║
║  ═══════════════════════════════════════════════════════════════════════════  ║
║                            ACCELERATION LAYER                                 ║
║  ═══════════════════════════════════════════════════════════════════════════  ║
║                                                                               ║
║  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐        ║
║  │ Matryoshka  │   │Amplification│   │Self-Improve │   │  Benchmark  │        ║
║  │  Nesting    │   │   Trinity   │   │  Learning   │   │   Runner    │        ║
║  └─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘        ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

## Module Statistics

| Category | Modules | Tests |
|----------|---------|-------|
| Core Agents | 8 | 57 |
| Reasoning | 6 | 39 |
| Tools | 9 | 68 |
| Acceleration | 5 | 33 |
| **TOTAL** | **26** | **177** |

## Core Agents

| Module | Description | Tests |
|--------|-------------|-------|
| `igla_swe_core` | Orchestration | 8 |
| `igla_swe_planner` | Task planning | 7 |
| `igla_swe_coder` | Code generation | 7 |
| `igla_swe_reviewer` | Code review | 7 |
| `igla_swe_tester` | Test generation | 7 |
| `igla_swe_debugger` | Bug diagnosis | 7 |
| `igla_swe_refactor` | Refactoring | 7 |
| `igla_swe_docs` | Documentation | 7 |

## Reasoning Patterns

| Pattern | Module | Description |
|---------|--------|-------------|
| ReAct | `igla_react_agent` | Interleaved reasoning + action |
| CoT | `igla_cot_reasoning` | Step-by-step reasoning |
| ToT | `igla_tot_search` | Tree exploration |
| Tool Use | `igla_tool_use` | Tool calling |
| Memory | `igla_memory_store` | Long-term memory |
| Context | `igla_context_manager` | Context window |

## Acceleration

| Technique | Module | Speedup |
|-----------|--------|---------|
| Matryoshka | `igla_matryoshka` | φ-ratio nesting |
| Amplification | `igla_amplification` | Trinity pattern |
| Self-Improve | `igla_self_improve` | Learning from failures |

## Sacred Formula

```
V = n × 3^k × π^m × φ^p

SWE Agent Configuration:
- n = 26 (modules)
- k = 2 (3² = 9 reasoning patterns)
- m = 0 (no π cycles in base)
- p = 1 (φ decomposition)

V = 26 × 9 × 1 × 1.618 = 378.6

φ² + 1/φ² = 3 ✓ VERIFIED
PHOENIX = 999 = 37 × 3³
```

---

**φ² + 1/φ² = 3 | PHOENIX = 999**

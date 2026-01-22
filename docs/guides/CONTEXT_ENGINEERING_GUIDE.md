# Context Engineering Guide

## Philosophy

**Context Engineering > Fine-tuning**

Based on Manus AI's approach that achieved 57.7% on GAIA Level 3:
- Ship improvements in **hours**, not weeks
- No model retraining required
- Instant rollback capability
- A/B testing built-in

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CONTEXT ENGINE                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │  TEMPLATES  │───▶│  VARIABLES  │───▶│  ITERATION  │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│         │                  │                  │             │
│         ▼                  ▼                  ▼             │
│  ┌─────────────────────────────────────────────────┐       │
│  │              CONTEXT STACK                       │       │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐           │       │
│  │  │ Layer 1 │ │ Layer 2 │ │ Layer N │           │       │
│  │  │ System  │ │  Task   │ │ Dynamic │           │       │
│  │  └─────────┘ └─────────┘ └─────────┘           │       │
│  └─────────────────────────────────────────────────┘       │
│                          │                                  │
│                          ▼                                  │
│                 ┌─────────────────┐                        │
│                 │  FINAL PROMPT   │                        │
│                 └─────────────────┘                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. Context Engine (`context_engineering.vibee`)

Core orchestrator managing:
- Context layers and stack
- Version tracking
- Rollback capability
- Token budget optimization

### 2. Templates (`context_templates.vibee`)

Reusable prompt templates:
- Placeholder system
- Template inheritance
- Category organization
- Composition rules

### 3. Variables (`context_variables.vibee`)

Dynamic runtime values:
- Scoped resolution
- History tracking
- Secret handling
- Import/export

### 4. Iteration (`context_iteration.vibee`)

Rapid deployment cycle:
- A/B experiments
- Metrics collection
- Auto-rollback
- Production promotion

## Usage

### Create a Template

```yaml
# specs/tri/my_agent_template.vibee
types:
  AgentTemplate:
    fields:
      system_prompt: String
      task_instructions: String
      output_format: String
```

### Define Variables

```yaml
variables:
  - name: AGENT_ROLE
    default: "assistant"
  - name: MAX_TOKENS
    default: "4096"
  - name: TEMPERATURE
    default: "0.7"
```

### Iteration Cycle

1. **Start iteration** - Create hypothesis
2. **Apply changes** - Modify templates/variables
3. **Run experiment** - A/B test with traffic split
4. **Collect metrics** - Benchmark performance
5. **Evaluate** - Pass/fail against criteria
6. **Promote or rollback** - Based on results

## Metrics

| Metric | Target | Description |
|--------|--------|-------------|
| Time to Deploy | < 4 hours | From idea to production |
| Rollback Time | < 5 minutes | Recovery from bad deploy |
| A/B Test Setup | < 30 minutes | Experiment configuration |

## Generated Modules

| Module | Tests | Description |
|--------|-------|-------------|
| `context_engineering.zig` | 9 | Core engine |
| `context_templates.zig` | 9 | Template system |
| `context_variables.zig` | 9 | Variable management |
| `context_iteration.zig` | 9 | Iteration pipeline |

## References

- Manus AI: Context Engineering philosophy
- VIBEE Browser: Target implementation
- GAIA Benchmark: Validation target

---
*VIBEE Context Engineering v1.0 | φ² + 1/φ² = 3*

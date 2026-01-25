# MVP ROADMAP

## Goal

Execute one WebArena task end-to-end using VIBEE-generated code.

## Current State

- ✅ 15 bottleneck specs created
- ✅ 3 MVP specs created
- ✅ All .zig files generated
- ✅ All tests passing
- ⚠️ JS runtime exists but not connected to Zig

## Phase 1: Bridge (Week 1)

1. Implement `bottleneck_node_bridge.zig` with real N-API bindings
2. Create npm package wrapping Zig native module
3. Test JSON parsing performance vs JS

## Phase 2: Integration (Week 2)

1. Replace `JSON.parse` in agent.js with Zig parser
2. Measure latency improvement
3. Add metrics collection

## Phase 3: Single Task (Week 3)

1. Run one WebArena task
2. Capture execution trace
3. Validate answer

## Phase 4: Benchmark (Week 4)

1. Run full WebArena benchmark
2. Compare with baseline
3. Document results

## Success Criteria

| Metric | Target |
|--------|--------|
| Single task completion | ✅ Pass |
| JSON parse speedup | 5x vs JS |
| E2E latency | <100ms per step |
| WebArena score | >0% (any task) |

## Files

```
specs/tri/
├── bottleneck_*.vibee  # 12 specs
└── mvp_*.vibee         # 3 specs

trinity/output/
├── bottleneck_*.zig    # 12 generated
└── mvp_*.zig           # 3 generated
```

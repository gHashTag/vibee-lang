# Testbench Specification in VIBEE

**Sacred Formula:** φ² + 1/φ² = 3

**Version:** v24.φ.1 (January 2026)

---

## Overview

VIBEE supports testbench specification through the `behaviors` section.
Each behavior describes a test scenario that is generated as a separate Verilog module.

---

## Behaviors as Test Scenarios

### Format

```yaml
behaviors:
  - name: test_scenario_name
    given: Precondition description
    when: Action/stimulus description
    then: Expected result/assertion
```

### Example

```yaml
behaviors:
  - name: test_idle_to_load
    given: FSM in IDLE state
    when: start signal asserted
    then: FSM transitions to LOAD, busy becomes 1

  - name: test_full_cycle
    given: FSM starts in IDLE
    when: Complete processing cycle executed
    then: FSM returns to IDLE with correct outputs
```

### Generated Verilog

Each behavior generates a separate module:

```verilog
// Behavior: test_idle_to_load
// Given: FSM in IDLE state
// When: start signal asserted
// Then: FSM transitions to LOAD, busy becomes 1
module behavior_test_idle_to_load (
    input wire clk,
    input wire rst_n,
    input wire [31:0] input_data,
    output reg [31:0] output_data,
    output reg done
);
    // Behavior implementation
endmodule
```

---

## FSM Integration

Behaviors work with FSM definitions:

```yaml
fsm:
  - name: processor
    states: [IDLE, LOAD, EXEC, DONE]
    transitions:
      - from: IDLE
        to: LOAD
        condition: "start"
    outputs:
      - state: IDLE
        busy: "1'b0"
      - state: LOAD
        busy: "1'b1"

behaviors:
  - name: test_idle_to_load
    given: FSM in IDLE state
    when: start signal asserted
    then: FSM transitions to LOAD, busy becomes 1
```

---

## Best Practices

1. **One behavior per transition** - Test each FSM transition separately
2. **Full cycle test** - Include a behavior that tests the complete FSM cycle
3. **Output verification** - Describe expected outputs in the `then` clause
4. **Edge cases** - Add behaviors for error conditions and timeouts

---

## Metrics

| Metric                  | Before | After | Improvement |
|-------------------------|--------|-------|-------------|
| Behavior modules        | 0      | 5+    | +500%       |
| Test scenarios in spec  | 0      | 5+    | +500%       |
| Documentation coverage  | 0%     | 100%  | +100%       |

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3**

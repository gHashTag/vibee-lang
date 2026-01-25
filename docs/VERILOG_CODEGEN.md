# VIBEE Verilog Code Generator

Generate synthesizable Verilog from `.vibee` specifications.

## Usage

```bash
# Create spec with language: verilog
./bin/vibee gen specs/tri/my_module.vibee
# Output: trinity/output/fpga/my_module.v
```

## Specification Format

```yaml
name: my_counter
version: "1.0.0"
language: verilog
module: my_counter

types:
  CounterConfig:
    fields:
      width: Int
      max_value: Int

behaviors:
  - name: increment
    given: Counter running
    when: Clock rising edge
    then: Increment count
```

## Generated Output

- Sacred constants module (φ, φ², trinity)
- Type definitions as Verilog comments
- Top module with FSM
- Behavior modules
- Testbench

## Validation

```bash
verilator --lint-only --top-module my_counter_top trinity/output/fpga/my_counter.v
```

## Metrics

- Generation time: ~1ms
- Expansion ratio: ~7x (spec lines → Verilog lines)
- Lint: passes Verilator

φ² + 1/φ² = 3

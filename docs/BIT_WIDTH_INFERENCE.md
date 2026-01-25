# Bit-Width Inference in VIBEE

**Sacred Formula:** φ² + 1/φ² = 3

**Version:** v24.φ (January 2026)

---

## Overview

VIBEE supports automatic bit-width inference for HDL signals from:
1. Verilog literals (`sig == 8'hFF` → 8 bits)
2. Bidirectional comparisons (`8'hFF == sig` → 8 bits)
3. Bit slices (`data[7:0]` → 8 bits minimum)
4. FSM output values (`result: "8'hAA"` → 8 bits)

---

## Automatic Width Inference

### From Verilog Literals

```yaml
transitions:
  - from: IDLE
    to: CHECK
    condition: "mode == 2'b00"      # mode → 2 bits
  - from: CHECK
    to: DONE
    condition: "count == 8'hFF"     # count → 8 bits
```

### Bidirectional (Both Sides)

```yaml
transitions:
  - condition: "16'd1234 == addr"   # addr → 16 bits
```

### From Bit Slices

```yaml
transitions:
  - condition: "data[7:0] == 8'hFF"   # data → 8 bits minimum
  - condition: "status[31:16] == 0"   # status → 32 bits minimum
```

### From FSM Outputs

```yaml
outputs:
  - state: DONE
    result: "8'hFF"    # result → 8 bits
    status: "4'b1111"  # status → 4 bits
```

---

## Signal Width Specification

### In .vibee Specs

```yaml
signals:
  # 8-bit counter
  - name: count_8bit
    width: 8
    direction: output
    signed: false
    
  # 16-bit address bus
  - name: mem_addr
    width: 16
    direction: output
    
  # 32-bit data bus
  - name: data_bus
    width: 32
    direction: input
    
  # 64-bit AXI data
  - name: axi_tdata
    width: 64
    direction: input
```

### Generated Verilog

```verilog
output wire [7:0] count_8bit;
output wire [15:0] mem_addr;
input wire [31:0] data_bus;
input wire [63:0] axi_tdata;
```

---

## Type Width Specification

### In .vibee Specs

```yaml
types:
  Counter8:
    description: "8-bit counter"
    fields:
      value: Int
      overflow: Bool
    width: 8
    
  DataReg32:
    description: "32-bit register"
    fields:
      data: Int
      valid: Bool
    width: 32
```

---

## Constants for Width Parameters

```yaml
constants:
  COUNTER_WIDTH: 8
  DATA_WIDTH: 32
  ADDR_WIDTH: 16
  AXI_DATA_WIDTH: 64
```

---

## Supported Widths

| Width | Verilog | Use Case |
|-------|---------|----------|
| 1 | `wire` | Single bit signals |
| 8 | `[7:0]` | Byte data, small counters |
| 16 | `[15:0]` | Addresses, medium counters |
| 32 | `[31:0]` | Standard data bus |
| 64 | `[63:0]` | AXI data, large values |

---

## E2E Pipeline

```
.vibee spec → vibee gen → .v file → iverilog → simulation → VCD
```

### Example

```bash
# Generate Verilog
./bin/vibee gen specs/tri/counter_fpga.vibee

# Compile
iverilog -o sim trinity/output/fpga/counter_fpga.v

# Simulate
vvp sim

# View waveforms
gtkwave counter_fpga.vcd
```

---

## Benchmark Results

| Metric | Without Width | With Width |
|--------|---------------|------------|
| 8-bit signals | 0 | 4 |
| 16-bit signals | 0 | 4 |
| 32-bit signals | 22 | 20 |
| 64-bit signals | 7 | 15 |

---

## Best Practices

1. **Always specify width** for signals in HDL modules
2. **Use constants** for parameterized widths
3. **Match AXI standards** (64-bit data, 32-bit address)
4. **Minimize bit width** for FPGA resource optimization

---

## FSM Auto-Signal Extraction

**NEW:** The VIBEE generator automatically extracts signals from FSM transition conditions!

### How It Works

FSM transitions like:
```yaml
transitions:
  - from: IDLE
    to: RUNNING
    when: "start && mode == 2'b00"
```

The generator automatically:
1. Parses the condition expression
2. Extracts identifiers (`start`, `mode`)
3. Filters out Verilog literals (`2'b00`, `8'hFF`)
4. Filters out FSM state names (`IDLE`, `DONE`)
5. Filters out already-declared signals
6. Generates `input wire` declarations

### Generated Verilog

```verilog
input  wire        start,  // Auto-extracted from FSM
input  wire        mode,   // Auto-extracted from FSM
input  wire        xfer_done,  // Auto-extracted from FSM
```

### No Manual Declaration Needed

```yaml
signals:
  # NOTE: FSM control signals (start, mode, xfer_done) are AUTO-EXTRACTED
  # from transition conditions - no need to declare them manually!
  
  - name: clk
    width: 1
    direction: input
```

### Automatic Width Inference from Verilog Literals

**NEW:** The generator now automatically infers signal widths from Verilog literals in conditions!

```yaml
transitions:
  - from: IDLE
    to: MODE_CHECK
    condition: "mode == 2'b00"      # mode inferred as 2-bit
  - from: MODE_CHECK
    to: COUNT_CHECK
    condition: "count == 8'hFF"     # count inferred as 8-bit
  - from: COUNT_CHECK
    to: DONE
    condition: "addr == 16'd1234"   # addr inferred as 16-bit
```

**Generated Verilog:**
```verilog
input  wire [1:0] mode,   // Auto-extracted from FSM (width inferred)
input  wire [7:0] count,  // Auto-extracted from FSM (width inferred)
input  wire [15:0] addr,  // Auto-extracted from FSM (width inferred)
```

### Supported Literal Formats

| Format | Example | Inferred Width |
|--------|---------|----------------|
| Binary | `4'b1010` | 4 bits |
| Hex | `12'hABC` | 12 bits |
| Decimal | `24'd123456` | 24 bits |
| Octal | `6'o77` | 6 bits |

### Limitations

- Signals without literals default to 1-bit
- Output signals must still be declared manually
- Width is inferred from comparison operators (`==`, `!=`, `<`, `>`, `<=`, `>=`)

### Common FSM Signals

| Signal | Width | Direction | Auto-Extracted |
|--------|-------|-----------|----------------|
| `start` | 1 | input | ✅ Yes (default) |
| `mode == 2'b00` | 2 | input | ✅ Yes (inferred) |
| `count == 8'hFF` | 8 | input | ✅ Yes (inferred) |
| `done` | 1 | output | ❌ No (declare manually) |

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3**

# FPGA DEPLOYMENT GUIDE - VIBEE to Arty A7

**Sacred Formula:** `V = n × 3^k × π^m × φ^p × e^q`  
**Golden Identity:** `φ² + 1/φ² = 3`  
**Target:** Digilent Arty A7-35T

---

## Overview

This guide covers deploying VIBEE-generated Verilog to real FPGA hardware.

**Pipeline:**
```
.vibee spec → vibeec gen → .v (Verilog) → Vivado → bitstream → FPGA
```

---

## Hardware Requirements

### Recommended Board: Digilent Arty A7-35T

| Specification | Value |
|---------------|-------|
| FPGA | Xilinx Artix-7 XC7A35TICSG324-1L |
| LUTs | 33,280 |
| Flip-Flops | 41,600 |
| Block RAM | 50 × 36Kb (225 KB) |
| DSP Slices | 90 |
| Clock | 100 MHz oscillator |
| LEDs | 4 green, 4 RGB |
| Buttons | 4 |
| Switches | 4 |
| USB-JTAG | Built-in |
| Price | ~$150 USD |

**Purchase Links:**
- [Digilent Store](https://digilent.com/shop/arty-a7-artix-7-fpga-development-board/)
- [Amazon](https://www.amazon.com/dp/B07B9RXMG4)
- [Mouser](https://www.mouser.com/ProductDetail/Digilent/410-319)

### Alternative Boards

| Board | FPGA | LUTs | Price | Notes |
|-------|------|------|-------|-------|
| Arty A7-100T | XC7A100T | 63,400 | ~$250 | More resources |
| Basys 3 | XC7A35T | 33,280 | ~$150 | Academic focused |
| Nexys A7 | XC7A100T | 63,400 | ~$300 | More I/O |
| Cmod A7 | XC7A35T | 33,280 | ~$90 | Breadboard form |

---

## Software Requirements

### Xilinx Vivado ML Standard (Free)

1. **Download:** [Xilinx Downloads](https://www.xilinx.com/support/download.html)
2. **Version:** 2023.2 or later
3. **Edition:** ML Standard (free, supports Artix-7)
4. **Size:** ~50 GB installed

**Installation Steps:**
```bash
# Linux
chmod +x Xilinx_Unified_*_Lin64.bin
./Xilinx_Unified_*_Lin64.bin

# Select: Vivado ML Standard
# Select: Artix-7 device support only (saves space)
```

### Digilent Board Files

```bash
# Clone board files
git clone https://github.com/Digilent/vivado-boards.git

# Copy to Vivado installation
cp -r vivado-boards/new/board_files/* \
  /tools/Xilinx/Vivado/2023.2/data/boards/board_files/
```

---

## Quick Start

### Step 1: Generate Verilog

```bash
cd /workspaces/vibee-lang

# Generate from .vibee specification
./bin/vibeec gen specs/fpga/hello_fpga_led.vibee

# Output:
#   trinity/output/fpga/hello_fpga_led.v
```

### Step 2: Verify with Simulation

```bash
cd trinity/output/fpga

# Icarus Verilog simulation
iverilog -o test hello_fpga_led.v
vvp test

# Expected output:
# ═══════════════════════════════════════════════════════════════
# hello_fpga_led Testbench - φ² + 1/φ² = 3
# ═══════════════════════════════════════════════════════════════
# Test 1: Basic operation
#   PASS: Output valid=0, data = 1234559f
# Golden Identity: φ² + 1/φ² = 3 ✓
# PHOENIX = 999 ✓
```

### Step 3: Create Vivado Project

```bash
# Launch Vivado
vivado &

# Or use TCL script
vivado -mode batch -source scripts/create_project.tcl
```

### Step 4: Synthesize and Implement

```bash
# Using TCL script
vivado -mode batch -source scripts/build_bitstream.tcl

# Or in GUI:
# 1. Run Synthesis
# 2. Run Implementation
# 3. Generate Bitstream
```

### Step 5: Program FPGA

```bash
# Connect Arty A7 via USB
# In Vivado:
# 1. Open Hardware Manager
# 2. Auto Connect
# 3. Program Device
# 4. Select .bit file
```

---

## Project Structure

```
vibee-lang/
├── specs/fpga/
│   ├── hello_fpga_led.vibee      # LED blinker spec
│   └── trinity_fpga_mvp.vibee    # Trinity MVP spec
│
├── trinity/output/fpga/
│   ├── hello_fpga_led.v          # Generated Verilog
│   ├── constraints/
│   │   └── arty_a7.xdc           # Pin constraints
│   └── scripts/
│       ├── create_project.tcl    # Project creation
│       └── build_bitstream.tcl   # Build automation
│
└── docs/
    └── FPGA_DEPLOYMENT_GUIDE.md  # This file
```

---

## Pin Assignments (Arty A7-35T)

### Clock and Reset

| Signal | Pin | Description |
|--------|-----|-------------|
| clk | E3 | 100 MHz oscillator |
| rst_n | C2 | BTN0 (active low) |

### LEDs

| Signal | Pin | Description |
|--------|-----|-------------|
| led[0] | H5 | LD4 (green) |
| led[1] | J5 | LD5 (green) |
| led[2] | T9 | LD6 (green) |
| led[3] | T10 | LD7 (green) |

### RGB LEDs

| Signal | Pin | Description |
|--------|-----|-------------|
| led0_r | G6 | LD0 Red |
| led0_g | F6 | LD0 Green |
| led0_b | E1 | LD0 Blue |

### Buttons

| Signal | Pin | Description |
|--------|-----|-------------|
| btn[0] | D9 | BTN0 |
| btn[1] | C9 | BTN1 |
| btn[2] | B9 | BTN2 |
| btn[3] | B8 | BTN3 |

### Switches

| Signal | Pin | Description |
|--------|-----|-------------|
| sw[0] | A8 | SW0 |
| sw[1] | C11 | SW1 |
| sw[2] | C10 | SW2 |
| sw[3] | A10 | SW3 |

---

## Expected Results

### Hello FPGA LED

After programming:
- All 4 green LEDs blink at 1 Hz (500ms on, 500ms off)
- Synchronized blinking demonstrates clock domain working
- Reset button (BTN0) resets the counter

### Resource Utilization (Estimated)

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| LUTs | ~50 | 33,280 | <1% |
| FFs | ~30 | 41,600 | <1% |
| BRAM | 0 | 50 | 0% |
| DSP | 0 | 90 | 0% |

### Timing

| Metric | Value |
|--------|-------|
| Target Clock | 100 MHz |
| Achieved Fmax | >200 MHz |
| Setup Slack | >5 ns |
| Hold Slack | >0 ns |

---

## Troubleshooting

### "No hardware target found"

1. Check USB cable connection
2. Install Digilent drivers: `sudo apt install libftdi1-2`
3. Add udev rules:
   ```bash
   echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="0403", MODE="0666"' | \
     sudo tee /etc/udev/rules.d/52-digilent.rules
   sudo udevadm control --reload-rules
   ```

### "Timing not met"

1. Check clock constraint in XDC file
2. Reduce target frequency
3. Add pipeline stages

### "Bitstream generation failed"

1. Check for unconnected ports
2. Verify all signals have drivers
3. Check for combinational loops

---

## Advanced: Trinity FPGA MVP

For the full Trinity OS on FPGA:

```bash
# Generate
./bin/vibeec gen specs/fpga/trinity_fpga_mvp.vibee

# Expected resources:
# - LUTs: ~500
# - FFs: ~300
# - BRAM: 0
# - Fmax: >100 MHz
```

---

## References

- [Arty A7 Reference Manual](https://digilent.com/reference/programmable-logic/arty-a7/reference-manual)
- [Vivado Design Suite User Guide](https://docs.xilinx.com/r/en-US/ug910-vivado-getting-started)
- [Artix-7 Data Sheet](https://docs.xilinx.com/v/u/en-US/ds181_Artix_7_Data_Sheet)

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3**

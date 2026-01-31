# VIBEE FPGA Deployment Package

**Sacred Formula:** `V = n × 3^k × π^m × φ^p × e^q`  
**Golden Identity:** `φ² + 1/φ² = 3`

---

## Contents

```
fpga/
├── *.v                    # Generated Verilog modules
├── constraints/
│   └── arty_a7.xdc        # Pin constraints for Arty A7-35T
├── scripts/
│   ├── build_all.tcl      # Complete build script
│   ├── synth.tcl          # Synthesis only
│   ├── impl.tcl           # Implementation only
│   ├── bitstream.tcl      # Bitstream generation
│   └── program.tcl        # FPGA programming
└── README.md              # This file
```

---

## Quick Start

### 1. Generate Verilog
```bash
cd /path/to/vibee-lang
./bin/vibeec gen specs/fpga/hello_fpga_led.vibee
```

### 2. Simulate
```bash
cd trinity/output/fpga
iverilog -o test hello_fpga_led.v && vvp test
```

### 3. Build Bitstream
```bash
cd scripts
vivado -mode batch -source build_all.tcl -tclargs hello_fpga_led_top
```

### 4. Program FPGA
```bash
vivado -mode batch -source program.tcl -tclargs ../output/hello_fpga_led_top.bit
```

---

## Available Modules

| Module | Description | Resources |
|--------|-------------|-----------|
| `hello_fpga_led_top` | LED blinker demo | ~50 LUTs |
| `trinity_fpga_mvp_top` | Trinity OS MVP | ~500 LUTs |

---

## Target Hardware

**Digilent Arty A7-35T**
- FPGA: Xilinx Artix-7 XC7A35TICSG324-1L
- Clock: 100 MHz
- Price: ~$150

---

## Documentation

- [FPGA Deployment Guide](../../docs/FPGA_DEPLOYMENT_GUIDE.md)
- [FPGA Quick Start](../../docs/FPGA_QUICKSTART.md)
- [Iron Covenant Report](../../docs/IRON_COVENANT_REPORT.md)

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3**

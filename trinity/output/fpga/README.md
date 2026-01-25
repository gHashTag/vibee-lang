# VIBEE BitNet FPGA Accelerator

**Sacred Formula:** V = n × 3^k × π^m × φ^p × e^q  
**Golden Identity:** φ² + 1/φ² = 3 | PHOENIX = 999

---

## Overview

This directory contains the complete FPGA implementation of the VIBEE BitNet b1.58 accelerator, targeting Xilinx Zynq UltraScale+ (ZCU104) and Virtex UltraScale+ (VCU118) devices.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         BITNET FPGA ACCELERATOR                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                     │
│  │  AXI-Lite   │    │ AXI-Stream  │    │ AXI-Stream  │                     │
│  │  Control    │    │   Input     │    │   Output    │                     │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘                     │
│         │                  │                  │                             │
│         └──────────────────┼──────────────────┘                             │
│                            │                                                │
│                   ┌────────┴────────┐                                       │
│                   │  BitNet Engine  │                                       │
│                   │  ┌───────────┐  │                                       │
│                   │  │ SIMD ×16  │  │                                       │
│                   │  └───────────┘  │                                       │
│                   │  ┌───────────┐  │                                       │
│                   │  │Weight BRAM│  │                                       │
│                   │  └───────────┘  │                                       │
│                   └─────────────────┘                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Xilinx Vivado 2023.2 or later
- Target board: ZCU104 or VCU118
- Linux or Windows with Vivado installed

### Build Steps (Standalone PL)

```bash
# Navigate to FPGA directory
cd trinity/output/fpga

# Create Vivado project
make create

# Run synthesis
make synth

# Run implementation (place & route)
make impl

# Generate bitstream
make bitstream

# Or run full flow
make all
```

### Build Steps (Zynq PS-PL Integration)

```bash
# Полный flow для ZCU104 с Zynq PS
make zynq

# Или пошагово:
make bd      # Создание Block Design
make synth   # Синтез
make impl    # Имплементация
make xsa     # Экспорт XSA для Vitis/PetaLinux
```

## Zynq Block Design Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ZYNQ ULTRASCALE+ (ZCU104)                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    PROCESSING SYSTEM (PS)                           │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │   │
│  │  │ ARM A53 ×4  │  │   DDR4      │  │   UART      │  │   SD      │  │   │
│  │  │ @ 1.2 GHz   │  │   2 GB      │  │   Console   │  │   Boot    │  │   │
│  │  └──────┬──────┘  └──────┬──────┘  └─────────────┘  └───────────┘  │   │
│  │         │                │                                          │   │
│  │  ┌──────┴────────────────┴──────────────────────────────────────┐  │   │
│  │  │                    AXI Interconnect                          │  │   │
│  │  └──────┬────────────────┬────────────────┬────────────────┬────┘  │   │
│  │         │                │                │                │        │   │
│  │      M_AXI_HPM0       S_AXI_HP0       S_AXI_HP1       S_AXI_HP2     │   │
│  └─────────┼────────────────┼────────────────┼────────────────┼────────┘   │
│            │                │                │                │            │
│  ══════════╪════════════════╪════════════════╪════════════════╪════════   │
│            │                │                │                │   PS-PL   │
│  ══════════╪════════════════╪════════════════╪════════════════╪════════   │
│            │                │                │                │            │
│  ┌─────────┴────────────────┴────────────────┴────────────────┴────────┐   │
│  │                    PROGRAMMABLE LOGIC (PL)                          │   │
│  │                                                                     │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │   │
│  │  │ AXI         │  │ DMA Input   │  │ DMA Output  │  │ DMA       │  │   │
│  │  │ Interconnect│  │ (MM2S)      │  │ (S2MM)      │  │ Weight    │  │   │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬─────┘  │   │
│  │         │                │                │                │        │   │
│  │         │         ┌──────┴────────────────┴────────────────┘        │   │
│  │         │         │                                                 │   │
│  │  ┌──────┴─────────┴─────────────────────────────────────────────┐  │   │
│  │  │                    BITNET ACCELERATOR                        │  │   │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │  │   │
│  │  │  │ AXI-Lite    │  │ AXI-Stream  │  │ AXI-Stream  │          │  │   │
│  │  │  │ Control     │  │ Input       │  │ Output      │          │  │   │
│  │  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │  │   │
│  │  │         │                │                │                  │  │   │
│  │  │         └────────────────┼────────────────┘                  │  │   │
│  │  │                          │                                   │  │   │
│  │  │                ┌─────────┴─────────┐                         │  │   │
│  │  │                │  SIMD Engine ×16  │                         │  │   │
│  │  │                │  Weight BRAM      │                         │  │   │
│  │  │                │  Perf Counters    │                         │  │   │
│  │  │                └───────────────────┘                         │  │   │
│  │  └──────────────────────────────────────────────────────────────┘  │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Address Map

| Peripheral | Base Address | Size | Description |
|------------|--------------|------|-------------|
| BitNet Control | 0xA000_0000 | 4 KB | Регистры управления |
| DMA Input | 0xA001_0000 | 4 KB | DMA для входных данных |
| DMA Output | 0xA002_0000 | 4 KB | DMA для выходных данных |
| DMA Weight | 0xA003_0000 | 4 KB | DMA для загрузки весов |

## Interrupts

| IRQ | Source | Description |
|-----|--------|-------------|
| IRQ[0] | BitNet | Inference complete |
| IRQ[1] | DMA Input | MM2S transfer complete |
| IRQ[2] | DMA Output | S2MM transfer complete |
| IRQ[3] | DMA Weight | Weight load complete |

### Programming the FPGA

```bash
# Connect board via JTAG
make program
```

## Directory Structure

```
fpga/
├── *.v                    # Generated Verilog modules
├── constraints/
│   ├── vibee.xdc          # VCU118 constraints
│   └── zcu104_bitnet.xdc  # ZCU104 constraints
├── scripts/
│   ├── create_project.tcl # Project creation
│   ├── synth.tcl          # Synthesis
│   ├── impl.tcl           # Implementation
│   ├── bitstream.tcl      # Bitstream generation
│   └── program.tcl        # FPGA programming
├── build/                 # Build artifacts
├── reports/               # Synthesis/impl reports
├── sim/                   # Simulation files
└── Makefile               # Build automation
```

## Key Modules

| Module | Description | LUTs | FFs |
|--------|-------------|------|-----|
| bitnet_synth_wrapper | Top-level wrapper | 500 | 300 |
| bitnet_multilayer_engine | Multi-layer inference | 12,800 | 9,600 |
| bitnet_simd_core | 27-way SIMD unit | 2,000 | 1,500 |
| axi_lite_bitnet_ctrl | Control registers | 500 | 300 |
| axi_stream_bitnet | Data streaming | 800 | 600 |
| bitnet_weight_loader | Weight loading | 400 | 300 |
| bitnet_perf_counter | Performance monitoring | 300 | 500 |

## Resource Utilization (Estimated)

### ZCU104 (xczu7ev)

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| LUTs | 15,300 | 230,400 | 6.6% |
| FFs | 11,600 | 460,800 | 2.5% |
| BRAM | 18 | 312 | 5.8% |
| DSP | 1 | 1,728 | 0.1% |

### VCU118 (xcvu9p)

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| LUTs | 15,300 | 1,182,240 | 1.3% |
| FFs | 11,600 | 2,364,480 | 0.5% |
| BRAM | 18 | 2,160 | 0.8% |
| DSP | 1 | 6,840 | 0.01% |

## Performance Targets

| Metric | ZCU104 (200MHz) | VCU118 (300MHz) |
|--------|-----------------|-----------------|
| Throughput | 66 tok/s | 100 tok/s |
| Latency | 15 ms/tok | 10 ms/tok |
| Power | ~8W | ~12W |
| Energy | 8.3 tok/J | 8.3 tok/J |

## Register Map (AXI-Lite)

| Offset | Name | R/W | Description |
|--------|------|-----|-------------|
| 0x00 | CTRL | R/W | Control (start, reset) |
| 0x04 | STATUS | R | Status (busy, done, error) |
| 0x08 | IRQ_EN | R/W | Interrupt enable |
| 0x0C | IRQ_STAT | R/W1C | Interrupt status |
| 0x10 | CONFIG0 | R/W | Layer count, neurons |
| 0x14 | CONFIG1 | R/W | Chunks, threshold |
| 0x28 | CYCLES_LO | R | Cycle count [31:0] |
| 0x2C | CYCLES_HI | R | Cycle count [63:32] |
| 0x30 | VERSION | R | IP version |

## Troubleshooting

### Timing Failures

If timing fails, try:
1. Reduce clock frequency in XDC
2. Enable retiming in synthesis settings
3. Add pblock constraints for critical modules

### Resource Overflow

If resources exceed target:
1. Reduce NUM_SIMD_CORES parameter
2. Reduce MAX_LAYERS parameter
3. Use smaller BRAM depth

## References

- BitNet b1.58: [arXiv:2402.17764](https://arxiv.org/abs/2402.17764)
- FPGA-Accelerated RISC-V: [arXiv:2511.06955](https://arxiv.org/abs/2511.06955)

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3**

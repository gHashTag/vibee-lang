# VIBEE: FPGA Hardware & HLS Technical Reference

VIBEE is a powerful High-Level Synthesis (HLS) compiler designed to close the gap between high-level software development and low-level FPGA hardware design.

## 🚀 Key Concepts

### 1. Specification-First Hardware
VIBEE uses `.vibee` behavioral specifications to describe hardware logic. This allows the compiler to understand the **intent** behind the code rather than just the implementation details.

```yaml
language: varlog
module: my_accelerator
pipeline: auto
target_frequency: 250
```

### 2. Vendor Portability (Unified Wrappers)
VIBEE abstracts away vendor-specific hardware primitives (like PLLs, DSPs, or memories). 
- **Xilinx (AMD) Target**: Instantiates MMCME2, DSP48E1, etc.
- **Intel (Altera) Target**: Instantiates ALTPLL, ALTMULT_ADD, etc.
- **Generic Target**: Uses standard behavioral Verilog.

### 3. Cycle-Accurate Reporting
Every generated Verilog file includes performance metadata in the header, estimated by the internal `LatencyAnalyzer`.
```verilog
// Latency: 6 cycles
// Target: xilinx (250 MHz)
```

### 4. Intention-based Pipelining
By specifying `pipeline: auto`, VIBEE automatically balances data paths by inserting pipeline registers to meet your `target_frequency`.

---

## 🛠️ Project Structure for Hardware Developers

| Path | Description |
|------|-------------|
| `src/vibeec/verilog_codegen.zig` | The core HLS / Verilog generation engine. |
| `specs/tri/` | Example specifications including BitNet accelerators (e.g., `bitnet_top.vibee`). |
| `trinity/output/fpga/` | The default output directory for generated `.v` and `.tb.v` files. |
| `docs/habr/` | High-level guides and performance comparisons. |

## 🧪 Quick Start for Hardware
1. **Clone**: `git clone https://github.com/gHashTag/vibee-lang`
2. **Generate**: `./bin/vibee gen-hdl specs/tri/bitnet_top.vibee`
3. **Verify**: `verilator --lint-only trinity/output/fpga/bitnet_top.v`

---

## 📈 Performance Benchmarks
VIBEE-generated BitNet accelerators achieve **8.0 token/J** on Xilinx ZCU104, outperforming traditional GPU-based inference in energy efficiency.

[View Synthesis Summary](../trinity/output/fpga/reports/SYNTHESIS_SUMMARY.md)

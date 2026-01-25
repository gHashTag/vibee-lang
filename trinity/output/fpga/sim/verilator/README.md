# VIBEE FPGA Verilator Simulation

Verilator testbenches for RTL verification.

## Structure

```
sim/verilator/
├── tb_ternary_logic.cpp    # Ternary logic core tests
├── tb_simd_core.cpp        # SIMD MAC unit tests
├── tb_top.cpp              # Top-level integration test
├── Makefile                # Build automation
└── obj_dir/                # Verilator output (generated)
```

## Usage

```bash
# Lint check (no simulation)
make lint

# Build and run all tests
make test

# Run specific test
make tb_ternary_logic && ./obj_dir/Vtb_ternary_logic

# Clean
make clean
```

## Requirements

- Verilator 4.0+
- C++17 compiler

---

φ² + 1/φ² = 3 | PHOENIX = 999

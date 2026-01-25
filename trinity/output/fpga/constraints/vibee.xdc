# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE FPGA - Timing Constraints for VCU118 (Xilinx VU9P)
# ═══════════════════════════════════════════════════════════════════════════════
# Target: 300 MHz operation (3.333 ns period)
#
# Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
# Golden Identity: φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# CLOCK DEFINITIONS
# ═══════════════════════════════════════════════════════════════════════════════

# Primary system clock - 300 MHz from VCU118 differential clock
# VCU118 has 300MHz LVDS clock on pins E12/D12
create_clock -period 3.333 -name sys_clk [get_ports clk]

# Clock uncertainty for jitter and skew
set_clock_uncertainty 0.100 [get_clocks sys_clk]

# ═══════════════════════════════════════════════════════════════════════════════
# INPUT CONSTRAINTS
# ═══════════════════════════════════════════════════════════════════════════════

# Reset signal - asynchronous, but synchronized internally
set_input_delay -clock sys_clk -max 1.0 [get_ports rst_n]
set_input_delay -clock sys_clk -min 0.5 [get_ports rst_n]

# AXI-Lite Slave Interface (Control registers)
set_input_delay -clock sys_clk -max 1.5 [get_ports s_axi_*]
set_input_delay -clock sys_clk -min 0.5 [get_ports s_axi_*]

# ═══════════════════════════════════════════════════════════════════════════════
# OUTPUT CONSTRAINTS
# ═══════════════════════════════════════════════════════════════════════════════

# AXI-Lite Slave Interface outputs
set_output_delay -clock sys_clk -max 1.5 [get_ports s_axi_*]
set_output_delay -clock sys_clk -min 0.5 [get_ports s_axi_*]

# AXI4 Master Interface (DDR memory)
set_output_delay -clock sys_clk -max 1.5 [get_ports m_axi_*]
set_output_delay -clock sys_clk -min 0.5 [get_ports m_axi_*]

# Interrupt output
set_output_delay -clock sys_clk -max 1.0 [get_ports irq]
set_output_delay -clock sys_clk -min 0.5 [get_ports irq]

# ═══════════════════════════════════════════════════════════════════════════════
# FALSE PATHS
# ═══════════════════════════════════════════════════════════════════════════════

# Reset is asynchronous - no timing path
set_false_path -from [get_ports rst_n]

# Configuration registers are quasi-static during operation
set_false_path -from [get_cells -hierarchical -filter {NAME =~ *config_reg*}]

# ═══════════════════════════════════════════════════════════════════════════════
# MULTICYCLE PATHS
# ═══════════════════════════════════════════════════════════════════════════════

# Ternary multiplication has 2-cycle latency in pipeline
# Allow 2 cycles for trit_mult operations
set_multicycle_path 2 -setup -from [get_cells -hierarchical -filter {NAME =~ *trit_mult*}]
set_multicycle_path 1 -hold -from [get_cells -hierarchical -filter {NAME =~ *trit_mult*}]

# SIMD accumulator has 3-cycle latency
set_multicycle_path 3 -setup -from [get_cells -hierarchical -filter {NAME =~ *simd_acc*}]
set_multicycle_path 2 -hold -from [get_cells -hierarchical -filter {NAME =~ *simd_acc*}]

# ═══════════════════════════════════════════════════════════════════════════════
# MAX DELAY CONSTRAINTS
# ═══════════════════════════════════════════════════════════════════════════════

# Critical path: SIMD multiply-accumulate chain
# Target: Complete 27-way parallel MAC in single cycle
set_max_delay 3.0 -from [get_cells -hierarchical -filter {NAME =~ *simd_core*}] \
                  -to [get_cells -hierarchical -filter {NAME =~ *simd_core*}]

# Weight memory to compute path
set_max_delay 2.5 -from [get_cells -hierarchical -filter {NAME =~ *weight_mem*}] \
                  -to [get_cells -hierarchical -filter {NAME =~ *compute*}]

# ═══════════════════════════════════════════════════════════════════════════════
# PHYSICAL CONSTRAINTS
# ═══════════════════════════════════════════════════════════════════════════════

# Keep SIMD cores together for minimal routing delay
# create_pblock pblock_simd
# add_cells_to_pblock [get_pblocks pblock_simd] [get_cells -hierarchical -filter {NAME =~ *simd_core*}]
# resize_pblock [get_pblocks pblock_simd] -add {SLICE_X0Y0:SLICE_X50Y100}

# Keep weight memory near compute units
# create_pblock pblock_weights
# add_cells_to_pblock [get_pblocks pblock_weights] [get_cells -hierarchical -filter {NAME =~ *weight_bram*}]
# resize_pblock [get_pblocks pblock_weights] -add {RAMB36_X0Y0:RAMB36_X5Y20}

# ═══════════════════════════════════════════════════════════════════════════════
# CLOCK DOMAIN CROSSING
# ═══════════════════════════════════════════════════════════════════════════════

# All logic runs on single clock domain - no CDC constraints needed
# If adding DDR interface, add appropriate CDC constraints here

# ═══════════════════════════════════════════════════════════════════════════════
# POWER OPTIMIZATION
# ═══════════════════════════════════════════════════════════════════════════════

# Enable clock gating for idle modules
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -hierarchical -filter {NAME =~ *gated_clk*}]

# ═══════════════════════════════════════════════════════════════════════════════
# DEBUG
# ═══════════════════════════════════════════════════════════════════════════════

# Mark debug signals for ILA insertion (optional)
# set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *debug_*}]

# ═══════════════════════════════════════════════════════════════════════════════
# VCU118 SPECIFIC PIN ASSIGNMENTS (Reference - adjust for actual board)
# ═══════════════════════════════════════════════════════════════════════════════

# System clock (300 MHz LVDS)
# set_property PACKAGE_PIN E12 [get_ports clk_p]
# set_property PACKAGE_PIN D12 [get_ports clk_n]
# set_property IOSTANDARD LVDS [get_ports clk_*]

# Reset button (active low)
# set_property PACKAGE_PIN L19 [get_ports rst_n]
# set_property IOSTANDARD LVCMOS12 [get_ports rst_n]

# ═══════════════════════════════════════════════════════════════════════════════
# TIMING EXCEPTIONS SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
# 
# Clock Period: 3.333 ns (300 MHz)
# Setup Margin: 0.333 ns (10%)
# Hold Margin: 0.100 ns
#
# Critical Paths:
#   1. SIMD MAC chain: 3.0 ns max
#   2. Weight fetch: 2.5 ns max
#   3. AXI interface: 1.5 ns I/O delay
#
# φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

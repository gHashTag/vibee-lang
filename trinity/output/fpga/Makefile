# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE BitNet FPGA - Synthesis Makefile
# ═══════════════════════════════════════════════════════════════════════════════
# Usage:
#   make create    - Create Vivado project
#   make synth     - Run synthesis
#   make impl      - Run implementation (place & route)
#   make bitstream - Generate bitstream
#   make program   - Program FPGA
#   make all       - Full flow (create -> bitstream)
#   make clean     - Clean generated files
#   make report    - Generate utilization report
#
# Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
# Golden Identity: φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

# Configuration
PROJECT_NAME := vibee_bitnet
VIVADO := vivado
VIVADO_FLAGS := -mode batch -nojournal -nolog

# Target device (choose one)
# VCU118 (Virtex UltraScale+)
# PART := xcvu9p-flga2104-2L-e
# ZCU104 (Zynq UltraScale+)
PART := xczu7ev-ffvc1156-2-e

# Directories
SCRIPT_DIR := scripts
CONSTRAINT_DIR := constraints
BUILD_DIR := build
REPORT_DIR := reports

# Source files
VERILOG_SRCS := $(wildcard *.v)
XDC_SRCS := $(wildcard $(CONSTRAINT_DIR)/*.xdc)

# Targets
.PHONY: all create synth impl bitstream program clean report help

# Default target
all: bitstream

# Help
help:
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "VIBEE BitNet FPGA Synthesis Makefile"
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "Targets:"
	@echo "  make create    - Create Vivado project"
	@echo "  make synth     - Run synthesis"
	@echo "  make impl      - Run implementation"
	@echo "  make bitstream - Generate bitstream"
	@echo "  make program   - Program FPGA"
	@echo "  make all       - Full flow"
	@echo "  make clean     - Clean build files"
	@echo "  make report    - Generate reports"
	@echo ""
	@echo "Configuration:"
	@echo "  PROJECT: $(PROJECT_NAME)"
	@echo "  PART: $(PART)"
	@echo "  SOURCES: $(words $(VERILOG_SRCS)) Verilog files"
	@echo ""
	@echo "φ² + 1/φ² = 3 | PHOENIX = 999"
	@echo "═══════════════════════════════════════════════════════════════════════════════"

# Create project
create: $(BUILD_DIR)/.project_created

$(BUILD_DIR)/.project_created: $(VERILOG_SRCS) $(XDC_SRCS)
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "Creating Vivado Project: $(PROJECT_NAME)"
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(REPORT_DIR)
	$(VIVADO) $(VIVADO_FLAGS) -source $(SCRIPT_DIR)/create_project.tcl -tclargs $(PROJECT_NAME) $(PART)
	@touch $@

# Synthesis
synth: $(BUILD_DIR)/.synth_done

$(BUILD_DIR)/.synth_done: $(BUILD_DIR)/.project_created
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "Running Synthesis"
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	$(VIVADO) $(VIVADO_FLAGS) -source $(SCRIPT_DIR)/synth.tcl
	@touch $@

# Implementation
impl: $(BUILD_DIR)/.impl_done

$(BUILD_DIR)/.impl_done: $(BUILD_DIR)/.synth_done
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "Running Implementation"
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	$(VIVADO) $(VIVADO_FLAGS) -source $(SCRIPT_DIR)/impl.tcl
	@touch $@

# Bitstream
bitstream: $(BUILD_DIR)/.bitstream_done

$(BUILD_DIR)/.bitstream_done: $(BUILD_DIR)/.impl_done
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "Generating Bitstream"
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	$(VIVADO) $(VIVADO_FLAGS) -source $(SCRIPT_DIR)/bitstream.tcl
	@touch $@

# Program FPGA
program: $(BUILD_DIR)/.bitstream_done
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "Programming FPGA"
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	$(VIVADO) $(VIVADO_FLAGS) -source $(SCRIPT_DIR)/program.tcl

# Generate reports
report:
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "Generating Reports"
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@mkdir -p $(REPORT_DIR)
	@if [ -f $(BUILD_DIR)/vivado/$(PROJECT_NAME).xpr ]; then \
		$(VIVADO) $(VIVADO_FLAGS) -source $(SCRIPT_DIR)/report.tcl; \
	else \
		echo "Project not found. Run 'make create' first."; \
	fi

# Clean
clean:
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "Cleaning Build Files"
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	rm -rf $(BUILD_DIR)
	rm -rf vivado
	rm -rf .Xil
	rm -f vivado*.log vivado*.jou
	rm -f *.log *.jou

# Quick synthesis check (no implementation)
check: create synth
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "Synthesis Check Complete"
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@cat $(REPORT_DIR)/utilization_synth.rpt | head -50

# Source file listing
sources:
	@echo "Verilog Sources ($(words $(VERILOG_SRCS)) files):"
	@for f in $(VERILOG_SRCS); do echo "  $$f"; done
	@echo ""
	@echo "Constraint Files:"
	@for f in $(XDC_SRCS); do echo "  $$f"; done

# ═══════════════════════════════════════════════════════════════════════════════
# φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

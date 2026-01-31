# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE FPGA - Complete Build Script (Synthesis + Implementation + Bitstream)
# ═══════════════════════════════════════════════════════════════════════════════
#
# Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
# Golden Identity: φ² + 1/φ² = 3
# PHOENIX = 999
#
# Usage: vivado -mode batch -source build_all.tcl -tclargs <top_module>
#
# Example: vivado -mode batch -source build_all.tcl -tclargs hello_fpga_led_top
#
# ═══════════════════════════════════════════════════════════════════════════════

# Get top module from arguments or use default
if {$argc > 0} {
    set top_module [lindex $argv 0]
} else {
    set top_module "hello_fpga_led_top"
}

# Project settings
set project_name "vibee_fpga_${top_module}"
set project_dir "./vivado_${top_module}"
set part_number "xc7a35ticsg324-1L"
set output_dir "./output"

# Source directories
set rtl_dir ".."
set constraints_dir "../constraints"

puts ""
puts "═══════════════════════════════════════════════════════════════════════════════"
puts "VIBEE FPGA - Complete Build"
puts "═══════════════════════════════════════════════════════════════════════════════"
puts "Sacred Formula: V = n × 3^k × π^m × φ^p × e^q"
puts "Golden Identity: φ² + 1/φ² = 3"
puts ""
puts "Top Module: $top_module"
puts "Part: $part_number"
puts "═══════════════════════════════════════════════════════════════════════════════"
puts ""

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 1: Create Project
# ═══════════════════════════════════════════════════════════════════════════════

puts "PHASE 1: Creating project..."

# Create project directory
file mkdir $project_dir
file mkdir $output_dir

# Create project
create_project $project_name $project_dir -part $part_number -force

# Add source files
set verilog_files [glob -nocomplain $rtl_dir/*.v]
if {[llength $verilog_files] > 0} {
    add_files -norecurse $verilog_files
    puts "  Added [llength $verilog_files] Verilog files"
}

# Set top module
set_property top $top_module [current_fileset]

# Add constraints
if {[file exists $constraints_dir/arty_a7.xdc]} {
    add_files -fileset constrs_1 -norecurse $constraints_dir/arty_a7.xdc
    puts "  Added constraints: arty_a7.xdc"
}

puts "  Project created: $project_dir/$project_name.xpr"
puts ""

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 2: Synthesis
# ═══════════════════════════════════════════════════════════════════════════════

puts "PHASE 2: Running synthesis..."

# Configure synthesis
set_property strategy Flow_PerfOptimized_high [get_runs synth_1]

# Launch synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check status
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    close_project
    exit 1
}

puts "  Synthesis complete"
puts ""

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 3: Implementation
# ═══════════════════════════════════════════════════════════════════════════════

puts "PHASE 3: Running implementation..."

# Configure implementation
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]

# Launch implementation
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Check status
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed!"
    close_project
    exit 1
}

puts "  Implementation complete"
puts ""

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 4: Generate Bitstream
# ═══════════════════════════════════════════════════════════════════════════════

puts "PHASE 4: Generating bitstream..."

# Open implemented design
open_run impl_1

# Generate bitstream
set bitstream_file "$output_dir/${top_module}.bit"
write_bitstream -force $bitstream_file

puts "  Bitstream generated: $bitstream_file"
puts ""

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 5: Generate Reports
# ═══════════════════════════════════════════════════════════════════════════════

puts "PHASE 5: Generating reports..."

file mkdir $output_dir/reports

# Utilization report
report_utilization -file $output_dir/reports/utilization.rpt

# Timing report
report_timing_summary -file $output_dir/reports/timing.rpt

# Power report
report_power -file $output_dir/reports/power.rpt

puts "  Reports generated in $output_dir/reports/"
puts ""

# ═══════════════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════════════

puts "═══════════════════════════════════════════════════════════════════════════════"
puts "BUILD COMPLETE"
puts "═══════════════════════════════════════════════════════════════════════════════"
puts ""
puts "Output files:"
puts "  Bitstream: $bitstream_file"
puts "  Reports:   $output_dir/reports/"
puts ""
puts "To program FPGA:"
puts "  1. Connect Arty A7 via USB"
puts "  2. Run: vivado -mode batch -source program.tcl -tclargs $bitstream_file"
puts ""

# Print utilization summary
puts "Resource Utilization:"
puts "─────────────────────────────────────────────────────────────────────────────"
report_utilization -hierarchical -hierarchical_depth 1

puts ""
puts "═══════════════════════════════════════════════════════════════════════════════"
puts "Golden Identity: φ² + 1/φ² = 3 ✓"
puts "PHOENIX = 999 ✓"
puts "═══════════════════════════════════════════════════════════════════════════════"

close_project

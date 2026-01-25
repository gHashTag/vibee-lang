# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE FPGA - Vivado Project Creation Script
# ═══════════════════════════════════════════════════════════════════════════════
# Usage: vivado -mode batch -source create_project.tcl
#
# Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
# Golden Identity: φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

# Project settings
set project_name "vibee_bitnet"
set project_dir "./vivado"
set part "xcvu9p-flga2104-2L-e"  ;# VCU118
# Alternative: set part "xczu7ev-ffvc1156-2-e"  ;# ZCU104

# Create project
create_project $project_name $project_dir -part $part -force

# Set project properties
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# ═══════════════════════════════════════════════════════════════════════════════
# ADD SOURCE FILES
# ═══════════════════════════════════════════════════════════════════════════════

# Get script directory
set script_dir [file dirname [info script]]
set fpga_dir [file normalize "$script_dir/.."]

# Add all Verilog sources
add_files -norecurse [glob -nocomplain $fpga_dir/*.v]

# Set top module
set_property top vibee_fpga_top [current_fileset]

# ═══════════════════════════════════════════════════════════════════════════════
# ADD CONSTRAINTS
# ═══════════════════════════════════════════════════════════════════════════════

add_files -fileset constrs_1 -norecurse $fpga_dir/constraints/vibee.xdc

# ═══════════════════════════════════════════════════════════════════════════════
# SYNTHESIS SETTINGS
# ═══════════════════════════════════════════════════════════════════════════════

set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FANOUT_LIMIT 10000 [get_runs synth_1]

# ═══════════════════════════════════════════════════════════════════════════════
# IMPLEMENTATION SETTINGS
# ═══════════════════════════════════════════════════════════════════════════════

set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE ExploreWithRemap [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE ExtraNetDelay_high [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

# ═══════════════════════════════════════════════════════════════════════════════
# SAVE PROJECT
# ═══════════════════════════════════════════════════════════════════════════════

puts "═══════════════════════════════════════════════════════════════════════════════"
puts "VIBEE FPGA Project Created Successfully"
puts "═══════════════════════════════════════════════════════════════════════════════"
puts "Project: $project_name"
puts "Part: $part"
puts "Directory: $project_dir"
puts ""
puts "Next steps:"
puts "  1. Open Vivado GUI: vivado $project_dir/$project_name.xpr"
puts "  2. Or run synthesis: vivado -mode batch -source synth.tcl"
puts ""
puts "φ² + 1/φ² = 3 | PHOENIX = 999"
puts "═══════════════════════════════════════════════════════════════════════════════"

close_project

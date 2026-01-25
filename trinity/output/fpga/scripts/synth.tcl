# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE FPGA - Synthesis Script
# ═══════════════════════════════════════════════════════════════════════════════
# Usage: vivado -mode batch -source synth.tcl
#
# Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
# Golden Identity: φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

set project_name "vibee_bitnet"
set project_dir "./vivado"

# Open project
open_project $project_dir/$project_name.xpr

puts "═══════════════════════════════════════════════════════════════════════════════"
puts "VIBEE FPGA - Running Synthesis"
puts "═══════════════════════════════════════════════════════════════════════════════"

# Reset synthesis run
reset_run synth_1

# Launch synthesis
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# Check status
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

# Open synthesized design
open_run synth_1

# Generate reports
file mkdir ../reports
report_utilization -file ../reports/utilization_synth.rpt
report_timing_summary -file ../reports/timing_synth.rpt
report_design_analysis -file ../reports/design_analysis.rpt

puts ""
puts "═══════════════════════════════════════════════════════════════════════════════"
puts "SYNTHESIS COMPLETE"
puts "═══════════════════════════════════════════════════════════════════════════════"
puts ""
puts "Reports generated in ../reports/"
puts ""

# Print utilization summary
report_utilization -hierarchical -hierarchical_depth 2

puts ""
puts "φ² + 1/φ² = 3 | PHOENIX = 999"
puts "═══════════════════════════════════════════════════════════════════════════════"

close_project

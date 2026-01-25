# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE FPGA - Implementation Script (Place & Route)
# ═══════════════════════════════════════════════════════════════════════════════
# Usage: vivado -mode batch -source impl.tcl
#
# Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
# Golden Identity: φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

set project_name "vibee_bitnet"
set project_dir "./vivado"

# Open project
open_project $project_dir/$project_name.xpr

puts "═══════════════════════════════════════════════════════════════════════════════"
puts "VIBEE FPGA - Running Implementation"
puts "═══════════════════════════════════════════════════════════════════════════════"

# Check if synthesis is complete
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "Synthesis not complete. Running synthesis first..."
    launch_runs synth_1 -jobs 8
    wait_on_run synth_1
}

# Reset implementation run
reset_run impl_1

# Launch implementation
launch_runs impl_1 -jobs 8
wait_on_run impl_1

# Check status
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed!"
    exit 1
}

# Open implemented design
open_run impl_1

# Generate reports
file mkdir ../reports
report_utilization -file ../reports/utilization_impl.rpt
report_timing_summary -file ../reports/timing_impl.rpt
report_power -file ../reports/power_impl.rpt
report_clock_utilization -file ../reports/clock_impl.rpt
report_drc -file ../reports/drc_impl.rpt

puts ""
puts "═══════════════════════════════════════════════════════════════════════════════"
puts "IMPLEMENTATION COMPLETE"
puts "═══════════════════════════════════════════════════════════════════════════════"
puts ""

# Print timing summary
puts "TIMING SUMMARY:"
puts "═══════════════════════════════════════════════════════════════════════════════"
report_timing_summary -no_header -no_detailed_paths

puts ""
puts "UTILIZATION SUMMARY:"
puts "═══════════════════════════════════════════════════════════════════════════════"
report_utilization -hierarchical -hierarchical_depth 1

puts ""
puts "φ² + 1/φ² = 3 | PHOENIX = 999"
puts "═══════════════════════════════════════════════════════════════════════════════"

close_project

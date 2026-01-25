# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE FPGA - Bitstream Generation Script
# ═══════════════════════════════════════════════════════════════════════════════
# Usage: vivado -mode batch -source bitstream.tcl
#
# Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
# Golden Identity: φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

set project_name "vibee_bitnet"
set project_dir "./vivado"

# Open project
open_project $project_dir/$project_name.xpr

puts "═══════════════════════════════════════════════════════════════════════════════"
puts "VIBEE FPGA - Generating Bitstream"
puts "═══════════════════════════════════════════════════════════════════════════════"

# Check if implementation is complete
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "Implementation not complete. Running implementation first..."
    launch_runs impl_1 -jobs 8
    wait_on_run impl_1
}

# Generate bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# Create output directory
file mkdir ../output

# Copy bitstream
set bitstream_file [glob -nocomplain $project_dir/$project_name.runs/impl_1/*.bit]
if {$bitstream_file ne ""} {
    file copy -force $bitstream_file ../output/vibee_bitnet.bit
    puts "Bitstream copied to ../output/vibee_bitnet.bit"
}

# Generate hardware handoff for SDK
write_hw_platform -fixed -include_bit -force ../output/vibee_bitnet.xsa

puts ""
puts "═══════════════════════════════════════════════════════════════════════════════"
puts "BITSTREAM GENERATION COMPLETE"
puts "═══════════════════════════════════════════════════════════════════════════════"
puts ""
puts "Output files:"
puts "  - ../output/vibee_bitnet.bit  (FPGA bitstream)"
puts "  - ../output/vibee_bitnet.xsa  (Hardware platform for SDK)"
puts ""
puts "To program FPGA:"
puts "  1. Connect VCU118 via JTAG"
puts "  2. Run: vivado -mode batch -source program.tcl"
puts ""
puts "φ² + 1/φ² = 3 | PHOENIX = 999"
puts "═══════════════════════════════════════════════════════════════════════════════"

close_project

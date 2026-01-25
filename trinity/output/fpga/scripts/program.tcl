# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE FPGA - Programming Script
# ═══════════════════════════════════════════════════════════════════════════════
# Usage: vivado -mode batch -source program.tcl
#
# Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
# Golden Identity: φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

set bitstream_file "../output/vibee_bitnet.bit"

puts "═══════════════════════════════════════════════════════════════════════════════"
puts "VIBEE FPGA - Programming Device"
puts "═══════════════════════════════════════════════════════════════════════════════"

# Check bitstream exists
if {![file exists $bitstream_file]} {
    puts "ERROR: Bitstream not found: $bitstream_file"
    puts "Run bitstream.tcl first to generate the bitstream."
    exit 1
}

# Open hardware manager
open_hw_manager

# Connect to hardware server
connect_hw_server -allow_non_jtag

# Get hardware targets
set targets [get_hw_targets]
if {[llength $targets] == 0} {
    puts "ERROR: No hardware targets found!"
    puts "Check JTAG connection to VCU118."
    close_hw_manager
    exit 1
}

# Open first target
open_hw_target [lindex $targets 0]

# Get device
set device [get_hw_devices]
if {[llength $device] == 0} {
    puts "ERROR: No devices found on target!"
    close_hw_target
    close_hw_manager
    exit 1
}

# Select first device (should be VU9P)
current_hw_device [lindex $device 0]

# Set programming file
set_property PROGRAM.FILE $bitstream_file [current_hw_device]

# Program device
puts "Programming device..."
program_hw_devices [current_hw_device]

puts ""
puts "═══════════════════════════════════════════════════════════════════════════════"
puts "PROGRAMMING COMPLETE"
puts "═══════════════════════════════════════════════════════════════════════════════"
puts ""
puts "VIBEE BitNet Accelerator is now running on FPGA!"
puts ""
puts "Device: [get_property NAME [current_hw_device]]"
puts "Bitstream: $bitstream_file"
puts ""
puts "φ² + 1/φ² = 3 | PHOENIX = 999"
puts "═══════════════════════════════════════════════════════════════════════════════"

# Close connections
close_hw_target
close_hw_manager

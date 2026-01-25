# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE BitNet - JTAG-AXI Debug Commands
# ═══════════════════════════════════════════════════════════════════════════════
# TCL команды для отладки через JTAG-to-AXI Master
#
# Использование в Hardware Manager:
#   source jtag_axi_debug.tcl
#   jtag_connect
#   bitnet_status
#
# Священная Формула: V = n × 3^k × π^m × φ^p × e^q
# Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

namespace eval ::jtag_debug {
    # Базовые адреса
    variable BITNET_BASE     0xA0000000
    variable DMA_INPUT_BASE  0xA0010000
    variable DMA_OUTPUT_BASE 0xA0020000
    variable DMA_WEIGHT_BASE 0xA0030000
    
    # BitNet регистры
    variable REG_CONTROL     0x00
    variable REG_STATUS      0x04
    variable REG_VERSION     0x08
    variable REG_CONFIG      0x0C
    variable REG_INFER_CNT   0x14
    variable REG_CYCLE_CNT   0x18
    variable REG_ERROR       0x1C
    
    variable jtag_axi ""
    variable connected 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# БАЗОВЫЕ ФУНКЦИИ
# ═══════════════════════════════════════════════════════════════════════════════

proc jtag_connect {} {
    variable ::jtag_debug::jtag_axi
    variable ::jtag_debug::connected
    
    puts "Подключение к JTAG-AXI..."
    
    if {[catch {current_hw_server}]} {
        open_hw_manager
    }
    
    if {[catch {connect_hw_server -allow_non_jtag} err]} {
        puts "ОШИБКА: $err"
        return 0
    }
    
    open_hw_target [lindex [get_hw_targets] 0]
    current_hw_device [lindex [get_hw_devices] 0]
    refresh_hw_device [current_hw_device]
    
    set ::jtag_debug::jtag_axi [get_hw_axis]
    if {$::jtag_debug::jtag_axi eq ""} {
        puts "ОШИБКА: JTAG-AXI не найден"
        return 0
    }
    
    reset_hw_axi $::jtag_debug::jtag_axi
    set ::jtag_debug::connected 1
    puts "✓ Подключено к JTAG-AXI"
    return 1
}

proc axi_read {addr} {
    variable ::jtag_debug::jtag_axi
    create_hw_axi_txn rd_txn $::jtag_debug::jtag_axi -type READ -address $addr -len 1
    run_hw_axi rd_txn
    set data [get_property DATA [get_hw_axi_txns rd_txn]]
    delete_hw_axi_txn rd_txn
    return $data
}

proc axi_write {addr data} {
    variable ::jtag_debug::jtag_axi
    create_hw_axi_txn wr_txn $::jtag_debug::jtag_axi -type WRITE -address $addr -data $data -len 1
    run_hw_axi wr_txn
    delete_hw_axi_txn wr_txn
}

proc axi_dump {base num_words} {
    puts "Memory dump from 0x[format %08X $base]:"
    for {set i 0} {$i < $num_words} {incr i} {
        set addr [expr {$base + $i * 4}]
        set data [axi_read $addr]
        puts [format "  0x%08X: 0x%s" $addr $data]
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# BITNET КОМАНДЫ
# ═══════════════════════════════════════════════════════════════════════════════

proc bitnet_status {} {
    variable ::jtag_debug::BITNET_BASE
    
    puts "═══════════════════════════════════════════════════════════"
    puts "BitNet Accelerator Status"
    puts "═══════════════════════════════════════════════════════════"
    
    set version [axi_read [expr {$::jtag_debug::BITNET_BASE + 0x08}]]
    set status [axi_read [expr {$::jtag_debug::BITNET_BASE + 0x04}]]
    set infer [axi_read [expr {$::jtag_debug::BITNET_BASE + 0x14}]]
    set cycles [axi_read [expr {$::jtag_debug::BITNET_BASE + 0x18}]]
    
    puts "  Version:     0x$version"
    puts "  Status:      0x$status"
    puts "  Inferences:  [expr 0x$infer]"
    puts "  Cycles:      [expr 0x$cycles]"
}

proc bitnet_start {} {
    variable ::jtag_debug::BITNET_BASE
    axi_write [expr {$::jtag_debug::BITNET_BASE + 0x00}] 0x00000001
    puts "✓ BitNet started"
}

proc bitnet_reset {} {
    variable ::jtag_debug::BITNET_BASE
    axi_write [expr {$::jtag_debug::BITNET_BASE + 0x00}] 0x80000000
    after 10
    axi_write [expr {$::jtag_debug::BITNET_BASE + 0x00}] 0x00000000
    puts "✓ BitNet reset"
}

puts "JTAG-AXI Debug commands loaded. Run: jtag_connect"

# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE BitNet - VIO Dashboard Script
# ═══════════════════════════════════════════════════════════════════════════════
# Интерактивная панель управления BitNet акселератором через VIO
#
# Использование: 
#   vivado -mode tcl -source vio_dashboard.tcl
#   Или в Hardware Manager: source vio_dashboard.tcl
#
# Священная Формула: V = n × 3^k × π^m × φ^p × e^q
# Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
# ═══════════════════════════════════════════════════════════════════════════════

namespace eval ::vio_dashboard {
    variable hw_target ""
    variable hw_device ""
    variable connected 0
    
    # VIO cores
    variable vio_runtime ""
    variable vio_simd ""
    variable vio_perf ""
    variable vio_thermal ""
    
    # Engine states
    variable engine_states {
        0x00 "IDLE"
        0x01 "LOADING_WEIGHTS"
        0x02 "LOADING_INPUT"
        0x03 "COMPUTING"
        0x04 "STORING_OUTPUT"
        0x05 "DONE"
        0xFF "ERROR"
    }
    
    # Error flags
    variable error_flags {
        0x01 "FIFO_OVERFLOW"
        0x02 "FIFO_UNDERFLOW"
        0x04 "AXI_ERROR"
        0x08 "TIMEOUT"
        0x10 "WEIGHT_MISMATCH"
        0x20 "CHECKSUM_FAIL"
        0x40 "THERMAL_WARN"
        0x80 "THERMAL_CRIT"
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# ПОДКЛЮЧЕНИЕ К HARDWARE
# ═══════════════════════════════════════════════════════════════════════════════

proc ::vio_dashboard::connect {} {
    variable hw_target
    variable hw_device
    variable connected
    variable vio_runtime
    variable vio_simd
    variable vio_perf
    variable vio_thermal
    
    puts ""
    puts "═══════════════════════════════════════════════════════════════════════════════"
    puts "VIBEE VIO Dashboard - Подключение"
    puts "═══════════════════════════════════════════════════════════════════════════════"
    
    # Открываем hw_manager если не открыт
    if {[catch {current_hw_server}]} {
        open_hw_manager
    }
    
    # Подключаемся к hw_server
    if {[catch {connect_hw_server -allow_non_jtag} err]} {
        puts "ОШИБКА: Не удалось подключиться к hw_server: $err"
        return 0
    }
    
    # Находим target
    set targets [get_hw_targets]
    if {[llength $targets] == 0} {
        puts "ОШИБКА: Не найдено JTAG targets"
        return 0
    }
    
    set hw_target [lindex $targets 0]
    open_hw_target $hw_target
    puts "  Target: $hw_target"
    
    # Находим device
    set devices [get_hw_devices]
    if {[llength $devices] == 0} {
        puts "ОШИБКА: Не найдено FPGA devices"
        return 0
    }
    
    set hw_device [lindex $devices 0]
    current_hw_device $hw_device
    puts "  Device: $hw_device"
    
    # Refresh device
    refresh_hw_device $hw_device
    
    # Находим VIO cores
    set vios [get_hw_vios -quiet]
    
    foreach vio $vios {
        set name [get_property CELL_NAME $vio]
        puts "  Найден VIO: $name"
        
        if {[string match "*vio_runtime*" $name]} {
            set vio_runtime $vio
        } elseif {[string match "*vio_simd*" $name]} {
            set vio_simd $vio
        } elseif {[string match "*vio_perf*" $name]} {
            set vio_perf $vio
        } elseif {[string match "*vio_thermal*" $name]} {
            set vio_thermal $vio
        }
    }
    
    if {$vio_runtime eq ""} {
        puts "ПРЕДУПРЕЖДЕНИЕ: vio_runtime не найден"
    }
    
    set connected 1
    puts ""
    puts "✓ Подключение успешно"
    puts ""
    
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# ЧТЕНИЕ СТАТУСА
# ═══════════════════════════════════════════════════════════════════════════════

proc ::vio_dashboard::status {} {
    variable connected
    variable vio_runtime
    variable vio_simd
    variable vio_perf
    variable vio_thermal
    variable engine_states
    variable error_flags
    
    if {!$connected} {
        puts "ОШИБКА: Не подключено. Выполните: vio_dashboard::connect"
        return
    }
    
    puts ""
    puts "═══════════════════════════════════════════════════════════════════════════════"
    puts "VIBEE BitNet - Runtime Status"
    puts "═══════════════════════════════════════════════════════════════════════════════"
    
    # Refresh all VIOs
    if {$vio_runtime ne ""} {
        refresh_hw_vio $vio_runtime
    }
    if {$vio_simd ne ""} {
        refresh_hw_vio $vio_simd
    }
    if {$vio_perf ne ""} {
        refresh_hw_vio $vio_perf
    }
    if {$vio_thermal ne ""} {
        refresh_hw_vio $vio_thermal
    }
    
    # ─────────────────────────────────────────────────────────────────────────────
    # Engine Status
    # ─────────────────────────────────────────────────────────────────────────────
    
    if {$vio_runtime ne ""} {
        puts ""
        puts "┌─────────────────────────────────────────────────────────────────────────────┐"
        puts "│ ENGINE STATUS                                                               │"
        puts "├─────────────────────────────────────────────────────────────────────────────┤"
        
        # Читаем probe_in значения
        set probes [get_hw_probes -of_objects $vio_runtime -filter {TYPE == probe_in}]
        
        foreach probe $probes {
            set name [get_property NAME $probe]
            set value [get_property INPUT_VALUE $probe]
            
            switch -glob $name {
                "*probe_in0*" {
                    set state_name [dict get $engine_states $value]
                    puts [format "│ %-20s: 0x%02X (%s)" "Engine State" $value $state_name]
                }
                "*probe_in1*" {
                    puts [format "│ %-20s: %d" "Inference Count" $value]
                }
                "*probe_in2*" {
                    set err_str [decode_errors $value]
                    puts [format "│ %-20s: 0x%02X %s" "Error Flags" $value $err_str]
                }
                "*probe_in3*" {
                    puts [format "│ %-20s: %d" "Current Layer" $value]
                }
                "*probe_in4*" {
                    puts [format "│ %-20s: %d cycles" "Cycle Count" $value]
                }
                "*probe_in5*" {
                    puts [format "│ %-20s: %d%%" "Utilization" $value]
                }
                "*probe_in6*" {
                    set in_level [expr {$value & 0x0F}]
                    set out_level [expr {($value >> 4) & 0x0F}]
                    puts [format "│ %-20s: IN=%d/15, OUT=%d/15" "FIFO Status" $in_level $out_level]
                }
                "*probe_in7*" {
                    set temp_c [expr {($value * 503.975 / 4096.0) - 273.15}]
                    puts [format "│ %-20s: %.1f°C (raw: 0x%03X)" "Temperature" $temp_c $value]
                }
            }
        }
        
        puts "└─────────────────────────────────────────────────────────────────────────────┘"
    }
    
    # ─────────────────────────────────────────────────────────────────────────────
    # SIMD Status
    # ─────────────────────────────────────────────────────────────────────────────
    
    if {$vio_simd ne ""} {
        puts ""
        puts "┌─────────────────────────────────────────────────────────────────────────────┐"
        puts "│ SIMD BLOCKS (27 = 3³)                                                       │"
        puts "├─────────────────────────────────────────────────────────────────────────────┤"
        
        set probes [get_hw_probes -of_objects $vio_simd -filter {TYPE == probe_in}]
        
        foreach probe $probes {
            set name [get_property NAME $probe]
            set value [get_property INPUT_VALUE $probe]
            
            switch -glob $name {
                "*probe_in0*" {
                    set active_count [count_bits $value]
                    puts [format "│ %-20s: %d/27 active (0x%07X)" "SIMD Active" $active_count $value]
                }
                "*probe_in1*" {
                    set stall_count [count_bits $value]
                    puts [format "│ %-20s: %d/27 stalled (0x%07X)" "SIMD Stall" $stall_count $value]
                }
                "*probe_in2*" {
                    set error_count [count_bits $value]
                    puts [format "│ %-20s: %d/27 errors (0x%07X)" "SIMD Error" $error_count $value]
                }
            }
        }
        
        puts "└─────────────────────────────────────────────────────────────────────────────┘"
    }
    
    # ─────────────────────────────────────────────────────────────────────────────
    # Performance Counters
    # ─────────────────────────────────────────────────────────────────────────────
    
    if {$vio_perf ne ""} {
        puts ""
        puts "┌─────────────────────────────────────────────────────────────────────────────┐"
        puts "│ PERFORMANCE COUNTERS                                                        │"
        puts "├─────────────────────────────────────────────────────────────────────────────┤"
        
        set probes [get_hw_probes -of_objects $vio_perf -filter {TYPE == probe_in}]
        set counter_names {
            "Total Cycles"
            "Compute Cycles"
            "Mem Stall Cycles"
            "AXI Wait Cycles"
            "Layer Cycles"
            "SIMD Active Cycles"
            "Cache Hits"
            "Cache Misses"
        }
        
        set idx 0
        foreach probe $probes {
            set value [get_property INPUT_VALUE $probe]
            set name [lindex $counter_names $idx]
            puts [format "│ %-20s: %d" $name $value]
            incr idx
        }
        
        puts "└─────────────────────────────────────────────────────────────────────────────┘"
    }
    
    # ─────────────────────────────────────────────────────────────────────────────
    # Thermal Status
    # ─────────────────────────────────────────────────────────────────────────────
    
    if {$vio_thermal ne ""} {
        puts ""
        puts "┌─────────────────────────────────────────────────────────────────────────────┐"
        puts "│ THERMAL STATUS                                                              │"
        puts "├─────────────────────────────────────────────────────────────────────────────┤"
        
        set probes [get_hw_probes -of_objects $vio_thermal -filter {TYPE == probe_in}]
        
        foreach probe $probes {
            set name [get_property NAME $probe]
            set value [get_property INPUT_VALUE $probe]
            
            switch -glob $name {
                "*probe_in0*" {
                    set temp_c [expr {($value * 503.975 / 4096.0) - 273.15}]
                    puts [format "│ %-20s: %.1f°C" "Current Temp" $temp_c]
                }
                "*probe_in1*" {
                    set temp_c [expr {($value * 503.975 / 4096.0) - 273.15}]
                    puts [format "│ %-20s: %.1f°C" "Max Temp" $temp_c]
                }
                "*probe_in2*" {
                    set temp_c [expr {($value * 503.975 / 4096.0) - 273.15}]
                    puts [format "│ %-20s: %.1f°C" "Min Temp" $temp_c]
                }
                "*probe_in3*" {
                    set status_str "OK"
                    if {$value & 0x40} { set status_str "WARNING" }
                    if {$value & 0x80} { set status_str "CRITICAL" }
                    puts [format "│ %-20s: %s (0x%02X)" "Thermal Status" $status_str $value]
                }
            }
        }
        
        puts "└─────────────────────────────────────────────────────────────────────────────┘"
    }
    
    puts ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# КОМАНДЫ УПРАВЛЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════════

proc ::vio_dashboard::start_inference {} {
    variable connected
    variable vio_runtime
    
    if {!$connected || $vio_runtime eq ""} {
        puts "ОШИБКА: Не подключено или vio_runtime не найден"
        return
    }
    
    puts "Запуск inference..."
    
    # Находим probe_out0 (force_start)
    set probe [get_hw_probes -of_objects $vio_runtime -filter {NAME =~ "*probe_out0*"}]
    
    # Pulse: 0 -> 1 -> 0
    set_property OUTPUT_VALUE 0 $probe
    commit_hw_vio $vio_runtime
    
    set_property OUTPUT_VALUE 1 $probe
    commit_hw_vio $vio_runtime
    
    after 10
    
    set_property OUTPUT_VALUE 0 $probe
    commit_hw_vio $vio_runtime
    
    puts "✓ Inference запущен"
}

proc ::vio_dashboard::reset {} {
    variable connected
    variable vio_runtime
    
    if {!$connected || $vio_runtime eq ""} {
        puts "ОШИБКА: Не подключено или vio_runtime не найден"
        return
    }
    
    puts "Выполнение soft reset..."
    
    # Находим probe_out1 (force_reset)
    set probe [get_hw_probes -of_objects $vio_runtime -filter {NAME =~ "*probe_out1*"}]
    
    # Pulse reset
    set_property OUTPUT_VALUE 1 $probe
    commit_hw_vio $vio_runtime
    
    after 100
    
    set_property OUTPUT_VALUE 0 $probe
    commit_hw_vio $vio_runtime
    
    puts "✓ Reset выполнен"
}

proc ::vio_dashboard::set_debug_mode {enable} {
    variable connected
    variable vio_runtime
    
    if {!$connected || $vio_runtime eq ""} {
        puts "ОШИБКА: Не подключено или vio_runtime не найден"
        return
    }
    
    set probe [get_hw_probes -of_objects $vio_runtime -filter {NAME =~ "*probe_out2*"}]
    set_property OUTPUT_VALUE $enable $probe
    commit_hw_vio $vio_runtime
    
    if {$enable} {
        puts "✓ Debug mode ВКЛЮЧЕН"
    } else {
        puts "✓ Debug mode ВЫКЛЮЧЕН"
    }
}

proc ::vio_dashboard::set_layer {layer_num} {
    variable connected
    variable vio_runtime
    
    if {!$connected || $vio_runtime eq ""} {
        puts "ОШИБКА: Не подключено или vio_runtime не найден"
        return
    }
    
    set probe [get_hw_probes -of_objects $vio_runtime -filter {NAME =~ "*probe_out4*"}]
    set_property OUTPUT_VALUE $layer_num $probe
    commit_hw_vio $vio_runtime
    
    puts "✓ Мониторинг слоя $layer_num"
}

proc ::vio_dashboard::set_threshold {value} {
    variable connected
    variable vio_runtime
    
    if {!$connected || $vio_runtime eq ""} {
        puts "ОШИБКА: Не подключено или vio_runtime не найден"
        return
    }
    
    set probe [get_hw_probes -of_objects $vio_runtime -filter {NAME =~ "*probe_out5*"}]
    set_property OUTPUT_VALUE $value $probe
    commit_hw_vio $vio_runtime
    
    puts "✓ Threshold установлен: 0x[format %04X $value]"
}

proc ::vio_dashboard::set_simd_enable {mask} {
    variable connected
    variable vio_runtime
    
    if {!$connected || $vio_runtime eq ""} {
        puts "ОШИБКА: Не подключено или vio_runtime не найден"
        return
    }
    
    set probe [get_hw_probes -of_objects $vio_runtime -filter {NAME =~ "*probe_out6*"}]
    set_property OUTPUT_VALUE $mask $probe
    commit_hw_vio $vio_runtime
    
    set count [count_bits $mask]
    puts "✓ SIMD enable: $count/27 блоков (0x[format %07X $mask])"
}

proc ::vio_dashboard::reset_perf_counters {} {
    variable connected
    variable vio_perf
    
    if {!$connected || $vio_perf eq ""} {
        puts "ОШИБКА: Не подключено или vio_perf не найден"
        return
    }
    
    set probe [get_hw_probes -of_objects $vio_perf -filter {NAME =~ "*probe_out0*"}]
    
    # Pulse reset
    set_property OUTPUT_VALUE 1 $probe
    commit_hw_vio $vio_perf
    
    after 10
    
    set_property OUTPUT_VALUE 0 $probe
    commit_hw_vio $vio_perf
    
    puts "✓ Performance counters сброшены"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ═══════════════════════════════════════════════════════════════════════════════

proc ::vio_dashboard::decode_errors {value} {
    variable error_flags
    
    if {$value == 0} {
        return "(OK)"
    }
    
    set errors {}
    dict for {bit name} $error_flags {
        if {$value & $bit} {
            lappend errors $name
        }
    }
    
    return "([join $errors ", "])"
}

proc ::vio_dashboard::count_bits {value} {
    set count 0
    while {$value > 0} {
        if {$value & 1} {
            incr count
        }
        set value [expr {$value >> 1}]
    }
    return $count
}

# ═══════════════════════════════════════════════════════════════════════════════
# АВТОМАТИЧЕСКИЙ МОНИТОРИНГ
# ═══════════════════════════════════════════════════════════════════════════════

proc ::vio_dashboard::monitor {interval_ms} {
    variable connected
    
    if {!$connected} {
        puts "ОШИБКА: Не подключено"
        return
    }
    
    puts "Запуск мониторинга (интервал: ${interval_ms}ms)"
    puts "Нажмите Ctrl+C для остановки"
    puts ""
    
    while {1} {
        status
        after $interval_ms
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# СПРАВКА
# ═══════════════════════════════════════════════════════════════════════════════

proc ::vio_dashboard::help {} {
    puts ""
    puts "═══════════════════════════════════════════════════════════════════════════════"
    puts "VIBEE VIO Dashboard - Справка"
    puts "═══════════════════════════════════════════════════════════════════════════════"
    puts ""
    puts "Подключение:"
    puts "  vio_dashboard::connect              - Подключиться к FPGA"
    puts ""
    puts "Мониторинг:"
    puts "  vio_dashboard::status               - Показать текущий статус"
    puts "  vio_dashboard::monitor 1000         - Автоматический мониторинг (ms)"
    puts ""
    puts "Управление Engine:"
    puts "  vio_dashboard::start_inference      - Запустить inference"
    puts "  vio_dashboard::reset                - Soft reset"
    puts "  vio_dashboard::set_debug_mode 1     - Включить debug mode"
    puts "  vio_dashboard::set_layer 5          - Мониторить слой 5"
    puts ""
    puts "Настройка параметров:"
    puts "  vio_dashboard::set_threshold 0x8000 - Установить threshold"
    puts "  vio_dashboard::set_simd_enable 0x7FFFFFF - Включить все SIMD"
    puts "  vio_dashboard::reset_perf_counters  - Сбросить счётчики"
    puts ""
    puts "═══════════════════════════════════════════════════════════════════════════════"
    puts ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# АВТОЗАПУСК
# ═══════════════════════════════════════════════════════════════════════════════

puts ""
puts "═══════════════════════════════════════════════════════════════════════════════"
puts "VIBEE VIO Dashboard загружен"
puts "═══════════════════════════════════════════════════════════════════════════════"
puts ""
puts "Команды:"
puts "  vio_dashboard::connect   - Подключиться к FPGA"
puts "  vio_dashboard::status    - Показать статус"
puts "  vio_dashboard::help      - Справка"
puts ""
puts "═══════════════════════════════════════════════════════════════════════════════"

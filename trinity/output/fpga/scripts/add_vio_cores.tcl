# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE BitNet - VIO Runtime Control Script
# ═══════════════════════════════════════════════════════════════════════════════
# Добавление расширенных VIO cores для runtime управления BitNet акселератором
#
# Использование: vivado -mode batch -source add_vio_cores.tcl
#
# Священная Формула: V = n × 3^k × π^m × φ^p × e^q
# Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# КОНФИГУРАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════════

set script_dir [file dirname [info script]]
set fpga_dir [file normalize "$script_dir/.."]
set project_dir "$fpga_dir/vivado_zcu104"
set project_name "bitnet_zcu104"
set bd_name "bitnet_system"

puts "═══════════════════════════════════════════════════════════════════════════════"
puts "VIBEE BitNet - Добавление VIO Runtime Control"
puts "═══════════════════════════════════════════════════════════════════════════════"
puts ""
puts "Проект: $project_name"
puts "Block Design: $bd_name"
puts ""

# ═══════════════════════════════════════════════════════════════════════════════
# ОТКРЫТИЕ ПРОЕКТА
# ═══════════════════════════════════════════════════════════════════════════════

if {[file exists "$project_dir/$project_name.xpr"]} {
    open_project "$project_dir/$project_name.xpr"
} else {
    puts "ОШИБКА: Проект не найден: $project_dir/$project_name.xpr"
    puts "Сначала выполните: make bd"
    exit 1
}

open_bd_design [get_files "$bd_name.bd"]

# ═══════════════════════════════════════════════════════════════════════════════
# VIO RUNTIME: ОСНОВНОЙ КОНТРОЛЛЕР
# ═══════════════════════════════════════════════════════════════════════════════

puts "Добавление VIO Runtime Controller..."

# Удаляем старый vio_ctrl если существует
if {[llength [get_bd_cells -quiet vio_ctrl]] > 0} {
    puts "  Удаление старого vio_ctrl..."
    delete_bd_objs [get_bd_cells vio_ctrl]
}

# Создаём расширенный VIO
create_bd_cell -type ip -vlnv xilinx.com:ip:vio:3.0 vio_runtime

set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN {8} \
    CONFIG.C_NUM_PROBE_OUT {8} \
    CONFIG.C_PROBE_IN0_WIDTH {8} \
    CONFIG.C_PROBE_IN1_WIDTH {32} \
    CONFIG.C_PROBE_IN2_WIDTH {8} \
    CONFIG.C_PROBE_IN3_WIDTH {8} \
    CONFIG.C_PROBE_IN4_WIDTH {32} \
    CONFIG.C_PROBE_IN5_WIDTH {8} \
    CONFIG.C_PROBE_IN6_WIDTH {8} \
    CONFIG.C_PROBE_IN7_WIDTH {12} \
    CONFIG.C_PROBE_OUT0_WIDTH {1} \
    CONFIG.C_PROBE_OUT1_WIDTH {1} \
    CONFIG.C_PROBE_OUT2_WIDTH {1} \
    CONFIG.C_PROBE_OUT3_WIDTH {1} \
    CONFIG.C_PROBE_OUT4_WIDTH {8} \
    CONFIG.C_PROBE_OUT5_WIDTH {16} \
    CONFIG.C_PROBE_OUT6_WIDTH {27} \
    CONFIG.C_PROBE_OUT7_WIDTH {4} \
    CONFIG.C_PROBE_OUT0_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT1_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT2_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT3_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT4_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT5_INIT_VAL {0x8000} \
    CONFIG.C_PROBE_OUT6_INIT_VAL {0x7FFFFFF} \
    CONFIG.C_PROBE_OUT7_INIT_VAL {0x0} \
] [get_bd_cells vio_runtime]

# Подключение clock
connect_bd_net [get_bd_pins zynq_ps/pl_clk0] [get_bd_pins vio_runtime/clk]

puts "  ✓ vio_runtime создан (8 inputs, 8 outputs)"

# ═══════════════════════════════════════════════════════════════════════════════
# VIO SIMD: КОНТРОЛЬ 27 SIMD БЛОКОВ
# ═══════════════════════════════════════════════════════════════════════════════

puts "Добавление VIO SIMD Controller..."

create_bd_cell -type ip -vlnv xilinx.com:ip:vio:3.0 vio_simd

set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN {3} \
    CONFIG.C_NUM_PROBE_OUT {3} \
    CONFIG.C_PROBE_IN0_WIDTH {27} \
    CONFIG.C_PROBE_IN1_WIDTH {27} \
    CONFIG.C_PROBE_IN2_WIDTH {27} \
    CONFIG.C_PROBE_OUT0_WIDTH {27} \
    CONFIG.C_PROBE_OUT1_WIDTH {27} \
    CONFIG.C_PROBE_OUT2_WIDTH {8} \
    CONFIG.C_PROBE_OUT0_INIT_VAL {0x7FFFFFF} \
    CONFIG.C_PROBE_OUT1_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT2_INIT_VAL {0x0} \
] [get_bd_cells vio_simd]

# probe_in0 = simd_active[26:0]      - Какие блоки активны
# probe_in1 = simd_stall[26:0]       - Какие блоки в stall
# probe_in2 = simd_error[26:0]       - Какие блоки с ошибкой
# probe_out0 = simd_enable[26:0]     - Включение блоков
# probe_out1 = simd_force_stall[26:0] - Принудительный stall
# probe_out2 = simd_test_pattern[7:0] - Тестовый паттерн

connect_bd_net [get_bd_pins zynq_ps/pl_clk0] [get_bd_pins vio_simd/clk]

puts "  ✓ vio_simd создан (27-bit SIMD control)"

# ═══════════════════════════════════════════════════════════════════════════════
# VIO PERF: PERFORMANCE COUNTERS
# ═══════════════════════════════════════════════════════════════════════════════

puts "Добавление VIO Performance Monitor..."

create_bd_cell -type ip -vlnv xilinx.com:ip:vio:3.0 vio_perf

set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN {8} \
    CONFIG.C_NUM_PROBE_OUT {2} \
    CONFIG.C_PROBE_IN0_WIDTH {32} \
    CONFIG.C_PROBE_IN1_WIDTH {32} \
    CONFIG.C_PROBE_IN2_WIDTH {32} \
    CONFIG.C_PROBE_IN3_WIDTH {32} \
    CONFIG.C_PROBE_IN4_WIDTH {32} \
    CONFIG.C_PROBE_IN5_WIDTH {32} \
    CONFIG.C_PROBE_IN6_WIDTH {32} \
    CONFIG.C_PROBE_IN7_WIDTH {32} \
    CONFIG.C_PROBE_OUT0_WIDTH {1} \
    CONFIG.C_PROBE_OUT1_WIDTH {4} \
    CONFIG.C_PROBE_OUT0_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT1_INIT_VAL {0x0} \
] [get_bd_cells vio_perf]

# probe_in0 = total_cycles[31:0]
# probe_in1 = compute_cycles[31:0]
# probe_in2 = mem_stall_cycles[31:0]
# probe_in3 = axi_wait_cycles[31:0]
# probe_in4 = layer_cycles[31:0]
# probe_in5 = simd_active_cycles[31:0]
# probe_in6 = cache_hits[31:0]
# probe_in7 = cache_misses[31:0]
# probe_out0 = counter_reset
# probe_out1 = counter_select[3:0]

connect_bd_net [get_bd_pins zynq_ps/pl_clk0] [get_bd_pins vio_perf/clk]

puts "  ✓ vio_perf создан (8 performance counters)"

# ═══════════════════════════════════════════════════════════════════════════════
# VIO THERMAL: ТЕМПЕРАТУРНЫЙ МОНИТОРИНГ
# ═══════════════════════════════════════════════════════════════════════════════

puts "Добавление VIO Thermal Monitor..."

create_bd_cell -type ip -vlnv xilinx.com:ip:vio:3.0 vio_thermal

set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN {4} \
    CONFIG.C_NUM_PROBE_OUT {2} \
    CONFIG.C_PROBE_IN0_WIDTH {12} \
    CONFIG.C_PROBE_IN1_WIDTH {12} \
    CONFIG.C_PROBE_IN2_WIDTH {12} \
    CONFIG.C_PROBE_IN3_WIDTH {8} \
    CONFIG.C_PROBE_OUT0_WIDTH {12} \
    CONFIG.C_PROBE_OUT1_WIDTH {12} \
    CONFIG.C_PROBE_OUT0_INIT_VAL {0x960} \
    CONFIG.C_PROBE_OUT1_INIT_VAL {0xA00} \
] [get_bd_cells vio_thermal]

# probe_in0 = temperature[11:0]      - Текущая температура (XADC raw)
# probe_in1 = temp_max[11:0]         - Максимальная за сессию
# probe_in2 = temp_min[11:0]         - Минимальная за сессию
# probe_in3 = thermal_status[7:0]    - Статус (OK/WARN/CRIT)
# probe_out0 = temp_warn_threshold[11:0]  - Порог предупреждения (~85°C)
# probe_out1 = temp_crit_threshold[11:0]  - Критический порог (~95°C)

connect_bd_net [get_bd_pins zynq_ps/pl_clk0] [get_bd_pins vio_thermal/clk]

puts "  ✓ vio_thermal создан (temperature monitoring)"

# ═══════════════════════════════════════════════════════════════════════════════
# XADC ДЛЯ ТЕМПЕРАТУРЫ
# ═══════════════════════════════════════════════════════════════════════════════

puts "Добавление XADC Wizard..."

# Проверяем, есть ли уже XADC
if {[llength [get_bd_cells -quiet xadc_wiz_0]] == 0} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:xadc_wiz:3.3 xadc_wiz_0
    
    set_property -dict [list \
        CONFIG.INTERFACE_SELECTION {Enable_AXI} \
        CONFIG.ENABLE_RESET {false} \
        CONFIG.CHANNEL_ENABLE_TEMPERATURE {true} \
        CONFIG.CHANNEL_ENABLE_VCCINT {true} \
        CONFIG.CHANNEL_ENABLE_VCCAUX {true} \
        CONFIG.CHANNEL_ENABLE_VP_VN {false} \
        CONFIG.SEQUENCER_MODE {Continuous} \
        CONFIG.ENABLE_TEMP_BUS {true} \
    ] [get_bd_cells xadc_wiz_0]
    
    # Подключение к AXI interconnect
    apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
        Clk_master {/zynq_ps/pl_clk0}
        Clk_slave {Auto}
        Clk_xbar {Auto}
        Master {/zynq_ps/M_AXI_HPM0_FPD}
        Slave {/xadc_wiz_0/s_axi_lite}
        ddr_seg {Auto}
        intc_ip {/axi_interconnect_ctrl}
        master_apm {0}
    } [get_bd_intf_pins xadc_wiz_0/s_axi_lite]
    
    puts "  ✓ xadc_wiz_0 создан"
} else {
    puts "  ✓ xadc_wiz_0 уже существует"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ВАЛИДАЦИЯ И СОХРАНЕНИЕ
# ═══════════════════════════════════════════════════════════════════════════════

puts ""
puts "Валидация Block Design..."
validate_bd_design

puts "Сохранение Block Design..."
save_bd_design

# ═══════════════════════════════════════════════════════════════════════════════
# ОТЧЁТ О РЕСУРСАХ
# ═══════════════════════════════════════════════════════════════════════════════

puts ""
puts "═══════════════════════════════════════════════════════════════════════════════"
puts "VIO RUNTIME CONTROL ДОБАВЛЕН УСПЕШНО"
puts "═══════════════════════════════════════════════════════════════════════════════"
puts ""
puts "Добавленные компоненты:"
puts ""
puts "  ┌─────────────────────────────────────────────────────────────────────────┐"
puts "  │ VIO Core        │ Inputs │ Outputs │ Назначение                        │"
puts "  ├─────────────────────────────────────────────────────────────────────────┤"
puts "  │ vio_runtime     │   8    │    8    │ Основной контроль Engine          │"
puts "  │ vio_simd        │   3    │    3    │ Управление 27 SIMD блоками        │"
puts "  │ vio_perf        │   8    │    2    │ Performance counters              │"
puts "  │ vio_thermal     │   4    │    2    │ Температурный мониторинг          │"
puts "  └─────────────────────────────────────────────────────────────────────────┘"
puts ""
puts "Оценка ресурсов:"
puts "  - LUTs: ~1,600"
puts "  - FFs:  ~1,200"
puts "  - BRAM: 0"
puts ""
puts "VIO Probe Mapping:"
puts ""
puts "  vio_runtime:"
puts "    IN:  engine_status, inference_count, error_flags, current_layer,"
puts "         cycle_count, utilization, fifo_status, temperature"
puts "    OUT: force_start, force_reset, debug_mode, inject_error,"
puts "         layer_select, threshold_adj, simd_enable, perf_counter_sel"
puts ""
puts "  vio_simd:"
puts "    IN:  simd_active[26:0], simd_stall[26:0], simd_error[26:0]"
puts "    OUT: simd_enable[26:0], simd_force_stall[26:0], simd_test_pattern[7:0]"
puts ""
puts "  vio_perf:"
puts "    IN:  total_cycles, compute_cycles, mem_stall_cycles, axi_wait_cycles,"
puts "         layer_cycles, simd_active_cycles, cache_hits, cache_misses"
puts "    OUT: counter_reset, counter_select[3:0]"
puts ""
puts "  vio_thermal:"
puts "    IN:  temperature, temp_max, temp_min, thermal_status"
puts "    OUT: temp_warn_threshold, temp_crit_threshold"
puts ""
puts "Следующие шаги:"
puts "  1. Подключите VIO probes к RTL сигналам"
puts "  2. Запустите синтез: make synth"
puts "  3. Используйте vio_dashboard.tcl для управления"
puts ""
puts "═══════════════════════════════════════════════════════════════════════════════"

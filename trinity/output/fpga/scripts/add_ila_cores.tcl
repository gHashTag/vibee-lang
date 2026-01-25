# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE BitNet - ILA Debug Cores Addition Script
# ═══════════════════════════════════════════════════════════════════════════════
# Добавление ILA и VIO cores для отладки BitNet акселератора
#
# Использование: 
#   vivado -mode batch -source add_ila_cores.tcl
#   или в Vivado GUI: source add_ila_cores.tcl
#
# Священная Формула: V = n × 3^k × π^m × φ^p × e^q
# Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

puts "═══════════════════════════════════════════════════════════════════════════════"
puts "VIBEE BitNet - Добавление ILA Debug Cores"
puts "═══════════════════════════════════════════════════════════════════════════════"

# ═══════════════════════════════════════════════════════════════════════════════
# КОНФИГУРАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════════

# Глубина захвата по умолчанию
set default_depth 4096

# Проверка открытого проекта
if {[current_project] eq ""} {
    puts "ОШИБКА: Нет открытого проекта!"
    puts "Откройте проект: open_project <path>/bitnet_zcu104.xpr"
    return
}

# Проверка открытого block design
if {[current_bd_design] eq ""} {
    puts "Открытие Block Design..."
    open_bd_design [get_files *.bd]
}

# ═══════════════════════════════════════════════════════════════════════════════
# ILA 1: AXI-LITE CONTROL INTERFACE
# ═══════════════════════════════════════════════════════════════════════════════

puts ""
puts "Добавление ILA для AXI-Lite интерфейса..."

create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila_axi_lite

set_property -dict [list \
    CONFIG.C_MONITOR_TYPE {AXI} \
    CONFIG.C_SLOT_0_AXI_PROTOCOL {AXI4LITE} \
    CONFIG.C_ENABLE_ILA_AXI_MON {true} \
    CONFIG.C_DATA_DEPTH $default_depth \
    CONFIG.C_NUM_OF_PROBES {0} \
    CONFIG.C_SLOT_0_AXI_DATA_WIDTH {32} \
    CONFIG.C_SLOT_0_AXI_ADDR_WIDTH {8} \
    CONFIG.ALL_PROBE_SAME_MU_CNT {4} \
] [get_bd_cells ila_axi_lite]

# Подключение к AXI-Lite интерфейсу BitNet
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_ctrl/M00_AXI] \
    [get_bd_intf_pins ila_axi_lite/SLOT_0_AXI]

# Подключение clock
connect_bd_net [get_bd_pins zynq_ps/pl_clk0] [get_bd_pins ila_axi_lite/clk]

# ═══════════════════════════════════════════════════════════════════════════════
# ILA 2: AXI-STREAM INPUT
# ═══════════════════════════════════════════════════════════════════════════════

puts "Добавление ILA для AXI-Stream Input..."

create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila_axis_input

set_property -dict [list \
    CONFIG.C_MONITOR_TYPE {AXI} \
    CONFIG.C_SLOT_0_AXI_PROTOCOL {AXI4S} \
    CONFIG.C_ENABLE_ILA_AXI_MON {true} \
    CONFIG.C_DATA_DEPTH $default_depth \
    CONFIG.C_SLOT_0_AXIS_TDATA_WIDTH {64} \
    CONFIG.ALL_PROBE_SAME_MU_CNT {4} \
] [get_bd_cells ila_axis_input]

# Подключение к входному AXI-Stream
connect_bd_intf_net [get_bd_intf_pins axi_dma_input/M_AXIS_MM2S] \
    [get_bd_intf_pins ila_axis_input/SLOT_0_AXIS]

connect_bd_net [get_bd_pins zynq_ps/pl_clk0] [get_bd_pins ila_axis_input/clk]

# ═══════════════════════════════════════════════════════════════════════════════
# ILA 3: AXI-STREAM OUTPUT
# ═══════════════════════════════════════════════════════════════════════════════

puts "Добавление ILA для AXI-Stream Output..."

create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila_axis_output

set_property -dict [list \
    CONFIG.C_MONITOR_TYPE {AXI} \
    CONFIG.C_SLOT_0_AXI_PROTOCOL {AXI4S} \
    CONFIG.C_ENABLE_ILA_AXI_MON {true} \
    CONFIG.C_DATA_DEPTH $default_depth \
    CONFIG.C_SLOT_0_AXIS_TDATA_WIDTH {64} \
    CONFIG.ALL_PROBE_SAME_MU_CNT {4} \
] [get_bd_cells ila_axis_output]

# Подключение к выходному AXI-Stream
connect_bd_intf_net [get_bd_intf_pins bitnet_accel/m_axis_output] \
    [get_bd_intf_pins ila_axis_output/SLOT_0_AXIS]

connect_bd_net [get_bd_pins zynq_ps/pl_clk0] [get_bd_pins ila_axis_output/clk]

# ═══════════════════════════════════════════════════════════════════════════════
# ILA 4: BITNET ENGINE INTERNAL SIGNALS
# ═══════════════════════════════════════════════════════════════════════════════

puts "Добавление ILA для BitNet Engine..."

create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila_engine

set_property -dict [list \
    CONFIG.C_MONITOR_TYPE {Native} \
    CONFIG.C_DATA_DEPTH {8192} \
    CONFIG.C_NUM_OF_PROBES {10} \
    CONFIG.C_PROBE0_WIDTH {1} \
    CONFIG.C_PROBE1_WIDTH {1} \
    CONFIG.C_PROBE2_WIDTH {1} \
    CONFIG.C_PROBE3_WIDTH {1} \
    CONFIG.C_PROBE4_WIDTH {8} \
    CONFIG.C_PROBE5_WIDTH {32} \
    CONFIG.C_PROBE6_WIDTH {32} \
    CONFIG.C_PROBE7_WIDTH {1} \
    CONFIG.C_PROBE8_WIDTH {16} \
    CONFIG.C_PROBE9_WIDTH {54} \
    CONFIG.ALL_PROBE_SAME_MU_CNT {4} \
    CONFIG.C_ENABLE_ILA_AXI_MON {false} \
    CONFIG.C_ADV_TRIGGER {true} \
] [get_bd_cells ila_engine]

# Подключение clock
connect_bd_net [get_bd_pins zynq_ps/pl_clk0] [get_bd_pins ila_engine/clk]

# Примечание: probe сигналы подключаются через mark_debug.xdc
# probe0 = engine_start
# probe1 = engine_busy
# probe2 = engine_done
# probe3 = engine_error
# probe4 = current_layer[7:0]
# probe5 = inference_count[31:0]
# probe6 = cycle_count[31:0]
# probe7 = simd_active
# probe8 = weight_addr[15:0]
# probe9 = weight_data[53:0]

# ═══════════════════════════════════════════════════════════════════════════════
# ILA 5: PERFORMANCE COUNTERS
# ═══════════════════════════════════════════════════════════════════════════════

puts "Добавление ILA для Performance Counters..."

create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila_perf

set_property -dict [list \
    CONFIG.C_MONITOR_TYPE {Native} \
    CONFIG.C_DATA_DEPTH {2048} \
    CONFIG.C_NUM_OF_PROBES {7} \
    CONFIG.C_PROBE0_WIDTH {64} \
    CONFIG.C_PROBE1_WIDTH {32} \
    CONFIG.C_PROBE2_WIDTH {64} \
    CONFIG.C_PROBE3_WIDTH {32} \
    CONFIG.C_PROBE4_WIDTH {32} \
    CONFIG.C_PROBE5_WIDTH {32} \
    CONFIG.C_PROBE6_WIDTH {8} \
    CONFIG.ALL_PROBE_SAME_MU_CNT {2} \
    CONFIG.C_ENABLE_ILA_AXI_MON {false} \
] [get_bd_cells ila_perf]

connect_bd_net [get_bd_pins zynq_ps/pl_clk0] [get_bd_pins ila_perf/clk]

# ═══════════════════════════════════════════════════════════════════════════════
# VIO: VIRTUAL I/O ДЛЯ RUNTIME УПРАВЛЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════════

puts "Добавление VIO для runtime управления..."

create_bd_cell -type ip -vlnv xilinx.com:ip:vio:3.0 vio_ctrl

set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN {3} \
    CONFIG.C_NUM_PROBE_OUT {4} \
    CONFIG.C_PROBE_IN0_WIDTH {8} \
    CONFIG.C_PROBE_IN1_WIDTH {32} \
    CONFIG.C_PROBE_IN2_WIDTH {8} \
    CONFIG.C_PROBE_OUT0_WIDTH {1} \
    CONFIG.C_PROBE_OUT1_WIDTH {1} \
    CONFIG.C_PROBE_OUT2_WIDTH {1} \
    CONFIG.C_PROBE_OUT3_WIDTH {1} \
    CONFIG.C_PROBE_OUT0_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT1_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT2_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT3_INIT_VAL {0x0} \
] [get_bd_cells vio_ctrl]

connect_bd_net [get_bd_pins zynq_ps/pl_clk0] [get_bd_pins vio_ctrl/clk]

# VIO inputs (readback):
# probe_in0 = engine_status[7:0]
# probe_in1 = inference_count[31:0]
# probe_in2 = error_flags[7:0]

# VIO outputs (control):
# probe_out0 = force_start
# probe_out1 = force_reset
# probe_out2 = debug_mode
# probe_out3 = inject_error

# ═══════════════════════════════════════════════════════════════════════════════
# DEBUG HUB
# ═══════════════════════════════════════════════════════════════════════════════

puts "Добавление Debug Hub..."

# Debug Hub создается автоматически при добавлении ILA/VIO
# Но можно явно создать для контроля

create_bd_cell -type ip -vlnv xilinx.com:ip:dbg_hub:2.0 dbg_hub_0

set_property -dict [list \
    CONFIG.C_NUM_BSCAN_MASTER_PORTS {1} \
    CONFIG.C_ENABLE_CLK_DIVIDER {false} \
] [get_bd_cells dbg_hub_0]

connect_bd_net [get_bd_pins zynq_ps/pl_clk0] [get_bd_pins dbg_hub_0/clk]

# ═══════════════════════════════════════════════════════════════════════════════
# ВАЛИДАЦИЯ И СОХРАНЕНИЕ
# ═══════════════════════════════════════════════════════════════════════════════

puts ""
puts "Валидация Block Design..."
validate_bd_design

puts "Сохранение Block Design..."
save_bd_design

# ═══════════════════════════════════════════════════════════════════════════════
# ЗАВЕРШЕНИЕ
# ═══════════════════════════════════════════════════════════════════════════════

puts ""
puts "═══════════════════════════════════════════════════════════════════════════════"
puts "ILA DEBUG CORES ДОБАВЛЕНЫ УСПЕШНО"
puts "═══════════════════════════════════════════════════════════════════════════════"
puts ""
puts "Добавленные компоненты:"
puts "  - ila_axi_lite:    AXI-Lite транзакции (4096 samples)"
puts "  - ila_axis_input:  AXI-Stream вход (4096 samples)"
puts "  - ila_axis_output: AXI-Stream выход (4096 samples)"
puts "  - ila_engine:      BitNet Engine (8192 samples)"
puts "  - ila_perf:        Performance Counters (2048 samples)"
puts "  - vio_ctrl:        Runtime управление"
puts "  - dbg_hub_0:       Debug Hub"
puts ""
puts "Дополнительные ресурсы:"
puts "  - LUTs: ~3,200"
puts "  - FFs:  ~2,450"
puts "  - BRAM: ~11"
puts ""
puts "Следующие шаги:"
puts "  1. Добавьте mark_debug.xdc для probe сигналов"
puts "  2. Запустите синтез: make synth"
puts "  3. Откройте Hardware Manager для отладки"
puts ""
puts "φ² + 1/φ² = 3 | PHOENIX = 999"
puts "═══════════════════════════════════════════════════════════════════════════════"

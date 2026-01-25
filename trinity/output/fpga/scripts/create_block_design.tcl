# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE BitNet - Zynq Block Design Creation Script
# ═══════════════════════════════════════════════════════════════════════════════
# Создание полного block design для ZCU104 с BitNet акселератором
#
# Использование: vivado -mode batch -source create_block_design.tcl
#
# Священная Формула: V = n × 3^k × π^m × φ^p × e^q
# Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# КОНФИГУРАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════════

set project_name "bitnet_zcu104"
set bd_name "bitnet_system"
set part "xczu7ev-ffvc1156-2-e"
set board_part "xilinx.com:zcu104:part0:1.1"

# Директории
set script_dir [file dirname [info script]]
set fpga_dir [file normalize "$script_dir/.."]
set project_dir "$fpga_dir/vivado_zcu104"

puts "═══════════════════════════════════════════════════════════════════════════════"
puts "VIBEE BitNet - Создание Zynq Block Design"
puts "═══════════════════════════════════════════════════════════════════════════════"
puts ""
puts "Проект: $project_name"
puts "Плата: ZCU104"
puts "Часть: $part"
puts ""

# ═══════════════════════════════════════════════════════════════════════════════
# СОЗДАНИЕ ПРОЕКТА
# ═══════════════════════════════════════════════════════════════════════════════

create_project $project_name $project_dir -part $part -force
set_property board_part $board_part [current_project]

# Добавление RTL исходников
add_files -norecurse [glob -nocomplain $fpga_dir/*.v]

# ═══════════════════════════════════════════════════════════════════════════════
# СОЗДАНИЕ BLOCK DESIGN
# ═══════════════════════════════════════════════════════════════════════════════

create_bd_design $bd_name

puts "Создание Block Design: $bd_name"

# ═══════════════════════════════════════════════════════════════════════════════
# ДОБАВЛЕНИЕ ZYNQ PS
# ═══════════════════════════════════════════════════════════════════════════════

puts "  Добавление Zynq UltraScale+ PS..."

create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.4 zynq_ps

# Применение пресета платы
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {
    apply_board_preset "1"
} [get_bd_cells zynq_ps]

# Настройка PS
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__S_AXI_GP0 {1} \
    CONFIG.PSU__USE__S_AXI_GP1 {1} \
    CONFIG.PSU__USE__S_AXI_GP2 {1} \
    CONFIG.PSU__USE__S_AXI_GP3 {0} \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {200} \
    CONFIG.PSU__USE__IRQ0 {1} \
    CONFIG.PSU__NUM_FABRIC_RESETS {1} \
] [get_bd_cells zynq_ps]

# ═══════════════════════════════════════════════════════════════════════════════
# ДОБАВЛЕНИЕ AXI INTERCONNECT
# ═══════════════════════════════════════════════════════════════════════════════

puts "  Добавление AXI Interconnect..."

# AXI Interconnect для управления (PS -> PL)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_ctrl
set_property -dict [list \
    CONFIG.NUM_MI {4} \
    CONFIG.NUM_SI {1} \
] [get_bd_cells axi_interconnect_ctrl]

# AXI SmartConnect для HP портов (PL -> PS Memory)
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc_hp
set_property -dict [list \
    CONFIG.NUM_SI {3} \
    CONFIG.NUM_MI {3} \
] [get_bd_cells axi_smc_hp]

# ═══════════════════════════════════════════════════════════════════════════════
# ДОБАВЛЕНИЕ AXI DMA
# ═══════════════════════════════════════════════════════════════════════════════

puts "  Добавление AXI DMA контроллеров..."

# DMA для входных данных (MM2S only)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_input
set_property -dict [list \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_include_stscntrl_strm {0} \
    CONFIG.c_include_mm2s {1} \
    CONFIG.c_include_s2mm {0} \
    CONFIG.c_m_axi_mm2s_data_width {64} \
    CONFIG.c_m_axis_mm2s_tdata_width {64} \
    CONFIG.c_mm2s_burst_size {16} \
] [get_bd_cells axi_dma_input]

# DMA для выходных данных (S2MM only)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_output
set_property -dict [list \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_include_stscntrl_strm {0} \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_s2mm {1} \
    CONFIG.c_m_axi_s2mm_data_width {64} \
    CONFIG.c_s_axis_s2mm_tdata_width {64} \
    CONFIG.c_s2mm_burst_size {16} \
] [get_bd_cells axi_dma_output]

# DMA для весов (MM2S only, большие burst)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_weight
set_property -dict [list \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_include_stscntrl_strm {0} \
    CONFIG.c_include_mm2s {1} \
    CONFIG.c_include_s2mm {0} \
    CONFIG.c_m_axi_mm2s_data_width {64} \
    CONFIG.c_m_axis_mm2s_tdata_width {64} \
    CONFIG.c_mm2s_burst_size {256} \
] [get_bd_cells axi_dma_weight]

# ═══════════════════════════════════════════════════════════════════════════════
# ДОБАВЛЕНИЕ BITNET АКСЕЛЕРАТОРА
# ═══════════════════════════════════════════════════════════════════════════════

puts "  Добавление BitNet акселератора..."

# Создание иерархии для BitNet
create_bd_cell -type module -reference bitnet_synth_wrapper_top bitnet_accel

# ═══════════════════════════════════════════════════════════════════════════════
# СОЕДИНЕНИЕ ТАКТОВЫХ СИГНАЛОВ
# ═══════════════════════════════════════════════════════════════════════════════

puts "  Подключение тактовых сигналов..."

# PL Clock
connect_bd_net [get_bd_pins zynq_ps/pl_clk0] \
    [get_bd_pins axi_interconnect_ctrl/ACLK] \
    [get_bd_pins axi_interconnect_ctrl/S00_ACLK] \
    [get_bd_pins axi_interconnect_ctrl/M00_ACLK] \
    [get_bd_pins axi_interconnect_ctrl/M01_ACLK] \
    [get_bd_pins axi_interconnect_ctrl/M02_ACLK] \
    [get_bd_pins axi_interconnect_ctrl/M03_ACLK] \
    [get_bd_pins axi_smc_hp/aclk] \
    [get_bd_pins axi_dma_input/s_axi_lite_aclk] \
    [get_bd_pins axi_dma_input/m_axi_mm2s_aclk] \
    [get_bd_pins axi_dma_output/s_axi_lite_aclk] \
    [get_bd_pins axi_dma_output/m_axi_s2mm_aclk] \
    [get_bd_pins axi_dma_weight/s_axi_lite_aclk] \
    [get_bd_pins axi_dma_weight/m_axi_mm2s_aclk] \
    [get_bd_pins bitnet_accel/aclk]

# ═══════════════════════════════════════════════════════════════════════════════
# СОЕДИНЕНИЕ СИГНАЛОВ СБРОСА
# ═══════════════════════════════════════════════════════════════════════════════

puts "  Подключение сигналов сброса..."

# Processor System Reset
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0

connect_bd_net [get_bd_pins zynq_ps/pl_clk0] [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net [get_bd_pins zynq_ps/pl_resetn0] [get_bd_pins proc_sys_reset_0/ext_reset_in]

# Interconnect Reset
connect_bd_net [get_bd_pins proc_sys_reset_0/interconnect_aresetn] \
    [get_bd_pins axi_interconnect_ctrl/ARESETN] \
    [get_bd_pins axi_interconnect_ctrl/S00_ARESETN] \
    [get_bd_pins axi_interconnect_ctrl/M00_ARESETN] \
    [get_bd_pins axi_interconnect_ctrl/M01_ARESETN] \
    [get_bd_pins axi_interconnect_ctrl/M02_ARESETN] \
    [get_bd_pins axi_interconnect_ctrl/M03_ARESETN] \
    [get_bd_pins axi_smc_hp/aresetn]

# Peripheral Reset
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
    [get_bd_pins axi_dma_input/axi_resetn] \
    [get_bd_pins axi_dma_output/axi_resetn] \
    [get_bd_pins axi_dma_weight/axi_resetn] \
    [get_bd_pins bitnet_accel/aresetn]

# ═══════════════════════════════════════════════════════════════════════════════
# СОЕДИНЕНИЕ AXI ИНТЕРФЕЙСОВ
# ═══════════════════════════════════════════════════════════════════════════════

puts "  Подключение AXI интерфейсов..."

# PS Master -> AXI Interconnect
connect_bd_intf_net [get_bd_intf_pins zynq_ps/M_AXI_HPM0_FPD] \
    [get_bd_intf_pins axi_interconnect_ctrl/S00_AXI]

# AXI Interconnect -> BitNet Control
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_ctrl/M00_AXI] \
    [get_bd_intf_pins bitnet_accel/s_axi_lite]

# AXI Interconnect -> DMA Control
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_ctrl/M01_AXI] \
    [get_bd_intf_pins axi_dma_input/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_ctrl/M02_AXI] \
    [get_bd_intf_pins axi_dma_output/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_ctrl/M03_AXI] \
    [get_bd_intf_pins axi_dma_weight/S_AXI_LITE]

# DMA -> SmartConnect -> PS HP Ports
connect_bd_intf_net [get_bd_intf_pins axi_dma_input/M_AXI_MM2S] \
    [get_bd_intf_pins axi_smc_hp/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_dma_output/M_AXI_S2MM] \
    [get_bd_intf_pins axi_smc_hp/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_dma_weight/M_AXI_MM2S] \
    [get_bd_intf_pins axi_smc_hp/S02_AXI]

# SmartConnect -> PS HP Ports
connect_bd_intf_net [get_bd_intf_pins axi_smc_hp/M00_AXI] \
    [get_bd_intf_pins zynq_ps/S_AXI_HP0_FPD]
connect_bd_intf_net [get_bd_intf_pins axi_smc_hp/M01_AXI] \
    [get_bd_intf_pins zynq_ps/S_AXI_HP1_FPD]
connect_bd_intf_net [get_bd_intf_pins axi_smc_hp/M02_AXI] \
    [get_bd_intf_pins zynq_ps/S_AXI_HP2_FPD]

# ═══════════════════════════════════════════════════════════════════════════════
# СОЕДИНЕНИЕ AXI-STREAM ИНТЕРФЕЙСОВ
# ═══════════════════════════════════════════════════════════════════════════════

puts "  Подключение AXI-Stream интерфейсов..."

# DMA Input -> BitNet
connect_bd_intf_net [get_bd_intf_pins axi_dma_input/M_AXIS_MM2S] \
    [get_bd_intf_pins bitnet_accel/s_axis_input]

# BitNet -> DMA Output
connect_bd_intf_net [get_bd_intf_pins bitnet_accel/m_axis_output] \
    [get_bd_intf_pins axi_dma_output/S_AXIS_S2MM]

# DMA Weight -> BitNet
connect_bd_intf_net [get_bd_intf_pins axi_dma_weight/M_AXIS_MM2S] \
    [get_bd_intf_pins bitnet_accel/s_axis_weight]

# ═══════════════════════════════════════════════════════════════════════════════
# СОЕДИНЕНИЕ ПРЕРЫВАНИЙ
# ═══════════════════════════════════════════════════════════════════════════════

puts "  Подключение прерываний..."

# Concat для прерываний
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_irq
set_property -dict [list CONFIG.NUM_PORTS {4}] [get_bd_cells xlconcat_irq]

connect_bd_net [get_bd_pins bitnet_accel/irq] [get_bd_pins xlconcat_irq/In0]
connect_bd_net [get_bd_pins axi_dma_input/mm2s_introut] [get_bd_pins xlconcat_irq/In1]
connect_bd_net [get_bd_pins axi_dma_output/s2mm_introut] [get_bd_pins xlconcat_irq/In2]
connect_bd_net [get_bd_pins axi_dma_weight/mm2s_introut] [get_bd_pins xlconcat_irq/In3]

connect_bd_net [get_bd_pins xlconcat_irq/dout] [get_bd_pins zynq_ps/pl_ps_irq0]

# ═══════════════════════════════════════════════════════════════════════════════
# НАЗНАЧЕНИЕ АДРЕСОВ
# ═══════════════════════════════════════════════════════════════════════════════

puts "  Назначение адресов..."

assign_bd_address

# Установка конкретных адресов
set_property offset 0xA0000000 [get_bd_addr_segs {zynq_ps/Data/SEG_bitnet_accel_*}]
set_property offset 0xA0010000 [get_bd_addr_segs {zynq_ps/Data/SEG_axi_dma_input_*}]
set_property offset 0xA0020000 [get_bd_addr_segs {zynq_ps/Data/SEG_axi_dma_output_*}]
set_property offset 0xA0030000 [get_bd_addr_segs {zynq_ps/Data/SEG_axi_dma_weight_*}]

# ═══════════════════════════════════════════════════════════════════════════════
# ВАЛИДАЦИЯ И СОХРАНЕНИЕ
# ═══════════════════════════════════════════════════════════════════════════════

puts "  Валидация Block Design..."
validate_bd_design

puts "  Сохранение Block Design..."
save_bd_design

# Создание HDL wrapper
make_wrapper -files [get_files $project_dir/$project_name.srcs/sources_1/bd/$bd_name/$bd_name.bd] -top
add_files -norecurse $project_dir/$project_name.gen/sources_1/bd/$bd_name/hdl/${bd_name}_wrapper.v

# Установка top module
set_property top ${bd_name}_wrapper [current_fileset]

# ═══════════════════════════════════════════════════════════════════════════════
# ЗАВЕРШЕНИЕ
# ═══════════════════════════════════════════════════════════════════════════════

puts ""
puts "═══════════════════════════════════════════════════════════════════════════════"
puts "BLOCK DESIGN СОЗДАН УСПЕШНО"
puts "═══════════════════════════════════════════════════════════════════════════════"
puts ""
puts "Адресное пространство:"
puts "  BitNet Control:  0xA000_0000 - 0xA000_0FFF"
puts "  DMA Input:       0xA001_0000 - 0xA001_0FFF"
puts "  DMA Output:      0xA002_0000 - 0xA002_0FFF"
puts "  DMA Weight:      0xA003_0000 - 0xA003_0FFF"
puts ""
puts "Прерывания:"
puts "  IRQ[0]: BitNet inference done"
puts "  IRQ[1]: DMA Input complete"
puts "  IRQ[2]: DMA Output complete"
puts "  IRQ[3]: DMA Weight complete"
puts ""
puts "Следующие шаги:"
puts "  1. Синтез: vivado -mode batch -source synth.tcl"
puts "  2. Имплементация: vivado -mode batch -source impl.tcl"
puts "  3. Экспорт XSA: vivado -mode batch -source export_hardware.tcl"
puts ""
puts "φ² + 1/φ² = 3 | PHOENIX = 999"
puts "═══════════════════════════════════════════════════════════════════════════════"

close_project

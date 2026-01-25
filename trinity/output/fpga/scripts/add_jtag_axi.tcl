# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE BitNet - JTAG-to-AXI Master Integration Script
# ═══════════════════════════════════════════════════════════════════════════════
# Добавление JTAG-to-AXI Master для прямого доступа к памяти и регистрам
# через Vivado Hardware Manager
#
# Использование: 
#   vivado -mode batch -source add_jtag_axi.tcl
#   или в Vivado GUI: source add_jtag_axi.tcl
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

# JTAG-AXI конфигурация
set JTAG_AXI_DATA_WIDTH 32
set JTAG_AXI_ADDR_WIDTH 32
set JTAG_AXI_PROTOCOL 2  ;# 0=AXI4LITE, 1=AXI3, 2=AXI4

puts "═══════════════════════════════════════════════════════════════════════════════"
puts "VIBEE BitNet - Добавление JTAG-to-AXI Master"
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
    puts "Сначала выполните: source create_block_design.tcl"
    exit 1
}

# Открываем Block Design
open_bd_design [get_files "$bd_name.bd"]

# ═══════════════════════════════════════════════════════════════════════════════
# ПРОВЕРКА СУЩЕСТВУЮЩЕГО JTAG-AXI
# ═══════════════════════════════════════════════════════════════════════════════

if {[llength [get_bd_cells -quiet jtag_axi_debug]] > 0} {
    puts "ПРЕДУПРЕЖДЕНИЕ: jtag_axi_debug уже существует"
    puts "Удаление старого экземпляра..."
    delete_bd_objs [get_bd_cells jtag_axi_debug]
}

# ═══════════════════════════════════════════════════════════════════════════════
# СОЗДАНИЕ JTAG-TO-AXI MASTER
# ═══════════════════════════════════════════════════════════════════════════════

puts "Создание JTAG-to-AXI Master IP..."

create_bd_cell -type ip -vlnv xilinx.com:ip:jtag_axi:1.2 jtag_axi_debug

set_property -dict [list \
    CONFIG.PROTOCOL $JTAG_AXI_PROTOCOL \
    CONFIG.M_AXI_DATA_WIDTH $JTAG_AXI_DATA_WIDTH \
    CONFIG.M_AXI_ADDR_WIDTH $JTAG_AXI_ADDR_WIDTH \
    CONFIG.M_AXI_ID_WIDTH {1} \
    CONFIG.RD_TXN_QUEUE_LENGTH {4} \
    CONFIG.WR_TXN_QUEUE_LENGTH {4} \
] [get_bd_cells jtag_axi_debug]

puts "  ✓ jtag_axi_debug создан"

# ═══════════════════════════════════════════════════════════════════════════════
# РАСШИРЕНИЕ AXI INTERCONNECT
# ═══════════════════════════════════════════════════════════════════════════════

puts "Расширение AXI Interconnect..."

# Получаем текущее число SI портов
set current_si [get_property CONFIG.NUM_SI [get_bd_cells axi_interconnect_ctrl]]
set new_si [expr {$current_si + 1}]
set new_si_port "S0${current_si}"

puts "  Текущее NUM_SI: $current_si"
puts "  Новое NUM_SI: $new_si"
puts "  Новый порт: ${new_si_port}_AXI"

# Расширяем interconnect
set_property CONFIG.NUM_SI $new_si [get_bd_cells axi_interconnect_ctrl]

puts "  ✓ AXI Interconnect расширен"

# ═══════════════════════════════════════════════════════════════════════════════
# ПОДКЛЮЧЕНИЕ CLOCK И RESET
# ═══════════════════════════════════════════════════════════════════════════════

puts "Подключение clock и reset..."

# Clock для JTAG-AXI
connect_bd_net [get_bd_pins zynq_ps/pl_clk0] \
    [get_bd_pins jtag_axi_debug/aclk]

# Reset для JTAG-AXI
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
    [get_bd_pins jtag_axi_debug/aresetn]

# Clock для нового порта interconnect
connect_bd_net [get_bd_pins zynq_ps/pl_clk0] \
    [get_bd_pins axi_interconnect_ctrl/${new_si_port}_ACLK]

# Reset для нового порта interconnect
connect_bd_net [get_bd_pins proc_sys_reset_0/interconnect_aresetn] \
    [get_bd_pins axi_interconnect_ctrl/${new_si_port}_ARESETN]

puts "  ✓ Clock и reset подключены"

# ═══════════════════════════════════════════════════════════════════════════════
# ПОДКЛЮЧЕНИЕ AXI ИНТЕРФЕЙСА
# ═══════════════════════════════════════════════════════════════════════════════

puts "Подключение AXI интерфейса..."

connect_bd_intf_net [get_bd_intf_pins jtag_axi_debug/M_AXI] \
    [get_bd_intf_pins axi_interconnect_ctrl/${new_si_port}_AXI]

puts "  ✓ AXI интерфейс подключен"

# ═══════════════════════════════════════════════════════════════════════════════
# НАЗНАЧЕНИЕ АДРЕСОВ
# ═══════════════════════════════════════════════════════════════════════════════

puts "Назначение адресов..."

# Автоматическое назначение адресов для JTAG-AXI
assign_bd_address -target_address_space /jtag_axi_debug/Data

# Установка конкретных диапазонов
set addr_segs [get_bd_addr_segs -of_objects [get_bd_addr_spaces jtag_axi_debug/Data]]

foreach seg $addr_segs {
    set seg_name [get_property NAME $seg]
    puts "  Сегмент: $seg_name"
}

puts "  ✓ Адреса назначены"

# ═══════════════════════════════════════════════════════════════════════════════
# ВАЛИДАЦИЯ И СОХРАНЕНИЕ
# ═══════════════════════════════════════════════════════════════════════════════

puts ""
puts "Валидация Block Design..."
validate_bd_design

puts "Сохранение Block Design..."
save_bd_design

# ═══════════════════════════════════════════════════════════════════════════════
# ОТЧЁТ
# ═══════════════════════════════════════════════════════════════════════════════

puts ""
puts "═══════════════════════════════════════════════════════════════════════════════"
puts "JTAG-TO-AXI MASTER ДОБАВЛЕН УСПЕШНО"
puts "═══════════════════════════════════════════════════════════════════════════════"
puts ""
puts "Конфигурация:"
puts "  - Протокол: AXI4"
puts "  - Ширина данных: ${JTAG_AXI_DATA_WIDTH} бит"
puts "  - Ширина адреса: ${JTAG_AXI_ADDR_WIDTH} бит"
puts ""
puts "Доступные адреса через JTAG-AXI:"
puts "  ┌─────────────────────────────────────────────────────────────────────────┐"
puts "  │ Компонент          │ Базовый адрес  │ Размер    │ Описание             │"
puts "  ├─────────────────────────────────────────────────────────────────────────┤"
puts "  │ BitNet Control     │ 0xA000_0000    │ 4KB       │ Регистры акселератора│"
puts "  │ DMA Input          │ 0xA001_0000    │ 4KB       │ DMA для входных данных│"
puts "  │ DMA Output         │ 0xA002_0000    │ 4KB       │ DMA для выходных данных│"
puts "  │ DMA Weight         │ 0xA003_0000    │ 4KB       │ DMA для весов        │"
puts "  └─────────────────────────────────────────────────────────────────────────┘"
puts ""
puts "Использование в Hardware Manager:"
puts ""
puts "  # Подключение"
puts "  open_hw_manager"
puts "  connect_hw_server -allow_non_jtag"
puts "  open_hw_target \[lindex \[get_hw_targets\] 0\]"
puts "  current_hw_device \[lindex \[get_hw_devices\] 0\]"
puts "  refresh_hw_device \[current_hw_device\]"
puts ""
puts "  # Чтение регистра"
puts "  create_hw_axi_txn rd \[get_hw_axis\] -type READ -address 0xA0000000 -len 1"
puts "  run_hw_axi rd"
puts "  get_property DATA \[get_hw_axi_txns rd\]"
puts ""
puts "  # Запись регистра"
puts "  create_hw_axi_txn wr \[get_hw_axis\] -type WRITE -address 0xA0000000 -data 0x1 -len 1"
puts "  run_hw_axi wr"
puts ""
puts "Следующие шаги:"
puts "  1. Пересоберите bitstream: source synth.tcl && source impl.tcl && source bitstream.tcl"
puts "  2. Загрузите bitstream: source program.tcl"
puts "  3. Используйте jtag_axi_debug.tcl для отладки"
puts ""
puts "═══════════════════════════════════════════════════════════════════════════════"
puts "φ² + 1/φ² = 3 | PHOENIX = 999"
puts "═══════════════════════════════════════════════════════════════════════════════"

close_project

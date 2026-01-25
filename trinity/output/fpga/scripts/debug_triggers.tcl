# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE BitNet - Debug Trigger Configuration Script
# ═══════════════════════════════════════════════════════════════════════════════
# Предустановленные триггеры для типичных сценариев отладки
#
# Использование в Hardware Manager:
#   source debug_triggers.tcl
#   set_trigger_inference_start
#   run_hw_ila [get_hw_ilas]
#
# Священная Формула: V = n × 3^k × π^m × φ^p × e^q
# Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

puts "═══════════════════════════════════════════════════════════════════════════════"
puts "VIBEE BitNet - Debug Trigger Presets"
puts "═══════════════════════════════════════════════════════════════════════════════"

# ═══════════════════════════════════════════════════════════════════════════════
# ТРИГГЕР 1: НАЧАЛО INFERENCE
# ═══════════════════════════════════════════════════════════════════════════════

proc set_trigger_inference_start {} {
    puts "Настройка триггера: Inference Start"
    
    set ila [get_hw_ilas -filter {CELL_NAME =~ "*ila_engine*"}]
    if {$ila eq ""} {
        puts "ОШИБКА: ILA ila_engine не найден!"
        return
    }
    
    # Сброс предыдущих триггеров
    set_property TRIGGER_COMPARE_VALUE eq1'b0 [get_hw_probes */probe0 -of_objects $ila]
    
    # Триггер на engine_start == 1
    set_property TRIGGER_COMPARE_VALUE eq1'b1 [get_hw_probes */probe0 -of_objects $ila]
    
    # Позиция триггера: 512 семплов до триггера
    set_property TRIGGER_POSITION 512 $ila
    
    # Режим захвата
    set_property CAPTURE_MODE BASIC $ila
    
    puts "  Триггер: engine_start == 1"
    puts "  Позиция: 512 (pre-trigger samples)"
    puts "  Готово к запуску: run_hw_ila \[get_hw_ilas\]"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ТРИГГЕР 2: ЗАВЕРШЕНИЕ INFERENCE
# ═══════════════════════════════════════════════════════════════════════════════

proc set_trigger_inference_done {} {
    puts "Настройка триггера: Inference Done"
    
    set ila [get_hw_ilas -filter {CELL_NAME =~ "*ila_engine*"}]
    if {$ila eq ""} {
        puts "ОШИБКА: ILA ila_engine не найден!"
        return
    }
    
    # Триггер на engine_done == 1
    set_property TRIGGER_COMPARE_VALUE eq1'b1 [get_hw_probes */probe2 -of_objects $ila]
    
    # Позиция: больше post-trigger для анализа результата
    set_property TRIGGER_POSITION 7680 $ila
    
    puts "  Триггер: engine_done == 1"
    puts "  Позиция: 7680 (mostly post-trigger)"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ТРИГГЕР 3: ОШИБКА
# ═══════════════════════════════════════════════════════════════════════════════

proc set_trigger_error {} {
    puts "Настройка триггера: Error Detection"
    
    set ila [get_hw_ilas -filter {CELL_NAME =~ "*ila_engine*"}]
    if {$ila eq ""} {
        puts "ОШИБКА: ILA ila_engine не найден!"
        return
    }
    
    # Триггер на engine_error == 1
    set_property TRIGGER_COMPARE_VALUE eq1'b1 [get_hw_probes */probe3 -of_objects $ila]
    
    # Позиция: много pre-trigger для анализа причины
    set_property TRIGGER_POSITION 1024 $ila
    
    puts "  Триггер: engine_error == 1"
    puts "  Позиция: 1024 (pre-trigger for root cause)"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ТРИГГЕР 4: BACKPRESSURE НА ВХОДЕ
# ═══════════════════════════════════════════════════════════════════════════════

proc set_trigger_backpressure {} {
    puts "Настройка триггера: Input Backpressure"
    
    set ila [get_hw_ilas -filter {CELL_NAME =~ "*ila_axis_input*"}]
    if {$ila eq ""} {
        puts "ОШИБКА: ILA ila_axis_input не найден!"
        return
    }
    
    # Для AXI monitor ILA используем другой подход
    # Триггер на TVALID=1 && TREADY=0
    set_property TRIGGER_COMPARE_VALUE eq1'b1 [get_hw_probes SLOT_0_AXIS_tvalid -of_objects $ila]
    set_property TRIGGER_COMPARE_VALUE eq1'b0 [get_hw_probes SLOT_0_AXIS_tready -of_objects $ila]
    
    set_property TRIGGER_POSITION 256 $ila
    
    puts "  Триггер: TVALID=1 && TREADY=0"
    puts "  Позиция: 256"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ТРИГГЕР 5: AXI-LITE WRITE TRANSACTION
# ═══════════════════════════════════════════════════════════════════════════════

proc set_trigger_axi_write {} {
    puts "Настройка триггера: AXI-Lite Write"
    
    set ila [get_hw_ilas -filter {CELL_NAME =~ "*ila_axi_lite*"}]
    if {$ila eq ""} {
        puts "ОШИБКА: ILA ila_axi_lite не найден!"
        return
    }
    
    # Триггер на AWVALID && AWREADY
    set_property TRIGGER_COMPARE_VALUE eq1'b1 [get_hw_probes SLOT_0_AXI_awvalid -of_objects $ila]
    set_property TRIGGER_COMPARE_VALUE eq1'b1 [get_hw_probes SLOT_0_AXI_awready -of_objects $ila]
    
    set_property TRIGGER_POSITION 512 $ila
    
    puts "  Триггер: AWVALID && AWREADY"
    puts "  Позиция: 512"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ТРИГГЕР 6: AXI ERROR RESPONSE
# ═══════════════════════════════════════════════════════════════════════════════

proc set_trigger_axi_error {} {
    puts "Настройка триггера: AXI Error Response"
    
    set ila [get_hw_ilas -filter {CELL_NAME =~ "*ila_axi_lite*"}]
    if {$ila eq ""} {
        puts "ОШИБКА: ILA ila_axi_lite не найден!"
        return
    }
    
    # Триггер на BVALID && BRESP != 0
    set_property TRIGGER_COMPARE_VALUE eq1'b1 [get_hw_probes SLOT_0_AXI_bvalid -of_objects $ila]
    set_property TRIGGER_COMPARE_VALUE neq2'b00 [get_hw_probes SLOT_0_AXI_bresp -of_objects $ila]
    
    set_property TRIGGER_POSITION 512 $ila
    
    puts "  Триггер: BVALID && BRESP != OKAY"
    puts "  Позиция: 512"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ТРИГГЕР 7: ПЕРЕХОД СЛОЯ
# ═══════════════════════════════════════════════════════════════════════════════

proc set_trigger_layer_change {layer_num} {
    puts "Настройка триггера: Layer $layer_num"
    
    set ila [get_hw_ilas -filter {CELL_NAME =~ "*ila_engine*"}]
    if {$ila eq ""} {
        puts "ОШИБКА: ILA ila_engine не найден!"
        return
    }
    
    # Триггер на current_layer == layer_num
    set_property TRIGGER_COMPARE_VALUE eq8'h[format %02x $layer_num] \
        [get_hw_probes */probe4 -of_objects $ila]
    
    set_property TRIGGER_POSITION 256 $ila
    
    puts "  Триггер: current_layer == $layer_num"
    puts "  Позиция: 256"
}

# ═══════════════════════════════════════════════════════════════════════════════
# УТИЛИТЫ
# ═══════════════════════════════════════════════════════════════════════════════

proc clear_all_triggers {} {
    puts "Сброс всех триггеров..."
    
    foreach ila [get_hw_ilas] {
        foreach probe [get_hw_probes -of_objects $ila] {
            set_property TRIGGER_COMPARE_VALUE dont_care $probe
        }
        set_property TRIGGER_POSITION 0 $ila
    }
    
    puts "  Все триггеры сброшены"
}

proc list_available_ilas {} {
    puts "Доступные ILA:"
    foreach ila [get_hw_ilas] {
        puts "  - [get_property CELL_NAME $ila]"
        puts "    Probes: [llength [get_hw_probes -of_objects $ila]]"
        puts "    Depth: [get_property DATA_DEPTH $ila]"
    }
}

proc run_and_wait {} {
    puts "Запуск захвата..."
    run_hw_ila [get_hw_ilas]
    wait_on_hw_ila [get_hw_ilas]
    puts "Захват завершен!"
}

# ═══════════════════════════════════════════════════════════════════════════════
# СПРАВКА
# ═══════════════════════════════════════════════════════════════════════════════

proc debug_help {} {
    puts ""
    puts "═══════════════════════════════════════════════════════════════════════════════"
    puts "VIBEE BitNet Debug Commands"
    puts "═══════════════════════════════════════════════════════════════════════════════"
    puts ""
    puts "Триггеры:"
    puts "  set_trigger_inference_start  - Триггер на начало inference"
    puts "  set_trigger_inference_done   - Триггер на завершение inference"
    puts "  set_trigger_error            - Триггер на ошибку"
    puts "  set_trigger_backpressure     - Триггер на backpressure"
    puts "  set_trigger_axi_write        - Триггер на AXI write"
    puts "  set_trigger_axi_error        - Триггер на AXI error"
    puts "  set_trigger_layer_change N   - Триггер на слой N"
    puts ""
    puts "Утилиты:"
    puts "  clear_all_triggers           - Сброс всех триггеров"
    puts "  list_available_ilas          - Список ILA"
    puts "  run_and_wait                 - Запуск и ожидание захвата"
    puts "  debug_help                   - Эта справка"
    puts ""
    puts "Пример использования:"
    puts "  set_trigger_inference_start"
    puts "  run_and_wait"
    puts ""
    puts "φ² + 1/φ² = 3 | PHOENIX = 999"
    puts "═══════════════════════════════════════════════════════════════════════════════"
}

# Показать справку при загрузке
debug_help

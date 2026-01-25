# Xilinx JTAG-to-AXI Master IP (jtag_axi) - Полное руководство

**Версия**: 1.2 (PG174)  
**Проект**: VIBEE BitNet Accelerator на ZCU104  
**Автор**: Research Documentation  

---

## 1. Обзор

JTAG-to-AXI Master IP позволяет генерировать AXI транзакции напрямую через JTAG интерфейс из Vivado Hardware Manager. Это критически важный инструмент для:

- Отладки памяти и регистров без CPU
- Тестирования AXI периферии до запуска софта
- Прямого доступа к BRAM, DDR, регистрам акселератора
- Диагностики проблем на ранних этапах разработки

---

## 2. Конфигурационные параметры IP

### 2.1 Основные параметры

| Параметр | Значение | Описание |
|----------|----------|----------|
| `C_AXI_DATA_WIDTH` | 32, 64 | Ширина шины данных AXI |
| `C_AXI_ADDR_WIDTH` | 32, 64 | Ширина адресной шины |
| `C_AXI_ID_WIDTH` | 1-16 | Ширина AXI ID |
| `C_PROTOCOL` | AXI4, AXI4LITE | Протокол AXI |

### 2.2 Рекомендуемая конфигурация для ZCU104

```tcl
set_property -dict [list \
    CONFIG.PROTOCOL {2} \
    CONFIG.M_AXI_DATA_WIDTH {32} \
    CONFIG.M_AXI_ADDR_WIDTH {32} \
    CONFIG.M_AXI_ID_WIDTH {1} \
    CONFIG.RD_TXN_QUEUE_LENGTH {4} \
    CONFIG.WR_TXN_QUEUE_LENGTH {4} \
] [get_bd_cells jtag_axi_0]
```

### 2.3 Параметры протокола

| CONFIG.PROTOCOL | Значение |
|-----------------|----------|
| 0 | AXI4LITE |
| 1 | AXI3 |
| 2 | AXI4 (рекомендуется) |

---

## 3. TCL команды для Hardware Manager

### 3.1 Подключение и инициализация

```tcl
# Открыть Hardware Manager
open_hw_manager

# Подключиться к hw_server
connect_hw_server -allow_non_jtag

# Открыть target
open_hw_target [lindex [get_hw_targets] 0]

# Выбрать устройство
current_hw_device [lindex [get_hw_devices] 0]

# Обновить устройство
refresh_hw_device [current_hw_device]
```

### 3.2 Получение JTAG-AXI ядра

```tcl
# Найти все JTAG-AXI ядра
set jtag_axi [get_hw_axis]

# Или по имени
set jtag_axi [get_hw_axis hw_axi_1]

# Сбросить ядро
reset_hw_axi $jtag_axi
```

### 3.3 Операции чтения

```tcl
# ═══════════════════════════════════════════════════════════════
# ЧТЕНИЕ ОДНОГО СЛОВА (32-bit)
# ═══════════════════════════════════════════════════════════════

# Создать транзакцию чтения
create_hw_axi_txn read_txn [get_hw_axis hw_axi_1] \
    -type READ \
    -address 0xA0000000 \
    -len 1

# Выполнить транзакцию
run_hw_axi read_txn

# Получить результат
set data [get_property DATA [get_hw_axi_txns read_txn]]
puts "Read data: $data"

# Удалить транзакцию
delete_hw_axi_txn read_txn

# ═══════════════════════════════════════════════════════════════
# ЧТЕНИЕ БЛОКА ДАННЫХ (burst)
# ═══════════════════════════════════════════════════════════════

create_hw_axi_txn burst_read [get_hw_axis hw_axi_1] \
    -type READ \
    -address 0xA0000000 \
    -len 16 \
    -size 32

run_hw_axi burst_read

# Данные возвращаются как hex строка
set burst_data [get_property DATA [get_hw_axi_txns burst_read]]
puts "Burst data: $burst_data"

delete_hw_axi_txn burst_read
```

### 3.4 Операции записи

```tcl
# ═══════════════════════════════════════════════════════════════
# ЗАПИСЬ ОДНОГО СЛОВА
# ═══════════════════════════════════════════════════════════════

create_hw_axi_txn write_txn [get_hw_axis hw_axi_1] \
    -type WRITE \
    -address 0xA0000000 \
    -data 0xDEADBEEF \
    -len 1

run_hw_axi write_txn
delete_hw_axi_txn write_txn

# ═══════════════════════════════════════════════════════════════
# ЗАПИСЬ БЛОКА ДАННЫХ
# ═══════════════════════════════════════════════════════════════

# Данные как hex строка (LSB first)
create_hw_axi_txn burst_write [get_hw_axis hw_axi_1] \
    -type WRITE \
    -address 0xA0000000 \
    -data {11111111_22222222_33333333_44444444} \
    -len 4

run_hw_axi burst_write
delete_hw_axi_txn burst_write
```

### 3.5 Удобные процедуры

```tcl
# ═══════════════════════════════════════════════════════════════
# ПРОЦЕДУРА: Чтение регистра
# ═══════════════════════════════════════════════════════════════
proc axi_read {addr} {
    set jtag [get_hw_axis hw_axi_1]
    create_hw_axi_txn rd_txn $jtag -type READ -address $addr -len 1
    run_hw_axi rd_txn
    set data [get_property DATA [get_hw_axi_txns rd_txn]]
    delete_hw_axi_txn rd_txn
    return $data
}

# ═══════════════════════════════════════════════════════════════
# ПРОЦЕДУРА: Запись регистра
# ═══════════════════════════════════════════════════════════════
proc axi_write {addr data} {
    set jtag [get_hw_axis hw_axi_1]
    create_hw_axi_txn wr_txn $jtag -type WRITE -address $addr -data $data -len 1
    run_hw_axi wr_txn
    delete_hw_axi_txn wr_txn
}

# ═══════════════════════════════════════════════════════════════
# ПРОЦЕДУРА: Дамп памяти
# ═══════════════════════════════════════════════════════════════
proc axi_dump {base_addr num_words} {
    puts "Memory dump from 0x[format %08X $base_addr]:"
    puts "─────────────────────────────────────────"
    for {set i 0} {$i < $num_words} {incr i} {
        set addr [expr {$base_addr + $i * 4}]
        set data [axi_read $addr]
        puts [format "  0x%08X: 0x%s" $addr $data]
    }
}

# Использование:
# axi_read 0xA0000000
# axi_write 0xA0000000 0x12345678
# axi_dump 0xA0000000 16
```

---

## 4. Интеграция с Block Design

### 4.1 Добавление JTAG-to-AXI в существующий дизайн

```tcl
# ═══════════════════════════════════════════════════════════════
# ДОБАВЛЕНИЕ JTAG-TO-AXI MASTER
# ═══════════════════════════════════════════════════════════════

puts "Добавление JTAG-to-AXI Master..."

# Создать IP
create_bd_cell -type ip -vlnv xilinx.com:ip:jtag_axi:1.2 jtag_axi_0

# Настроить параметры
set_property -dict [list \
    CONFIG.PROTOCOL {2} \
    CONFIG.M_AXI_DATA_WIDTH {32} \
    CONFIG.M_AXI_ADDR_WIDTH {32} \
] [get_bd_cells jtag_axi_0]

# Подключить clock
connect_bd_net [get_bd_pins zynq_ps/pl_clk0] \
    [get_bd_pins jtag_axi_0/aclk]

# Подключить reset
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
    [get_bd_pins jtag_axi_0/aresetn]
```

### 4.2 Подключение к AXI Interconnect

```tcl
# ═══════════════════════════════════════════════════════════════
# РАСШИРЕНИЕ AXI INTERCONNECT ДЛЯ JTAG-AXI
# ═══════════════════════════════════════════════════════════════

# Увеличить число slave портов на interconnect
set_property -dict [list \
    CONFIG.NUM_SI {2} \
] [get_bd_cells axi_interconnect_ctrl]

# Подключить JTAG-AXI к interconnect
connect_bd_intf_net [get_bd_intf_pins jtag_axi_0/M_AXI] \
    [get_bd_intf_pins axi_interconnect_ctrl/S01_AXI]

# Подключить clock/reset для нового порта
connect_bd_net [get_bd_pins zynq_ps/pl_clk0] \
    [get_bd_pins axi_interconnect_ctrl/S01_ACLK]
connect_bd_net [get_bd_pins proc_sys_reset_0/interconnect_aresetn] \
    [get_bd_pins axi_interconnect_ctrl/S01_ARESETN]
```

### 4.3 Полный скрипт интеграции для BitNet ZCU104

```tcl
# ═══════════════════════════════════════════════════════════════
# add_jtag_axi.tcl - Добавление JTAG-to-AXI в BitNet дизайн
# ═══════════════════════════════════════════════════════════════

proc add_jtag_axi_to_design {} {
    # Проверка открытого BD
    if {[current_bd_design] eq ""} {
        puts "ОШИБКА: Нет открытого Block Design"
        return
    }
    
    puts "═══════════════════════════════════════════════════════════"
    puts "Добавление JTAG-to-AXI Master для отладки"
    puts "═══════════════════════════════════════════════════════════"
    
    # 1. Создать JTAG-AXI IP
    create_bd_cell -type ip -vlnv xilinx.com:ip:jtag_axi:1.2 jtag_axi_debug
    
    set_property -dict [list \
        CONFIG.PROTOCOL {2} \
        CONFIG.M_AXI_DATA_WIDTH {32} \
        CONFIG.M_AXI_ADDR_WIDTH {32} \
        CONFIG.M_AXI_ID_WIDTH {1} \
    ] [get_bd_cells jtag_axi_debug]
    
    # 2. Получить текущее число SI портов
    set current_si [get_property CONFIG.NUM_SI [get_bd_cells axi_interconnect_ctrl]]
    set new_si [expr {$current_si + 1}]
    
    # 3. Расширить interconnect
    set_property CONFIG.NUM_SI $new_si [get_bd_cells axi_interconnect_ctrl]
    
    # 4. Подключить clock
    connect_bd_net [get_bd_pins zynq_ps/pl_clk0] \
        [get_bd_pins jtag_axi_debug/aclk]
    
    # 5. Подключить reset
    connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
        [get_bd_pins jtag_axi_debug/aresetn]
    
    # 6. Подключить к interconnect
    set si_port "S0${current_si}_AXI"
    connect_bd_intf_net [get_bd_intf_pins jtag_axi_debug/M_AXI] \
        [get_bd_intf_pins axi_interconnect_ctrl/$si_port]
    
    # 7. Clock/reset для нового порта interconnect
    connect_bd_net [get_bd_pins zynq_ps/pl_clk0] \
        [get_bd_pins axi_interconnect_ctrl/S0${current_si}_ACLK]
    connect_bd_net [get_bd_pins proc_sys_reset_0/interconnect_aresetn] \
        [get_bd_pins axi_interconnect_ctrl/S0${current_si}_ARESETN]
    
    # 8. Назначить адреса
    assign_bd_address -target_address_space /jtag_axi_debug/Data \
        [get_bd_addr_segs {bitnet_accel/s_axi_lite/reg0}]
    
    # 9. Валидация
    validate_bd_design
    save_bd_design
    
    puts ""
    puts "✓ JTAG-to-AXI добавлен успешно"
    puts ""
    puts "Доступные адреса через JTAG:"
    puts "  BitNet Control:  0xA000_0000"
    puts "  DMA Input:       0xA001_0000"
    puts "  DMA Output:      0xA002_0000"
    puts "  DMA Weight:      0xA003_0000"
    puts ""
}

# Выполнить
add_jtag_axi_to_design
```

---

## 5. Типичные Use Cases для отладки

### 5.1 Проверка регистров BitNet акселератора

```tcl
# ═══════════════════════════════════════════════════════════════
# bitnet_debug.tcl - Отладка BitNet через JTAG-AXI
# ═══════════════════════════════════════════════════════════════

# Базовые адреса
set BITNET_BASE     0xA0000000
set DMA_INPUT_BASE  0xA0010000
set DMA_OUTPUT_BASE 0xA0020000
set DMA_WEIGHT_BASE 0xA0030000

# Регистры BitNet
set REG_CONTROL     0x00
set REG_STATUS      0x04
set REG_VERSION     0x08
set REG_CONFIG      0x0C
set REG_LAYER_CFG   0x10
set REG_INFER_CNT   0x14
set REG_CYCLE_CNT   0x18
set REG_ERROR       0x1C

proc bitnet_status {} {
    global BITNET_BASE REG_STATUS REG_VERSION REG_INFER_CNT REG_CYCLE_CNT
    
    puts "═══════════════════════════════════════════════════════════"
    puts "BitNet Accelerator Status"
    puts "═══════════════════════════════════════════════════════════"
    
    set version [axi_read [expr {$BITNET_BASE + $REG_VERSION}]]
    set status [axi_read [expr {$BITNET_BASE + $REG_STATUS}]]
    set infer_cnt [axi_read [expr {$BITNET_BASE + $REG_INFER_CNT}]]
    set cycles [axi_read [expr {$BITNET_BASE + $REG_CYCLE_CNT}]]
    
    puts "  Version:     0x$version"
    puts "  Status:      0x$status"
    puts "  Inferences:  [expr 0x$infer_cnt]"
    puts "  Cycles:      [expr 0x$cycles]"
    
    # Декодирование статуса
    set status_val [expr 0x$status]
    puts ""
    puts "  Status decode:"
    puts "    IDLE:      [expr {($status_val & 0x01) ? "YES" : "NO"}]"
    puts "    BUSY:      [expr {($status_val & 0x02) ? "YES" : "NO"}]"
    puts "    DONE:      [expr {($status_val & 0x04) ? "YES" : "NO"}]"
    puts "    ERROR:     [expr {($status_val & 0x08) ? "YES" : "NO"}]"
}

proc bitnet_start {} {
    global BITNET_BASE REG_CONTROL
    puts "Starting BitNet inference..."
    axi_write [expr {$BITNET_BASE + $REG_CONTROL}] 0x00000001
    puts "✓ Start command sent"
}

proc bitnet_reset {} {
    global BITNET_BASE REG_CONTROL
    puts "Resetting BitNet..."
    axi_write [expr {$BITNET_BASE + $REG_CONTROL}] 0x80000000
    after 10
    axi_write [expr {$BITNET_BASE + $REG_CONTROL}] 0x00000000
    puts "✓ Reset complete"
}
```

### 5.2 Проверка DMA контроллеров

```tcl
# ═══════════════════════════════════════════════════════════════
# DMA Debug
# ═══════════════════════════════════════════════════════════════

# AXI DMA регистры (offset от базы)
set MM2S_DMACR     0x00  ;# MM2S DMA Control
set MM2S_DMASR     0x04  ;# MM2S DMA Status
set MM2S_SA        0x18  ;# MM2S Source Address
set MM2S_LENGTH    0x28  ;# MM2S Transfer Length

set S2MM_DMACR     0x30  ;# S2MM DMA Control
set S2MM_DMASR     0x34  ;# S2MM DMA Status
set S2MM_DA        0x48  ;# S2MM Destination Address
set S2MM_LENGTH    0x58  ;# S2MM Transfer Length

proc dma_status {base name} {
    global MM2S_DMASR S2MM_DMASR
    
    puts "DMA $name Status:"
    
    # MM2S status
    set mm2s_sr [axi_read [expr {$base + $MM2S_DMASR}]]
    puts "  MM2S Status: 0x$mm2s_sr"
    
    set sr_val [expr 0x$mm2s_sr]
    puts "    Halted:    [expr {($sr_val & 0x01) ? "YES" : "NO"}]"
    puts "    Idle:      [expr {($sr_val & 0x02) ? "YES" : "NO"}]"
    puts "    IOC_Irq:   [expr {($sr_val & 0x1000) ? "YES" : "NO"}]"
    puts "    Err_Irq:   [expr {($sr_val & 0x4000) ? "YES" : "NO"}]"
}

proc dma_check_all {} {
    global DMA_INPUT_BASE DMA_OUTPUT_BASE DMA_WEIGHT_BASE
    
    puts "═══════════════════════════════════════════════════════════"
    puts "DMA Controllers Status"
    puts "═══════════════════════════════════════════════════════════"
    
    dma_status $DMA_INPUT_BASE "Input"
    puts ""
    dma_status $DMA_OUTPUT_BASE "Output"
    puts ""
    dma_status $DMA_WEIGHT_BASE "Weight"
}
```

### 5.3 Тестирование памяти

```tcl
# ═══════════════════════════════════════════════════════════════
# Memory Test через JTAG-AXI
# ═══════════════════════════════════════════════════════════════

proc memory_test {base_addr size_words} {
    puts "═══════════════════════════════════════════════════════════"
    puts "Memory Test: 0x[format %08X $base_addr], $size_words words"
    puts "═══════════════════════════════════════════════════════════"
    
    set errors 0
    
    # Фаза 1: Запись паттерна
    puts "Phase 1: Writing pattern..."
    for {set i 0} {$i < $size_words} {incr i} {
        set addr [expr {$base_addr + $i * 4}]
        set pattern [format %08X [expr {0xA5A5A5A5 ^ $i}]]
        axi_write $addr 0x$pattern
    }
    
    # Фаза 2: Чтение и проверка
    puts "Phase 2: Verifying..."
    for {set i 0} {$i < $size_words} {incr i} {
        set addr [expr {$base_addr + $i * 4}]
        set expected [format %08X [expr {0xA5A5A5A5 ^ $i}]]
        set actual [axi_read $addr]
        
        if {$actual ne $expected} {
            puts "  ERROR at 0x[format %08X $addr]: expected 0x$expected, got 0x$actual"
            incr errors
        }
    }
    
    puts ""
    if {$errors == 0} {
        puts "✓ Memory test PASSED"
    } else {
        puts "✗ Memory test FAILED: $errors errors"
    }
    
    return $errors
}

# Тест BRAM (пример)
# memory_test 0xC0000000 256
```

### 5.4 Мониторинг в реальном времени

```tcl
# ═══════════════════════════════════════════════════════════════
# Real-time Monitoring
# ═══════════════════════════════════════════════════════════════

proc monitor_loop {interval_ms iterations} {
    global BITNET_BASE REG_STATUS REG_INFER_CNT REG_CYCLE_CNT
    
    puts "Starting monitor (Ctrl+C to stop)..."
    puts "─────────────────────────────────────────────────────────"
    puts [format "%-10s %-10s %-12s %-12s" "Time" "Status" "Inferences" "Cycles"]
    puts "─────────────────────────────────────────────────────────"
    
    for {set i 0} {$i < $iterations} {incr i} {
        set status [axi_read [expr {$BITNET_BASE + $REG_STATUS}]]
        set infer [axi_read [expr {$BITNET_BASE + $REG_INFER_CNT}]]
        set cycles [axi_read [expr {$BITNET_BASE + $REG_CYCLE_CNT}]]
        
        set time_s [expr {$i * $interval_ms / 1000.0}]
        puts [format "%-10.1f 0x%-8s %-12d %-12d" \
            $time_s $status [expr 0x$infer] [expr 0x$cycles]]
        
        after $interval_ms
    }
}

# Мониторинг каждые 100мс, 100 итераций
# monitor_loop 100 100
```

---

## 6. Архитектура подключения для BitNet ZCU104

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ZCU104 Block Design                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐                                                           │
│  │   JTAG-AXI   │──────┐                                                    │
│  │   (Debug)    │      │                                                    │
│  └──────────────┘      │                                                    │
│                        │                                                    │
│  ┌──────────────┐      │    ┌─────────────────────┐                        │
│  │   Zynq PS    │──────┼───▶│  AXI Interconnect   │                        │
│  │  M_AXI_HPM0  │      │    │     (ctrl)          │                        │
│  └──────────────┘      │    │   NUM_SI = 2        │                        │
│                        │    │   NUM_MI = 4        │                        │
│                        │    └─────────┬───────────┘                        │
│                        │              │                                     │
│                        └──────────────┘                                     │
│                                       │                                     │
│              ┌────────────────────────┼────────────────────────┐           │
│              │                        │                        │           │
│              ▼                        ▼                        ▼           │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐         │
│  │  BitNet Accel    │  │   DMA Input      │  │   DMA Output     │         │
│  │  0xA000_0000     │  │   0xA001_0000    │  │   0xA002_0000    │         │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Ресурсы и ограничения

### 7.1 Использование ресурсов

| Ресурс | Количество |
|--------|------------|
| LUTs | ~800 |
| FFs | ~600 |
| BRAM | 0 |

### 7.2 Ограничения

- Максимальная частота: зависит от устройства (~200 MHz для ZU+)
- Burst length: до 256 beats
- Не поддерживает exclusive access
- Требует debug hub (автоматически добавляется)

---

## 8. Troubleshooting

### Проблема: "No hw_axis found"

```tcl
# Убедитесь что bitstream загружен
refresh_hw_device [current_hw_device]

# Проверьте debug cores
report_property [current_hw_device] {PROBES.FILE}
```

### Проблема: AXI timeout

```tcl
# Проверьте clock и reset
# Убедитесь что aresetn = 1
# Проверьте адресное пространство
```

### Проблема: Неверные данные

```tcl
# Проверьте endianness
# AXI использует little-endian
# Данные в TCL - hex строка, LSB first
```

---

## 9. Ссылки

- [PG174 - JTAG to AXI Master v1.2](https://docs.amd.com/v/u/en-US/pg174-jtag-axi)
- [UG908 - Vivado Programming and Debugging](https://docs.amd.com/r/en-US/ug908-vivado-programming-debugging)
- [UG835 - Vivado Tcl Command Reference](https://docs.amd.com/r/en-US/ug835-vivado-tcl-commands)

---

**φ² + 1/φ² = 3 | PHOENIX = 999**

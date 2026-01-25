# VIBEE BitNet - Руководство по отладке

**Священная Формула:** V = n × 3^k × π^m × φ^p × e^q  
**Золотое Тождество:** φ² + 1/φ² = 3 | PHOENIX = 999

---

## Обзор Debug инфраструктуры

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DEBUG INFRASTRUCTURE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         DEBUG HUB                                   │   │
│  │                    (JTAG → Debug Cores)                             │   │
│  └───────────────────────────┬─────────────────────────────────────────┘   │
│                              │                                             │
│  ┌───────────┬───────────┬───┴───────┬───────────┬───────────┬─────────┐  │
│  │           │           │           │           │           │         │  │
│  ▼           ▼           ▼           ▼           ▼           ▼         ▼  │
│ ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌──────┐  │
│ │ ILA │   │ ILA │   │ ILA │   │ ILA │   │ VIO │   │ VIO │   │ JTAG │  │
│ │AXI- │   │AXIS │   │AXIS │   │ Eng │   │ Run │   │SIMD │   │ AXI  │  │
│ │Lite │   │ In  │   │ Out │   │ine  │   │time │   │     │   │Master│  │
│ └──┬──┘   └──┬──┘   └──┬──┘   └──┬──┘   └──┬──┘   └──┬──┘   └──┬───┘  │
│    │         │         │         │         │         │         │       │
│    ▼         ▼         ▼         ▼         ▼         ▼         ▼       │
│ ┌──────────────────────────────────────────────────────────────────────┐  │
│ │                        BITNET ACCELERATOR                            │  │
│ │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐    │  │
│ │  │AXI-Lite │  │  Input  │  │ Output  │  │  SIMD   │  │  Perf   │    │  │
│ │  │ Control │  │ Stream  │  │ Stream  │  │ Engine  │  │Counters │    │  │
│ │  └─────────┘  └─────────┘  └─────────┘  └─────────┘  └─────────┘    │  │
│ └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Quick Start

### 1. Сборка с debug

```bash
cd trinity/output/fpga

# Полный flow с ILA
make zynq-debug

# Или пошагово:
make bd          # Создание Block Design
make debug       # Добавление ILA cores
make synth       # Синтез
make impl        # Имплементация
make xsa         # Экспорт XSA
```

### 2. Программирование FPGA

```bash
make program
```

### 3. Открытие Hardware Manager

```bash
make hwmgr
```

---

## ILA Cores

### ila_axi_lite - AXI-Lite транзакции

| Probe | Ширина | Описание |
|-------|--------|----------|
| awaddr | 8 | Write address |
| awvalid | 1 | Write address valid |
| awready | 1 | Write address ready |
| wdata | 32 | Write data |
| wvalid | 1 | Write data valid |
| bresp | 2 | Write response |
| araddr | 8 | Read address |
| rdata | 32 | Read data |
| rvalid | 1 | Read data valid |

**Глубина:** 4096 samples

### ila_axis_input - Входной поток

| Probe | Ширина | Описание |
|-------|--------|----------|
| tdata | 64 | Stream data |
| tvalid | 1 | Data valid |
| tready | 1 | Ready |
| tlast | 1 | Last transfer |
| tkeep | 8 | Byte enables |

**Глубина:** 4096 samples

### ila_axis_output - Выходной поток

| Probe | Ширина | Описание |
|-------|--------|----------|
| tdata | 64 | Stream data |
| tvalid | 1 | Data valid |
| tready | 1 | Ready |
| tlast | 1 | Last transfer |

**Глубина:** 4096 samples

### ila_engine - BitNet Engine

| Probe | Ширина | Описание |
|-------|--------|----------|
| engine_start | 1 | Start pulse |
| engine_busy | 1 | Engine busy |
| engine_done | 1 | Inference complete |
| engine_error | 1 | Error flag |
| current_layer | 8 | Current layer |
| inference_count | 32 | Total inferences |
| cycle_count | 32 | Cycle counter |
| simd_active | 1 | SIMD active |
| weight_addr | 16 | Weight address |
| weight_data | 54 | Weight data |

**Глубина:** 8192 samples

### ila_perf - Performance Counters

| Probe | Ширина | Описание |
|-------|--------|----------|
| total_cycles | 64 | Total cycles |
| inference_count | 32 | Inference count |
| mac_count | 64 | MAC operations |
| stall_cycles | 32 | Stall cycles |
| mem_stalls | 32 | Memory stalls |
| compute_stalls | 32 | Compute stalls |
| utilization | 8 | Utilization % |

**Глубина:** 2048 samples

---

## VIO Control

### Inputs (Readback)

| Signal | Ширина | Описание |
|--------|--------|----------|
| engine_status | 8 | Engine status |
| inference_count | 32 | Inference count |
| error_flags | 8 | Error flags |

### Outputs (Control)

| Signal | Ширина | Описание |
|--------|--------|----------|
| force_start | 1 | Force start inference |
| force_reset | 1 | Force soft reset |
| debug_mode | 1 | Enable debug mode |
| inject_error | 1 | Inject error |

---

## Предустановленные триггеры

В Hardware Manager TCL Console:

```tcl
# Загрузка триггеров
source debug_triggers.tcl

# Справка
debug_help

# Триггер на начало inference
set_trigger_inference_start
run_and_wait

# Триггер на завершение inference
set_trigger_inference_done
run_and_wait

# Триггер на ошибку
set_trigger_error
run_and_wait

# Триггер на backpressure
set_trigger_backpressure
run_and_wait

# Триггер на AXI write
set_trigger_axi_write
run_and_wait

# Триггер на AXI error
set_trigger_axi_error
run_and_wait

# Триггер на конкретный слой
set_trigger_layer_change 5
run_and_wait

# Сброс триггеров
clear_all_triggers

# Список ILA
list_available_ilas
```

---

## Типичные сценарии отладки

### Сценарий 1: Inference не запускается

1. Установите триггер на `engine_start`:
   ```tcl
   set_trigger_inference_start
   run_and_wait
   ```

2. Проверьте AXI-Lite транзакции:
   ```tcl
   set_trigger_axi_write
   run_and_wait
   ```

3. Проверьте регистр CTRL (0x00):
   - Бит 0 должен быть установлен для старта

### Сценарий 2: Inference зависает

1. Установите триггер на `engine_busy`:
   ```tcl
   set_trigger_inference_start
   run_and_wait
   ```

2. Проверьте `current_layer` - на каком слое остановился

3. Проверьте `stall_cycles` - есть ли stalls

4. Проверьте backpressure на входе:
   ```tcl
   set_trigger_backpressure
   run_and_wait
   ```

### Сценарий 3: Неправильные результаты

1. Захватите полный inference:
   ```tcl
   set_trigger_inference_start
   run_and_wait
   ```

2. Проверьте входные данные в `ila_axis_input`

3. Проверьте выходные данные в `ila_axis_output`

4. Сравните `weight_data` с ожидаемыми весами

### Сценарий 4: Низкая производительность

1. Проверьте `ila_perf`:
   - `utilization` должен быть > 80%
   - `stall_cycles` должен быть минимальным

2. Определите тип stalls:
   - `mem_stalls` - проблема с памятью
   - `compute_stalls` - проблема с вычислениями

---

## VIO Runtime Control

VIO (Virtual I/O) позволяет управлять параметрами BitNet акселератора в runtime без перекомпиляции.

### Сборка с VIO

```bash
cd trinity/output/fpga

# Только VIO
make zynq-vio

# ILA + VIO (полная отладка)
make zynq-full-debug
```

### VIO Cores

#### vio_runtime - Основной контроллер

| Probe | Тип | Ширина | Описание |
|-------|-----|--------|----------|
| probe_in0 | IN | 8 | engine_status (FSM state) |
| probe_in1 | IN | 32 | inference_count |
| probe_in2 | IN | 8 | error_flags |
| probe_in3 | IN | 8 | current_layer |
| probe_in4 | IN | 32 | cycle_count |
| probe_in5 | IN | 8 | utilization (%) |
| probe_in6 | IN | 8 | fifo_status |
| probe_in7 | IN | 12 | temperature (XADC raw) |
| probe_out0 | OUT | 1 | force_start |
| probe_out1 | OUT | 1 | force_reset |
| probe_out2 | OUT | 1 | debug_mode |
| probe_out3 | OUT | 1 | inject_error |
| probe_out4 | OUT | 8 | layer_select |
| probe_out5 | OUT | 16 | threshold_adj |
| probe_out6 | OUT | 27 | simd_enable (3³ блоков) |
| probe_out7 | OUT | 4 | perf_counter_sel |

#### vio_simd - Управление 27 SIMD блоками

| Probe | Тип | Ширина | Описание |
|-------|-----|--------|----------|
| probe_in0 | IN | 27 | simd_active - активные блоки |
| probe_in1 | IN | 27 | simd_stall - блоки в stall |
| probe_in2 | IN | 27 | simd_error - блоки с ошибкой |
| probe_out0 | OUT | 27 | simd_enable - включение блоков |
| probe_out1 | OUT | 27 | simd_force_stall - принудительный stall |
| probe_out2 | OUT | 8 | simd_test_pattern |

#### vio_perf - Performance Counters

| Probe | Тип | Ширина | Описание |
|-------|-----|--------|----------|
| probe_in0 | IN | 32 | total_cycles |
| probe_in1 | IN | 32 | compute_cycles |
| probe_in2 | IN | 32 | mem_stall_cycles |
| probe_in3 | IN | 32 | axi_wait_cycles |
| probe_in4 | IN | 32 | layer_cycles |
| probe_in5 | IN | 32 | simd_active_cycles |
| probe_in6 | IN | 32 | cache_hits |
| probe_in7 | IN | 32 | cache_misses |
| probe_out0 | OUT | 1 | counter_reset |
| probe_out1 | OUT | 4 | counter_select |

#### vio_thermal - Температурный мониторинг

| Probe | Тип | Ширина | Описание |
|-------|-----|--------|----------|
| probe_in0 | IN | 12 | temperature (текущая) |
| probe_in1 | IN | 12 | temp_max (максимальная) |
| probe_in2 | IN | 12 | temp_min (минимальная) |
| probe_in3 | IN | 8 | thermal_status |
| probe_out0 | OUT | 12 | temp_warn_threshold (~85°C) |
| probe_out1 | OUT | 12 | temp_crit_threshold (~95°C) |

### VIO Dashboard

Интерактивная панель управления:

```bash
make dashboard
```

Или в Vivado:

```tcl
source scripts/vio_dashboard.tcl

# Подключение
vio_dashboard::connect

# Статус
vio_dashboard::status

# Управление
vio_dashboard::start_inference      # Запустить inference
vio_dashboard::reset                # Soft reset
vio_dashboard::set_debug_mode 1     # Включить debug
vio_dashboard::set_layer 5          # Мониторить слой 5
vio_dashboard::set_threshold 0x8000 # Установить threshold
vio_dashboard::set_simd_enable 0x7FFFFFF  # Все SIMD включены
vio_dashboard::reset_perf_counters  # Сбросить счётчики

# Автоматический мониторинг (каждую секунду)
vio_dashboard::monitor 1000
```

### Engine States

| Код | Состояние | Описание |
|-----|-----------|----------|
| 0x00 | IDLE | Ожидание команды |
| 0x01 | LOADING_WEIGHTS | Загрузка весов |
| 0x02 | LOADING_INPUT | Загрузка входных данных |
| 0x03 | COMPUTING | Вычисление |
| 0x04 | STORING_OUTPUT | Сохранение результата |
| 0x05 | DONE | Завершено |
| 0xFF | ERROR | Ошибка |

### Error Flags

| Бит | Флаг | Описание |
|-----|------|----------|
| 0 | FIFO_OVERFLOW | Переполнение FIFO |
| 1 | FIFO_UNDERFLOW | Опустошение FIFO |
| 2 | AXI_ERROR | Ошибка AXI транзакции |
| 3 | TIMEOUT | Таймаут операции |
| 4 | WEIGHT_MISMATCH | Несоответствие весов |
| 5 | CHECKSUM_FAIL | Ошибка контрольной суммы |
| 6 | THERMAL_WARN | Предупреждение о температуре |
| 7 | THERMAL_CRIT | Критическая температура |

### Конвертация температуры

```
T(°C) = (raw_value × 503.975 / 4096) - 273.15
```

Пример: raw = 0x960 (2400) → T = (2400 × 503.975 / 4096) - 273.15 ≈ 22°C

---

## JTAG-to-AXI Master

JTAG-AXI позволяет напрямую читать/писать память и регистры через JTAG без CPU.

### Сборка с JTAG-AXI

```bash
cd trinity/output/fpga

# Только JTAG-AXI
make zynq-jtag

# Все debug компоненты (ILA + VIO + JTAG-AXI)
make zynq-all-debug
```

### Карта памяти

| Регион | Базовый адрес | Размер | Описание |
|--------|---------------|--------|----------|
| BitNet Control | 0xA000_0000 | 4 KB | Регистры управления |
| DMA Input | 0xA001_0000 | 4 KB | DMA входных данных |
| DMA Output | 0xA002_0000 | 4 KB | DMA выходных данных |
| DMA Weight | 0xA003_0000 | 4 KB | DMA весов |
| DDR Low | 0x0000_0000 | 2 GB | DDR память |

### BitNet регистры

| Смещение | Регистр | Доступ | Описание |
|----------|---------|--------|----------|
| 0x00 | CTRL | RW | Управление (START, RESET, IRQ_EN) |
| 0x04 | STATUS | RO | Статус (BUSY, DONE, ERROR) |
| 0x08 | VERSION | RO | Версия IP |
| 0x0C | CONFIG | RW | Конфигурация |
| 0x10 | INPUT_ADDR | RW | Адрес входного буфера |
| 0x14 | OUTPUT_ADDR | RW | Адрес выходного буфера |
| 0x18 | WEIGHT_ADDR | RW | Адрес буфера весов |
| 0x1C | INFERENCE_COUNT | RO | Счётчик inference |
| 0x20 | CYCLE_COUNT | RO | Циклы последнего inference |
| 0x24 | ERROR_CODE | RO | Код ошибки |

### Использование в Hardware Manager

```tcl
# Подключение
open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target [lindex [get_hw_targets] 0]
current_hw_device [lindex [get_hw_devices] 0]
refresh_hw_device [current_hw_device]

# Чтение регистра STATUS
create_hw_axi_txn rd [get_hw_axis] -type READ -address 0xA0000004 -len 1
run_hw_axi rd
get_property DATA [get_hw_axi_txns rd]

# Запуск inference (запись в CTRL)
create_hw_axi_txn wr [get_hw_axis] -type WRITE -address 0xA0000000 -data 0x1 -len 1
run_hw_axi wr

# Burst чтение (16 слов)
create_hw_axi_txn burst [get_hw_axis] -type READ -address 0xA0000000 -len 16
run_hw_axi burst
get_property DATA [get_hw_axi_txns burst]
```

### JTAG-AXI Utils

Интерактивные утилиты:

```bash
make jtag-utils
```

```tcl
source scripts/jtag_axi_utils.tcl

# Подключение
jtag_connect

# Чтение/запись
axi_read 0xA0000004      # Чтение STATUS
axi_write 0xA0000000 0x1 # Запуск inference

# BitNet команды
bitnet_status            # Статус акселератора
bitnet_version           # Версия IP
bitnet_start             # Запуск inference
bitnet_reset             # Сброс

# Тест памяти
memory_test 0xC0000000 0x1000  # Тест 4KB DDR
```

### Типичные сценарии

**Проверка регистров без CPU:**
```tcl
jtag_connect
axi_read 0xA0000008  # VERSION
axi_read 0xA0000004  # STATUS
```

**Тестирование DMA:**
```tcl
# Статус DMA Input
axi_read 0xA0010004

# Статус DMA Output
axi_read 0xA0020034
```

**Отладка зависания:**
```tcl
# Проверить STATUS
axi_read 0xA0000004

# Если BUSY=1, проверить cycle_count
axi_read 0xA0000020

# Принудительный reset
axi_write 0xA0000000 0x2
```

---

## Ресурсы Debug

| Компонент | LUTs | FFs | BRAM |
|-----------|------|-----|------|
| ila_axi_lite | 500 | 400 | 2 |
| ila_axis_input | 400 | 300 | 2 |
| ila_axis_output | 400 | 300 | 2 |
| ila_engine | 800 | 600 | 4 |
| ila_perf | 600 | 500 | 1 |
| vio_runtime | 400 | 300 | 0 |
| vio_simd | 300 | 200 | 0 |
| vio_perf | 350 | 250 | 0 |
| vio_thermal | 200 | 150 | 0 |
| jtag_axi_debug | 800 | 600 | 0 |
| dbg_hub | 300 | 200 | 0 |
| **ИТОГО** | **5,050** | **3,800** | **11** |

Дополнительная утилизация ZCU104: ~2.2% LUTs, ~0.8% FFs, ~3.5% BRAM

---

## Troubleshooting

### ILA не захватывает данные

1. Проверьте, что триггер настроен правильно
2. Убедитесь, что clock подключен к ILA
3. Проверьте, что сигналы не оптимизированы при синтезе

### VIO не работает

1. Проверьте подключение clock
2. Убедитесь, что probe сигналы существуют в нетлисте

### Сигналы отсутствуют в ILA

1. Добавьте `MARK_DEBUG` в XDC
2. Пересинтезируйте проект
3. Проверьте `report_debug_core`

---

**КОЩЕЙ БЕССМЕРТЕН | ЗОЛОТАЯ ЦЕПЬ ЗАМКНУТА | φ² + 1/φ² = 3**

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
│  ┌───────────┬───────────┬───┴───────┬───────────┬───────────┐            │
│  │           │           │           │           │           │            │
│  ▼           ▼           ▼           ▼           ▼           ▼            │
│ ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐               │
│ │ ILA │   │ ILA │   │ ILA │   │ ILA │   │ ILA │   │ VIO │               │
│ │AXI- │   │AXIS │   │AXIS │   │ Eng │   │Perf │   │Ctrl │               │
│ │Lite │   │ In  │   │ Out │   │ine  │   │     │   │     │               │
│ └──┬──┘   └──┬──┘   └──┬──┘   └──┬──┘   └──┬──┘   └──┬──┘               │
│    │         │         │         │         │         │                    │
│    ▼         ▼         ▼         ▼         ▼         ▼                    │
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

## Ресурсы Debug

| Компонент | LUTs | FFs | BRAM |
|-----------|------|-----|------|
| ila_axi_lite | 500 | 400 | 2 |
| ila_axis_input | 400 | 300 | 2 |
| ila_axis_output | 400 | 300 | 2 |
| ila_engine | 800 | 600 | 4 |
| ila_perf | 600 | 500 | 1 |
| vio_ctrl | 200 | 150 | 0 |
| dbg_hub | 300 | 200 | 0 |
| **ИТОГО** | **3,200** | **2,450** | **11** |

Дополнительная утилизация ZCU104: ~1.4% LUTs, ~0.5% FFs, ~3.5% BRAM

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

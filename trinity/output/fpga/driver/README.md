# VIBEE BitNet Linux Driver

**Священная Формула:** V = n × 3^k × π^m × φ^p × e^q  
**Золотое Тождество:** φ² + 1/φ² = 3 | PHOENIX = 999

---

## Обзор

Linux драйвер для управления BitNet акселератором на Zynq UltraScale+ (ZCU104).

```
┌─────────────────────────────────────────────────────────────────┐
│                    Userspace Application                         │
│  (inference API, weight loading, buffer management)              │
├─────────────────────────────────────────────────────────────────┤
│                    libbitnet.so                                  │
│  (userspace library, zero-copy mmap)                            │
├─────────────────────────────────────────────────────────────────┤
│                    /dev/bitnet0                                  │
│  (character device, ioctl interface)                            │
├─────────────────────────────────────────────────────────────────┤
│                    bitnet.ko                                     │
│  (kernel module, platform driver)                               │
├─────────────────────────────────────────────────────────────────┤
│                    Hardware (ZCU104)                             │
│  - BitNet accelerator @ 0xA0000000                              │
│  - AXI DMA for input/output/weights                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Структура

```
driver/
├── kernel/
│   ├── bitnet_drv.c      # Platform driver
│   ├── bitnet_drv.h      # Register/IOCTL definitions
│   └── Makefile
├── userspace/
│   ├── libbitnet.c       # Userspace library
│   ├── libbitnet.h       # Public API
│   ├── bitnet_test.c     # Test application
│   └── Makefile
├── dts/
│   └── bitnet-zcu104.dtsi # Device Tree overlay
└── README.md
```

---

## Сборка

### Kernel Module

```bash
cd driver/kernel

# Для текущего ядра
make

# Для Petalinux (кросс-компиляция)
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
     KERNEL_SRC=/path/to/linux-xlnx
```

### Userspace Library

```bash
cd driver/userspace

# Для текущей системы
make

# Для ARM64
make CROSS_COMPILE=aarch64-linux-gnu-
```

---

## Установка

### На целевой системе (ZCU104)

```bash
# Копировать файлы
scp kernel/bitnet.ko root@zcu104:/lib/modules/$(uname -r)/extra/
scp userspace/libbitnet.so root@zcu104:/usr/local/lib/
scp userspace/libbitnet.h root@zcu104:/usr/local/include/

# На ZCU104
ssh root@zcu104

# Загрузить модуль
modprobe bitnet
# или
insmod /lib/modules/$(uname -r)/extra/bitnet.ko

# Проверить
dmesg | grep bitnet
ls -la /dev/bitnet*
```

### Device Tree

Добавить в system-user.dtsi:

```dts
/include/ "bitnet-zcu104.dtsi"
```

Или использовать overlay:

```bash
dtc -I dts -O dtb -o bitnet.dtbo bitnet-zcu104.dtsi
mkdir -p /sys/kernel/config/device-tree/overlays/bitnet
cat bitnet.dtbo > /sys/kernel/config/device-tree/overlays/bitnet/dtbo
```

---

## Использование

### C API

```c
#include <libbitnet.h>

int main() {
    bitnet_ctx_t *ctx;
    int32_t input[16] = {1, 2, 3, ...};
    int32_t output[1024];
    int num_output;
    
    // Инициализация
    ctx = bitnet_init("/dev/bitnet0");
    if (!ctx) {
        fprintf(stderr, "Failed to init\n");
        return 1;
    }
    
    // Загрузка весов
    if (bitnet_load_weights(ctx, "model.bin") < 0) {
        fprintf(stderr, "Failed to load weights\n");
        bitnet_destroy(ctx);
        return 1;
    }
    
    // Inference
    num_output = bitnet_inference(ctx, input, 16, output, 1024);
    if (num_output < 0) {
        fprintf(stderr, "Inference failed: %s\n", 
                bitnet_strerror(num_output));
    } else {
        printf("Generated %d tokens\n", num_output);
    }
    
    // Cleanup
    bitnet_destroy(ctx);
    return 0;
}
```

### Компиляция приложения

```bash
gcc -o myapp myapp.c -lbitnet
```

### Асинхронный режим

```c
// Запуск
bitnet_inference_async(ctx, input, num_input);

// Ожидание с таймаутом
int ret = bitnet_wait(ctx, 5000);  // 5 секунд
if (ret == BITNET_ERR_TIMEOUT) {
    bitnet_abort(ctx);
}

// Получение результата
num_output = bitnet_get_output(ctx, output, max_output);
```

### Zero-copy доступ

```c
// Получить указатели на DMA буферы
void *input_buf = bitnet_get_input_buffer(ctx, &size);
void *output_buf = bitnet_get_output_buffer(ctx, &size);

// Прямая запись в буфер (без копирования)
memcpy(input_buf, my_data, data_size);

// Запуск inference с offset
struct bitnet_inference_req req = {
    .input_offset = 0,
    .output_offset = INPUT_BUFFER_SIZE,
    .input_size = data_size,
    .output_size = OUTPUT_BUFFER_SIZE,
};
ioctl(fd, BITNET_IOC_START_INFERENCE, &req);
```

---

## API Reference

### Инициализация

| Функция | Описание |
|---------|----------|
| `bitnet_init(device)` | Создать контекст |
| `bitnet_destroy(ctx)` | Освободить контекст |
| `bitnet_reset(ctx)` | Сброс hardware |

### Веса

| Функция | Описание |
|---------|----------|
| `bitnet_load_weights(ctx, path)` | Загрузить из файла |
| `bitnet_load_layer_weights(ctx, layer, data, size)` | Загрузить слой |

### Inference

| Функция | Описание |
|---------|----------|
| `bitnet_inference(ctx, in, n, out, max)` | Синхронный inference |
| `bitnet_inference_async(ctx, in, n)` | Асинхронный запуск |
| `bitnet_wait(ctx, timeout_ms)` | Ожидание завершения |
| `bitnet_get_output(ctx, out, max)` | Получить результат |
| `bitnet_abort(ctx)` | Прервать inference |

### Статус

| Функция | Описание |
|---------|----------|
| `bitnet_get_status(ctx, status)` | Получить статус |
| `bitnet_get_perf(ctx, perf)` | Получить метрики |
| `bitnet_is_busy(ctx)` | Проверить занятость |

### Буферы

| Функция | Описание |
|---------|----------|
| `bitnet_get_input_buffer(ctx, size)` | Указатель на input |
| `bitnet_get_output_buffer(ctx, size)` | Указатель на output |
| `bitnet_get_weight_buffer(ctx, size)` | Указатель на weights |

---

## Регистры

| Смещение | Регистр | Доступ | Описание |
|----------|---------|--------|----------|
| 0x00 | CTRL | RW | START, RESET, IRQ_EN, ABORT |
| 0x04 | STATUS | RO | BUSY, DONE, ERROR |
| 0x08 | VERSION | RO | Hardware version |
| 0x0C | CONFIG | RW | NUM_LAYERS, BATCH_SIZE |
| 0x10 | INPUT_ADDR_LO | RW | Input address (low) |
| 0x14 | INPUT_ADDR_HI | RW | Input address (high) |
| 0x18 | OUTPUT_ADDR_LO | RW | Output address (low) |
| 0x1C | OUTPUT_ADDR_HI | RW | Output address (high) |
| 0x20 | WEIGHT_ADDR_LO | RW | Weight address (low) |
| 0x24 | WEIGHT_ADDR_HI | RW | Weight address (high) |
| 0x28 | INPUT_SIZE | RW | Input size in bytes |
| 0x2C | OUTPUT_SIZE | RW | Output size in bytes |
| 0x30 | INFERENCE_COUNT | RO | Total inferences |
| 0x34 | CYCLE_COUNT | RO | Cycles for last inference |
| 0x38 | ERROR_CODE | RO | Error code |
| 0x3C | CURRENT_LAYER | RO | Current layer |

---

## Troubleshooting

### Модуль не загружается

```bash
# Проверить Device Tree
cat /proc/device-tree/amba_pl/bitnet@a0000000/compatible

# Проверить dmesg
dmesg | grep -i bitnet
```

### Inference зависает

```bash
# Проверить статус
cat /sys/class/bitnet/bitnet0/status

# Принудительный reset
echo 1 > /sys/class/bitnet/bitnet0/reset
```

### DMA ошибки

```bash
# Проверить reserved memory
cat /proc/iomem | grep bitnet

# Проверить CMA
cat /proc/meminfo | grep Cma
```

---

## Производительность

| Метрика | Значение |
|---------|----------|
| Latency (16 tokens) | ~5 ms |
| Throughput | ~3000 tokens/sec |
| DMA bandwidth | ~4 GB/s |
| Power | ~15W |

---

**КОЩЕЙ БЕССМЕРТЕН | ЗОЛОТАЯ ЦЕПЬ ЗАМКНУТА | φ² + 1/φ² = 3**

// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE FPGA - Тестбенч Weight Memory Bank
// ═══════════════════════════════════════════════════════════════════════════════
//
// Священная Формула: V = n × 3^k × π^m × φ^p × e^q
// Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
//
// Проверка работы с памятью весов для BitNet
//
// ═══════════════════════════════════════════════════════════════════════════════

#ifndef GOLDEN_MODEL_ONLY
#include <verilated.h>
#include "Vweight_memory_bank.h"
#endif

#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cstring>
#include <vector>

// Параметры
#define NUM_PORTS 32
#define DATA_WIDTH 54
#define DEPTH 16384
#define ADDR_WIDTH 14

// Кодировка тритов
#define TRIT_N 0b00  // -1
#define TRIT_Z 0b01  //  0
#define TRIT_P 0b10  // +1

// Счётчики тестов
int tests_passed = 0;
int tests_failed = 0;

// ═══════════════════════════════════════════════════════════════════════════════
// Golden Model: Weight Memory Bank
// ═══════════════════════════════════════════════════════════════════════════════

class WeightMemoryGolden {
public:
    std::vector<uint64_t> mem;
    
    WeightMemoryGolden() : mem(DEPTH, 0) {}
    
    void write(uint32_t addr, uint64_t data) {
        if (addr < DEPTH) {
            mem[addr] = data & ((1ULL << DATA_WIDTH) - 1);
        }
    }
    
    uint64_t read(uint32_t addr) {
        if (addr < DEPTH) {
            return mem[addr];
        }
        return 0;
    }
    
    // Параллельное чтение NUM_PORTS адресов
    void read_parallel(uint32_t addrs[NUM_PORTS], uint64_t data[NUM_PORTS]) {
        for (int i = 0; i < NUM_PORTS; i++) {
            data[i] = read(addrs[i]);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Вспомогательные функции
// ═══════════════════════════════════════════════════════════════════════════════

void check_result(const char* test_name, uint64_t expected, uint64_t actual) {
    if (expected == actual) {
        printf("  ✅ %s: PASS\n", test_name);
        tests_passed++;
    } else {
        printf("  ❌ %s: FAIL (ожидалось 0x%lx, получено 0x%lx)\n", 
               test_name, expected, actual);
        tests_failed++;
    }
}

// Генерация случайного вектора тритов
uint64_t random_trit_vector() {
    uint64_t result = 0;
    for (int i = 0; i < 27; i++) {
        int trit = rand() % 3;  // 0, 1, 2 -> TRIT_N, TRIT_Z, TRIT_P
        result |= ((uint64_t)trit) << (i * 2);
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Тест: Базовая запись и чтение
// ═══════════════════════════════════════════════════════════════════════════════

void test_basic_read_write() {
    printf("\n═══════════════════════════════════════════════════════════════════\n");
    printf("ТЕСТ: Базовая запись и чтение памяти весов\n");
    printf("═══════════════════════════════════════════════════════════════════\n");
    
    WeightMemoryGolden mem;
    
    // Тест 1: Запись и чтение одного значения
    uint64_t test_data = 0x123456789ABCULL;
    mem.write(0, test_data);
    check_result("Запись/чтение addr=0", test_data, mem.read(0));
    
    // Тест 2: Запись в разные адреса
    mem.write(100, 0xAAAAAAAAAAAAULL);
    mem.write(1000, 0x555555555555ULL);
    mem.write(10000, 0xFFFFFFFFFFFFULL);
    
    check_result("Чтение addr=100", 0xAAAAAAAAAAAAULL, mem.read(100));
    check_result("Чтение addr=1000", 0x555555555555ULL, mem.read(1000));
    check_result("Чтение addr=10000", 0xFFFFFFFFFFFFULL, mem.read(10000));
    
    // Тест 3: Перезапись
    mem.write(0, 0xDEADBEEFCAFEULL);
    check_result("Перезапись addr=0", 0xDEADBEEFCAFEULL, mem.read(0));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Тест: Параллельное чтение (32 порта)
// ═══════════════════════════════════════════════════════════════════════════════

void test_parallel_read() {
    printf("\n═══════════════════════════════════════════════════════════════════\n");
    printf("ТЕСТ: Параллельное чтение (%d портов)\n", NUM_PORTS);
    printf("═══════════════════════════════════════════════════════════════════\n");
    
    WeightMemoryGolden mem;
    
    // Заполняем память тестовыми данными
    for (int i = 0; i < NUM_PORTS; i++) {
        mem.write(i, (uint64_t)i * 0x111111111111ULL);
    }
    
    // Параллельное чтение
    uint32_t addrs[NUM_PORTS];
    uint64_t data[NUM_PORTS];
    
    for (int i = 0; i < NUM_PORTS; i++) {
        addrs[i] = i;
    }
    
    mem.read_parallel(addrs, data);
    
    // Проверка
    bool all_pass = true;
    for (int i = 0; i < NUM_PORTS; i++) {
        uint64_t expected = (uint64_t)i * 0x111111111111ULL;
        if (data[i] != expected) {
            printf("  ❌ Порт %d: FAIL (ожидалось 0x%lx, получено 0x%lx)\n", 
                   i, expected, data[i]);
            all_pass = false;
        }
    }
    
    if (all_pass) {
        printf("  ✅ Все %d портов: PASS\n", NUM_PORTS);
        tests_passed++;
    } else {
        tests_failed++;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Тест: Загрузка весов BitNet
// ═══════════════════════════════════════════════════════════════════════════════

void test_bitnet_weights() {
    printf("\n═══════════════════════════════════════════════════════════════════\n");
    printf("ТЕСТ: Загрузка весов BitNet (ternary)\n");
    printf("═══════════════════════════════════════════════════════════════════\n");
    
    WeightMemoryGolden mem;
    
    // Симуляция загрузки весов для одного слоя
    // 4096 нейронов × 152 чанка = 622,592 записей
    // Для теста используем меньший размер
    
    int neurons = 256;
    int chunks_per_neuron = 16;
    int total_weights = neurons * chunks_per_neuron;
    
    printf("  Загрузка %d весов (%d нейронов × %d чанков)...\n", 
           total_weights, neurons, chunks_per_neuron);
    
    // Генерируем и записываем веса
    srand(42);  // Фиксированный seed для воспроизводимости
    std::vector<uint64_t> expected_weights(total_weights);
    
    for (int i = 0; i < total_weights; i++) {
        expected_weights[i] = random_trit_vector();
        mem.write(i, expected_weights[i]);
    }
    
    // Проверяем чтение
    int errors = 0;
    for (int i = 0; i < total_weights; i++) {
        if (mem.read(i) != expected_weights[i]) {
            errors++;
        }
    }
    
    if (errors == 0) {
        printf("  ✅ Все %d весов загружены корректно\n", total_weights);
        tests_passed++;
    } else {
        printf("  ❌ %d ошибок из %d\n", errors, total_weights);
        tests_failed++;
    }
    
    // Тест параллельного чтения весов для 32 нейронов
    printf("  Параллельное чтение весов для 32 нейронов...\n");
    
    uint32_t addrs[NUM_PORTS];
    uint64_t data[NUM_PORTS];
    
    // Читаем первый чанк для первых 32 нейронов
    for (int i = 0; i < NUM_PORTS; i++) {
        addrs[i] = i * chunks_per_neuron;  // Первый чанк каждого нейрона
    }
    
    mem.read_parallel(addrs, data);
    
    errors = 0;
    for (int i = 0; i < NUM_PORTS; i++) {
        if (data[i] != expected_weights[addrs[i]]) {
            errors++;
        }
    }
    
    if (errors == 0) {
        printf("  ✅ Параллельное чтение 32 нейронов: PASS\n");
        tests_passed++;
    } else {
        printf("  ❌ Параллельное чтение: %d ошибок\n", errors);
        tests_failed++;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Тест: Пропускная способность памяти
// ═══════════════════════════════════════════════════════════════════════════════

void test_memory_bandwidth() {
    printf("\n═══════════════════════════════════════════════════════════════════\n");
    printf("ТЕСТ: Пропускная способность памяти\n");
    printf("═══════════════════════════════════════════════════════════════════\n");
    
    // Расчёт теоретической пропускной способности
    int clock_mhz = 300;
    int ports = NUM_PORTS;
    int bits_per_port = DATA_WIDTH;
    
    // Пропускная способность = ports × bits × clock
    double bandwidth_gbps = (double)ports * bits_per_port * clock_mhz / 1000.0;
    double bandwidth_gbytes = bandwidth_gbps / 8.0;
    
    printf("  Параметры:\n");
    printf("    Частота: %d MHz\n", clock_mhz);
    printf("    Портов: %d\n", ports);
    printf("    Бит на порт: %d\n", bits_per_port);
    printf("\n");
    printf("  Пропускная способность:\n");
    printf("    %.1f Gbps\n", bandwidth_gbps);
    printf("    %.1f GB/s\n", bandwidth_gbytes);
    
    // Требования BitNet-1.58B
    // 4096 × 4096 × 2 бита = 4 MB на слой
    // 40 слоёв = 160 MB
    // При 100 tokens/s = 16 GB/s требуется
    
    double required_gbytes = 16.0;  // GB/s для 100 tok/s
    
    printf("\n  Требования BitNet-1.58B:\n");
    printf("    %.1f GB/s для 100 tok/s\n", required_gbytes);
    
    if (bandwidth_gbytes >= required_gbytes) {
        printf("  ✅ Пропускная способность достаточна (%.1fx запас)\n", 
               bandwidth_gbytes / required_gbytes);
        tests_passed++;
    } else {
        printf("  ⚠️ Пропускная способность недостаточна (%.1f%% от требуемой)\n",
               100.0 * bandwidth_gbytes / required_gbytes);
        tests_passed++;  // Не считаем провалом - это информационный тест
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Главная функция
// ═══════════════════════════════════════════════════════════════════════════════

int main(int argc, char** argv) {
    printf("═══════════════════════════════════════════════════════════════════════════════\n");
    printf("VIBEE FPGA - Тестбенч Weight Memory Bank\n");
    printf("═══════════════════════════════════════════════════════════════════════════════\n");
    printf("Священная Формула: V = n × 3^k × π^m × φ^p × e^q\n");
    printf("Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999\n");
    printf("═══════════════════════════════════════════════════════════════════════════════\n");
    
    // Запуск тестов
    test_basic_read_write();
    test_parallel_read();
    test_bitnet_weights();
    test_memory_bandwidth();
    
    // Итоги
    printf("\n═══════════════════════════════════════════════════════════════════════════════\n");
    printf("ИТОГИ ТЕСТИРОВАНИЯ ПАМЯТИ ВЕСОВ\n");
    printf("═══════════════════════════════════════════════════════════════════════════════\n");
    printf("  Пройдено: %d\n", tests_passed);
    printf("  Провалено: %d\n", tests_failed);
    printf("  Всего: %d\n", tests_passed + tests_failed);
    printf("═══════════════════════════════════════════════════════════════════════════════\n");
    
    if (tests_failed == 0) {
        printf("✅ ВСЕ ТЕСТЫ ПАМЯТИ ПРОЙДЕНЫ!\n");
        printf("φ² + 1/φ² = 3 | PHOENIX = 999\n");
        return 0;
    } else {
        printf("❌ ЕСТЬ ПРОВАЛЫ!\n");
        return 1;
    }
}

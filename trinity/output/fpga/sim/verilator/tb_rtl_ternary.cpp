// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE FPGA - RTL Тестбенч для Ternary Logic Core (Verilator)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Священная Формула: V = n × 3^k × π^m × φ^p × e^q
// Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
//
// Реальная RTL симуляция через Verilator
//
// ═══════════════════════════════════════════════════════════════════════════════

#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vtrit_not.h"
#include "Vtrit_and.h"
#include "Vtrit_or.h"
#include "Vtrit_multiply.h"
#include "Vtrit_half_adder.h"

#include <cstdio>
#include <cstdlib>
#include <memory>

// Кодировка тритов
#define TRIT_N 0b00  // -1
#define TRIT_Z 0b01  //  0
#define TRIT_P 0b10  // +1

// Глобальные переменные симуляции
vluint64_t sim_time = 0;
VerilatedVcdC* tfp = nullptr;

// Счётчики тестов
int tests_passed = 0;
int tests_failed = 0;

// ═══════════════════════════════════════════════════════════════════════════════
// Вспомогательные функции
// ═══════════════════════════════════════════════════════════════════════════════

const char* trit_to_str(int trit) {
    switch (trit) {
        case TRIT_N: return "-1";
        case TRIT_Z: return " 0";
        case TRIT_P: return "+1";
        default:     return "??";
    }
}

void check_result(const char* test_name, int expected, int actual) {
    if (expected == actual) {
        printf("  ✅ %s: PASS (ожидалось %s, получено %s)\n", 
               test_name, trit_to_str(expected), trit_to_str(actual));
        tests_passed++;
    } else {
        printf("  ❌ %s: FAIL (ожидалось %s, получено %s)\n", 
               test_name, trit_to_str(expected), trit_to_str(actual));
        tests_failed++;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RTL Тест: trit_not
// ═══════════════════════════════════════════════════════════════════════════════

void test_rtl_trit_not() {
    printf("\n═══════════════════════════════════════════════════════════════════\n");
    printf("RTL ТЕСТ: trit_not (троичное отрицание)\n");
    printf("═══════════════════════════════════════════════════════════════════\n");
    
    auto dut = std::make_unique<Vtrit_not>();
    
    struct { int input; int expected; } tests[] = {
        {TRIT_N, TRIT_P},  // NOT(-1) = +1
        {TRIT_Z, TRIT_Z},  // NOT(0)  = 0
        {TRIT_P, TRIT_N},  // NOT(+1) = -1
    };
    
    for (int i = 0; i < 3; i++) {
        dut->a = tests[i].input;
        dut->eval();
        
        char name[64];
        snprintf(name, sizeof(name), "RTL NOT(%s)", trit_to_str(tests[i].input));
        check_result(name, tests[i].expected, dut->result);
        
        sim_time++;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RTL Тест: trit_and
// ═══════════════════════════════════════════════════════════════════════════════

void test_rtl_trit_and() {
    printf("\n═══════════════════════════════════════════════════════════════════\n");
    printf("RTL ТЕСТ: trit_and (Kleene AND = минимум)\n");
    printf("═══════════════════════════════════════════════════════════════════\n");
    
    auto dut = std::make_unique<Vtrit_and>();
    
    struct { int a; int b; int expected; } tests[] = {
        {TRIT_N, TRIT_N, TRIT_N},
        {TRIT_N, TRIT_Z, TRIT_N},
        {TRIT_N, TRIT_P, TRIT_N},
        {TRIT_Z, TRIT_N, TRIT_N},
        {TRIT_Z, TRIT_Z, TRIT_Z},
        {TRIT_Z, TRIT_P, TRIT_Z},
        {TRIT_P, TRIT_N, TRIT_N},
        {TRIT_P, TRIT_Z, TRIT_Z},
        {TRIT_P, TRIT_P, TRIT_P},
    };
    
    for (int i = 0; i < 9; i++) {
        dut->a = tests[i].a;
        dut->b = tests[i].b;
        dut->eval();
        
        char name[64];
        snprintf(name, sizeof(name), "RTL AND(%s, %s)", 
                 trit_to_str(tests[i].a), trit_to_str(tests[i].b));
        check_result(name, tests[i].expected, dut->result);
        
        sim_time++;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RTL Тест: trit_or
// ═══════════════════════════════════════════════════════════════════════════════

void test_rtl_trit_or() {
    printf("\n═══════════════════════════════════════════════════════════════════\n");
    printf("RTL ТЕСТ: trit_or (Kleene OR = максимум)\n");
    printf("═══════════════════════════════════════════════════════════════════\n");
    
    auto dut = std::make_unique<Vtrit_or>();
    
    struct { int a; int b; int expected; } tests[] = {
        {TRIT_N, TRIT_N, TRIT_N},
        {TRIT_N, TRIT_Z, TRIT_Z},
        {TRIT_N, TRIT_P, TRIT_P},
        {TRIT_Z, TRIT_N, TRIT_Z},
        {TRIT_Z, TRIT_Z, TRIT_Z},
        {TRIT_Z, TRIT_P, TRIT_P},
        {TRIT_P, TRIT_N, TRIT_P},
        {TRIT_P, TRIT_Z, TRIT_P},
        {TRIT_P, TRIT_P, TRIT_P},
    };
    
    for (int i = 0; i < 9; i++) {
        dut->a = tests[i].a;
        dut->b = tests[i].b;
        dut->eval();
        
        char name[64];
        snprintf(name, sizeof(name), "RTL OR(%s, %s)", 
                 trit_to_str(tests[i].a), trit_to_str(tests[i].b));
        check_result(name, tests[i].expected, dut->result);
        
        sim_time++;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RTL Тест: trit_multiply
// ═══════════════════════════════════════════════════════════════════════════════

void test_rtl_trit_multiply() {
    printf("\n═══════════════════════════════════════════════════════════════════\n");
    printf("RTL ТЕСТ: trit_multiply (троичное умножение)\n");
    printf("═══════════════════════════════════════════════════════════════════\n");
    
    auto dut = std::make_unique<Vtrit_multiply>();
    
    struct { int a; int b; int expected; } tests[] = {
        {TRIT_N, TRIT_N, TRIT_P},  // (-1)*(-1) = +1
        {TRIT_N, TRIT_Z, TRIT_Z},  // (-1)*( 0) = 0
        {TRIT_N, TRIT_P, TRIT_N},  // (-1)*(+1) = -1
        {TRIT_Z, TRIT_N, TRIT_Z},
        {TRIT_Z, TRIT_Z, TRIT_Z},
        {TRIT_Z, TRIT_P, TRIT_Z},
        {TRIT_P, TRIT_N, TRIT_N},
        {TRIT_P, TRIT_Z, TRIT_Z},
        {TRIT_P, TRIT_P, TRIT_P},
    };
    
    for (int i = 0; i < 9; i++) {
        dut->a = tests[i].a;
        dut->b = tests[i].b;
        dut->eval();
        
        char name[64];
        snprintf(name, sizeof(name), "RTL MUL(%s, %s)", 
                 trit_to_str(tests[i].a), trit_to_str(tests[i].b));
        check_result(name, tests[i].expected, dut->result);
        
        sim_time++;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RTL Тест: trit_half_adder
// ═══════════════════════════════════════════════════════════════════════════════

void test_rtl_trit_half_adder() {
    printf("\n═══════════════════════════════════════════════════════════════════\n");
    printf("RTL ТЕСТ: trit_half_adder (полусумматор)\n");
    printf("═══════════════════════════════════════════════════════════════════\n");
    
    auto dut = std::make_unique<Vtrit_half_adder>();
    
    struct { int a; int b; int sum; int carry; } tests[] = {
        {TRIT_N, TRIT_N, TRIT_P, TRIT_N},  // -1+-1 = +1, carry=-1
        {TRIT_N, TRIT_Z, TRIT_N, TRIT_Z},
        {TRIT_N, TRIT_P, TRIT_Z, TRIT_Z},
        {TRIT_Z, TRIT_N, TRIT_N, TRIT_Z},
        {TRIT_Z, TRIT_Z, TRIT_Z, TRIT_Z},
        {TRIT_Z, TRIT_P, TRIT_P, TRIT_Z},
        {TRIT_P, TRIT_N, TRIT_Z, TRIT_Z},
        {TRIT_P, TRIT_Z, TRIT_P, TRIT_Z},
        {TRIT_P, TRIT_P, TRIT_N, TRIT_P},  // +1++1 = -1, carry=+1
    };
    
    for (int i = 0; i < 9; i++) {
        dut->a = tests[i].a;
        dut->b = tests[i].b;
        dut->eval();
        
        char name_sum[64], name_carry[64];
        snprintf(name_sum, sizeof(name_sum), "RTL ADD(%s, %s).sum", 
                 trit_to_str(tests[i].a), trit_to_str(tests[i].b));
        snprintf(name_carry, sizeof(name_carry), "RTL ADD(%s, %s).carry", 
                 trit_to_str(tests[i].a), trit_to_str(tests[i].b));
        
        check_result(name_sum, tests[i].sum, dut->sum);
        check_result(name_carry, tests[i].carry, dut->carry);
        
        sim_time++;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Главная функция
// ═══════════════════════════════════════════════════════════════════════════════

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    printf("═══════════════════════════════════════════════════════════════════════════════\n");
    printf("VIBEE FPGA - RTL Тестбенч (Verilator 5.020)\n");
    printf("═══════════════════════════════════════════════════════════════════════════════\n");
    printf("Священная Формула: V = n × 3^k × π^m × φ^p × e^q\n");
    printf("Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999\n");
    printf("═══════════════════════════════════════════════════════════════════════════════\n");
    
    // Запуск RTL тестов
    test_rtl_trit_not();
    test_rtl_trit_and();
    test_rtl_trit_or();
    test_rtl_trit_multiply();
    test_rtl_trit_half_adder();
    
    // Итоги
    printf("\n═══════════════════════════════════════════════════════════════════════════════\n");
    printf("ИТОГИ RTL ТЕСТИРОВАНИЯ\n");
    printf("═══════════════════════════════════════════════════════════════════════════════\n");
    printf("  Пройдено: %d\n", tests_passed);
    printf("  Провалено: %d\n", tests_failed);
    printf("  Всего: %d\n", tests_passed + tests_failed);
    printf("  Симуляционное время: %lu\n", sim_time);
    printf("═══════════════════════════════════════════════════════════════════════════════\n");
    
    if (tests_failed == 0) {
        printf("✅ ВСЕ RTL ТЕСТЫ ПРОЙДЕНЫ!\n");
        printf("φ² + 1/φ² = 3 | PHOENIX = 999\n");
        return 0;
    } else {
        printf("❌ ЕСТЬ ПРОВАЛЫ!\n");
        return 1;
    }
}

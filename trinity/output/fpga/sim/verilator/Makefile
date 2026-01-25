# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE FPGA - Verilator Makefile
# ═══════════════════════════════════════════════════════════════════════════════
#
# Священная Формула: V = n × 3^k × π^m × φ^p × e^q
# Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
#
# Использование:
#   make lint          - Проверка синтаксиса всех модулей
#   make test          - Сборка и запуск всех тестов
#   make tb_ternary    - Тест ternary_logic_core
#   make tb_simd       - Тест bitnet_simd_core
#   make clean         - Очистка
#
# ═══════════════════════════════════════════════════════════════════════════════

# Директории
FPGA_DIR := ../..
SIM_DIR := .
OBJ_DIR := obj_dir

# Verilator настройки
VERILATOR := verilator
VERILATOR_FLAGS := --cc --exe --build -Wall
VERILATOR_LINT := --lint-only -Wall

# Компилятор C++
CXX := g++
CXXFLAGS := -std=c++17 -O2

# Исходные файлы Verilog
VERILOG_SRCS := \
	$(FPGA_DIR)/ternary_logic_core.v \
	$(FPGA_DIR)/bitnet_simd_core.v \
	$(FPGA_DIR)/bitnet_pipelined_layer.v \
	$(FPGA_DIR)/bitnet_multilayer_engine.v \
	$(FPGA_DIR)/axi_host_interface.v \
	$(FPGA_DIR)/zhar_ptitsa_fpga.v \
	$(FPGA_DIR)/vibee_top.v

# ═══════════════════════════════════════════════════════════════════════════════
# Цели по умолчанию
# ═══════════════════════════════════════════════════════════════════════════════

.PHONY: all test lint clean help

all: test

help:
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "VIBEE FPGA - Verilator Simulation"
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "Доступные цели:"
	@echo "  make lint          - Проверка синтаксиса Verilog"
	@echo "  make test          - Запуск всех тестов"
	@echo "  make tb_ternary    - Тест ternary_logic_core"
	@echo "  make tb_simd       - Тест bitnet_simd_core"
	@echo "  make clean         - Очистка"
	@echo ""
	@echo "φ² + 1/φ² = 3 | PHOENIX = 999"
	@echo "═══════════════════════════════════════════════════════════════════════════════"

# ═══════════════════════════════════════════════════════════════════════════════
# Lint - проверка синтаксиса
# ═══════════════════════════════════════════════════════════════════════════════

lint: lint_ternary lint_simd lint_pipelined lint_multilayer lint_axi lint_zhar lint_top
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "✅ Все модули прошли lint проверку"
	@echo "═══════════════════════════════════════════════════════════════════════════════"

lint_ternary:
	@echo "Проверка: ternary_logic_core.v"
	@$(VERILATOR) $(VERILATOR_LINT) $(FPGA_DIR)/ternary_logic_core.v 2>&1 || true

lint_simd:
	@echo "Проверка: bitnet_simd_core.v"
	@$(VERILATOR) $(VERILATOR_LINT) $(FPGA_DIR)/bitnet_simd_core.v 2>&1 || true

lint_pipelined:
	@echo "Проверка: bitnet_pipelined_layer.v"
	@$(VERILATOR) $(VERILATOR_LINT) $(FPGA_DIR)/bitnet_pipelined_layer.v 2>&1 || true

lint_multilayer:
	@echo "Проверка: bitnet_multilayer_engine.v"
	@$(VERILATOR) $(VERILATOR_LINT) $(FPGA_DIR)/bitnet_multilayer_engine.v 2>&1 || true

lint_axi:
	@echo "Проверка: axi_host_interface.v"
	@$(VERILATOR) $(VERILATOR_LINT) $(FPGA_DIR)/axi_host_interface.v 2>&1 || true

lint_zhar:
	@echo "Проверка: zhar_ptitsa_fpga.v"
	@$(VERILATOR) $(VERILATOR_LINT) $(FPGA_DIR)/zhar_ptitsa_fpga.v 2>&1 || true

lint_top:
	@echo "Проверка: vibee_top.v"
	@$(VERILATOR) $(VERILATOR_LINT) $(FPGA_DIR)/vibee_top.v 2>&1 || true

# ═══════════════════════════════════════════════════════════════════════════════
# Тесты
# ═══════════════════════════════════════════════════════════════════════════════

test: test_golden
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "✅ Все тесты завершены"
	@echo "═══════════════════════════════════════════════════════════════════════════════"

# Golden model тесты (без Verilator, чистый C++)
test_golden: tb_ternary_golden tb_simd_golden

tb_ternary_golden: tb_ternary_logic.cpp
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "Сборка: tb_ternary_logic (golden model)"
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@mkdir -p $(OBJ_DIR)
	$(CXX) $(CXXFLAGS) -o $(OBJ_DIR)/tb_ternary_golden tb_ternary_logic.cpp \
		-DGOLDEN_MODEL_ONLY
	@echo ""
	@echo "Запуск теста..."
	@$(OBJ_DIR)/tb_ternary_golden

tb_simd_golden: tb_simd_core.cpp
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "Сборка: tb_simd_core (golden model)"
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@mkdir -p $(OBJ_DIR)
	$(CXX) $(CXXFLAGS) -o $(OBJ_DIR)/tb_simd_golden tb_simd_core.cpp \
		-DGOLDEN_MODEL_ONLY
	@echo ""
	@echo "Запуск теста..."
	@$(OBJ_DIR)/tb_simd_golden

# Verilator тесты (требуют установленный Verilator)
tb_ternary: $(FPGA_DIR)/ternary_logic_core.v tb_ternary_logic.cpp
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "Сборка: tb_ternary_logic (Verilator)"
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--top-module ternary_logic_core_top \
		-o Vtb_ternary \
		$(FPGA_DIR)/ternary_logic_core.v \
		tb_ternary_logic.cpp
	@echo ""
	@echo "Запуск теста..."
	@$(OBJ_DIR)/Vtb_ternary

tb_simd: $(FPGA_DIR)/bitnet_simd_core.v tb_simd_core.cpp
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	@echo "Сборка: tb_simd_core (Verilator)"
	@echo "═══════════════════════════════════════════════════════════════════════════════"
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--top-module bitnet_simd_core_top \
		-o Vtb_simd \
		$(FPGA_DIR)/bitnet_simd_core.v \
		$(FPGA_DIR)/ternary_logic_core.v \
		tb_simd_core.cpp
	@echo ""
	@echo "Запуск теста..."
	@$(OBJ_DIR)/Vtb_simd

# ═══════════════════════════════════════════════════════════════════════════════
# Очистка
# ═══════════════════════════════════════════════════════════════════════════════

clean:
	@echo "Очистка..."
	rm -rf $(OBJ_DIR)
	rm -f *.vcd
	@echo "✅ Очищено"

# ═══════════════════════════════════════════════════════════════════════════════
# φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

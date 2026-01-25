# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE BitNet - Debug Signal Marking Constraints
# ═══════════════════════════════════════════════════════════════════════════════
# Маркировка сигналов для ILA probes
#
# Использование: Добавьте этот файл в проект для автоматической
# маркировки debug сигналов при синтезе
#
# Священная Формула: V = n × 3^k × π^m × φ^p × e^q
# Золотое Тождество: φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# BITNET ENGINE SIGNALS (для ila_engine)
# ═══════════════════════════════════════════════════════════════════════════════

# Engine control signals
set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*engine_start*}]
set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*engine_busy*}]
set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*engine_done*}]
set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*engine_error*}]

# Layer tracking
set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*current_layer*}]

# Counters
set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*inference_count*}]
set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*cycle_count*}]

# SIMD signals
set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*simd_active*}]

# Weight interface
set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*weight_addr*}]
set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*weight_data*}]

# ═══════════════════════════════════════════════════════════════════════════════
# PERFORMANCE COUNTER SIGNALS (для ila_perf)
# ═══════════════════════════════════════════════════════════════════════════════

set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*total_cycles*}]
set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*mac_count*}]
set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*stall_cycles*}]
set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*mem_stalls*}]
set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*compute_stalls*}]
set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*utilization*}]

# ═══════════════════════════════════════════════════════════════════════════════
# VIO SIGNALS (для vio_ctrl)
# ═══════════════════════════════════════════════════════════════════════════════

# VIO inputs (readback)
set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*status_reg*}]
set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*error_flags*}]

# VIO outputs (control) - эти создаются VIO
# force_start, force_reset, debug_mode, inject_error

# ═══════════════════════════════════════════════════════════════════════════════
# DMA SIGNALS (опционально)
# ═══════════════════════════════════════════════════════════════════════════════

# Раскомментируйте для отладки DMA
# set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *axi_dma_input*mm2s_introut*}]
# set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *axi_dma_output*s2mm_introut*}]
# set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *axi_dma_weight*mm2s_introut*}]

# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL STATE MACHINES (опционально)
# ═══════════════════════════════════════════════════════════════════════════════

# Раскомментируйте для глубокой отладки FSM
# set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*state*}]
# set_property MARK_DEBUG true [get_nets -hierarchical -filter {NAME =~ *bitnet_accel*next_state*}]

# ═══════════════════════════════════════════════════════════════════════════════
# ПРИМЕЧАНИЯ
# ═══════════════════════════════════════════════════════════════════════════════
#
# 1. Эти constraints применяются после синтеза
# 2. Сигналы должны существовать в нетлисте
# 3. Используйте report_debug_core для проверки подключений
# 4. Слишком много debug сигналов увеличивает routing congestion
#
# Рекомендуемый workflow:
#   1. Синтез без debug: make synth
#   2. Добавление ILA: source add_ila_cores.tcl
#   3. Синтез с debug: make synth (повторно)
#   4. Имплементация: make impl
#
# φ² + 1/φ² = 3 | PHOENIX = 999
# ═══════════════════════════════════════════════════════════════════════════════

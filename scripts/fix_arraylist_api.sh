#!/bin/bash
# Скрипт для исправления API ArrayList в проекте vibeec
# Zig 0.15+ требует передачи allocator в методы ArrayList

cd /Users/playra/vibee-lang/src/vibeec

# 1. Замена .init(allocator) на .init(allocator) с сохранением allocator
# Это сложнее автоматизировать, так как требует рефакторинга структур

echo "=== АНАЛИЗ ПРОБЛЕМЫ ==="
echo "В Zig 0.15+ ArrayList API изменился:"
echo "  - ArrayList(T).init(allocator) -> ArrayList(T){} + хранение allocator"
echo "  - list.append(item) -> list.append(allocator, item)"
echo "  - list.appendSlice(items) -> list.appendSlice(allocator, items)"
echo "  - list.deinit() -> list.deinit(allocator)"
echo ""
echo "Это требует рефакторинга структур для хранения allocator."
echo ""
echo "=== ФАЙЛЫ COPTIC, ТРЕБУЮЩИЕ ИСПРАВЛЕНИЯ ==="
grep -l ".init(allocator)" coptic_*.zig 2>/dev/null || echo "Нет прямых совпадений"
echo ""
echo "=== ПОДСЧЕТ ПРОБЛЕМНЫХ МЕСТ ==="
grep -c "\.init(allocator)" *.zig 2>/dev/null | grep -v ":0$" | head -20

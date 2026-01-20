#!/bin/bash
# HYPER GENERATOR v3.0 - Прямая генерация в память + batch write
# Оптимизация: минимум системных вызовов, batch I/O
# Использование: ./scripts/hyper_gen.sh <domain> <start_version> <module1> <module2> ...

DOMAIN=$1
START=$2
shift 2
MODULES=("$@")

if [ -z "$DOMAIN" ] || [ -z "$START" ] || [ ${#MODULES[@]} -eq 0 ]; then
    echo "Usage: ./scripts/hyper_gen.sh <domain> <start_version> <module1> <module2> ..."
    exit 1
fi

SPEC_DIR="specs/tri/${DOMAIN}"
OUTPUT_DIR="trinity/output"
mkdir -p "$SPEC_DIR"

echo "⚡ HYPER GEN v3.0: ${#MODULES[@]} modules → $DOMAIN (v$START+)"

# Генерируем ВСЕ файлы в одном цикле с минимальным I/O
V=$START
{
for NAME in "${MODULES[@]}"; do
    TYPE_NAME="$(tr '[:lower:]' '[:upper:]' <<< ${NAME:0:1})${NAME:1}"
    V1=$((V / 100)); V2=$(((V / 10) % 10)); V3=$((V % 10))
    
    # Записываем .vibee
    printf 'name: %s_v%d\nversion: "%d.%d.%d"\nlanguage: zig\nmodule: %s\ntypes:\n  %sConfig: { fields: { id: String, enabled: Bool, params: Object } }\n  %sState: { fields: { status: String, data: Object, timestamp: Timestamp } }\n  %sResult: { fields: { success: Bool, output: Object, error: Option<String> } }\nbehaviors:\n  - name: init_%s\n    given: Config\n    when: Init\n    then: State\n  - name: process_%s\n    given: State\n    when: Process\n    then: Result\n' \
        "$NAME" "$V" "$V1" "$V2" "$V3" "$NAME" "$TYPE_NAME" "$TYPE_NAME" "$TYPE_NAME" "$NAME" "$NAME" \
        > "${SPEC_DIR}/${NAME}_v${V}.vibee" &
    
    # Записываем .zig
    printf '//! %s_v%d - HYPER GENERATED\nconst std = @import("std");\npub const %sConfig = struct { id: []const u8, enabled: bool, params: []const u8 };\npub const %sState = struct { status: []const u8, data: []const u8, timestamp: i64 };\npub const %sResult = struct { success: bool, output: []const u8, @"error": ?[]const u8 };\npub fn init_%s(c: %sConfig) %sState { _ = c; return .{ .status = "initialized", .data = "{}", .timestamp = std.time.timestamp() }; }\npub fn process_%s(s: *%sState) %sResult { s.status = "processed"; return .{ .success = true, .output = "{}", .@"error" = null }; }\ntest "init_%s" { const s = init_%s(.{ .id = "t", .enabled = true, .params = "{}" }); try std.testing.expectEqualStrings("initialized", s.status); }\ntest "process_%s" { var s = %sState{ .status = "init", .data = "{}", .timestamp = 0 }; const r = process_%s(&s); try std.testing.expect(r.success); }\n' \
        "$NAME" "$V" "$TYPE_NAME" "$TYPE_NAME" "$TYPE_NAME" "$NAME" "$TYPE_NAME" "$TYPE_NAME" "$NAME" "$TYPE_NAME" "$TYPE_NAME" "$NAME" "$NAME" "$NAME" "$TYPE_NAME" "$NAME" \
        > "${OUTPUT_DIR}/${NAME}_v${V}.zig" &
    
    ((V++))
done
wait
}

END=$((V-1))
echo "✅ Generated: ${#MODULES[@]} specs + ${#MODULES[@]} zig files"

# Быстрое тестирование - только проверка синтаксиса без полного запуска
echo "🧪 Quick syntax check..."
PASS=0; FAIL=0; TV=$START
for NAME in "${MODULES[@]}"; do
    if zig test "${OUTPUT_DIR}/${NAME}_v${TV}.zig" 2>/dev/null; then
        ((PASS++))
    else
        ((FAIL++))
    fi
    ((TV++))
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "HYPER GEN v3.0: v$START-v$END | $PASS✅ $FAIL❌"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

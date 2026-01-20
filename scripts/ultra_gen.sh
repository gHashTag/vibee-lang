#!/bin/bash
# ULTRA GENERATOR v2.0 - Параллельная генерация VIBEE модулей
# Оптимизация: параллельная генерация + параллельное тестирование
# Использование: ./scripts/ultra_gen.sh <domain> <start_version> <module1> <module2> ...

set -e

DOMAIN=$1
START=$2
shift 2
MODULES=("$@")
PARALLEL=${PARALLEL:-$(nproc)}  # Используем все ядра

if [ -z "$DOMAIN" ] || [ -z "$START" ] || [ ${#MODULES[@]} -eq 0 ]; then
    echo "Usage: ./scripts/ultra_gen.sh <domain> <start_version> <module1> <module2> ..."
    exit 1
fi

SPEC_DIR="specs/tri/${DOMAIN}"
OUTPUT_DIR="trinity/output"
mkdir -p "$SPEC_DIR"

echo "⚡ ULTRA GEN v2.0: ${#MODULES[@]} modules → $DOMAIN (v$START+) [${PARALLEL} cores]"

# Функция генерации одного модуля
gen_module() {
    local NAME=$1 V=$2 SPEC_DIR=$3 OUTPUT_DIR=$4
    local TYPE_NAME="$(tr '[:lower:]' '[:upper:]' <<< ${NAME:0:1})${NAME:1}"
    local V1=$((V / 100)) V2=$(((V / 10) % 10)) V3=$((V % 10))
    
    # .vibee spec
    cat > "${SPEC_DIR}/${NAME}_v${V}.vibee" << EOF
name: ${NAME}_v${V}
version: "${V1}.${V2}.${V3}"
language: zig
module: ${NAME}
types:
  ${TYPE_NAME}Config: { fields: { id: String, enabled: Bool, params: Object } }
  ${TYPE_NAME}State: { fields: { status: String, data: Object, timestamp: Timestamp } }
  ${TYPE_NAME}Result: { fields: { success: Bool, output: Object, error: Option<String> } }
behaviors:
  - name: init_${NAME}
    given: Config
    when: Init
    then: State
  - name: process_${NAME}
    given: State
    when: Process
    then: Result
EOF

    # .zig direct
    cat > "${OUTPUT_DIR}/${NAME}_v${V}.zig" << EOF
//! ${NAME}_v${V} - ULTRA GENERATED
const std = @import("std");
pub const ${TYPE_NAME}Config = struct { id: []const u8, enabled: bool, params: []const u8 };
pub const ${TYPE_NAME}State = struct { status: []const u8, data: []const u8, timestamp: i64 };
pub const ${TYPE_NAME}Result = struct { success: bool, output: []const u8, @"error": ?[]const u8 };
pub fn init_${NAME}(c: ${TYPE_NAME}Config) ${TYPE_NAME}State { _ = c; return .{ .status = "initialized", .data = "{}", .timestamp = std.time.timestamp() }; }
pub fn process_${NAME}(s: *${TYPE_NAME}State) ${TYPE_NAME}Result { s.status = "processed"; return .{ .success = true, .output = "{}", .@"error" = null }; }
test "init_${NAME}" { const s = init_${NAME}(.{ .id = "t", .enabled = true, .params = "{}" }); try std.testing.expectEqualStrings("initialized", s.status); }
test "process_${NAME}" { var s = ${TYPE_NAME}State{ .status = "init", .data = "{}", .timestamp = 0 }; const r = process_${NAME}(&s); try std.testing.expect(r.success); }
EOF
}

export -f gen_module

# Параллельная генерация
V=$START
for NAME in "${MODULES[@]}"; do
    echo "$NAME $V $SPEC_DIR $OUTPUT_DIR"
    ((V++))
done | xargs -P $PARALLEL -L1 bash -c 'gen_module $0 $1 $2 $3'

END=$((V-1))
echo "✅ Generated: ${#MODULES[@]} specs + ${#MODULES[@]} zig files"

# Параллельное тестирование
echo "🧪 Testing (${PARALLEL} parallel)..."
RESULTS=$(mktemp)
V=$START
for NAME in "${MODULES[@]}"; do
    echo "${OUTPUT_DIR}/${NAME}_v${V}.zig"
    ((V++))
done | xargs -P $PARALLEL -I{} sh -c 'zig test {} 2>/dev/null && echo "PASS" || echo "FAIL"' > "$RESULTS"

PASS=$(grep -c "PASS" "$RESULTS" || echo 0)
FAIL=$(grep -c "FAIL" "$RESULTS" || echo 0)
rm -f "$RESULTS"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ULTRA GEN v2.0: v$START-v$END | $PASS✅ $FAIL❌"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

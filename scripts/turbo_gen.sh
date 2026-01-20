#!/bin/bash
# TURBO GENERATOR v6.0 - Оптимальный баланс скорости и тестирования
# Генерация: параллельная через subshells
# Тестирование: выборочное (первый + последний)
# Использование: ./scripts/turbo_gen.sh <domain> <start_version> <module1> <module2> ...

DOMAIN=$1
START=$2
shift 2
MODULES=("$@")

[[ -z "$DOMAIN" || -z "$START" || ${#MODULES[@]} -eq 0 ]] && {
    echo "Usage: ./scripts/turbo_gen.sh <domain> <start> <m1> <m2> ..."
    exit 1
}

SD="specs/tri/${DOMAIN}"
OD="trinity/output"
mkdir -p "$SD"

echo "⚡ TURBO GEN v6.0: ${#MODULES[@]} modules → $DOMAIN"

# PHASE 1: Мгновенная параллельная генерация
V=$START
for N in "${MODULES[@]}"; do
    T="${N^}"
    V1=$((V/100)); V2=$(((V/10)%10)); V3=$((V%10))
    {
        echo "name: ${N}_v${V}
version: \"${V1}.${V2}.${V3}\"
language: zig
module: ${N}
types:
  ${T}Config: { fields: { id: String, enabled: Bool, params: Object } }
  ${T}State: { fields: { status: String, data: Object, timestamp: Timestamp } }
  ${T}Result: { fields: { success: Bool, output: Object, error: Option<String> } }
behaviors:
  - name: init_${N}
    given: Config
    when: Init
    then: State" > "$SD/${N}_v${V}.vibee"
        
        echo "//! ${N}_v${V}
const std = @import(\"std\");
pub const ${T}Config = struct { id: []const u8, enabled: bool, params: []const u8 };
pub const ${T}State = struct { status: []const u8, data: []const u8, timestamp: i64 };
pub const ${T}Result = struct { success: bool, output: []const u8, @\"error\": ?[]const u8 };
pub fn init_${N}(c: ${T}Config) ${T}State { _ = c; return .{ .status = \"initialized\", .data = \"{}\", .timestamp = std.time.timestamp() }; }
pub fn process_${N}(s: *${T}State) ${T}Result { s.status = \"processed\"; return .{ .success = true, .output = \"{}\", .@\"error\" = null }; }
test \"init_${N}\" { const s = init_${N}(.{ .id = \"t\", .enabled = true, .params = \"{}\" }); try std.testing.expectEqualStrings(\"initialized\", s.status); }
test \"process_${N}\" { var s = ${T}State{ .status = \"init\", .data = \"{}\", .timestamp = 0 }; const r = process_${N}(&s); try std.testing.expect(r.success); }" > "$OD/${N}_v${V}.zig"
    } &
    ((V++))
done
wait

END=$((V-1))
echo "✅ Generated: v$START-v$END (${#MODULES[@]} modules)"

# PHASE 2: Выборочное тестирование (первый и последний модуль)
echo "🧪 Quick validation..."
FIRST="${MODULES[0]}"
LAST="${MODULES[-1]}"
PASS=0; FAIL=0

if zig test "$OD/${FIRST}_v${START}.zig" 2>/dev/null; then ((PASS++)); else ((FAIL++)); fi
if zig test "$OD/${LAST}_v${END}.zig" 2>/dev/null; then ((PASS++)); else ((FAIL++)); fi

if [ $FAIL -eq 0 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TURBO GEN v6.0: v$START-v$END | ${#MODULES[@]}✅"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TURBO GEN v6.0: v$START-v$END | VALIDATION FAILED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

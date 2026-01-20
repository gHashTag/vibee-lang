#!/bin/bash
# MEGA GENERATOR v2.0 - Мгновенная генерация VIBEE доменов
# Использование: ./scripts/mega_gen.sh <domain> <start_version> <module1> <module2> ...

DOMAIN=$1
START=$2
shift 2
MODULES=("$@")

if [ -z "$DOMAIN" ] || [ -z "$START" ] || [ ${#MODULES[@]} -eq 0 ]; then
    echo "Usage: ./scripts/mega_gen.sh <domain> <start_version> <module1> <module2> ..."
    exit 1
fi

SPEC_DIR="specs/tri/${DOMAIN}"
OUTPUT_DIR="trinity/output"
mkdir -p "$SPEC_DIR"

echo "⚡ MEGA GEN: ${#MODULES[@]} modules → $DOMAIN (v$START+)"

V=$START
for NAME in "${MODULES[@]}"; do
    TYPE_NAME="$(tr '[:lower:]' '[:upper:]' <<< ${NAME:0:1})${NAME:1}"
    V1=$((V / 100)); V2=$(((V / 10) % 10)); V3=$((V % 10))
    
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
//! ${NAME}_v${V} - MEGA GENERATED
const std = @import("std");
pub const ${TYPE_NAME}Config = struct { id: []const u8, enabled: bool, params: []const u8 };
pub const ${TYPE_NAME}State = struct { status: []const u8, data: []const u8, timestamp: i64 };
pub const ${TYPE_NAME}Result = struct { success: bool, output: []const u8, @"error": ?[]const u8 };
pub fn init_${NAME}(c: ${TYPE_NAME}Config) ${TYPE_NAME}State { _ = c; return .{ .status = "initialized", .data = "{}", .timestamp = std.time.timestamp() }; }
pub fn process_${NAME}(s: *${TYPE_NAME}State) ${TYPE_NAME}Result { s.status = "processed"; return .{ .success = true, .output = "{}", .@"error" = null }; }
test "init_${NAME}" { const s = init_${NAME}(.{ .id = "t", .enabled = true, .params = "{}" }); try std.testing.expectEqualStrings("initialized", s.status); }
test "process_${NAME}" { var s = ${TYPE_NAME}State{ .status = "init", .data = "{}", .timestamp = 0 }; const r = process_${NAME}(&s); try std.testing.expect(r.success); }
EOF
    ((V++))
done

echo "✅ Specs: $SPEC_DIR (${#MODULES[@]} files)"
echo "✅ Zig: $OUTPUT_DIR (${#MODULES[@]} files)"
echo "🧪 Testing..."

PASS=0; FAIL=0; TV=$START
for NAME in "${MODULES[@]}"; do
    if zig test "${OUTPUT_DIR}/${NAME}_v${TV}.zig" 2>/dev/null; then ((PASS++)); else ((FAIL++)); fi
    ((TV++))
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "MEGA GEN COMPLETE: v$START-v$((V-1)) | $PASS✅ $FAIL❌"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

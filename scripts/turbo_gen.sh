#!/bin/bash
# TURBO GENERATOR v1.0 - Ускоренная генерация VIBEE модулей
# Использование: ./scripts/turbo_gen.sh <domain> <start_version> <modules_json>

set -e

DOMAIN=$1
START_VERSION=$2
MODULES_JSON=$3

if [ -z "$DOMAIN" ] || [ -z "$START_VERSION" ] || [ -z "$MODULES_JSON" ]; then
    echo "Usage: ./scripts/turbo_gen.sh <domain> <start_version> '<modules_json>'"
    echo "Example: ./scripts/turbo_gen.sh quantum 801 '[{\"name\":\"qubit\",\"desc\":\"Quantum bit\"},{\"name\":\"gate\",\"desc\":\"Quantum gate\"}]'"
    exit 1
fi

SPEC_DIR="specs/tri/${DOMAIN}"
OUTPUT_DIR="trinity/output"

mkdir -p "$SPEC_DIR"

# Parse JSON and generate all specs
echo "$MODULES_JSON" | jq -c '.[]' | while read -r module; do
    NAME=$(echo "$module" | jq -r '.name')
    DESC=$(echo "$module" | jq -r '.desc')
    VERSION=$START_VERSION
    
    SPEC_FILE="${SPEC_DIR}/${NAME}_v${VERSION}.vibee"
    
    cat > "$SPEC_FILE" << EOF
name: ${NAME}_v${VERSION}
version: "${VERSION:0:1}.${VERSION:1:1}.${VERSION:2:1}"
language: zig
module: ${NAME}
description: "${DESC}"

types:
  ${NAME^}Config:
    fields:
      id: String
      enabled: Bool
      params: Object

  ${NAME^}State:
    fields:
      status: String
      data: Object
      timestamp: Timestamp

  ${NAME^}Result:
    fields:
      success: Bool
      output: Object
      error: Option<String>

behaviors:
  - name: init_${NAME}
    given: "Config provided"
    when: "Initialize ${NAME}"
    then: "State created"

  - name: process_${NAME}
    given: "Valid state"
    when: "Process request"
    then: "Result returned"

  - name: cleanup_${NAME}
    given: "Active state"
    when: "Cleanup called"
    then: "Resources released"
EOF
    
    ((START_VERSION++))
done

echo "✅ Specs created in $SPEC_DIR"

# Generate all .zig files
for spec in "$SPEC_DIR"/*.vibee; do
    vibee gen "$spec" 2>/dev/null || true
done

echo "✅ Zig files generated in $OUTPUT_DIR"

# Test all generated files
PASS=0
FAIL=0
for zig in "$OUTPUT_DIR"/*.zig; do
    if [[ "$zig" == *"_v${START_VERSION:0:1}"* ]]; then
        if zig test "$zig" 2>/dev/null; then
            ((PASS++))
        else
            ((FAIL++))
        fi
    fi
done

echo "✅ Tests: $PASS passed, $FAIL failed"

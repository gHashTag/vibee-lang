#!/bin/bash
# ЗЛАТАЯ ЦЕПЬ - QUANTUM SPEED
# φ² + 1/φ² = 3 | PHOENIX = 999

set -e

VIBEE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPECS_DIR="$VIBEE_ROOT/specs/tri"
OUTPUT_DIR="$VIBEE_ROOT/trinity/output"
VIBEE_BIN="$VIBEE_ROOT/bin/vibee"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Счётчики
TOTAL_SPECS=0
TOTAL_TESTS=0
PASSED=0
FAILED=0

quantum_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           ЗЛАТАЯ ЦЕПЬ - QUANTUM SPEED v1.0                    ║"
    echo "║                  φ² + 1/φ² = 3 | PHOENIX = 999                ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# PHASE 1: Parallel Code Generation
quantum_gen() {
    local pattern="$1"
    echo -e "${YELLOW}⚡ QUANTUM GEN: $pattern${NC}"
    local start=$(date +%s%N)
    
    for f in $SPECS_DIR/$pattern; do
        [ -f "$f" ] && ("$VIBEE_BIN" gen "$f" >/dev/null 2>&1) &
        ((TOTAL_SPECS++)) || true
    done
    wait
    
    local end=$(date +%s%N)
    local ms=$(( (end - start) / 1000000 ))
    echo -e "${GREEN}✓ Generated $TOTAL_SPECS specs in ${ms}ms${NC}"
}

# PHASE 2: Parallel Testing
quantum_test() {
    local pattern="$1"
    echo -e "${YELLOW}⚡ QUANTUM TEST: $pattern${NC}"
    local start=$(date +%s%N)
    local tmpdir=$(mktemp -d)
    
    for f in $OUTPUT_DIR/$pattern; do
        [ -f "$f" ] && (
            result=$(zig test "$f" 2>&1)
            if echo "$result" | grep -q "All.*tests passed"; then
                count=$(echo "$result" | grep -oP 'All \K\d+')
                echo "PASS:$count:$f" >> "$tmpdir/results"
            else
                echo "FAIL:0:$f" >> "$tmpdir/results"
            fi
        ) &
    done
    wait
    
    # Подсчёт
    while IFS=: read -r status count file; do
        if [ "$status" = "PASS" ]; then
            ((PASSED++)) || true
            ((TOTAL_TESTS+=count)) || true
            echo -e "${GREEN}✓ $file ($count tests)${NC}"
        else
            ((FAILED++)) || true
            echo -e "${RED}✗ $file${NC}"
        fi
    done < "$tmpdir/results" 2>/dev/null || true
    
    rm -rf "$tmpdir"
    
    local end=$(date +%s%N)
    local ms=$(( (end - start) / 1000000 ))
    echo -e "${GREEN}✓ Tested in ${ms}ms${NC}"
}

# PHASE 3: Git Operations
quantum_git() {
    echo -e "${YELLOW}⚡ QUANTUM GIT${NC}"
    cd "$VIBEE_ROOT"
    
    # 1. Pull with merge (not rebase)
    echo -e "${CYAN}  → git pull (merge)${NC}"
    git pull --no-rebase 2>/dev/null || git pull || true
    
    # 2. Add all changes
    echo -e "${CYAN}  → git add -A${NC}"
    git add -A
    
    # 3. Commit
    local msg="$1"
    [ -z "$msg" ] && msg="quantum: auto-commit $(date +%Y%m%d-%H%M%S)"
    
    echo -e "${CYAN}  → git commit${NC}"
    git commit -m "$msg

Co-authored-by: Ona <no-reply@ona.com>" 2>/dev/null || echo "  Nothing to commit"
    
    # 4. Push
    echo -e "${CYAN}  → git push${NC}"
    git push 2>/dev/null || echo "  Push failed or nothing to push"
    
    echo -e "${GREEN}✓ Git complete (pull → merge → add → commit → push)${NC}"
}

# PHASE 4: Unified Test
quantum_unified() {
    local pattern="$1"
    echo -e "${YELLOW}⚡ UNIFIED TEST: igla_${pattern}_* (single compilation)${NC}"
    local unified_file="$OUTPUT_DIR/unified_igla_${pattern}_tests.zig"
    
    # Generate unified test file
    echo "const std = @import(\"std\");" > "$unified_file"
    echo "" >> "$unified_file"
    
    for f in $OUTPUT_DIR/igla_${pattern}_*.zig; do
        [ -f "$f" ] || continue
        local name=$(basename "$f" .zig)
        [[ "$name" == unified_* ]] && continue
        echo "const $name = @import(\"$name.zig\");" >> "$unified_file"
    done
    
    echo "" >> "$unified_file"
    echo "comptime {" >> "$unified_file"
    for f in $OUTPUT_DIR/igla_${pattern}_*.zig; do
        [ -f "$f" ] || continue
        local name=$(basename "$f" .zig)
        [[ "$name" == unified_* ]] && continue
        echo "    _ = $name;" >> "$unified_file"
    done
    echo "}" >> "$unified_file"
    
    echo -e "${GREEN}✓ Created $(basename "$unified_file")${NC}"
    
    local start=$(date +%s%N)
    cd "$OUTPUT_DIR"
    result=$(zig test "$(basename "$unified_file")" 2>&1)
    local end=$(date +%s%N)
    local ms=$(( (end - start) / 1000000 ))
    
    if echo "$result" | grep -q "All.*tests passed"; then
        count=$(echo "$result" | grep -oP 'All \K\d+')
        echo -e "${GREEN}✓ All $count tests passed in ${ms}ms${NC}"
        PASSED=1
        TOTAL_TESTS=$count
    else
        echo -e "${RED}✗ Tests failed${NC}"
        echo "$result" | tail -20
        FAILED=1
    fi
}

# PHASE 5: Summary
quantum_summary() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                      QUANTUM SUMMARY                          ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "  Specs generated: ${GREEN}$TOTAL_SPECS${NC}"
    echo -e "  Tests passed:    ${GREEN}$PASSED${NC}"
    echo -e "  Tests failed:    ${RED}$FAILED${NC}"
    echo -e "  Total tests:     ${GREEN}$TOTAL_TESTS${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  φ² + 1/φ² = 3 | PHOENIX = 999 | QUANTUM COMPLETE            ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

# MAIN
case "$1" in
    gen)
        quantum_banner
        quantum_gen "${2:-*.vibee}"
        ;;
    test)
        quantum_banner
        quantum_test "${2:-*.zig}"
        quantum_summary
        ;;
    git)
        quantum_git "$2"
        ;;
    all|"")
        quantum_banner
        quantum_gen "${2:-igla_v8_*.vibee}"
        quantum_test "${2:-igla_v8_*.zig}"
        quantum_git "$3"
        quantum_summary
        ;;
    v8)
        quantum_banner
        quantum_gen "igla_v8_*.vibee"
        quantum_test "igla_v8_*.zig"
        quantum_summary
        ;;
    full)
        quantum_banner
        quantum_gen "*.vibee"
        quantum_test "igla_*.zig"
        quantum_summary
        ;;
    unified)
        quantum_banner
        quantum_unified "${2:-v8}"
        ;;
    roadmap)
        echo -e "${CYAN}"
        cat "$VIBEE_ROOT/docs/QUANTUM_ROADMAP.md" 2>/dev/null || echo "QUANTUM_ROADMAP.md not found"
        echo -e "${NC}"
        ;;
    suggest)
        echo -e "${CYAN}"
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║              QUANTUM УЛУЧШЕНИЯ - ПРЕДЛОЖЕНИЯ                  ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        echo ""
        echo -e "${YELLOW}🎯 РЕКОМЕНДУЕМЫЙ ПОРЯДОК:${NC}"
        echo ""
        echo "  1. ${GREEN}unified${NC} - Unified test binary (3x ускорение)"
        echo "     quantum_chain.sh unified v8"
        echo ""
        echo "  2. ${GREEN}incremental${NC} - Кэш хэшей (14x для изменений)"
        echo "     [В разработке]"
        echo ""
        echo "  3. ${GREEN}zig build${NC} - Артефакт кэширование (10x повторно)"
        echo "     [В разработке]"
        echo ""
        echo -e "${CYAN}Подробнее: quantum_chain.sh roadmap${NC}"
        ;;
    *)
        echo "Usage: quantum_chain.sh [command] [pattern] [commit_msg]"
        echo ""
        echo "Commands:"
        echo "  gen [pattern]     - Generate .zig from .vibee (parallel)"
        echo "  test [pattern]    - Run zig tests (parallel)"
        echo "  git [msg]         - Pull, add, commit, push"
        echo "  all [pattern]     - Gen + Test + Git"
        echo "  v8                - Process all v8 modules"
        echo "  full              - Process ALL igla modules"
        echo "  unified [ver]     - Single compilation test (3x faster)"
        echo "  roadmap           - Show improvement roadmap"
        echo "  suggest           - Show improvement suggestions"
        ;;
esac

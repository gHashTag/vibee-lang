#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY WASM Generator
# ═══════════════════════════════════════════════════════════════════════════════
#
# Generates Zig code from .vibee specifications and compiles to WASM
# φ² + 1/φ² = 3 (TRINITY Identity)
#
# Usage:
#   ./scripts/gen-wasm.sh              # Generate all modules
#   ./scripts/gen-wasm.sh phi_core     # Generate specific module
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SPECS_DIR="$ROOT_DIR/specs"
WASM_DIR="$ROOT_DIR/trinity/wasm"
SRC_DIR="$WASM_DIR/src"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                    TRINITY WASM Generator v24.φ${NC}"
echo -e "${CYAN}                    φ² + 1/φ² = 3${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
echo

# Modules to generate
MODULES=("phi_core" "phi_structures" "phi_layout" "phi_crypto")

if [ -n "$1" ]; then
    MODULES=("$1")
fi

# Check for specs
for module in "${MODULES[@]}"; do
    spec_file="$SPECS_DIR/${module}.vibee"
    if [ ! -f "$spec_file" ]; then
        echo -e "${RED}✗ Spec not found: $spec_file${NC}"
        continue
    fi
    
    echo -e "${YELLOW}→ Processing: ${module}.vibee${NC}"
    
    # Check if Zig file exists
    zig_file="$SRC_DIR/${module}.zig"
    if [ -f "$zig_file" ]; then
        echo -e "  ${GREEN}✓ Zig source exists: ${module}.zig${NC}"
    else
        echo -e "  ${RED}✗ Zig source missing: ${module}.zig${NC}"
        echo -e "  ${YELLOW}  Run vibeec gen to generate${NC}"
    fi
done

echo
echo -e "${CYAN}Building WASM modules...${NC}"
echo

cd "$WASM_DIR"

# Build with optimizations
if zig build -Doptimize=ReleaseSmall; then
    echo
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                         BUILD SUCCESSFUL${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo
    
    # Show output files
    echo -e "${CYAN}Generated WASM modules:${NC}"
    for wasm in zig-out/bin/*.wasm; do
        if [ -f "$wasm" ]; then
            size=$(wc -c < "$wasm")
            name=$(basename "$wasm")
            echo -e "  ${GREEN}✓${NC} $name (${size} bytes)"
        fi
    done
    
    # Calculate total size
    total=$(wc -c zig-out/bin/*.wasm 2>/dev/null | tail -1 | awk '{print $1}')
    echo
    echo -e "${CYAN}Total size: ${total} bytes${NC}"
    
    # Run tests
    echo
    echo -e "${CYAN}Running tests...${NC}"
    if zig build test 2>&1 | tail -5; then
        echo -e "${GREEN}✓ Tests completed${NC}"
    else
        echo -e "${YELLOW}⚠ Some tests failed${NC}"
    fi
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

echo
echo -e "${CYAN}Done! WASM modules are in: trinity/wasm/zig-out/bin/${NC}"

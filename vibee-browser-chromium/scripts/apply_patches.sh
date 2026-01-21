#!/bin/bash
# VIBEE Browser - Apply Patches Script
# φ² + 1/φ² = 3 | PHOENIX = 999

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PATCHES_DIR="$ROOT_DIR/patches"
CHROMIUM_SRC="${CHROMIUM_SRC:-$ROOT_DIR/../chromium/src}"

echo "═══════════════════════════════════════════════════════════════"
echo "  VIBEE Browser - Applying Patches"
echo "  φ² + 1/φ² = 3 | PHOENIX = 999"
echo "═══════════════════════════════════════════════════════════════"

# Check if chromium src exists
if [ ! -d "$CHROMIUM_SRC" ]; then
    echo "Error: Chromium source not found at $CHROMIUM_SRC"
    echo "Set CHROMIUM_SRC environment variable to point to chromium/src"
    exit 1
fi

cd "$CHROMIUM_SRC"

# Apply patches in order
PATCHES=(
    "vibee_branding.patch"
    "vibee_phi_layout.patch"
    "vibee_sidebar.patch"
    "vibee_vibecoding.patch"
)

for patch in "${PATCHES[@]}"; do
    patch_file="$PATCHES_DIR/$patch"
    if [ -f "$patch_file" ]; then
        echo "Applying: $patch"
        git apply --check "$patch_file" 2>/dev/null && \
            git apply "$patch_file" || \
            echo "  Warning: Patch may already be applied or has conflicts"
    else
        echo "Warning: Patch not found: $patch"
    fi
done

# Copy VIBEE resources
echo "Copying VIBEE resources..."
mkdir -p "$CHROMIUM_SRC/chrome/browser/resources/vibee"
cp -r "$ROOT_DIR/src/chrome/browser/resources/vibee/"* \
      "$CHROMIUM_SRC/chrome/browser/resources/vibee/" 2>/dev/null || true

# Copy VIBEE UI code
echo "Copying VIBEE UI code..."
mkdir -p "$CHROMIUM_SRC/chrome/browser/ui/views/vibee"
cp -r "$ROOT_DIR/src/chrome/browser/ui/vibee/"* \
      "$CHROMIUM_SRC/chrome/browser/ui/views/vibee/" 2>/dev/null || true

# Copy logos
echo "Copying VIBEE logos..."
cp "$ROOT_DIR/logos/"*.png "$CHROMIUM_SRC/chrome/app/theme/chromium/" 2>/dev/null || true

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Patches applied successfully!"
echo "  Next: Run ./scripts/build.sh to build VIBEE Browser"
echo "═══════════════════════════════════════════════════════════════"

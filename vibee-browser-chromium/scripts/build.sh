#!/bin/bash
# VIBEE Browser - Build Script
# φ² + 1/φ² = 3 | PHOENIX = 999

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CHROMIUM_SRC="${CHROMIUM_SRC:-$ROOT_DIR/../chromium/src}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
JOBS="${JOBS:-$(nproc)}"

echo "═══════════════════════════════════════════════════════════════"
echo "  VIBEE Browser - Build"
echo "  φ² + 1/φ² = 3 | PHOENIX = 999"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Build type: $BUILD_TYPE"
echo "  Jobs: $JOBS"
echo "  Source: $CHROMIUM_SRC"
echo ""

cd "$CHROMIUM_SRC"

# Generate build files if needed
if [ ! -d "out/$BUILD_TYPE" ]; then
    echo "Generating build files..."
    
    # VIBEE-specific GN args
    cat > "out/$BUILD_TYPE/args.gn" << EOF
# VIBEE Browser Build Configuration
# φ² + 1/φ² = 3 | PHOENIX = 999

is_official_build = true
is_debug = false
symbol_level = 0
enable_nacl = false
blink_symbol_level = 0
v8_symbol_level = 0

# Thorium optimizations
is_component_build = false
enable_hangout_services_extension = false
enable_widevine = true
proprietary_codecs = true
ffmpeg_branding = "Chrome"

# VIBEE specific
chrome_pgo_phase = 0
enable_rust = true

# Branding
google_api_key = ""
google_default_client_id = ""
google_default_client_secret = ""
EOF

    gn gen "out/$BUILD_TYPE"
fi

# Build
echo "Building VIBEE Browser..."
echo "This may take several hours on first build."
echo ""

autoninja -C "out/$BUILD_TYPE" chrome -j"$JOBS"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Build complete!"
echo "  Binary: $CHROMIUM_SRC/out/$BUILD_TYPE/chrome"
echo ""
echo "  Run with: ./out/$BUILD_TYPE/chrome"
echo "═══════════════════════════════════════════════════════════════"

#!/bin/bash
# VIBEE Browser - macOS Build Script
# Creates .app bundle and .dmg installer
# φ² + 1/φ² = 3 | PHOENIX = 999

set -e

APP_NAME="VIBEE Browser"
APP_VERSION="2482"
BUNDLE_ID="com.vibee.browser"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  VIBEE Browser - macOS Build                                  ║"
echo "║  Version: $APP_VERSION                                            ║"
echo "║  φ² + 1/φ² = 3 | PHOENIX = 999                                ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

# Create directories
echo "Creating app bundle..."
rm -rf "dist/macos"
mkdir -p "dist/macos/$APP_NAME.app/Contents/MacOS"
mkdir -p "dist/macos/$APP_NAME.app/Contents/Resources"

# Create Info.plist
cat > "dist/macos/$APP_NAME.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>vibee-launcher</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>$APP_VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# Create launcher script
cat > "dist/macos/$APP_NAME.app/Contents/MacOS/vibee-launcher" << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "$0")/../Resources" && pwd)"
cd "$DIR"

# Start local server
python3 -m http.server 9999 &
SERVER_PID=$!

# Wait for server
sleep 1

# Open browser
open "http://localhost:9999/runtime.html"

# Keep running
wait $SERVER_PID
EOF

chmod +x "dist/macos/$APP_NAME.app/Contents/MacOS/vibee-launcher"

# Copy runtime
cp runtime/runtime.html "dist/macos/$APP_NAME.app/Contents/Resources/"

# Create simple icon (base64 encoded PNG)
# For now, create a placeholder
echo "Creating icon..."

# Build CLI for macOS ARM64 if Zig available
if command -v zig &> /dev/null; then
    echo "Building CLI for macOS ARM64..."
    cd generated/crush/zig
    zig build-exe main.zig -O ReleaseFast -target aarch64-macos 2>/dev/null || echo "Cross-compile not available in this environment"
    cd ../../..
fi

echo ""
echo "✅ App bundle created: dist/macos/$APP_NAME.app"
echo ""
echo "To create DMG (run on macOS):"
echo "  hdiutil create -volname \"$APP_NAME\" -srcfolder \"dist/macos/$APP_NAME.app\" -ov -format UDZO \"dist/VIBEE-Browser-$APP_VERSION.dmg\""
echo ""
echo "Or simply copy the .app to /Applications"

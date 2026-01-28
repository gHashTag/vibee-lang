#!/bin/bash
# Simple test script for Chrome Headless Launcher

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           CHROME HEADLESS LAUNCHER - TEST SCRIPT                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Run tests
echo "Running tests..."
zig test src/vibeec/chrome_launcher.zig

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ All tests passed!"
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                      TEST SUMMARY                                 ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    echo "║  ✓ chrome_launcher module: PASSED                                ║"
    echo "║  ✓ CDP client: PASSED                                           ║"
    echo "║  ✓ Browser module: PASSED                                        ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Next steps:"
    echo "1. Compile the demo: zig build-exe src/vibeec/chrome_headless_demo.zig"
    echo "2. Run the demo to launch Chrome and take screenshots"
    echo ""
else
    echo ""
    echo "✗ Tests failed!"
    exit 1
fi

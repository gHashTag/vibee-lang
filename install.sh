#!/bin/bash
# VIBEE Language - Bootstrap Installer
# Automatically installs Zig and rebuilds compiler for your architecture
# φ² + 1/φ² = 3 | PHOENIX = 999

set -e

# Colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

# ASCII Art
echo -e "${CYAN}${BOLD}"
cat << 'EOF'
   ██╗   ██╗██╗██████╗ ███████╗███████╗
   ██║   ██║██║██╔══██╗██╔════╝██╔════╝
   ██║   ██║██║██████╔╝█████╗  █████╗  
   ╚██╗ ██╔╝██║██╔══██╗██╔══╝  ██╔══╝  
    ╚████╔╝ ██║██████╔╝███████╗███████╗
     ╚═══╝  ╚═╝╚═════╝ ╚══════╝╚══════╝
EOF
echo -e "${RESET}${CYAN}          Bootstrap Installer v1.0${RESET}"
echo -e "${CYAN}          φ² + 1/φ² = 3 | PHOENIX = 999${RESET}"
echo ""

# Detect OS and architecture
OS="unknown"
ARCH="unknown"
case "$(uname -s)" in
    Darwin*)    OS="macos";;
    Linux*)     OS="linux";;
    CYGWIN*|MINGW*|MSYS*) OS="windows";;
    *)          OS="unknown";;
esac

case "$(uname -m)" in
    x86_64)     ARCH="x86_64";;
    arm64|aarch64) ARCH="aarch64";;
    *)          ARCH="unknown";;
esac

echo -e "${CYAN}Detected:${RESET} ${BOLD}$OS $ARCH${RESET}"
echo ""

# Check for existing Zig installation
ZIG_VERSION="0.13.0"
ZIG_NEEDED=false
if command -v zig >/dev/null 2>&1; then
    INSTALLED_VERSION=$(zig version 2>/dev/null || echo "0.0.0")
    if [[ "$INSTALLED_VERSION" != "$ZIG_VERSION" ]]; then
        echo -e "${YELLOW}Found Zig $INSTALLED_VERSION, but VIBEE requires $ZIG_VERSION${RESET}"
        ZIG_NEEDED=true
    else
        echo -e "${GREEN}✓ Zig $ZIG_VERSION already installed${RESET}"
    fi
else
    echo -e "${YELLOW}Zig not found in PATH${RESET}"
    ZIG_NEEDED=true
fi

# Install Zig if needed
if [[ "$ZIG_NEEDED" == true ]]; then
    echo -e "${CYAN}Installing Zig $ZIG_VERSION...${RESET}"
    
    case "$OS" in
        linux)
            if [[ "$ARCH" == "x86_64" ]]; then
                ZIG_URL="https://ziglang.org/download/$ZIG_VERSION/zig-linux-x86_64-$ZIG_VERSION.tar.xz"
            elif [[ "$ARCH" == "aarch64" ]]; then
                ZIG_URL="https://ziglang.org/download/$ZIG_VERSION/zig-linux-aarch64-$ZIG_VERSION.tar.xz"
            else
                echo -e "${RED}Unsupported architecture: $ARCH${RESET}"
                exit 1
            fi
            
            # Download and extract
            echo "Downloading Zig from $ZIG_URL"
            curl -L "$ZIG_URL" -o zig.tar.xz
            tar -xf zig.tar.xz -C /tmp
            rm zig.tar.xz
            ZIG_DIR="/tmp/zig-linux-$ARCH-$ZIG_VERSION"
            export PATH="$ZIG_DIR:$PATH"
            echo -e "${GREEN}✓ Zig installed to $ZIG_DIR${RESET}"
            ;;
        macos)
            if [[ "$ARCH" == "x86_64" ]]; then
                ZIG_URL="https://ziglang.org/download/$ZIG_VERSION/zig-macos-x86_64-$ZIG_VERSION.tar.xz"
            elif [[ "$ARCH" == "aarch64" ]]; then
                ZIG_URL="https://ziglang.org/download/$ZIG_VERSION/zig-macos-aarch64-$ZIG_VERSION.tar.xz"
            else
                echo -e "${RED}Unsupported architecture: $ARCH${RESET}"
                exit 1
            fi
            
            echo "Downloading Zig from $ZIG_URL"
            curl -L "$ZIG_URL" -o zig.tar.xz
            tar -xf zig.tar.xz -C /tmp
            rm zig.tar.xz
            ZIG_DIR="/tmp/zig-macos-$ARCH-$ZIG_VERSION"
            export PATH="$ZIG_DIR:$PATH"
            echo -e "${GREEN}✓ Zig installed to $ZIG_DIR${RESET}"
            ;;
        windows)
            echo -e "${RED}Windows installation via script not yet supported.${RESET}"
            echo "Please install Zig manually from https://ziglang.org/download/"
            exit 1
            ;;
        *)
            echo -e "${RED}Unsupported OS: $OS${RESET}"
            exit 1
            ;;
    esac
fi

# Verify Zig
ZIG_CMD="zig"
if [[ "$ZIG_NEEDED" == true ]]; then
    ZIG_CMD="$ZIG_DIR/zig"
fi

if ! command -v "$ZIG_CMD" >/dev/null 2>&1; then
    echo -e "${RED}Zig command not found after installation${RESET}"
    exit 1
fi

echo -e "${GREEN}✓ Using Zig: $($ZIG_CMD version)${RESET}"
echo ""

# Build VIBEE compiler
echo -e "${CYAN}Building VIBEE compiler...${RESET}"
echo "  OS: $OS, Architecture: $ARCH"
echo "  Optimization: ReleaseSafe (safe for all CPUs)"

cd src/vibeec

# Determine target
TARGET_FLAG=""
if [[ "$OS" == "macos" && "$ARCH" == "aarch64" ]]; then
    TARGET_FLAG="-Dtarget=aarch64-macos"
elif [[ "$OS" == "macos" && "$ARCH" == "x86_64" ]]; then
    TARGET_FLAG="-Dtarget=x86_64-macos"
elif [[ "$OS" == "linux" && "$ARCH" == "aarch64" ]]; then
    TARGET_FLAG="-Dtarget=aarch64-linux-gnu"
elif [[ "$OS" == "linux" && "$ARCH" == "x86_64" ]]; then
    TARGET_FLAG="-Dtarget=x86_64-linux-gnu"
fi

echo "  Target flags: $TARGET_FLAG"

# Build
if [[ -n "$TARGET_FLAG" ]]; then
    $ZIG_CMD build $TARGET_FLAG -Doptimize=ReleaseSafe
else
    $ZIG_CMD build -Doptimize=ReleaseSafe
fi

# Copy binary
cp zig-out/bin/vibeec ../../bin/vibee
cd ../..

echo -e "${GREEN}✓ Compiler built successfully${RESET}"
echo ""

# Verify installation
echo -e "${CYAN}Verifying installation...${RESET}"
if ./bin/vibee --help >/dev/null 2>&1; then
    echo -e "${GREEN}✓ VIBEE compiler is working!${RESET}"
    ./bin/vibee --version 2>/dev/null || echo "VIBEE version unknown"
else
    echo -e "${RED}Failed to run VIBEE compiler${RESET}"
    exit 1
fi

# Success message
echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  VIBEE installation complete!                                 ${RESET}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${CYAN}Next steps:${RESET}"
echo "  1. Try generating code: ${BOLD}./bin/vibee gen specs/tri/ai_provider.vibee${RESET}"
echo "  2. Run tests: ${BOLD}zig test trinity/output/ai_provider.zig${RESET}"
echo "  3. Use py2vibee: ${BOLD}py2vibee --help${RESET}"
echo ""
echo -e "${YELLOW}Note: The Zig installation is temporary (in /tmp).${RESET}"
echo -e "${YELLOW}To make Zig permanently available, add to your PATH:${RESET}"
if [[ "$ZIG_NEEDED" == true ]]; then
    echo -e "${BOLD}  export PATH=\"$ZIG_DIR:\$PATH\"${RESET}"
fi
echo ""
echo -e "${CYAN}Golden Chain is closed. KOSCHEI is immortal.${RESET}"
echo -e "${CYAN}φ² + 1/φ² = 3 | PHOENIX = 999${RESET}"

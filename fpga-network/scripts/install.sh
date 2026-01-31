#!/bin/bash
#
# FPGA.Network Agent Installer
# 
# Usage: curl -sSL https://fpga.network/install.sh | bash
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║   ███████╗██████╗  ██████╗  █████╗    ███╗   ██╗███████╗████████╗ ║
║   ██╔════╝██╔══██╗██╔════╝ ██╔══██╗   ████╗  ██║██╔════╝╚══██╔══╝ ║
║   █████╗  ██████╔╝██║  ███╗███████║   ██╔██╗ ██║█████╗     ██║    ║
║   ██╔══╝  ██╔═══╝ ██║   ██║██╔══██║   ██║╚██╗██║██╔══╝     ██║    ║
║   ██║     ██║     ╚██████╔╝██║  ██║██╗██║ ╚████║███████╗   ██║    ║
║   ╚═╝     ╚═╝      ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝    ║
║                                                                   ║
║   Decentralized BitNet LLM Inference Network                      ║
║   Installer v0.1.0                                                ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     OS_TYPE=Linux;;
    Darwin*)    OS_TYPE=Mac;;
    *)          OS_TYPE="UNKNOWN:${OS}"
esac

echo -e "${GREEN}Detected OS: ${OS_TYPE}${NC}"

# Check architecture
ARCH="$(uname -m)"
echo -e "${GREEN}Architecture: ${ARCH}${NC}"

# Installation directory
INSTALL_DIR="${HOME}/.fpga-network"
BIN_DIR="${INSTALL_DIR}/bin"
CONFIG_DIR="${INSTALL_DIR}"
BITSTREAM_DIR="${INSTALL_DIR}/bitstreams"
LOG_DIR="${INSTALL_DIR}/logs"

echo ""
echo -e "${YELLOW}Installation directory: ${INSTALL_DIR}${NC}"
echo ""

# Create directories
echo -e "${BLUE}Creating directories...${NC}"
mkdir -p "${BIN_DIR}"
mkdir -p "${CONFIG_DIR}"
mkdir -p "${BITSTREAM_DIR}"
mkdir -p "${LOG_DIR}"

# Check Python
echo -e "${BLUE}Checking Python...${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    echo -e "${GREEN}  Found Python ${PYTHON_VERSION}${NC}"
else
    echo -e "${RED}  Python 3 not found. Please install Python 3.10+${NC}"
    exit 1
fi

# Check pip
echo -e "${BLUE}Checking pip...${NC}"
if command -v pip3 &> /dev/null; then
    echo -e "${GREEN}  Found pip${NC}"
else
    echo -e "${YELLOW}  Installing pip...${NC}"
    curl -sSL https://bootstrap.pypa.io/get-pip.py | python3
fi

# Install Python dependencies
echo -e "${BLUE}Installing Python dependencies...${NC}"
pip3 install --quiet --user aiohttp pyyaml

# Download agent files
echo -e "${BLUE}Downloading FPGA.Network Agent...${NC}"

REPO_URL="https://raw.githubusercontent.com/gHashTag/vibee-lang/main/fpga-network"

# Download agent files
curl -sSL "${REPO_URL}/agent/cli.py" -o "${BIN_DIR}/cli.py" 2>/dev/null || {
    echo -e "${YELLOW}  Using local files...${NC}"
    # Copy from local if available
    if [ -f "$(dirname "$0")/../agent/cli.py" ]; then
        cp "$(dirname "$0")/../agent/"*.py "${BIN_DIR}/"
    fi
}

curl -sSL "${REPO_URL}/agent/config.py" -o "${BIN_DIR}/config.py" 2>/dev/null || true
curl -sSL "${REPO_URL}/agent/inference.py" -o "${BIN_DIR}/inference.py" 2>/dev/null || true
curl -sSL "${REPO_URL}/agent/network.py" -o "${BIN_DIR}/network.py" 2>/dev/null || true
curl -sSL "${REPO_URL}/agent/server.py" -o "${BIN_DIR}/server.py" 2>/dev/null || true
curl -sSL "${REPO_URL}/agent/proof.py" -o "${BIN_DIR}/proof.py" 2>/dev/null || true

# Create agent directory structure
mkdir -p "${BIN_DIR}/agent"
mv "${BIN_DIR}/"*.py "${BIN_DIR}/agent/" 2>/dev/null || true

# Create __init__.py
touch "${BIN_DIR}/agent/__init__.py"

# Create executable wrapper
cat > "${BIN_DIR}/fpga-agent" << 'WRAPPER'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PYTHONPATH="${SCRIPT_DIR}:${PYTHONPATH}"
python3 "${SCRIPT_DIR}/agent/cli.py" "$@"
WRAPPER

chmod +x "${BIN_DIR}/fpga-agent"

# Add to PATH
SHELL_RC=""
if [ -f "${HOME}/.bashrc" ]; then
    SHELL_RC="${HOME}/.bashrc"
elif [ -f "${HOME}/.zshrc" ]; then
    SHELL_RC="${HOME}/.zshrc"
fi

if [ -n "${SHELL_RC}" ]; then
    if ! grep -q "fpga-network/bin" "${SHELL_RC}"; then
        echo "" >> "${SHELL_RC}"
        echo "# FPGA.Network" >> "${SHELL_RC}"
        echo "export PATH=\"\${HOME}/.fpga-network/bin:\${PATH}\"" >> "${SHELL_RC}"
        echo -e "${GREEN}Added to PATH in ${SHELL_RC}${NC}"
    fi
fi

# Create symlink in /usr/local/bin if possible
if [ -w "/usr/local/bin" ]; then
    ln -sf "${BIN_DIR}/fpga-agent" /usr/local/bin/fpga-agent 2>/dev/null || true
fi

# Download bitstreams info
echo -e "${BLUE}Checking available bitstreams...${NC}"
cat > "${BITSTREAM_DIR}/README.md" << 'BITSTREAMS'
# FPGA.Network Bitstreams

Available bitstreams for BitNet inference:

| Model | FPGA | File | Size | Status |
|-------|------|------|------|--------|
| bitnet-1b | Alveo U50 | bitnet_1b_u50.bit | ~50MB | Available |
| bitnet-3b | Alveo U55C | bitnet_3b_u55c.bit | ~100MB | Available |
| bitnet-7b | Alveo U55C | bitnet_7b_u55c.bit | ~200MB | Available |
| bitnet-demo | Arty A7 | bitnet_demo_arty.bit | ~5MB | Available |

To download a bitstream:
```bash
fpga-agent download-bitstream bitnet-3b
```

Or manually:
```bash
curl -sSL https://fpga.network/bitstreams/bitnet_3b_u55c.bit -o ~/.fpga-network/bitstreams/bitnet_3b_u55c.bit
```
BITSTREAMS

# Detect FPGA
echo -e "${BLUE}Detecting FPGA hardware...${NC}"
FPGA_DETECTED="none"

if command -v xbutil &> /dev/null; then
    XBUTIL_OUTPUT=$(xbutil examine 2>/dev/null || true)
    if echo "${XBUTIL_OUTPUT}" | grep -qi "u55c"; then
        FPGA_DETECTED="alveo_u55c"
    elif echo "${XBUTIL_OUTPUT}" | grep -qi "u50"; then
        FPGA_DETECTED="alveo_u50"
    elif echo "${XBUTIL_OUTPUT}" | grep -qi "u280"; then
        FPGA_DETECTED="alveo_u280"
    fi
fi

if [ "${FPGA_DETECTED}" = "none" ]; then
    if lspci 2>/dev/null | grep -qi "xilinx"; then
        FPGA_DETECTED="xilinx_unknown"
    fi
fi

if [ "${FPGA_DETECTED}" = "none" ]; then
    echo -e "${YELLOW}  No FPGA detected. Agent will run in simulation mode.${NC}"
else
    echo -e "${GREEN}  Detected: ${FPGA_DETECTED}${NC}"
fi

# Create default config
echo -e "${BLUE}Creating default configuration...${NC}"
cat > "${CONFIG_DIR}/config.yaml" << CONFIG
# FPGA.Network Agent Configuration
name: "provider-$(hostname)"
region: "auto"
log_level: "INFO"

fpga:
  device_type: "${FPGA_DETECTED}"
  device_id: 0
  bitstream_path: null
  clock_freq_mhz: 300

network:
  coordinator_url: "https://api.fpga.network"
  heartbeat_interval: 30
  max_concurrent_requests: 10

wallet:
  address: ""
  keypair_path: null
  min_stake: 10000

inference:
  supported_models:
    - "bitnet-1b"
    - "bitnet-3b"
    - "bitnet-7b"
  max_tokens: 4096
  timeout_seconds: 60
  price_per_1k_tokens: 0.0001
CONFIG

echo -e "${GREEN}Configuration saved to ${CONFIG_DIR}/config.yaml${NC}"

# Done
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ FPGA.Network Agent installed successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "Next steps:"
echo ""
echo -e "  1. ${YELLOW}Restart your terminal${NC} or run:"
echo -e "     ${BLUE}source ${SHELL_RC}${NC}"
echo ""
echo -e "  2. ${YELLOW}Register your provider:${NC}"
echo -e "     ${BLUE}fpga-agent register --wallet YOUR_SOLANA_WALLET${NC}"
echo ""
echo -e "  3. ${YELLOW}Start the agent:${NC}"
echo -e "     ${BLUE}fpga-agent start${NC}"
echo ""
echo -e "Documentation: ${BLUE}https://docs.fpga.network${NC}"
echo -e "Support: ${BLUE}https://t.me/fpga_network${NC}"
echo ""

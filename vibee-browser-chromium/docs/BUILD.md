# Building VIBEE Browser

## φ² + 1/φ² = 3 | PHOENIX = 999

## System Requirements

### Hardware
- **CPU**: 8+ cores recommended
- **RAM**: 16 GB minimum, 32 GB recommended
- **Disk**: 100+ GB free space (SSD recommended)

### Software
- **OS**: Ubuntu 20.04+, Windows 10+, or macOS 11+
- **Python**: 3.8+
- **Git**: 2.25+

## Quick Start (Linux)

```bash
# 1. Install depot_tools
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH="$PATH:$(pwd)/depot_tools"

# 2. Clone Thorium (base)
mkdir chromium && cd chromium
fetch --nohooks chromium
cd src
git checkout tags/120.0.6099.234  # Match Thorium version

# 3. Sync dependencies
gclient sync -D --force --reset

# 4. Clone VIBEE patches
cd ../..
git clone https://github.com/gHashTag/vibee-browser-chromium.git

# 5. Apply VIBEE patches
cd vibee-browser-chromium
export CHROMIUM_SRC="../chromium/src"
./scripts/apply_patches.sh

# 6. Build
./scripts/build.sh
```

## Build Options

### Release Build (default)
```bash
BUILD_TYPE=Release ./scripts/build.sh
```

### Debug Build
```bash
BUILD_TYPE=Debug ./scripts/build.sh
```

### Parallel Jobs
```bash
JOBS=16 ./scripts/build.sh
```

## Build Times

| Hardware | First Build | Incremental |
|----------|-------------|-------------|
| 8 cores, 16GB RAM | ~6 hours | ~30 min |
| 16 cores, 32GB RAM | ~3 hours | ~15 min |
| 32 cores, 64GB RAM | ~1.5 hours | ~5 min |

## Troubleshooting

### Out of Memory
```bash
# Reduce parallel jobs
JOBS=4 ./scripts/build.sh

# Or add swap
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Missing Dependencies (Ubuntu)
```bash
sudo apt install -y build-essential clang lld gn ninja-build \
    libgtk-3-dev libglib2.0-dev libnss3-dev libatk1.0-dev \
    libatk-bridge2.0-dev libcups2-dev libdrm-dev libxkbcommon-dev \
    libxcomposite-dev libxdamage-dev libxrandr-dev libgbm-dev \
    libasound2-dev libpango1.0-dev libcairo2-dev
```

### Patch Conflicts
```bash
# Reset chromium src
cd chromium/src
git checkout .
git clean -fd

# Re-apply patches
cd ../../vibee-browser-chromium
./scripts/apply_patches.sh
```

## Output

After successful build:
```
chromium/src/out/Release/
├── chrome              # Main binary
├── chrome_sandbox      # Sandbox helper
├── libEGL.so
├── libGLESv2.so
├── resources.pak
├── v8_context_snapshot.bin
└── ...
```

## Running

```bash
# Run VIBEE Browser
./chromium/src/out/Release/chrome

# With flags
./chromium/src/out/Release/chrome --enable-features=VibeeAISidebar
```

## Creating Installer

### Linux (DEB)
```bash
cd chromium/src
autoninja -C out/Release installer
# Output: out/Release/vibee-browser_*.deb
```

### Windows (MSI)
```bash
autoninja -C out/Release mini_installer
# Output: out/Release/mini_installer.exe
```

### macOS (DMG)
```bash
autoninja -C out/Release chrome/installer/mac
# Output: out/Release/VIBEE Browser.dmg
```

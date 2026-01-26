# VIBEE Installation Guide

**Sacred Formula:** `V = n × 3^k × π^m × φ^p × e^q`  
**Golden Identity:** `φ² + 1/φ² = 3`

This guide covers installation of the VIBEE compiler for all supported platforms, including troubleshooting for common issues.

---

## 📦 Quick Installation

### Automatic Installer (Recommended)

```bash
curl -sSL https://raw.githubusercontent.com/gHashTag/vibee-lang/main/install.sh | bash
```

The installer will:
1. Detect your OS and architecture
2. Install Zig 0.13.0 (if missing)
3. Rebuild the compiler with safe optimizations
4. Verify the installation

### Docker (No Zig Required)

```bash
# Run directly from container registry
docker run --rm -v $(pwd):/app ghcr.io/ghashtag/vibee gen specs/tri/bitnet_top.vibee

# Build multi-arch image locally
docker buildx build --platform linux/amd64,linux/arm64 -t vibee .

# Run with local image
docker run --rm -v $(pwd):/app vibee gen specs/tri/bitnet_top.vibee
```

---

## 🛠️ Manual Build

### 1. Install Zig 0.13.0

**Ubuntu/Debian:**
```bash
sudo apt update && sudo apt install zig
```

**macOS:**
```bash
brew install zig@0.13
```

**Other platforms:** Download from [ziglang.org/download/0.13.0/](https://ziglang.org/download/0.13.0/)

Verify installation:
```bash
zig version
# Should output: 0.13.0
```

### 2. Build VIBEE Compiler

```bash
cd src/vibeec
zig build -Doptimize=ReleaseSafe  # Safe for all CPUs
cp zig-out/bin/vibeec ../../bin/vibee
cd ../..
```

### 3. Verify

```bash
./bin/vibee --help
./bin/vibee --version
```

---

## 🐳 Docker Details

### Multi-Architecture Support

The Docker image supports both `amd64` (x86_64) and `arm64` (Apple Silicon, AWS Graviton) architectures. Use `docker buildx` to build for multiple platforms:

```bash
# Create buildx builder (first time only)
docker buildx create --name vibee-builder --use

# Build and push multi-arch image
docker buildx build --platform linux/amd64,linux/arm64 -t vibee .

# Load image for current platform
docker buildx build --load -t vibee .
```

### Docker Compose

For IGLA runtime (separate from VIBEE compiler), use `deploy/docker-compose.yaml`:

```bash
cd deploy
docker-compose up -d igla
```

---

## ⚠️ Troubleshooting

### "Illegal instruction" Error

**Problem:** Pre-built `bin/vibee` binary crashes with `Illegal instruction`.

**Cause:** The binary was compiled for x86_64 with AVX/SSE CPU extensions not available on your processor.

**Solution:** Rebuild the compiler with safe optimizations:

```bash
cd src/vibeec
zig build -Doptimize=ReleaseSafe
cp zig-out/bin/vibeec ../../bin/vibee
```

Or use the automatic installer:

```bash
curl -sSL https://raw.githubusercontent.com/gHashTag/vibee-lang/main/install.sh | bash
```

### Zig Version Mismatch

**Problem:** `zig build` fails with compilation errors.

**Solution:** VIBEE requires Zig 0.13.0 exactly. Check version:

```bash
zig version
```

If incorrect, install correct version:

```bash
# Linux/macOS - manual download
curl -L https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz | tar -xJ -C ~/.local
export PATH="$HOME/.local/zig-linux-x86_64-0.13.0:$PATH"
```

### macOS Apple Silicon (ARM64)

**Problem:** Binary built for x86_64 runs slowly under Rosetta.

**Solution:** Build for native architecture:

```bash
cd src/vibeec
zig build -Dtarget=aarch64-macos -Doptimize=ReleaseSafe
cp zig-out/bin/vibeec ../../bin/vibee
```

### Docker Permission Denied

**Problem:** `docker run` fails with permission errors on mounted volumes.

**Solution:** Use absolute paths and ensure proper permissions:

```bash
docker run --rm -v "$(pwd):/app:z" vibee gen specs/tri/feature.vibee
```

Or adjust Docker daemon settings to allow shared folders.

### "Command not found: vibee"

**Problem:** `vibee` command not found after installation.

**Solution:** Ensure `bin/vibee` is executable and in PATH:

```bash
chmod +x bin/vibee
export PATH="$PATH:$(pwd)/bin"
# Or create symlink:
sudo ln -s "$(pwd)/bin/vibee" /usr/local/bin/vibee
```

### Out of Disk Space During Build

**Problem:** Zig build fails due to insufficient disk space.

**Solution:** Clean Zig cache:

```bash
rm -rf ~/.cache/zig
```

Or increase temporary directory space:

```bash
export TMPDIR=/path/to/larger/disk
```

---

## ❓ Frequently Asked Questions

### Q: Why does VIBEE need Zig?
**A:** VIBEE's compiler is written in Zig for performance and cross-compilation capabilities. Zig is only needed for building the compiler, not for using generated code.

### Q: Can I use VIBEE without internet access?
**A:** Yes, after initial installation. Download the repository and install Zig manually. The automatic installer requires internet.

### Q: What's the difference between VIBEE and IGLA?
**A:** VIBEE is the specification language and compiler. IGLA is a runtime environment built on VIBEE, focused on inference acceleration.

### Q: How do I update VIBEE?
**A:** Pull the latest changes and rebuild:
```bash
git pull origin main
cd src/vibeec && zig build -Doptimize=ReleaseSafe
cp zig-out/bin/vibeec ../../bin/vibee
```

### Q: Can I contribute binaries for other architectures?
**A:** Yes! Open a pull request with binaries built using `-Doptimize=ReleaseSafe` for:
- Linux ARMv7 (Raspberry Pi)
- Linux PowerPC
- FreeBSD/NetBSD

### Q: Where are generated files stored?
**A:** By default:
- Zig output: `trinity/output/`
- Verilog output: `trinity/output/fpga/`
- Multi-language output: `generated/multi/`

---

## 📊 Platform Support Matrix

| Platform | Architecture | Status | Notes |
|----------|--------------|--------|-------|
| Linux | x86_64 | ✅ Full | Pre-built binary available |
| Linux | aarch64 | ✅ Full | Rebuild required |
| macOS | x86_64 | ✅ Full | Rebuild required |
| macOS | arm64 (M1/M2/M3) | ✅ Full | Use `-Dtarget=aarch64-macos` |
| Windows | WSL2 (x86_64) | ✅ Full | Use Linux instructions |
| Windows | Native | ⚠️ Experimental | Requires Zig Windows target |
| Docker | Multi-arch | ✅ Full | Supports amd64/arm64 |

---

## 🔧 Advanced Configuration

### Custom Build Options

```bash
# Debug build (for development)
zig build -Doptimize=Debug

# ReleaseFast (maximum performance, may require modern CPU)
zig build -Doptimize=ReleaseFast

# ReleaseSmall (minimal binary size)
zig build -Doptimize=ReleaseSmall

# Cross-compile for Raspberry Pi
zig build -Dtarget=arm-linux-gnueabihf -Doptimize=ReleaseSafe
```

### Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `VIBEE_CACHE` | Cache directory for generated files | `~/.vibee/cache` |
| `ZIG_GLOBAL_CACHE` | Zig build cache | `~/.cache/zig` |
| `VIBEE_LOG` | Log level (debug, info, warn, error) | `info` |

### Integrating with CI/CD

**GitHub Actions example:**
```yaml
- name: Install VIBEE
  run: |
    curl -sSL https://raw.githubusercontent.com/gHashTag/vibee-lang/main/install.sh | bash
    echo "$(pwd)/bin" >> $GITHUB_PATH
```

**Docker in CI:**
```yaml
- name: Generate Verilog
  run: |
    docker run --rm -v $(pwd):/app ghcr.io/ghashtag/vibee \
      gen specs/tri/feature.vibee
```

---

## 🚨 Emergency Recovery

If everything fails:

1. **Clean rebuild:**
   ```bash
   rm -rf bin/vibee src/vibeec/zig-cache src/vibeec/zig-out
   cd src/vibeec && zig build -Doptimize=ReleaseSafe --verbose
   ```

2. **Fresh clone:**
   ```bash
   cd /tmp
   git clone https://github.com/gHashTag/vibee-lang
   cd vibee-lang
   ./install.sh
   ```

3. **Use Docker as fallback:**
   ```bash
   docker run --rm -v $(pwd):/app alpine:3.19 sh -c "
     apk add curl xz &&
     curl -L https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz | tar -xJ -C /opt &&
     /opt/zig-linux-x86_64-0.13.0/zig build -Doptimize=ReleaseSafe
   "
   ```

---

## 📞 Support

- **GitHub Issues:** [github.com/gHashTag/vibee-lang/issues](https://github.com/gHashTag/vibee-lang/issues)
- **Documentation:** [docs/INDEX.md](docs/INDEX.md)
- **Habr Articles:** [docs/habr/](docs/habr/)

**Golden Chain is closed. KOSCHEI is immortal.**  
**φ² + 1/φ² = 3 | PHOENIX = 999**

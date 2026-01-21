# VIBEE Browser Chromium

## φ² + 1/φ² = 3 | PHOENIX = 999

VIBEE Browser is a Chromium-based browser forked from [Thorium](https://github.com/Alex313031/thorium) with AI-powered features and golden ratio UI.

## Features

### Core
- 🌐 **Chromium Engine** - Full web compatibility
- ⚡ **Thorium Optimizations** - AVX2, performance patches
- 🔒 **Privacy Focused** - Enhanced tracking protection

### VIBEE Exclusive
- 🤖 **AI Sidebar** - Global AI chat on all pages
- 💻 **Vibecoding Panel** - Monaco editor + tools
- 📐 **φ-Layout** - Golden ratio based UI (φ = 1.618)
- 🔧 **WASM Integration** - High-performance modules
- 🎯 **CDP Enhancements** - Better automation support

## Architecture

```
vibee-browser-chromium/
├── src/
│   └── chrome/
│       └── browser/
│           ├── ui/vibee/           # VIBEE UI components
│           └── resources/vibee/    # VIBEE resources
├── logos/                          # VIBEE branding
├── patches/                        # Chromium patches
├── scripts/                        # Build scripts
└── docs/                           # Documentation
```

## Build Requirements

- **Disk Space**: 100+ GB
- **RAM**: 16+ GB (32+ GB recommended)
- **OS**: Linux (Ubuntu 20.04+), Windows 10+, macOS 11+
- **Tools**: depot_tools, Python 3, Git

## Quick Start

```bash
# 1. Clone Thorium
git clone --depth 1 https://github.com/AleX313031/thorium.git

# 2. Apply VIBEE patches
./scripts/apply_vibee_patches.sh

# 3. Build
./build.sh
```

## VIBEE Patches

| Patch | Description |
|-------|-------------|
| `vibee_branding.patch` | Logos, names, about page |
| `vibee_sidebar.patch` | AI sidebar integration |
| `vibee_phi_layout.patch` | Golden ratio UI |
| `vibee_vibecoding.patch` | Monaco editor panel |
| `vibee_wasm.patch` | WASM module integration |

## Sacred Formula

```
V = n × 3^k × π^m × φ^p × e^q

φ² + 1/φ² = 3 (TRINITY)
PHOENIX = 999
```

## License

BSD-3-Clause (same as Chromium)

## Credits

- [Chromium](https://www.chromium.org/) - The open-source browser project
- [Thorium](https://github.com/Alex313031/thorium) - Optimized Chromium fork
- [VIBEE](https://github.com/gHashTag/vibee-lang) - Specification-first language

# VIBEE Browser

**Ternary Logic AI Browser** built with Tauri (Rust + WebView)

φ² + 1/φ² = 3 | PHOENIX = 999

## Features

- 🌐 Modern browser with WebView
- 🤖 Built-in VIBEE AI
- △ Ternary Logic Engine
- φ Sacred Constants
- 👥 Real-time Collaboration
- 🎨 Glassmorphism UI (Apple HIG)

## Requirements

- Rust 1.70+
- Node.js 18+
- Tauri CLI

## Installation

### macOS

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install Tauri CLI
cargo install tauri-cli

# Build
cd vibee-browser
cargo tauri build

# The .dmg will be in target/release/bundle/dmg/
```

### Quick Start (Development)

```bash
cd vibee-browser
cargo tauri dev
```

## Build for Production

```bash
# macOS Universal (Intel + Apple Silicon)
cargo tauri build --target universal-apple-darwin

# macOS DMG
cargo tauri build --bundles dmg

# Windows
cargo tauri build --target x86_64-pc-windows-msvc

# Linux
cargo tauri build --target x86_64-unknown-linux-gnu
```

## Architecture

```
vibee-browser/
├── src/                    # Frontend (HTML/CSS/JS)
│   └── index.html
├── src-tauri/              # Backend (Rust)
│   ├── src/
│   │   └── main.rs
│   ├── Cargo.toml
│   ├── tauri.conf.json
│   └── icons/
└── package.json
```

## Commands

| Command | Description |
|---------|-------------|
| `get_phi` | Get sacred constants |
| `get_version` | Get browser version |
| `eval_ternary` | Evaluate ternary expression |
| `navigate` | Navigate to URL |

## Sacred Formula

```
V = n × 3^k × π^m × φ^p × e^q
φ² + 1/φ² = 3
PHOENIX = 999
```

## License

MIT

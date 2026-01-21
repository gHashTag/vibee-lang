# VIBEE Browser Integration Plan

## φ² + 1/φ² = 3 | PHOENIX = 999

## Phase 1: Fork & Setup (Week 1)

### 1.1 Fork Thorium
- [ ] Fork https://github.com/Alex313031/thorium to gHashTag/vibee-browser-chromium
- [ ] Clone locally
- [ ] Set up build environment (depot_tools)
- [ ] Verify base build works

### 1.2 Branding
- [ ] Replace Thorium logos with VIBEE logos
- [ ] Update product names in BRANDING file
- [ ] Update about page with φ formula
- [ ] Create VIBEE icons (16x16, 32x32, 48x48, 128x128, 256x256)

## Phase 2: Core Features (Week 2-3)

### 2.1 φ-Layout System
- [ ] Create `vibee_phi_layout.h/cc`
- [ ] Implement golden ratio calculations
- [ ] Add snap points (0.618, 0.382, 0.5)
- [ ] Integrate with browser frame

### 2.2 AI Sidebar
- [ ] Create `vibee_side_panel.h/cc`
- [ ] Add WebView for chat UI
- [ ] Implement OpenAI/Anthropic API integration
- [ ] Add streaming support
- [ ] Make sidebar global (visible on all tabs)

### 2.3 Vibecoding Panel
- [ ] Create `vibecoding_panel.h/cc`
- [ ] Integrate Monaco Editor
- [ ] Add toolbar with actions (Generate, Test, Build)
- [ ] Add output console
- [ ] Connect to VIBEE compiler

## Phase 3: WASM Integration (Week 4)

### 3.1 WASM Modules
- [ ] Integrate phi_ui.wasm
- [ ] Integrate vibee_browser.wasm
- [ ] Add WASM loader to browser
- [ ] Connect WASM to UI components

### 3.2 Performance
- [ ] Benchmark layout calculations
- [ ] Optimize WASM calls
- [ ] Add caching

## Phase 4: CDP Enhancements (Week 5)

### 4.1 Automation
- [ ] Enhanced screenshot API (<10ms)
- [ ] Better selector support
- [ ] Action recording
- [ ] Macro system

### 4.2 Agent Integration
- [ ] Browser Agent hooks
- [ ] Code Agent hooks
- [ ] Research Agent hooks

## Phase 5: Polish & Release (Week 6)

### 5.1 UI/UX
- [ ] Glassmorphism effects
- [ ] φ-easing animations
- [ ] Dark/Light themes
- [ ] Keyboard shortcuts

### 5.2 Testing
- [ ] Unit tests for VIBEE components
- [ ] Integration tests
- [ ] E2E tests
- [ ] Performance benchmarks

### 5.3 Release
- [ ] Build for Linux
- [ ] Build for Windows
- [ ] Build for macOS
- [ ] Create installers
- [ ] Write release notes

## Build Commands

```bash
# Setup (one time)
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH="$PATH:$(pwd)/depot_tools"

# Clone Thorium
git clone --depth 1 https://github.com/gHashTag/vibee-browser-chromium.git
cd vibee-browser-chromium

# Apply VIBEE patches
./scripts/apply_patches.sh

# Build
autoninja -C out/Release chrome

# Run
./out/Release/chrome
```

## File Structure

```
vibee-browser-chromium/
├── src/chrome/browser/
│   ├── ui/views/
│   │   ├── frame/vibee_phi_layout.h
│   │   ├── frame/vibee_phi_layout.cc
│   │   ├── side_panel/vibee_side_panel.h
│   │   ├── side_panel/vibee_side_panel.cc
│   │   └── vibee/vibecoding_panel.h
│   └── resources/vibee/
│       ├── chat.html
│       ├── vibecoding.html
│       └── icons/
├── patches/
│   ├── vibee_branding.patch
│   ├── vibee_sidebar.patch
│   ├── vibee_phi_layout.patch
│   └── vibee_vibecoding.patch
├── logos/
│   ├── vibee_16.png
│   ├── vibee_32.png
│   ├── vibee_48.png
│   ├── vibee_128.png
│   └── vibee_256.png
└── scripts/
    ├── apply_patches.sh
    └── build.sh
```

## Success Metrics

| Metric | Target |
|--------|--------|
| Build time | < 4 hours |
| Binary size | < 150 MB |
| Startup time | < 2 seconds |
| Layout calc | < 1 ms |
| Screenshot | < 10 ms |
| Memory usage | < 500 MB idle |

## Dependencies

- Chromium 120+
- Thorium patches
- depot_tools
- Python 3.8+
- Node.js 18+ (for Monaco)
- VIBEE compiler (for Vibecoding)

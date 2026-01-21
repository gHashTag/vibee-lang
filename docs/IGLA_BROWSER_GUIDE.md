# IGLA Browser Automation v4 Guide

**Author**: Dmitrii Vasilev  
**Version**: 4.0.0  
**Date**: 2026-01-21

---

## Overview

IGLA Browser is an AI-powered browser automation system built on Chrome DevTools Protocol (CDP). It features AI-driven selectors, visual regression testing, and self-healing test repair.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    IGLA BROWSER v4 ARCHITECTURE                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐       │
│  │   CDP       │     │   AI        │     │   Visual    │       │
│  │   Client    │────▶│   Selectors │────▶│   Diff      │       │
│  └─────────────┘     └─────────────┘     └─────────────┘       │
│         │                   │                   │               │
│         ▼                   ▼                   ▼               │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐       │
│  │   Browser   │     │   Self-     │     │   Test      │       │
│  │   Actions   │────▶│   Healing   │────▶│   Reports   │       │
│  └─────────────┘     └─────────────┘     └─────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Modules

| Module | Tests | Description |
|--------|-------|-------------|
| `igla_cdp_client` | 17 | Chrome DevTools Protocol client |
| `igla_browser_actions` | 25 | High-level browser automation |
| `igla_ai_selectors` | 16 | AI-driven element selection |
| `igla_visual_diff` | 16 | Visual regression testing |
| `igla_self_healing` | 16 | Automatic test repair |
| **TOTAL** | **90** | **100% pass rate** |

## CLI Commands

### System Info

```bash
vibee browser info
vibee browser help
```

### Browser Control

```bash
# Launch browser
vibee browser launch
vibee browser launch --headless
vibee browser launch --port 9223

# Navigate
vibee browser navigate https://example.com

# Take screenshot
vibee browser screenshot
vibee browser screenshot --full-page
```

### Element Interaction

```bash
# Click element
vibee browser click "#submit-button"
vibee browser click "button.primary" --ai-selectors

# Type text
vibee browser type "Hello World"
```

### Self-Healing

```bash
# Run self-healing analysis
vibee browser heal
```

## CDP Domains

| Domain | Description |
|--------|-------------|
| `Page` | Navigation, lifecycle events |
| `DOM` | Document manipulation |
| `Network` | Request interception |
| `Input` | Mouse, keyboard events |
| `Runtime` | JavaScript execution |
| `Emulation` | Device emulation |

## AI Selectors

AI Selectors use semantic matching to find elements:

```bash
# Natural language selector
vibee browser click "login button" --ai-selectors

# Fallback chain
vibee browser click "#login" --ai-selectors
# Tries: #login → [data-testid="login"] → button:contains("Login")
```

### Selector Strategies

| Strategy | Priority | Description |
|----------|----------|-------------|
| ID | 1 | `#element-id` |
| data-testid | 2 | `[data-testid="..."]` |
| ARIA | 3 | `[aria-label="..."]` |
| Text | 4 | `:contains("...")` |
| CSS | 5 | Standard CSS selector |

## Visual Diff

Visual regression testing compares screenshots:

```bash
# Create baseline
vibee browser screenshot --baseline homepage

# Compare with baseline
vibee browser screenshot --compare homepage
```

### Diff Options

| Option | Description |
|--------|-------------|
| `--threshold 0.1` | Pixel difference threshold |
| `--ignore-colors` | Ignore color differences |
| `--ignore-antialiasing` | Ignore antialiasing |

## Self-Healing

Automatic test repair when selectors break:

```bash
vibee browser heal
```

### Healing Strategies

1. **ID Change** - Detect renamed IDs
2. **Class Change** - Detect renamed classes
3. **Structure Change** - Detect DOM restructuring
4. **Fingerprint Match** - Match by element features

### Healing Report

```
Selectors analyzed:  10
Healed:              3
Failed:              0
Confidence avg:      0.92

Healed selectors:
  1. #old-button → #new-button (0.95)
  2. .submit-btn → [data-testid="submit"] (0.91)
```

## Configuration

```zig
pub const BrowserConfig = struct {
    host: []const u8 = "localhost",
    port: u16 = 9222,
    headless: bool = false,
    ai_selectors: bool = true,
    visual_diff: bool = true,
    self_healing: bool = true,
    timeout_ms: u32 = 30000,
};
```

## Specifications

All modules are generated from `.vibee` specifications:

```
specs/tri/igla_cdp_client.vibee
specs/tri/igla_browser_actions.vibee
specs/tri/igla_ai_selectors.vibee
specs/tri/igla_visual_diff.vibee
specs/tri/igla_self_healing.vibee
```

## Testing

```bash
# Test all browser modules
cd trinity/output
zig test igla_cdp_client.zig
zig test igla_browser_actions.zig
zig test igla_ai_selectors.zig
zig test igla_visual_diff.zig
zig test igla_self_healing.zig
```

## Sacred Constants

```
φ (phi)       = 1.618033988749895
φ²            = 2.618033988749895
1/φ²          = 0.381966011250105
φ² + 1/φ² = 3 ✓ VERIFIED

PHOENIX = 999 = 27 × 37 = 3³ × 37
```

---

**φ² + 1/φ² = 3 | PHOENIX = 999**

# Playwright Integration Guide

## Overview

Full Playwright browser automation for WebArena benchmark.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    PLAYWRIGHT INTEGRATION                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    CORE LAYER                            │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │   │
│  │  │   Core   │  │ Actions  │  │Selectors │              │   │
│  │  │ Instance │  │click/type│  │CSS/XPath │              │   │
│  │  └──────────┘  └──────────┘  └──────────┘              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   UTILITY LAYER                          │   │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐           │   │
│  │  │  Wait  │ │Extract │ │ Screen │ │Network │           │   │
│  │  │Strateg.│ │Content │ │  shot  │ │Intercpt│           │   │
│  │  └────────┘ └────────┘ └────────┘ └────────┘           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                  ADVANCED LAYER                          │   │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐           │   │
│  │  │Storage │ │ Frames │ │  DOM   │ │  A11y  │           │   │
│  │  │Cookies │ │iframes │ │ Parser │ │  Tree  │           │   │
│  │  └────────┘ └────────┘ └────────┘ └────────┘           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                 APPLICATION LAYER                        │   │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐           │   │
│  │  │Element │ │  Form  │ │Navigat.│ │Session │           │   │
│  │  │Locator │ │Handler │ │Manager │ │Manager │           │   │
│  │  └────────┘ └────────┘ └────────┘ └────────┘           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                  WEBARENA LAYER                          │   │
│  │  ┌────────────────┐  ┌────────────────┐                 │   │
│  │  │ Error Recovery │  │WebArena Adapter│                 │   │
│  │  │ Retry/Fallback │  │ Site-specific  │                 │   │
│  │  └────────────────┘  └────────────────┘                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Modules

### Core Layer
| Module | Tests | Description |
|--------|-------|-------------|
| browser_playwright_core | 9 | Browser launch, context, page |
| browser_playwright_actions | 11 | Click, type, scroll, hover |
| browser_playwright_selectors | 10 | CSS, XPath, text, role |

### Utility Layer
| Module | Tests | Description |
|--------|-------|-------------|
| browser_playwright_wait | 9 | Wait strategies |
| browser_playwright_extract | 9 | Content extraction |
| browser_playwright_screenshot | 8 | Visual capture |
| browser_playwright_network | 9 | Network interception |

### Advanced Layer
| Module | Tests | Description |
|--------|-------|-------------|
| browser_playwright_storage | 9 | Cookies, localStorage |
| browser_playwright_frames | 9 | iframe handling |
| browser_dom_parser | 9 | DOM analysis |
| browser_accessibility_tree | 9 | A11y tree extraction |

### Application Layer
| Module | Tests | Description |
|--------|-------|-------------|
| browser_element_locator | 9 | Smart element location |
| browser_form_handler | 9 | Form automation |
| browser_navigation_manager | 9 | Navigation state |
| browser_session_manager | 9 | Multi-tab management |

### WebArena Layer
| Module | Tests | Description |
|--------|-------|-------------|
| browser_error_recovery | 9 | Error handling |
| browser_webarena_adapter | 9 | WebArena specific |

**Total: 17 modules, 156 tests**

## Key Features

### 1. Selector Strategies
```
CSS → XPath → Text → Role → TestID
```

### 2. Wait Strategies
```
selector → navigation → load_state → function → timeout
```

### 3. Error Recovery
```
Timeout → Retry with backoff → Fallback selector → Circuit breaker
```

### 4. WebArena Sites
- Shopping (OneStopMarket)
- Forum (Reddit-like)
- GitLab
- Map (OpenStreetMap)
- Wiki (Wikipedia)

## Usage Flow

```
1. Launch browser (headless/headed)
2. Create context with storage state
3. Navigate to WebArena site
4. Login if needed
5. Execute task actions
6. Extract observation
7. Validate completion
```

---
*VIBEE Playwright Integration v1.0 | φ² + 1/φ² = 3*

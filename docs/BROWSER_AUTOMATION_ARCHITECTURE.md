# Browser Automation Architecture

## Target: WebArena #1

## Component Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      VIBEE BROWSER AUTOMATION                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ReAct Agent                                                           │
│       │                                                                 │
│       ▼                                                                 │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                    TOOL EXECUTOR (Masked)                        │  │
│   │   browser_* tools enabled based on state machine                 │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│       │                                                                 │
│       ▼                                                                 │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                    PLAYWRIGHT CORE                               │  │
│   │   Launch → Context → Page → Actions → Observations               │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│       │                                                                 │
│       ▼                                                                 │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                    WEBARENA ADAPTER                              │  │
│   │   Site-specific handling, login, state management                │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│       │                                                                 │
│       ▼                                                                 │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                    WEBARENA ENVIRONMENT                          │  │
│   │   Shopping │ Forum │ GitLab │ Map │ Wiki                         │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Action Flow

```
Task Intent
    │
    ▼
┌─────────────┐
│   Thought   │  "I need to click the login button"
└─────────────┘
    │
    ▼
┌─────────────┐
│   Action    │  browser_click(selector="#login-btn")
└─────────────┘
    │
    ▼
┌─────────────┐
│  Playwright │  page.click("#login-btn")
└─────────────┘
    │
    ▼
┌─────────────┐
│ Observation │  "Login form appeared, URL changed to /login"
└─────────────┘
    │
    ▼
Next iteration...
```

## Selector Priority

1. **TestID** - Most reliable
2. **Role + Name** - Accessibility-based
3. **CSS** - Standard web
4. **XPath** - Complex queries
5. **Text** - Content-based

## Error Recovery Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                    ERROR RECOVERY                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Element Not Found                                          │
│  ├─> Retry with wait (1s, 2s, 4s backoff)                  │
│  ├─> Try fallback selectors                                 │
│  ├─> Scroll into view                                       │
│  └─> Report failure with context                            │
│                                                             │
│  Timeout                                                    │
│  ├─> Increase timeout                                       │
│  ├─> Check network status                                   │
│  └─> Reload page if stuck                                   │
│                                                             │
│  Navigation Error                                           │
│  ├─> Retry navigation                                       │
│  ├─> Check URL validity                                     │
│  └─> Handle redirects                                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## WebArena Site Handling

| Site | Login Required | Special Handling |
|------|----------------|------------------|
| Shopping | Yes | Cart state, checkout flow |
| Forum | Yes | Post creation, voting |
| GitLab | Yes | Repo operations, issues |
| Map | No | Coordinates, routing |
| Wiki | No | Search, navigation |

## Observation Format

```json
{
  "url": "https://shop.webarena.dev/products",
  "title": "Products - OneStopMarket",
  "accessibility_tree": "...",
  "visible_text": "...",
  "interactive_elements": [
    {"role": "button", "name": "Add to Cart"},
    {"role": "link", "name": "View Details"}
  ]
}
```

## Metrics

| Metric | Target |
|--------|--------|
| Action success rate | >95% |
| Average action time | <2s |
| Error recovery rate | >80% |
| WebArena accuracy | >45% |

---
*VIBEE Browser Automation v1.0 | Target: WebArena #1*

# E2E Testing Guide

## Overview

End-to-end testing framework for VIBEE Browser pipeline.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        E2E TEST FRAMEWORK                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    TEST INFRASTRUCTURE                           │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │   │
│  │  │  Runner  │ │   Case   │ │ Asserts  │ │ Fixtures │           │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    BROWSER TESTS                                 │   │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐        │   │
│  │  │Browser │ │ Navig. │ │Element │ │Extract │ │  Form  │        │   │
│  │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘        │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    ADVANCED TESTS                                │   │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐                   │   │
│  │  │ Screen │ │Network │ │Storage │ │ Error  │                   │   │
│  │  └────────┘ └────────┘ └────────┘ └────────┘                   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    BENCHMARK TESTS                               │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐                        │   │
│  │  │ WebArena │ │   GAIA   │ │  ReAct   │                        │   │
│  │  └──────────┘ └──────────┘ └──────────┘                        │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    INTEGRATION & PERFORMANCE                     │   │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐            │   │
│  │  │ Integration  │ │ Performance  │ │   Report     │            │   │
│  │  └──────────────┘ └──────────────┘ └──────────────┘            │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Test Categories

### Infrastructure (4 modules)
| Module | Tests | Description |
|--------|-------|-------------|
| e2e_test_runner | 7 | Test execution engine |
| e2e_test_case | 7 | Test case structure |
| e2e_test_assertions | 9 | Assert functions |
| e2e_test_fixtures | 7 | Setup/teardown |

### Browser Tests (5 modules)
| Module | Tests | Description |
|--------|-------|-------------|
| e2e_browser_tests | 8 | Launch, context, close |
| e2e_navigation_tests | 8 | Goto, back, forward |
| e2e_element_tests | 10 | Click, type, hover |
| e2e_extraction_tests | 8 | Text, HTML, attributes |
| e2e_form_tests | 8 | Fill, submit, validate |

### Advanced Tests (4 modules)
| Module | Tests | Description |
|--------|-------|-------------|
| e2e_screenshot_tests | 7 | Visual capture |
| e2e_network_tests | 8 | Interception, mocking |
| e2e_storage_tests | 8 | Cookies, localStorage |
| e2e_error_tests | 8 | Timeout, recovery |

### Benchmark Tests (3 modules)
| Module | Tests | Description |
|--------|-------|-------------|
| e2e_webarena_tests | 8 | WebArena tasks |
| e2e_gaia_tests | 8 | GAIA tasks |
| e2e_react_agent_tests | 8 | ReAct loop |

### Integration & Performance (3 modules)
| Module | Tests | Description |
|--------|-------|-------------|
| e2e_integration_tests | 8 | Full pipeline |
| e2e_performance_tests | 8 | Latency, throughput |
| e2e_report_generator | 8 | Report generation |

**Total: 19 modules, 151 tests**

## Test Structure

### Given-When-Then Pattern
```
given: Precondition setup
when: Action execution
then: Expected outcome
```

### Example Test Case
```yaml
test_id: "click_button_001"
name: "Click submit button"
steps:
  - action: navigate
    params: {url: "https://example.com/form"}
  - action: click
    params: {selector: "#submit-btn"}
  - action: assert_url
    params: {expected: "https://example.com/success"}
```

## Assertions

| Assertion | Description |
|-----------|-------------|
| assert_equals | Exact match |
| assert_contains | Substring match |
| assert_matches | Regex match |
| assert_visible | Element visibility |
| assert_url | URL check |
| assert_title | Page title |
| assert_element_text | Element content |
| assert_element_count | Element count |

## Fixtures

### Browser Fixture
```yaml
browser_type: chromium
headless: true
viewport_width: 1280
viewport_height: 720
```

### Page Fixture
```yaml
url: "https://example.com"
wait_until: "networkidle"
cookies: [...]
```

## Running Tests

```bash
# Run all E2E tests
zig test trinity/output/e2e_*.zig

# Run specific category
zig test trinity/output/e2e_browser_tests.zig

# Run with verbose output
zig test trinity/output/e2e_test_runner.zig --verbose
```

## Report Generation

Reports include:
- Test summary (pass/fail counts)
- Failure details with screenshots
- Performance metrics
- Comparison with baseline

---
*VIBEE E2E Testing v1.0 | φ² + 1/φ² = 3*

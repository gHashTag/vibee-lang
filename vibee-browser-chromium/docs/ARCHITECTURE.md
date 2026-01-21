# VIBEE Browser Architecture

## φ² + 1/φ² = 3 | PHOENIX = 999

## Layer Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    VIBEE Browser                            │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ AI Sidebar  │  │  φ-Layout   │  │  Vibecoding Panel   │  │
│  │             │  │   System    │  │                     │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                     │            │
├─────────┴────────────────┴─────────────────────┴────────────┤
│                    VIBEE Integration Layer                  │
│              (patches/vibee_integration.patch)              │
├─────────────────────────────────────────────────────────────┤
│                    Thorium Optimizations                    │
│              (AVX, LTO, PGO, Memory)                        │
├─────────────────────────────────────────────────────────────┤
│                    Chromium Base                            │
│              (Blink, V8, Content, UI)                       │
└─────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Chromium Base

Standard Chromium components:
- **Blink**: Rendering engine
- **V8**: JavaScript engine
- **Content**: Multi-process architecture
- **UI**: Views framework

### 2. Thorium Layer

Performance optimizations:
- AVX/AVX2 SIMD instructions
- Link-Time Optimization (LTO)
- Profile-Guided Optimization (PGO)
- Memory allocator improvements

### 3. VIBEE Integration Layer

Bridge between Chromium and VIBEE features:

```cpp
// vibee/browser/vibee_browser_main_parts.h
class VibeeBrowserMainParts : public ChromeBrowserMainParts {
 public:
  void PreMainMessageLoopRun() override;
  void PostMainMessageLoopRun() override;
  
 private:
  std::unique_ptr<AISidebarController> ai_sidebar_;
  std::unique_ptr<PhiLayoutManager> phi_layout_;
  std::unique_ptr<VibecodingPanel> vibecoding_;
};
```

### 4. AI Sidebar

```
┌─────────────────────────────────────────┐
│ AISidebarController                     │
├─────────────────────────────────────────┤
│ - provider_: AIProvider*                │
│ - context_: ConversationContext         │
│ - view_: AISidebarView*                 │
├─────────────────────────────────────────┤
│ + Toggle()                              │
│ + SendMessage(text)                     │
│ + SummarizePage()                       │
│ + SetProvider(provider)                 │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ AIProvider (interface)                  │
├─────────────────────────────────────────┤
│ + SendRequest(prompt) → Response        │
│ + GetCapabilities() → Capabilities      │
│ + GetName() → string                    │
└─────────────────────────────────────────┘
         │
    ┌────┴────┬────────────┐
    ▼         ▼            ▼
┌────────┐ ┌────────┐ ┌────────┐
│ OpenAI │ │ Claude │ │ Ollama │
└────────┘ └────────┘ └────────┘
```

### 5. φ-Layout System

```
┌─────────────────────────────────────────┐
│ PhiLayoutManager                        │
├─────────────────────────────────────────┤
│ - phi_: double = 1.618033988749895      │
│ - enabled_: bool                        │
│ - constraints_: LayoutConstraints       │
├─────────────────────────────────────────┤
│ + CalculateMainWidth(total) → int       │
│ + CalculateSidebarWidth(total) → int    │
│ + ApplyToView(view)                     │
│ + Toggle()                              │
└─────────────────────────────────────────┘
```

**Golden Ratio Calculations:**
```cpp
constexpr double kPhi = 1.618033988749895;
constexpr double kPhiInverse = 0.618033988749895;

int CalculateMainWidth(int total) {
  return static_cast<int>(total * kPhiInverse);
}

int CalculateSidebarWidth(int total) {
  return total - CalculateMainWidth(total);
}
```

### 6. Vibecoding Panel

```
┌─────────────────────────────────────────┐
│ VibecodingPanel                         │
├─────────────────────────────────────────┤
│ - editor_: CodeEditor*                  │
│ - preview_: SpecPreview*                │
│ - generator_: CodeGenerator*            │
│ - test_runner_: TestRunner*             │
├─────────────────────────────────────────┤
│ + LoadSpec(path)                        │
│ + GenerateCode(target_lang)             │
│ + RunTests()                            │
│ + ShowPASAnalysis()                     │
└─────────────────────────────────────────┘
```

## File Structure

```
chromium/src/
├── chrome/
│   ├── browser/
│   │   └── vibee/
│   │       ├── ai_sidebar/
│   │       │   ├── ai_sidebar_controller.h
│   │       │   ├── ai_sidebar_controller.cc
│   │       │   ├── ai_sidebar_view.h
│   │       │   └── providers/
│   │       │       ├── openai_provider.cc
│   │       │       ├── claude_provider.cc
│   │       │       └── ollama_provider.cc
│   │       ├── phi_layout/
│   │       │   ├── phi_layout_manager.h
│   │       │   └── phi_layout_manager.cc
│   │       └── vibecoding/
│   │           ├── vibecoding_panel.h
│   │           ├── vibecoding_panel.cc
│   │           └── spec_parser.cc
│   └── app/
│       └── vibee_resources/
│           ├── vibee_logo.png
│           └── vibee_icon.ico
└── components/
    └── vibee/
        ├── core/
        │   └── phi_constants.h
        └── common/
            └── vibee_features.h
```

## Build Integration

### GN Targets

```gn
# chrome/browser/vibee/BUILD.gn
source_set("vibee") {
  sources = [
    "ai_sidebar/ai_sidebar_controller.cc",
    "ai_sidebar/ai_sidebar_controller.h",
    "phi_layout/phi_layout_manager.cc",
    "phi_layout/phi_layout_manager.h",
    "vibecoding/vibecoding_panel.cc",
    "vibecoding/vibecoding_panel.h",
  ]
  
  deps = [
    "//base",
    "//chrome/browser/ui",
    "//components/vibee/core",
    "//net",
    "//ui/views",
  ]
}
```

### Feature Flags

```cpp
// components/vibee/common/vibee_features.h
namespace vibee::features {

BASE_DECLARE_FEATURE(kAISidebar);
BASE_DECLARE_FEATURE(kPhiLayout);
BASE_DECLARE_FEATURE(kVibecodingPanel);

}  // namespace vibee::features
```

## Data Flow

### AI Request Flow

```
User Input
    │
    ▼
AISidebarController::SendMessage()
    │
    ▼
AIProvider::SendRequest()
    │
    ▼
Network Request (HTTPS)
    │
    ▼
AI Service (OpenAI/Claude/Ollama)
    │
    ▼
Response Parsing
    │
    ▼
AISidebarView::DisplayResponse()
```

### Vibecoding Flow

```
.vibee File
    │
    ▼
SpecParser::Parse()
    │
    ▼
Specification AST
    │
    ▼
CodeGenerator::Generate(target)
    │
    ▼
Generated Code (.zig/.py/.rs)
    │
    ▼
TestRunner::Run()
    │
    ▼
Results Display
```

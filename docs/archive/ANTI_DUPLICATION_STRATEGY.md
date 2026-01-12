# Anti-Duplication Strategy for VIBEE Plugins

## Problem Statement

**Issue:** Multiple plugins contained duplicate logic (e.g., `telegram_bot_legacy` duplicated `telegram_bot`)

**Goal:** Prevent duplication at compile-time and CI level

## Detection Strategies

### 1. AST-Based Similarity Detection

**Approach:** Parse `.vibee` files and compare Abstract Syntax Trees

**Metrics:**
- Function signature similarity
- Code structure similarity (AST diff)
- Variable naming patterns
- Control flow similarity

**Tools:**
- Custom Gleam parser
- Tree-sitter for syntax analysis
- Similarity threshold: >80% = duplicate

### 2. Hash-Based Deduplication

**Approach:** Hash normalized code blocks

**Process:**
1. Normalize code (remove whitespace, comments)
2. Hash each function/module
3. Store hashes in registry
4. Detect collisions

**Example:**
```gleam
// Original
pub fn send_message(chat_id: Int, text: String) -> Result {
  // implementation
}

// Normalized hash
hash("send_message(Int,String)->Result{...}") = "a3f5b2c1"
```

### 3. Import Graph Analysis

**Approach:** Detect circular dependencies and duplicate exports

**Checks:**
- Same function exported from multiple plugins
- Circular imports (A → B → A)
- Shadowed exports

**Example:**
```gleam
// BAD: Both export same function
// telegram_bot/actor.vibee
pub fn start() -> Result { ... }

// telegram_bot_legacy/actor.vibee
pub fn start() -> Result { ... }  // ❌ DUPLICATE EXPORT
```

### 4. Semantic Similarity (ML-Based)

**Approach:** Use embeddings to detect semantic duplicates

**Process:**
1. Generate code embeddings (CodeBERT, GraphCodeBERT)
2. Calculate cosine similarity
3. Flag similar functions (>0.85 similarity)

**Use Case:** Detect refactored duplicates with different names

## Implementation Plan

### Phase 1: Static Analysis Tool

Create `honeycomb/tools/dedup_checker.gleam`:

```gleam
import gleam/list
import gleam/string
import gleam/result
import simplifile

pub type DuplicateReport {
  DuplicateReport(
    file1: String,
    file2: String,
    similarity: Float,
    reason: String,
  )
}

pub fn check_plugin(plugin_path: String) -> List(DuplicateReport) {
  // 1. Find all .vibee files
  // 2. Parse and normalize
  // 3. Compare pairwise
  // 4. Return duplicates
}

pub fn check_all_plugins() -> Result(List(DuplicateReport), String) {
  // Scan honeycomb/ for all plugins
  // Run check_plugin on each
  // Cross-plugin comparison
}
```

### Phase 2: Lint Rules

Create `honeycomb/.dedup_rules.toml`:

```toml
[rules]
# Function signature similarity threshold
function_similarity_threshold = 0.80

# Allow same function name in different categories
allow_same_name_different_category = true

# Whitelist for intentional duplicates
whitelist = [
  "test_helpers.vibee",  # Test utilities can duplicate
  "types.vibee",         # Type definitions can overlap
]

# Blacklist patterns
blacklist_patterns = [
  "*_legacy*",  # No legacy plugins allowed
  "*_old*",     # No old versions
  "*_backup*",  # No backup files
]

[exports]
# Prevent duplicate exports
unique_exports = true

# Allow re-exports
allow_reexports = true

[imports]
# Detect circular dependencies
detect_circular = true

# Max import depth
max_import_depth = 5
```

### Phase 3: Pre-Commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Pre-commit hook: Check for duplicates

echo "🔍 Checking for duplicate logic..."

# Run dedup checker
gleam run -m honeycomb/tools/dedup_checker

if [ $? -ne 0 ]; then
  echo "❌ Duplicate logic detected!"
  echo "Run: gleam run -m honeycomb/tools/dedup_checker --fix"
  exit 1
fi

echo "✅ No duplicates found"
```

### Phase 4: CI Pipeline

Create `.github/workflows/anti-duplication.yml`:

```yaml
name: Anti-Duplication Check

on:
  pull_request:
    paths:
      - 'honeycomb/**/*.vibee'
  push:
    branches: [main]

jobs:
  check-duplicates:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Gleam
        uses: erlef/setup-beam@v1
        with:
          gleam-version: '1.0.0'
      
      - name: Install dependencies
        run: gleam deps download
      
      - name: Check for duplicates
        run: |
          gleam run -m honeycomb/tools/dedup_checker
          
      - name: Generate report
        if: failure()
        run: |
          gleam run -m honeycomb/tools/dedup_checker --report > duplication_report.md
          
      - name: Comment on PR
        if: failure()
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const report = fs.readFileSync('duplication_report.md', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## ❌ Duplicate Logic Detected\n\n${report}`
            });
```

## Enforcement Levels

### Level 1: Warning (Soft)
- Similarity 60-80%
- Log warning, don't block
- Use for initial rollout

### Level 2: Error (Hard)
- Similarity >80%
- Block commit/PR
- Require manual override

### Level 3: Strict (Production)
- Similarity >70%
- No overrides allowed
- Enforce unique exports

## Whitelist Mechanism

Allow intentional duplicates:

```toml
# honeycomb/.dedup_whitelist.toml
[[whitelist]]
file1 = "telegram/telegram_bot/src/core/types.vibee"
file2 = "telegram/telegram_bot/src/handlers/types.vibee"
reason = "Different type domains (core vs handlers)"
approved_by = "team_lead"
expires = "2026-06-01"

[[whitelist]]
pattern = "*/test/*"
reason = "Test utilities can duplicate"
approved_by = "auto"
```

## Detection Algorithms

### Algorithm 1: Token-Based Similarity

```gleam
pub fn token_similarity(code1: String, code2: String) -> Float {
  let tokens1 = tokenize(code1)
  let tokens2 = tokenize(code2)
  
  let common = list.filter(tokens1, fn(t) { list.contains(tokens2, t) })
  let total = list.length(tokens1) + list.length(tokens2)
  
  int.to_float(list.length(common) * 2) /. int.to_float(total)
}
```

### Algorithm 2: AST Diff

```gleam
pub fn ast_similarity(ast1: AST, ast2: AST) -> Float {
  case ast1, ast2 {
    Function(name1, params1, body1), Function(name2, params2, body2) -> {
      let name_match = if name1 == name2 { 1.0 } else { 0.0 }
      let params_match = params_similarity(params1, params2)
      let body_match = ast_similarity(body1, body2)
      
      (name_match +. params_match +. body_match) /. 3.0
    }
    _, _ -> 0.0
  }
}
```

### Algorithm 3: Export Collision

```gleam
pub fn check_export_collisions(plugins: List(Plugin)) -> List(Collision) {
  let exports = 
    plugins
    |> list.flat_map(fn(p) { p.exports })
    |> list.group_by(fn(e) { e.name })
  
  exports
  |> list.filter(fn(group) { list.length(group.1) > 1 })
  |> list.map(fn(group) {
    Collision(
      export_name: group.0,
      plugins: list.map(group.1, fn(e) { e.plugin }),
    )
  })
}
```

## Metrics & Reporting

### Dashboard Metrics

Track over time:
- Total plugins
- Duplicate functions detected
- Similarity scores (avg, max)
- Whitelist usage
- CI blocks

### Report Format

```markdown
# Duplication Report - 2026-01-10

## Summary
- Total plugins: 45
- Files scanned: 1,234
- Duplicates found: 3
- Similarity threshold: 80%

## Duplicates

### 1. High Similarity (95%)
**Files:**
- `telegram/telegram_bot/src/core/actor.vibee`
- `telegram/telegram_bot_legacy/src/actor.vibee`

**Functions:**
- `start() -> Result` (lines 10-25 vs 15-30)
- `stop() -> Result` (lines 30-40 vs 35-45)

**Recommendation:** Remove legacy plugin

### 2. Medium Similarity (82%)
**Files:**
- `ai/image_gen/src/flux.vibee`
- `ai/image_gen/src/stable_diffusion.vibee`

**Functions:**
- `generate(prompt: String) -> Result` (similar structure)

**Recommendation:** Extract common interface

## Actions Required
1. Review duplicates above
2. Update whitelist if intentional
3. Refactor or remove duplicates
```

## Best Practices

### DO ✅

1. **Extract common logic to shared modules**
   ```gleam
   // honeycomb/common/telegram/client.vibee
   pub fn send_message(...) -> Result { ... }
   
   // Use in plugins
   import common/telegram/client
   ```

2. **Use interfaces/protocols**
   ```gleam
   // Define interface
   pub type ImageGenerator {
     generate: fn(String) -> Result
   }
   
   // Implement in plugins
   pub fn flux_generator() -> ImageGenerator { ... }
   pub fn sd_generator() -> ImageGenerator { ... }
   ```

3. **Document intentional similarities**
   ```gleam
   // NOTE: Similar to ai/image_gen/flux.vibee
   // Reason: Different API endpoints, same pattern
   // Approved: 2026-01-10
   ```

### DON'T ❌

1. **Copy-paste code between plugins**
2. **Create `*_legacy`, `*_old`, `*_backup` plugins**
3. **Export same function from multiple plugins**
4. **Ignore duplication warnings**

## Migration Path

### Week 1: Setup
- [ ] Create dedup_checker tool
- [ ] Define lint rules
- [ ] Set up whitelist

### Week 2: Soft Enforcement
- [ ] Run checker, log warnings
- [ ] Identify false positives
- [ ] Tune thresholds

### Week 3: Hard Enforcement
- [ ] Add pre-commit hooks
- [ ] Block high-similarity commits
- [ ] Update documentation

### Week 4: CI Integration
- [ ] Add GitHub Actions
- [ ] Auto-comment on PRs
- [ ] Dashboard metrics

## Success Criteria

- ✅ Zero duplicate exports across plugins
- ✅ <5% code similarity between plugins (excluding common modules)
- ✅ All duplicates whitelisted or removed
- ✅ CI blocks new duplicates
- ✅ Team trained on anti-duplication practices

## Rollback Plan

If enforcement causes issues:

1. Disable pre-commit hooks
2. Set CI to warning-only mode
3. Review and adjust thresholds
4. Re-enable gradually

## See Also

- [TELEGRAM_CONSOLIDATION_REPORT.md](TELEGRAM_CONSOLIDATION_REPORT.md) - Example consolidation
- [honeycomb/tools/dedup_checker.gleam](tools/dedup_checker.gleam) - Detection tool
- [.dedup_rules.toml](.dedup_rules.toml) - Configuration

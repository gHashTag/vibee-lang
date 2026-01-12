# Automation Strategy - Subagents & Scripts

**Date:** 2026-01-10  
**Purpose:** Automate migration and plugin management through subagents and scripts

## Overview

**Problem:** 62 files in `gleam/src/vibee_lang/` need to be migrated to plugins  
**Solution:** Create autonomous subagent system with automated scripts  
**Approach:** Divide work into specialized subagents, each with specific tasks

## Subagent Architecture

### 1. Analyzer Subagent

**Purpose:** Analyze code and determine migration targets

**Tasks:**
- Scan `gleam/src/vibee_lang/` files
- Categorize by functionality
- Detect dependencies
- Generate migration plan

**Output:** `migration_plan.json`

```json
{
  "files": [
    {
      "source": "gleam/src/vibee_lang/auto_macro_generator.gleam",
      "target_category": "language/macros",
      "dependencies": ["macro_evolution"],
      "complexity": "medium",
      "priority": "high"
    }
  ]
}
```

### 2. Migrator Subagent

**Purpose:** Execute file migrations

**Tasks:**
- Create plugin structure
- Copy files
- Update imports
- Generate manifests
- Update documentation

**Output:** Migrated plugins in `honeycomb/`

### 3. Validator Subagent

**Purpose:** Validate migrations

**Tasks:**
- Check file integrity
- Verify imports
- Run tests
- Check for duplicates
- Validate manifests

**Output:** Validation report

### 4. Documenter Subagent

**Purpose:** Generate documentation

**Tasks:**
- Create README files
- Generate API docs
- Update migration notes
- Create examples

**Output:** Documentation files

### 5. Tester Subagent

**Purpose:** Run tests and checks

**Tasks:**
- Run unit tests
- Run integration tests
- Check code quality
- Measure coverage

**Output:** Test reports

### 6. Consolidator Subagent

**Purpose:** Find and merge similar plugins

**Tasks:**
- Detect similar plugins
- Analyze for consolidation
- Merge if appropriate
- Update dependencies

**Output:** Consolidated plugins

## Automation Scripts

### Script 1: Analyzer (`analyze_for_migration.sh`)

```bash
#!/bin/bash
# Analyze files for migration

echo "🔍 Analyzing files for migration..."

# Scan files
FILES=$(find gleam/src/vibee_lang -name "*.gleam" -type f)

# Categorize
for file in $FILES; do
  name=$(basename "$file" .gleam)
  
  # Determine category
  if [[ $name == *"compiler"* ]]; then
    category="core/compiler"
  elif [[ $name == *"macro"* ]]; then
    category="language/macros"
  elif [[ $name == *"lint"* ]] || [[ $name == *"format"* ]]; then
    category="tooling/linter"
  elif [[ $name == *"test"* ]]; then
    category="testing"
  elif [[ $name == *"repl"* ]] || [[ $name == *"tui"* ]]; then
    category="tooling/repl"
  else
    category="language/core"
  fi
  
  echo "$file -> honeycomb/$category/$name/"
done
```

### Script 2: Migrator (`migrate_to_plugin.sh`)

```bash
#!/bin/bash
# Migrate file to plugin

migrate_file() {
  local source=$1
  local target_category=$2
  local name=$(basename "$source" .gleam)
  
  echo "📦 Migrating $name to $target_category..."
  
  # Create plugin structure
  mkdir -p "honeycomb/$target_category/$name"/{src,test,docs}
  
  # Copy file
  cp "$source" "honeycomb/$target_category/$name/src/"
  
  # Generate manifest
  cat > "honeycomb/$target_category/$name/manifest.json" << EOF
{
  "name": "$name",
  "version": "1.0.0",
  "category": "$target_category",
  "description": "Migrated from gleam/src/vibee_lang/",
  "author": "VIBEE Team",
  "license": "MIT"
}
EOF
  
  # Generate README
  cat > "honeycomb/$target_category/$name/README.md" << EOF
# $name Plugin

**Category:** $target_category  
**Status:** Migrated from gleam/src/vibee_lang/

## Usage

\`\`\`gleam
import $target_category/$name
\`\`\`

## Migration Notes

Migrated on $(date +%Y-%m-%d)
EOF
  
  echo "✅ Migrated $name"
}
```

### Script 3: Validator (`validate_migration.sh`)

```bash
#!/bin/bash
# Validate migration

validate_plugin() {
  local plugin_path=$1
  
  echo "✓ Validating $plugin_path..."
  
  # Check manifest exists
  if [ ! -f "$plugin_path/manifest.json" ]; then
    echo "  ❌ Missing manifest.json"
    return 1
  fi
  
  # Check src exists
  if [ ! -d "$plugin_path/src" ]; then
    echo "  ❌ Missing src/ directory"
    return 1
  fi
  
  # Check for .gleam files
  if [ $(find "$plugin_path/src" -name "*.gleam" | wc -l) -eq 0 ]; then
    echo "  ❌ No .gleam files in src/"
    return 1
  fi
  
  # Check README
  if [ ! -f "$plugin_path/README.md" ]; then
    echo "  ⚠️  Missing README.md"
  fi
  
  echo "  ✅ Valid"
  return 0
}
```

### Script 4: Batch Migrator (`batch_migrate.sh`)

```bash
#!/bin/bash
# Batch migrate all files

set -e

echo "🚀 Starting batch migration..."

# Load migration plan
PLAN="migration_plan.json"

if [ ! -f "$PLAN" ]; then
  echo "❌ Migration plan not found. Run analyze_for_migration.sh first."
  exit 1
fi

# Process each file
jq -c '.files[]' "$PLAN" | while read -r item; do
  source=$(echo "$item" | jq -r '.source')
  category=$(echo "$item" | jq -r '.target_category')
  
  ./migrate_to_plugin.sh "$source" "$category"
done

echo "✅ Batch migration complete"
```

### Script 5: Cleanup (`cleanup_after_migration.sh`)

```bash
#!/bin/bash
# Cleanup after successful migration

cleanup_file() {
  local source=$1
  local backup_dir="gleam/src/vibee_lang/.migrated"
  
  echo "🧹 Cleaning up $source..."
  
  # Create backup
  mkdir -p "$backup_dir"
  mv "$source" "$backup_dir/"
  
  echo "✅ Moved to backup"
}
```

## Subagent Workflow

### Phase 1: Analysis

```
Analyzer Subagent
    ↓
Scan gleam/src/vibee_lang/
    ↓
Categorize files
    ↓
Detect dependencies
    ↓
Generate migration_plan.json
```

### Phase 2: Migration

```
Migrator Subagent
    ↓
Read migration_plan.json
    ↓
For each file:
  - Create plugin structure
  - Copy files
  - Generate manifest
  - Update imports
    ↓
Generate migration_report.json
```

### Phase 3: Validation

```
Validator Subagent
    ↓
For each migrated plugin:
  - Check structure
  - Verify imports
  - Run tests
  - Check duplicates
    ↓
Generate validation_report.json
```

### Phase 4: Documentation

```
Documenter Subagent
    ↓
For each plugin:
  - Generate README
  - Create examples
  - Update migration notes
    ↓
Generate docs_report.json
```

### Phase 5: Testing

```
Tester Subagent
    ↓
For each plugin:
  - Run unit tests
  - Run integration tests
  - Check coverage
    ↓
Generate test_report.json
```

### Phase 6: Cleanup

```
Cleanup Script
    ↓
For each successfully migrated file:
  - Move to backup
  - Update imports in remaining files
  - Commit changes
```

## Automation Pipeline

### Master Script (`automate_all.sh`)

```bash
#!/bin/bash
# Master automation script

set -e

echo "🤖 Starting full automation pipeline..."
echo ""

# Phase 1: Analysis
echo "Phase 1: Analysis"
./scripts/analyze_for_migration.sh > migration_plan.json
echo "✅ Analysis complete"
echo ""

# Phase 2: Migration
echo "Phase 2: Migration"
./scripts/batch_migrate.sh
echo "✅ Migration complete"
echo ""

# Phase 3: Validation
echo "Phase 3: Validation"
./scripts/validate_all_plugins.sh > validation_report.json
echo "✅ Validation complete"
echo ""

# Phase 4: Documentation
echo "Phase 4: Documentation"
./scripts/generate_all_docs.sh
echo "✅ Documentation complete"
echo ""

# Phase 5: Testing
echo "Phase 5: Testing"
./scripts/test_all_plugins.sh > test_report.json
echo "✅ Testing complete"
echo ""

# Phase 6: Cleanup
echo "Phase 6: Cleanup"
./scripts/cleanup_after_migration.sh
echo "✅ Cleanup complete"
echo ""

echo "🎉 Full automation pipeline complete!"
```

## Categorization Rules

### Automatic Categorization

```bash
categorize_file() {
  local file=$1
  local name=$(basename "$file" .gleam)
  
  # Compiler-related
  if [[ $name =~ (compiler|lexer|parser|ast|ir) ]]; then
    echo "core/compiler"
    return
  fi
  
  # Macro-related
  if [[ $name =~ (macro|meta) ]]; then
    echo "language/macros"
    return
  fi
  
  # Linting/Formatting
  if [[ $name =~ (lint|format|style|check) ]]; then
    echo "tooling/linter"
    return
  fi
  
  # Testing
  if [[ $name =~ (test|spec|assert) ]]; then
    echo "testing"
    return
  fi
  
  # REPL/TUI
  if [[ $name =~ (repl|tui|cli|interactive) ]]; then
    echo "tooling/repl"
    return
  fi
  
  # Type system
  if [[ $name =~ (type|inference|check) ]]; then
    echo "language/types"
    return
  fi
  
  # Error handling
  if [[ $name =~ (error|exception|panic) ]]; then
    echo "language/errors"
    return
  fi
  
  # Default
  echo "language/core"
}
```

## Dependency Resolution

### Detect Dependencies

```bash
detect_dependencies() {
  local file=$1
  
  # Extract imports
  grep "^import " "$file" | \
    sed 's/import //' | \
    sed 's/\.{.*//' | \
    sort -u
}
```

### Resolve Order

```bash
resolve_migration_order() {
  # Build dependency graph
  # Topological sort
  # Return ordered list
}
```

## Progress Tracking

### Migration Dashboard

```bash
show_progress() {
  local total=$(jq '.files | length' migration_plan.json)
  local completed=$(find honeycomb/ -name "manifest.json" -newer migration_plan.json | wc -l)
  local percent=$((completed * 100 / total))
  
  echo "Progress: $completed/$total ($percent%)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "█%.0s" $(seq 1 $((percent / 2)))
  echo ""
}
```

## Error Handling

### Rollback on Failure

```bash
rollback_migration() {
  local plugin=$1
  
  echo "⚠️  Rolling back $plugin..."
  
  # Remove plugin
  rm -rf "honeycomb/$plugin"
  
  # Restore from backup
  if [ -d "gleam/src/vibee_lang/.backup/$plugin" ]; then
    cp -r "gleam/src/vibee_lang/.backup/$plugin" "gleam/src/vibee_lang/"
  fi
  
  echo "✅ Rollback complete"
}
```

## Parallel Processing

### Parallel Migration

```bash
parallel_migrate() {
  local max_jobs=4
  
  jq -c '.files[]' migration_plan.json | \
    parallel -j $max_jobs ./migrate_to_plugin.sh {}
}
```

## Integration with Anti-Duplication

### Check Before Migration

```bash
check_duplicates_before_migration() {
  local source=$1
  local target=$2
  
  # Run dedup checker
  cd honeycomb && gleam run -m tools/dedup_checker \
    --check-file "$source" \
    --against "$target"
}
```

## Metrics & Reporting

### Generate Report

```bash
generate_final_report() {
  cat > AUTOMATION_REPORT.md << EOF
# Automation Report

**Date:** $(date)

## Summary

- Total files: $(jq '.files | length' migration_plan.json)
- Migrated: $migrated
- Failed: $failed
- Skipped: $skipped

## Details

$(cat migration_report.json | jq -r '.[] | "- \(.name): \(.status)"')

## Next Steps

1. Review failed migrations
2. Update imports
3. Run tests
4. Commit changes
EOF
}
```

## Configuration

### Config File (`.automation_config.toml`)

```toml
[migration]
# Source directory
source_dir = "gleam/src/vibee_lang"

# Target directory
target_dir = "honeycomb"

# Backup directory
backup_dir = "gleam/src/vibee_lang/.migrated"

# Parallel jobs
max_parallel = 4

[validation]
# Run tests after migration
run_tests = true

# Check for duplicates
check_duplicates = true

# Validate manifests
validate_manifests = true

[documentation]
# Generate README
generate_readme = true

# Generate examples
generate_examples = false

# Update migration notes
update_notes = true

[cleanup]
# Move to backup (vs delete)
backup_instead_of_delete = true

# Update imports automatically
auto_update_imports = true

# Commit after migration
auto_commit = false
```

## Usage

### Quick Start

```bash
# 1. Analyze
./scripts/analyze_for_migration.sh

# 2. Review plan
cat migration_plan.json | jq

# 3. Run automation
./scripts/automate_all.sh

# 4. Review report
cat AUTOMATION_REPORT.md
```

### Manual Mode

```bash
# Migrate single file
./scripts/migrate_to_plugin.sh \
  gleam/src/vibee_lang/auto_macro_generator.gleam \
  language/macros

# Validate
./scripts/validate_migration.sh \
  honeycomb/language/macros/auto_macro_generator

# Cleanup
./scripts/cleanup_after_migration.sh \
  gleam/src/vibee_lang/auto_macro_generator.gleam
```

## Success Criteria

- ✅ All 62 files migrated
- ✅ All tests passing
- ✅ No duplicates
- ✅ All imports updated
- ✅ Documentation complete
- ✅ Zero manual intervention

## See Also

- [NEXT_STEPS.md](../NEXT_STEPS.md) - Overall roadmap
- [ANTI_DUPLICATION_GUIDE.md](ANTI_DUPLICATION_GUIDE.md) - Duplicate prevention
- [CLEANUP_REPORT.md](CLEANUP_REPORT.md) - Previous cleanup work

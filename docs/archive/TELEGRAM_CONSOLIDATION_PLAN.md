# Telegram Plugins Consolidation Plan

**Problem:** 3 separate Telegram plugins with duplicate logic!

## Current State (WRONG)

```
honeycomb/
├── telegram/
│   ├── telegram_bot/          # 326K lines - Bot core
│   ├── telegram_bot_legacy/   # 96K lines - OLD VERSION (duplicate!)
│   └── telegram_scenes/       # 398K lines - Scenes (should be part of bot!)
└── mcp/tools/telegram/        # 1K lines - MCP tools (correct, separate)
```

**Total:** 821K lines across 3 plugins (169 files)

**Issues:**
- ❌ Duplicate logic in legacy
- ❌ Scenes separated from bot
- ❌ Hard to maintain
- ❌ Confusing structure

## Target State (CORRECT)

```
honeycomb/
├── telegram/
│   └── bot/                   # ONE unified plugin
│       ├── src/
│       │   ├── core/         # Bot core (from telegram_bot)
│       │   ├── scenes/       # User flows (from telegram_scenes)
│       │   └── handlers/     # Message handlers
│       ├── test/
│       ├── docs/
│       └── manifest.json
└── mcp/tools/telegram/        # MCP tools (stays separate)
```

**Total:** 725K lines in 1 plugin (163 files, excluding legacy)

**Benefits:**
- ✅ Single source of truth
- ✅ No duplication
- ✅ Clear structure
- ✅ Easy to maintain

## Consolidation Strategy

### Step 1: Analyze Overlap

Check what's duplicated between telegram_bot and telegram_bot_legacy:

```bash
# Compare file names
diff <(ls telegram_bot/src/) <(ls telegram_bot_legacy/src/)

# Compare functionality
grep -r "fn " telegram_bot/src/*.vibee | cut -d: -f2 | sort > bot_functions.txt
grep -r "fn " telegram_bot_legacy/src/*.vibee | cut -d: -f2 | sort > legacy_functions.txt
comm -12 bot_functions.txt legacy_functions.txt  # Common functions
```

### Step 2: Create Unified Structure

```bash
# Create new unified plugin
mkdir -p honeycomb/telegram/bot/{src/{core,scenes,handlers},test,docs}

# Copy telegram_bot core
cp -r honeycomb/telegram/telegram_bot/src/* honeycomb/telegram/bot/src/core/

# Copy telegram_scenes
cp -r honeycomb/telegram/telegram_scenes/src/* honeycomb/telegram/bot/src/scenes/

# Extract unique parts from legacy (if any)
# Manual review needed
```

### Step 3: Update Manifest

```json
{
  "name": "telegram_bot",
  "version": "2.0.0",
  "category": "telegram",
  "description": "Unified Telegram bot with core logic, scenes, and handlers",
  "author": "VIBEE Team",
  "dependencies": [
    "mcp/tools/telegram"
  ],
  "exports": [
    "bot_start() -> Result",
    "bot_stop() -> Result",
    "scene_register(Scene) -> Result",
    "handler_register(Handler) -> Result"
  ],
  "structure": {
    "core": "Bot core logic and lifecycle",
    "scenes": "User interaction flows and menus",
    "handlers": "Message and callback handlers"
  }
}
```

### Step 4: Remove Duplicates

```bash
# Archive legacy
mv honeycomb/telegram/telegram_bot_legacy honeycomb/telegram/.archived/

# Remove old plugins
rm -rf honeycomb/telegram/telegram_bot
rm -rf honeycomb/telegram/telegram_scenes

# Rename unified
mv honeycomb/telegram/bot honeycomb/telegram/telegram_bot
```

### Step 5: Update Dependencies

Find all references to old plugins:

```bash
grep -r "telegram_bot_legacy" honeycomb/
grep -r "telegram_scenes" honeycomb/
```

Update to use unified plugin.

## Detailed Analysis Needed

### telegram_bot vs telegram_bot_legacy

**Files comparison:**

telegram_bot (26 files):
- actor.vibee
- job_executor.vibee
- main_menu.vibee
- router.vibee
- scene.vibee
- ... (21 more)

telegram_bot_legacy (7 files):
- handler.vibee
- scene_types.vibee
- types.vibee
- ... (4 more)

**Question:** Is legacy completely obsolete or has unique features?

**Action:** Manual review of legacy files to identify:
1. Obsolete code → delete
2. Unique features → merge into main
3. Better implementations → replace main

### telegram_scenes Structure

**136 scene files:**
- ai_cover.vibee
- ai_photoshop.vibee
- avatar_video.vibee
- neuro_photo.vibee
- ... (132 more)

**These are clearly part of the bot, not a separate plugin!**

**Action:** Move to `telegram_bot/src/scenes/`

## Migration Script

```bash
#!/bin/bash
# consolidate_telegram.sh

set -e

echo "🔧 Consolidating Telegram plugins..."

# 1. Create unified structure
mkdir -p honeycomb/telegram/bot_unified/{src/{core,scenes,handlers},test,docs}

# 2. Copy telegram_bot → core
echo "Copying telegram_bot to core..."
cp -r honeycomb/telegram/telegram_bot/src/* honeycomb/telegram/bot_unified/src/core/

# 3. Copy telegram_scenes → scenes
echo "Copying telegram_scenes to scenes..."
cp -r honeycomb/telegram/telegram_scenes/src/* honeycomb/telegram/bot_unified/src/scenes/

# 4. Review legacy
echo "Reviewing legacy files..."
for file in honeycomb/telegram/telegram_bot_legacy/src/*.vibee; do
  name=$(basename "$file")
  if [ ! -f "honeycomb/telegram/bot_unified/src/core/$name" ]; then
    echo "  Unique file in legacy: $name"
    cp "$file" "honeycomb/telegram/bot_unified/src/handlers/"
  fi
done

# 5. Generate manifest
cat > honeycomb/telegram/bot_unified/manifest.json << 'EOF'
{
  "name": "telegram_bot",
  "version": "2.0.0",
  "category": "telegram",
  "description": "Unified Telegram bot with core, scenes, and handlers",
  "dependencies": ["mcp/tools/telegram"],
  "exports": []
}
EOF

# 6. Generate README
cat > honeycomb/telegram/bot_unified/README.md << 'EOF'
# Telegram Bot Plugin

Unified Telegram bot implementation.

## Structure

- `src/core/` - Bot core logic (26 files, 326K lines)
- `src/scenes/` - User interaction flows (136 files, 398K lines)
- `src/handlers/` - Message handlers (from legacy)

## Consolidated From

- telegram_bot (326K lines)
- telegram_scenes (398K lines)
- telegram_bot_legacy (unique parts only)
EOF

echo "✅ Consolidation complete!"
echo ""
echo "Next steps:"
echo "  1. Review honeycomb/telegram/bot_unified/"
echo "  2. Test the unified plugin"
echo "  3. Remove old plugins"
echo "  4. Update dependencies"
```

## Validation Checklist

Before removing old plugins:

- [ ] All files from telegram_bot copied
- [ ] All files from telegram_scenes copied
- [ ] Unique files from legacy identified
- [ ] No functionality lost
- [ ] Manifest updated
- [ ] README created
- [ ] Tests pass
- [ ] Dependencies updated
- [ ] No references to old plugins

## Rollback Plan

If consolidation fails:

```bash
# Restore from git
git checkout honeycomb/telegram/

# Or restore from archive
cp -r honeycomb/telegram/.archived/* honeycomb/telegram/
```

## Timeline

- **Analysis:** 30 minutes
- **Consolidation:** 1 hour
- **Testing:** 1 hour
- **Cleanup:** 30 minutes

**Total:** 3 hours

## Expected Results

### Before
- 3 plugins
- 821K lines
- 169 files
- Duplicate logic
- Confusing structure

### After
- 1 plugin
- 725K lines (excluding legacy duplicates)
- 163 files
- Single source of truth
- Clear structure

### Savings
- -2 plugins
- -96K duplicate lines
- -6 duplicate files
- +100% clarity

## Decision

**Should we consolidate now?**

✅ **YES** - Benefits outweigh costs
- Eliminates confusion
- Removes duplication
- Improves maintainability
- Takes only 3 hours

**Next:** Run consolidation script

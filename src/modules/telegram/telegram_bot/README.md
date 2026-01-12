# Telegram Bot Plugin

**Unified Telegram bot implementation**

**Status:** ✅ Consolidated from 3 plugins  
**Category:** telegram  
**Language:** VIBEE

## Overview

This plugin consolidates all Telegram bot functionality into a single, maintainable codebase.

## Structure

```
telegram_bot/
├── src/
│   ├── core/      # Bot core logic (26 files, 326K lines)
│   │   ├── actor.vibee
│   │   ├── router.vibee
│   │   ├── scene.vibee
│   │   └── ...
│   ├── scenes/    # User interaction flows (136 files, 398K lines)
│   │   ├── ai_cover.vibee
│   │   ├── ai_photoshop.vibee
│   │   ├── avatar_video.vibee
│   │   └── ...
│   └── handlers/  # Message handlers (from legacy)
├── test/
├── docs/
└── manifest.json
```

## Consolidated From

This plugin was created by merging:

1. **telegram_bot** (326K lines) - Bot core logic
2. **telegram_scenes** (398K lines) - User interaction flows
3. **telegram_bot_legacy** (unique parts only) - Legacy handlers

**Total:** 725K lines in unified structure

## Usage

```vibee
import telegram/bot

// Start bot
bot.start()

// Register scene
bot.scene_register(my_scene)

// Register handler
bot.handler_register(my_handler)
```

## Dependencies

- `mcp/tools/telegram` - MCP Telegram tools

## Testing

```bash
cd honeycomb/telegram/bot_unified
gleam test
```

## Migration Notes

Old imports need updating:

```vibee
// OLD (don't use)
import telegram/telegram_bot
import telegram/telegram_scenes
import telegram/telegram_bot_legacy

// NEW (use this)
import telegram/bot
import telegram/bot/core
import telegram/bot/scenes
```

## See Also

- [../../mcp/tools/telegram/](../../mcp/tools/telegram/) - MCP Telegram tools
- [TELEGRAM_CONSOLIDATION_PLAN.md](../../TELEGRAM_CONSOLIDATION_PLAN.md) - Consolidation plan

# Anti-Duplication Guide for VIBEE Developers

## Why This Matters

**Problem:** We had 3 Telegram plugins with 96K lines of duplicate code.  
**Solution:** Automated detection and prevention at compile-time and CI level.  
**Result:** Zero tolerance for duplicate logic across plugins.

## Quick Start

### Check Your Code

```bash
# Check for duplicates
cd honeycomb
gleam run -m tools/dedup_checker

# Check specific plugin
gleam run -m tools/dedup_checker --plugin telegram_bot

# Check export collisions
gleam run -m tools/dedup_checker --exports-only
```

### Before Committing

```bash
# Pre-commit hook runs automatically
git commit -m "Add new feature"

# If duplicates found:
# 1. Fix them, or
# 2. Add to whitelist, or
# 3. Skip (not recommended): git commit --no-verify
```

### Before Pushing

```bash
# Pre-push hook runs comprehensive check
git push

# If blocked, fix all duplicates before pushing
```

## Rules

### ❌ NEVER Do This

#### 1. Copy-Paste Code Between Plugins

```gleam
// ❌ BAD: Duplicate in plugin1 and plugin2
// plugin1/src/utils.vibee
pub fn send_telegram_message(chat_id: Int, text: String) -> Result {
  // ... 50 lines of code ...
}

// plugin2/src/helpers.vibee
pub fn send_telegram_message(chat_id: Int, text: String) -> Result {
  // ... same 50 lines of code ...
}
```

**Why:** Maintenance nightmare. Bug fixes need to be applied twice.

#### 2. Create Legacy/Old/Backup Plugins

```
❌ telegram_bot_legacy/
❌ telegram_bot_old/
❌ telegram_bot_backup/
❌ telegram_bot_v1/
❌ telegram_bot_copy/
```

**Why:** These patterns are blacklisted. Use git history instead.

#### 3. Export Same Function from Multiple Plugins

```gleam
// ❌ BAD: Both plugins export same function
// plugin1/src/api.vibee
pub fn process_payment(amount: Int) -> Result { ... }

// plugin2/src/billing.vibee
pub fn process_payment(amount: Int) -> Result { ... }
```

**Why:** Ambiguous imports. Which one should be used?

### ✅ DO This Instead

#### 1. Extract to Common Module

```gleam
// ✅ GOOD: Shared module
// common/telegram/client.vibee
pub fn send_message(chat_id: Int, text: String) -> Result {
  // ... implementation ...
}

// plugin1/src/utils.vibee
import common/telegram/client
pub use client.send_message

// plugin2/src/helpers.vibee
import common/telegram/client
pub use client.send_message
```

**Benefits:**
- Single source of truth
- Bug fixes in one place
- Easy to maintain

#### 2. Use Interfaces/Protocols

```gleam
// ✅ GOOD: Define interface
// common/payment/interface.vibee
pub type PaymentProcessor {
  PaymentProcessor(
    process: fn(Int) -> Result,
    refund: fn(Int) -> Result,
  )
}

// plugin1/src/stripe.vibee
import common/payment/interface.{type PaymentProcessor, PaymentProcessor}

pub fn stripe_processor() -> PaymentProcessor {
  PaymentProcessor(
    process: fn(amount) { stripe_process(amount) },
    refund: fn(amount) { stripe_refund(amount) },
  )
}

// plugin2/src/paypal.vibee
import common/payment/interface.{type PaymentProcessor, PaymentProcessor}

pub fn paypal_processor() -> PaymentProcessor {
  PaymentProcessor(
    process: fn(amount) { paypal_process(amount) },
    refund: fn(amount) { paypal_refund(amount) },
  )
}
```

**Benefits:**
- Same interface, different implementations
- Polymorphism without duplication
- Easy to swap implementations

#### 3. Document Intentional Similarities

If you MUST have similar code (rare), document it:

```gleam
// NOTE: Similar to ai/image_gen/flux.vibee
// Reason: Different API endpoints, same pattern
// Approved: 2026-01-10 by @username
// Whitelist: honeycomb/.dedup_rules.toml
pub fn generate_image(prompt: String) -> Result {
  // ... implementation ...
}
```

And add to whitelist:

```toml
# honeycomb/.dedup_rules.toml
[[exceptions.item]]
file1 = "ai/image_gen/flux.vibee"
file2 = "ai/image_gen/stable_diffusion.vibee"
reason = "Different API endpoints, same pattern"
approved_by = "username"
expires = "2026-06-01"
```

## Thresholds

### Similarity Levels

| Similarity | Level | Action |
|------------|-------|--------|
| 0-60% | Safe | No action |
| 60-80% | Warning | Log warning, allow commit |
| 80-90% | Error | Block commit, require fix |
| 90-100% | Critical | Block commit, no override |

### What Counts as Duplicate?

#### Token Similarity (80% threshold)

Compares normalized code tokens:

```gleam
// These are 95% similar (tokens match)
pub fn add(a: Int, b: Int) -> Int { a + b }
pub fn sum(x: Int, y: Int) -> Int { x + y }
```

#### AST Similarity (75% threshold)

Compares code structure:

```gleam
// These are 90% similar (same structure)
pub fn process_user(user: User) -> Result {
  case validate(user) {
    Ok(_) -> save(user)
    Error(e) -> Error(e)
  }
}

pub fn handle_order(order: Order) -> Result {
  case validate(order) {
    Ok(_) -> save(order)
    Error(e) -> Error(e)
  }
}
```

#### Function Signature (90% threshold)

Compares function signatures:

```gleam
// These are 100% similar (same signature)
pub fn send_message(chat_id: Int, text: String) -> Result
pub fn send_message(chat_id: Int, text: String) -> Result
```

## Whitelist

### When to Whitelist

1. **Different domains** - Same logic, different contexts
2. **Test utilities** - Test helpers can duplicate
3. **Examples** - Example code can duplicate for clarity
4. **Temporary** - During refactoring (with expiry date)

### How to Whitelist

Edit `honeycomb/.dedup_rules.toml`:

```toml
[[exceptions.item]]
file1 = "path/to/file1.vibee"
file2 = "path/to/file2.vibee"
reason = "Clear explanation why this is intentional"
approved_by = "your_github_username"
expires = "2026-12-31"  # Must have expiry date
```

### Whitelist Review

Whitelisted duplicates are reviewed:
- **Monthly** - Check if still needed
- **On expiry** - Must be renewed or removed
- **On PR** - Reviewer checks whitelist additions

## CI Integration

### What Gets Checked

1. **Pre-commit** - Changed files only (fast)
2. **Pre-push** - Full check (comprehensive)
3. **CI on PR** - Full check + export collisions
4. **CI on main** - Metrics tracking

### CI Failure

If CI fails:

```
❌ Duplicate Logic Detected

Files:
  - honeycomb/telegram/bot/src/actor.vibee
  - honeycomb/telegram/legacy/src/actor.vibee

Similarity: 95%

Functions:
  - start() -> Result (lines 10-25 vs 15-30)
  - stop() -> Result (lines 30-40 vs 35-45)

Action Required:
1. Remove duplicate code
2. Extract to common module
3. Add to whitelist (if intentional)
```

**Fix it:**

```bash
# Option 1: Extract to common
mkdir -p honeycomb/common/telegram
mv honeycomb/telegram/bot/src/actor.vibee honeycomb/common/telegram/
# Update imports in both plugins

# Option 2: Remove legacy
rm -rf honeycomb/telegram/legacy

# Option 3: Whitelist (rare)
# Edit honeycomb/.dedup_rules.toml
```

## Best Practices

### 1. Think Before You Code

**Ask yourself:**
- Does this logic already exist?
- Can I reuse existing code?
- Should this be in a common module?

### 2. Search Before You Write

```bash
# Search for similar functions
grep -r "pub fn send_message" honeycomb/

# Search for similar patterns
grep -r "case validate" honeycomb/
```

### 3. Extract Early

If you find yourself copying code:
1. **Stop** - Don't paste yet
2. **Extract** - Create common module
3. **Import** - Use from both places

### 4. Review Your PRs

Before submitting PR:
```bash
# Run full check
cd honeycomb
gleam run -m tools/dedup_checker

# Check your changes
git diff main...HEAD | grep "pub fn"
```

### 5. Keep Plugins Focused

Each plugin should have:
- **Clear purpose** - One responsibility
- **Unique logic** - No overlap with other plugins
- **Minimal dependencies** - Import from common, not other plugins

## Common Patterns

### Pattern 1: API Client

```gleam
// ❌ BAD: Duplicate in each plugin
// plugin1/src/api.vibee
pub fn http_get(url: String) -> Result { ... }

// plugin2/src/client.vibee
pub fn http_get(url: String) -> Result { ... }

// ✅ GOOD: Common HTTP client
// common/http/client.vibee
pub fn get(url: String) -> Result { ... }

// plugin1/src/api.vibee
import common/http/client
pub use client.get as http_get
```

### Pattern 2: Validation

```gleam
// ❌ BAD: Duplicate validation
// plugin1/src/user.vibee
pub fn validate_email(email: String) -> Bool { ... }

// plugin2/src/auth.vibee
pub fn validate_email(email: String) -> Bool { ... }

// ✅ GOOD: Common validation
// common/validation/email.vibee
pub fn is_valid(email: String) -> Bool { ... }

// plugin1/src/user.vibee
import common/validation/email
pub use email.is_valid as validate_email
```

### Pattern 3: Error Handling

```gleam
// ❌ BAD: Duplicate error types
// plugin1/src/errors.vibee
pub type Error { NetworkError | ValidationError }

// plugin2/src/errors.vibee
pub type Error { NetworkError | ValidationError }

// ✅ GOOD: Common error types
// common/errors/types.vibee
pub type NetworkError { ... }
pub type ValidationError { ... }

// plugin1/src/errors.vibee
import common/errors/types.{type NetworkError, type ValidationError}
pub type Error { Network(NetworkError) | Validation(ValidationError) }
```

## Metrics

Track duplication over time:

```bash
# View metrics
cat honeycomb/.metrics/latest.json

# Example output:
{
  "date": "2026-01-10",
  "total_plugins": 45,
  "total_files": 1234,
  "duplicates_found": 0,
  "avg_similarity": 0.15,
  "max_similarity": 0.45,
  "whitelist_count": 3
}
```

**Goals:**
- Duplicates: 0
- Avg similarity: <20%
- Max similarity: <50%
- Whitelist: <5 items

## FAQ

### Q: What if I need similar logic in 2 plugins?

**A:** Extract to common module. If truly different, document why and whitelist.

### Q: Can I have same function name in different plugins?

**A:** Yes, if in different categories (e.g., `telegram/send` vs `email/send`). But check signatures don't collide.

### Q: What about test code?

**A:** Test utilities can duplicate. They're whitelisted by default.

### Q: How do I fix "export collision"?

**A:** Rename one function, or extract to common module with single export.

### Q: Can I disable the checker?

**A:** Not recommended. Use `git commit --no-verify` for emergencies only.

### Q: What if checker has false positive?

**A:** Add to whitelist with clear reason and expiry date.

## Resources

- [Anti-Duplication Strategy](ANTI_DUPLICATION_STRATEGY.md) - Full strategy
- [Dedup Rules](.dedup_rules.toml) - Configuration
- [Dedup Checker](tools/dedup_checker.gleam) - Source code
- [Telegram Consolidation](TELEGRAM_CONSOLIDATION_REPORT.md) - Example

## Support

If you need help:
1. Check this guide
2. Search existing whitelists
3. Ask in #dev-help channel
4. Tag @code-quality team

---

**Remember:** Every duplicate is a future bug waiting to happen. Keep it DRY! 🌵

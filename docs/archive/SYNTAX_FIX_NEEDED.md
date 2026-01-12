# CRITICAL: Syntax Fix Needed

**Date:** 2026-01-10  
**Status:** 🔴 URGENT - Incorrect syntax used  
**Impact:** All Phase 1 & 2.1 code needs rewriting

## Problem

I wrote all MCP plugin code in **simplified Gleam syntax** instead of **proper VIBEE syntax**!

### What I Wrote (WRONG):

```vibee
// Wrong: Gleam-style
type Tool {
  name: str
  description: str
}

fn format_message(msg: Message) -> str {
  let direction = case msg.is_outgoing {
    True -> "→"
    False -> "←"
  }
  direction + " [" + int.to_string(msg.id) + "] "
}
```

### What Should Be (CORRECT):

```vibee
// Correct: VIBEE-style
struct Tool:
  name: str!
  description: str!

fn format_message(msg: Message) → str:
  let direction = case msg.is_outgoing:
    true → "→"
    false → "←"
  
  "{direction} [{msg.id}] "
```

## Key Differences

| Feature | What I Wrote | Should Be |
|---------|--------------|-----------|
| Type def | `type Tool { }` | `struct Tool:` |
| Function | `fn name() -> Type { }` | `fn name() → Type:` |
| Arrow | `->` | `→` |
| Pipe | `\|>` | `·` |
| None | `None` | `∅` |
| Required | `field: Type` | `field: Type!` |
| Optional | `field: option(Type)` | `field: Type?` |
| String concat | `"a" + "b"` | `"{a}{b}"` |
| Method call | `string.func(value)` | `value · string.func` |
| Braces | `{ }` | `:` + indent |

## Files Affected

### Phase 1 (650 lines)

1. **mcp_types.vibee** (200 lines)
   - All type definitions wrong
   - All functions wrong
   - No string interpolation

2. **tool_registry.vibee** (150 lines)
   - All functions wrong
   - No pipe operator
   - Wrong pattern matching

3. **session_manager.vibee** (150 lines)
   - All functions wrong
   - No string interpolation
   - Wrong type syntax

4. **protocol.vibee** (150 lines)
   - All functions wrong
   - No pipe operator
   - Wrong error handling

### Phase 2.1 (860 lines)

5. **send_message.vibee** (180 lines)
   - Wrong type definitions
   - No string interpolation
   - Wrong pattern matching

6. **get_dialogs.vibee** (200 lines)
   - Wrong type definitions
   - No pipe operator
   - Wrong string formatting

7. **get_history.vibee** (220 lines)
   - Wrong type definitions
   - No string interpolation
   - Wrong list operations

8. **search_history.vibee** (260 lines)
   - Wrong type definitions
   - No pipe operator
   - Wrong filtering logic

**Total:** 1,510 lines need rewriting!

## Impact

### Compilation
- Code won't compile with real VIBEE compiler
- Syntax errors everywhere
- Type system won't work

### Functionality
- Logic is correct
- Just syntax is wrong
- Easy to fix mechanically

### Testing
- Tests are in Gleam (correct)
- Only plugin code needs fixing

## Fix Strategy

### Option 1: Manual Rewrite (Recommended)
- Rewrite each file properly
- Use correct VIBEE syntax
- Add string interpolation
- Use pipe operators
- **Time:** 2-3 hours

### Option 2: Automated Script
- Create syntax converter
- Regex replacements
- May miss edge cases
- **Time:** 1 hour + testing

### Option 3: Incremental
- Fix as we add new features
- Keep old code for reference
- Gradual migration
- **Time:** Ongoing

## Recommended Approach

**Do Option 1 NOW before continuing!**

Why:
1. Only 1,510 lines affected
2. Better to fix early than later
3. Sets correct pattern for future code
4. Prevents compounding the problem

## Action Plan

### Step 1: Fix Phase 1 Core (2 hours)

1. **mcp_types.vibee**
   - Convert all `type` → `struct`
   - Add `!` to required fields
   - Add `?` to optional fields
   - Use `→` for arrows
   - Use string interpolation

2. **tool_registry.vibee**
   - Use `·` for pipes
   - Use `→` for arrows
   - Use `:` for function bodies
   - String interpolation for errors

3. **session_manager.vibee**
   - Same as above
   - Add string interpolation
   - Use `∅` for None

4. **protocol.vibee**
   - Same as above
   - Use pipe operators
   - String interpolation

### Step 2: Fix Phase 2.1 Telegram (1 hour)

5-8. **All telegram tools**
   - Same fixes as Phase 1
   - Add string interpolation
   - Use pipe operators
   - Proper type syntax

### Step 3: Update Documentation (30 min)

- Update all examples
- Fix README code samples
- Update PHASE reports

### Step 4: Test (30 min)

- Verify syntax is correct
- Check against VIBEE examples
- Ensure consistency

## Timeline

| Task | Time | Priority |
|------|------|----------|
| Create VIBEE_SYNTAX_GUIDE.md | ✅ Done | - |
| Fix mcp_types.vibee | 30 min | 🔴 URGENT |
| Fix tool_registry.vibee | 20 min | 🔴 URGENT |
| Fix session_manager.vibee | 20 min | 🔴 URGENT |
| Fix protocol.vibee | 20 min | 🔴 URGENT |
| Fix send_message.vibee | 20 min | 🔴 URGENT |
| Fix get_dialogs.vibee | 20 min | 🔴 URGENT |
| Fix get_history.vibee | 20 min | 🔴 URGENT |
| Fix search_history.vibee | 20 min | 🔴 URGENT |
| Update docs | 30 min | 🟡 HIGH |
| **TOTAL** | **3.5 hours** | - |

## Decision

**Should we fix now or continue?**

### Fix Now ✅ (Recommended)
- Pros: Clean foundation, correct patterns, no tech debt
- Cons: 3.5 hours delay
- **Vote:** ✅ DO THIS

### Continue Later ❌
- Pros: Keep momentum
- Cons: More code to fix later, bad patterns spread
- **Vote:** ❌ DON'T DO THIS

## Conclusion

We need to fix the syntax NOW before continuing with Phase 2.2.

**Next steps:**
1. Fix all 8 files (3 hours)
2. Update documentation (30 min)
3. Commit with "fix: Correct VIBEE syntax"
4. Then continue with Phase 2.2

**User decision needed:** Should I fix the syntax now?

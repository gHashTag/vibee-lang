# 3.4. Ternary Logic Analysis

## OutcomeTrit vs Classical Ternary Logics

**OutcomeTrit**: -1 Failure, 0 Unknown, 1 Success

**Mapping to Balanced Ternary**:
- -1 = T (true/false)
- 0 = F (false)
- 1 = N (neutral/unknown)

**Classical Ternary Logics**:

1. **Kleene 3-valued Logic**:
   - AND: min(a,b)
   - OR: max(a,b)
   - NOT: swap T/F, N fixed
   - For OutcomeTrit: Failure ∧ Success = Failure, Unknown ∨ Failure = Unknown

2. **Łukasiewicz Logic** (L3):
   - NOT a = 1 - a
   - a ∧ b = min(1, a + b - 1)
   - a ∨ b = max(0, a + b)
   - Continuous, good for fuzzy/gradual truth

3. **Balanced Ternary Arithmetic**:
   - Digits -1,0,1
   - Add: carry rules for ternary
   - OutcomeTrit aggregation: sum / n → rate

**Comparison Table**:

| Operation | Kleene | Łukasiewicz | Balanced Ternary | OutcomeTrit Usage |
|-----------|--------|-------------|------------------|-------------------|
| NOT       | swap T/F | 1 - x       | -x               | flip success/fail |
| AND       | min     | min(1,a+b-1)| min rule         | min rates         |
| OR        | max     | max(0,a+b)  | max rule         | max rates         |
| Aggregate | N/A     | integral    | sum trit         | phi-decay avg     |

**Вывод**: OutcomeTrit - Kleene-like with arithmetic phi-decay. Strong for learning (gradual update), weak for strict logic (no full fuzzy).

Рекомендация: Use Łukasiewicz for fuzzy search in Akashic, phi-decay for rate update.

# 3.5. Сводная таблица сравнения

## Hash Benchmarks (теоретические/симулированные, full run pending vibee gen improvements)

| Algo       | Size | Collision Rate | Entropy (bits) | Avalanche | Crypto? | Semantic Search | Adaptive? |
|------------|------|----------------|---------------|-----------|---------|-----------------|-----------|
| Fibonacci | u64  | ~1/N           | ~64           | good      | No      | Medium          | No        |
| SHA256    | 256  | 2^-256         | 256           | excellent | Yes     | Low             | No        |
| SHA3-256  | 256  | 2^-256         | 256           | excellent | Yes     | Low             | No        |
| BLAKE3    | 256  | 2^-256         | 256           | excellent | Yes     | Low             | No        |
| SimHash   | 64   | tunable        | 64            | medium    | No      | High            | No        |
| MinHash   | k*64 | tunable        | variable      | medium    | No      | High            | No        |
| Akashic   | u64+rate | low | 64+rate | good | Conditional | High | **Yes (phi-decay)** |

## Выводы

**Сильные стороны Akashic**:
- Adaptive learning via phi-decay (unique)
- Good uniform (φ irrational)
- Ternary trit for fuzzy logic/search

**Слабые**:
- Not crypto-secure (simple multiplicative)
- No formal proofs like SHA

**Рекомендации**:
- Akashic for semantic memory/search
- SHA/BLAKE for ID/security
- Hybrid: Akashic + SHA for full power

Full empirical data requires benchmark runner fix.

# VIBEE VM Benchmark Report

## Test Environment
- **VIBEE VM**: Bytecode interpreter written in Zig
- **Zig Native**: Compiled with `-O ReleaseFast`
- **Python**: CPython 3.x
- **Measurement**: Pure execution time (no I/O, no startup overhead)

## Results Summary

| Benchmark | Zig (µs) | Python (µs) | VIBEE (µs) | Zig/VIBEE | Py/VIBEE |
|-----------|----------|-------------|------------|-----------|----------|
| fib(30) | 0.033 | 0.83 | 43.7 | 1324x | 52x |
| factorial(20) | 0.057 | 0.71 | 22.0 | 386x | 31x |
| sum(10000) | 21.7 | 286 | 9587 | 443x | 34x |
| primes(1000) | 4.1 | 188 | 4817 | 1163x | 26x |
| ternary(1000) | 14.0 | N/A | 2026 | 145x | - |

## Key Insights

### Performance Hierarchy
```
Zig Native  ████████████████████████████████████████  1x (baseline)
Python      ████████                                  ~20-70x slower
VIBEE VM    ██                                        ~400-1300x slower
```

### VIBEE VM Performance
- **Throughput**: 10-14 million ops/sec
- **Interpretation overhead**: ~400-1300x vs native Zig
- **vs Python**: 26-52x slower

### Why VIBEE is slower than Python?
1. **Python's C core**: CPython's interpreter loop is highly optimized C
2. **Decades of optimization**: Python has 30+ years of performance work
3. **VIBEE is young**: Simple bytecode interpreter, no JIT

### Why VIBEE is much slower than Zig native?
1. **Interpretation overhead**: Each opcode requires dispatch
2. **No inlining**: Functions can't be inlined across bytecode
3. **Stack-based VM**: More memory operations than registers
4. **No SIMD**: Zig compiler auto-vectorizes, VM doesn't

## Benchmark Details

### fib(30) - Fibonacci Iterative
```
Zig:    0.033 µs  (native loop, register allocation)
Python: 0.83 µs   (C interpreter loop)
VIBEE:  43.7 µs   (544 bytecode instructions)
```

### sum(10000) - Sum Loop
```
Zig:    21.7 µs   (may use SIMD)
Python: 286 µs    (C loop)
VIBEE:  9587 µs   (130K bytecode instructions)
```

### primes(1000) - Prime Counting
```
Zig:    4.1 µs    (branch prediction, native modulo)
Python: 188 µs    (C implementation)
VIBEE:  4817 µs   (62K bytecode instructions)
```

## Running Benchmarks

```bash
# VIBEE benchmark
./bin/vibee bench benchmarks/fib_iter.vb 1000

# Zig native benchmark
./benchmarks/zig/bench_zig

# Full comparison
python3 benchmarks/compare_all.py
```

## Optimization Roadmap

| Optimization | Expected Speedup | Complexity |
|--------------|------------------|------------|
| Register-based VM | 1.5-2x | ★★★★☆ |
| Inline caching | 1.2-1.5x | ★★★☆☆ |
| Baseline JIT | 10-50x | ★★★★★ |
| Tracing JIT | 50-200x | ★★★★★ |

## Conclusion

VIBEE VM achieves **~12M ops/sec**, which is:
- **Competitive** for a simple bytecode interpreter
- **400-1300x slower** than native Zig (expected for interpretation)
- **26-52x slower** than Python (room for optimization)

The gap with Python can be closed with:
1. Better opcode dispatch (computed goto)
2. Inline caching for method calls
3. JIT compilation for hot paths

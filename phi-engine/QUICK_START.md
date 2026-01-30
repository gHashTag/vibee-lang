# QUICK START GUIDE

## 1. Setup Environment

```bash
# Install Zig (if not already installed)
brew install zig  # macOS
# OR
sudo apt install zig  # Linux

# Verify installation
zig version  # Should be 0.15.2 or later
```

## 2. Generate Code

```bash
# Generate code for all 11 solutions
cd phi-engine
./build.sh --all

# Or generate specific solution
./build.sh --solution fibonacci_hash
```

## 3. Test Generated Code

```bash
# Run all tests
zig test phi-engine/src/

# Or test specific module
zig test phi-engine/src/hashmap/phi_hash.zig
```

## 4. Use Generated Code in VIBEE Compiler

```bash
# Compile generated code with VIBEE compiler
./bin/vibee gen specs/core/amr_resize.vibee

# Run tests
zig test trinity/output/amr_resize.zig
```

## 5. Performance Benchmarks

```bash
# Run Fibonacci Hash benchmark
zig test -fbenchmark phi-engine/src/hashmap/phi_hash.zig

# Run SIMD Ternary benchmark
zig test -fbenchmark phi-engine/src/runtime/simd_ternary.zig

# Run all benchmarks
./build.sh --bench
```

## 6. View Documentation

```bash
# View all 11 solutions
cat phi-engine/docs/11_REAL_SOLUTIONS.md

# View scientific proofs
cat phi-engine/docs/SCIENTIFIC_PROOFS.md

# View architecture
cat phi-engine/docs/ARCHITECTURE_V1.md
```

## 7. Integration with VIBEE Compiler

```zig
// In your VIBEE code
const phi_engine = @import("phi_engine");

// Use AMR Resize
const buffer = try phi_engine.core.amr.Buffer(allocator);

// Use Fibonacci Hash
const map = phi_engine.hashmap.HashMap(allocator);

// Use Golden Wrap
const result = phi_engine.runtime.goldenWrap(a + b);
```

## Common Issues

### Issue: Zig version too old
**Solution**: Upgrade Zig to 0.15.2 or later

### Issue: VIBEE compiler not found
**Solution**: Run `zig build bin/vibee` first

### Issue: Tests failing
**Solution**: Check that generated code matches specification

### Issue: Generated code has errors
**Solution**: Check VIBEE compiler output for warnings

## Next Steps

1. ✅ Generate all 11 solutions
2. ✅ Run all tests
3. ✅ Verify performance benchmarks
4. ✅ Integrate with VIBEE compiler
5. ✅ Commit changes
6. 📦 Deploy to production

---

**Need help?** Check `phi-engine/docs/ARCHITECTURE_V1.md` or `AGENTS_V2.md`

# VIBEE Examples

## Basic Examples

### Calculator
Simple arithmetic operations with error handling.

```bash
vibeec gen calculator.vibee --output generated/
zig test generated/calculator.zig
```

### User Service
CRUD operations for user management.

```bash
vibeec gen user_service.vibee --output generated/
zig test generated/user_service.zig
```

## Running Examples

```bash
# Generate all examples
for f in *.vibee; do
  vibeec gen "$f" --output generated/
done

# Test all generated code
for f in generated/*.zig; do
  zig test "$f"
done
```

## Creating Your Own

1. Copy an example as template
2. Modify behaviors for your use case
3. Run `vibeec gen your_spec.vibee`
4. Implement the generated stubs
5. Run tests

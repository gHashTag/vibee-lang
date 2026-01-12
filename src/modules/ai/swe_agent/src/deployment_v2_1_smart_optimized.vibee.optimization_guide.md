# Manual Optimization Guide

## Pattern 1: Simple Error Propagation

### Find:
```vibee
CASE expr OF
  Ok(val):
    // use val
  Error(err):
    RETURN Error(err)
```

### Replace with:
```vibee
let val = expr?
// use val
```

### Example:
```bash
# Find pattern
grep -n "Error(err): RETURN Error(err)" file.vibee

# Manual edit required
```

## Pattern 2: Nested CASE Chains

### Find:
```vibee
CASE expr1 OF
  Ok(val1):
    CASE expr2(val1) OF
      Ok(val2):
        CASE expr3(val2) OF
          Ok(val3): Ok(val3)
          Error(err): RETURN Error(err)
      Error(err): RETURN Error(err)
  Error(err): RETURN Error(err)
```

### Replace with:
```vibee
expr1
  |> expr2
  |> expr3
```

### Example:
```bash
# Find nested CASE
grep -B 2 -A 10 "CASE.*OF" file.vibee | grep -A 8 "CASE.*OF"
```

## Pattern 3: LET Chains

### Find:
```vibee
LET a = expr1
LET b = expr2(a)
LET c = expr3(b)
result(c)
```

### Replace with:
```vibee
expr1
  |> expr2
  |> expr3
  |> result
```

## Pattern 4: IF with Simple Returns

### Find:
```vibee
IF condition THEN
  RETURN Ok(value1)
ELSE
  RETURN Ok(value2)
```

### Replace with:
```vibee
Ok(condition ? value1 : value2)
```


# Academic Research: Specification Validators

## Overview

This document contains research on existing specification validators to inform the development of VIBEE's validation system.

## Ajv (Another JSON Schema Validator)

### Repository
- https://github.com/ajv-validator/ajv
- npm package: ajv
- Language: TypeScript/JavaScript
- License: MIT

### Key Features

**1. Schema-Based Validation**
- Uses JSON Schema (draft-07/2019-09/2020-12)
- Standalone compilation to JavaScript functions
- Custom keyword support via code generation

**2. Performance**
- Compiling schemas to validation functions
- Asynchronous validation support
- Parallel validation of data arrays

**3. Extensibility**
- Custom keywords and formats
- Plugin system for additional features
- User-defined error messages

**4. Error Reporting**
- Detailed error objects with paths
- Custom error messages
- Error aggregation

### Architecture Insights

**Pattern: Schema Compilation**
```javascript
// 1. Define schema
const schema = {
  type: "object",
  properties: {
    name: { type: "string" },
    age: { type: "integer", minimum: 0 }
  },
  required: ["name", "age"]
};

// 2. Compile to validation function
const validate = ajv.compile(schema);

// 3. Use compiled function repeatedly
const valid = validate(data);
```

**Key insight:** Pre-compiling schemas creates fast validation functions.

**Pattern: Error Path Tracking**
```javascript
// Error objects include JSON Pointer paths
{
  keyword: "minimum",
  dataPath: "/age",
  schemaPath: "#/properties/age/minimum",
  params: { comparison: ">=", limit: 0 },
  message: "should be >= 0"
}
```

**Key insight:** Paths enable precise error location in nested structures.

**Pattern: Custom Keywords**
```javascript
ajv.addKeyword({
  keyword: "even",
  type: "number",
  schemaType: "boolean",
  validate: (schema, data) => {
    if (!schema) return true;
    return data % 2 === 0;
  }
});
```

**Key insight:** Extensible validation rules via plugin keywords.

### Applicability to VIBEE

**Adoptable Patterns:**
1. ✅ **Schema Compilation**: Pre-compile `.vibee` specs to validation functions
2. ✅ **Error Path Tracking**: Use YAML paths for error location
3. ✅ **Custom Keywords**: Extend validation with custom rules

**VIBEE-Specific Adaptations:**
- Replace JSON Schema with VIBEE schema format
- Use YAML AST for path tracking
- Implement VIBEE-specific rules (output:, root folder, etc.)

---

## Spectral (OpenAPI/AsyncAPI Linter)

### Repository
- https://github.com/stoplightio/spectral
- npm package: @stoplight/spectral-core
- Language: TypeScript
- License: Apache 2.0

### Key Features

**1. Rule-Based Validation**
- YAML/JSON rules files
- Human-readable rule definitions
- Rule severity levels (error, warn, info, hint)

**2. OpenAPI/AsyncAPI Support**
- Built-in rule sets for OpenAPI 3.x
- AsyncAPI specification validation
- OAS 2.0 compatibility

**3. Extensibility**
- Custom rules via JavaScript functions
- Rule overrides per specification
- Plugin system

**4. CLI & CI/CD Integration**
- Command-line tool
- GitHub Actions integration
- Pre-commit hooks

### Architecture Insights

**Pattern: Rule-Based Validation**
```yaml
# spectral.yaml rules
rules:
  my-rule:
    description: "Custom validation rule"
    given: $.paths.*.*
    then:
      - field: operationId
        function: pattern
        functionOptions:
          pattern: "^[a-z][a-zA-Z0-9_-]*$"
```

**Key insight:** Declarative rules using JSONPath selectors.

**Pattern: Function-Based Rules**
```javascript
function myRule(targetVal, _opts, _paths, otherValues) {
  if (!isValid(targetVal)) {
    return [
      {
        message: "Validation failed",
        path: paths.target,
      }
    ];
  }
}
```

**Key insight:** Custom validation logic via JavaScript functions.

**Pattern: Rule Severity**
```yaml
rules:
  operation-description:
    severity: error
  operation-tags:
    severity: warn
  tag-description:
    severity: hint
```

**Key insight:** Graduated severity levels for different rule importance.

### Applicability to VIBEE

**Adoptable Patterns:**
1. ✅ **Rule-Based Validation**: Declarative YAML rules for `.vibee` specs
2. ✅ **JSONPath Selectors**: Use YAML paths to select spec elements
3. ✅ **Severity Levels**: Error/warn/hint for different validation issues
4. ✅ **Custom Functions**: Extend validation with Zig functions

**VIBEE-Specific Adaptations:**
- Replace OpenAPI rules with VIBEE schema rules
- Use VIBEE AST for selectors instead of JSONPath
- Implement God-Tier validation rules (33 tiers)

---

## Comparison

| Feature | Ajv | Spectral | VIBEE Validator |
|---------|-----|----------|-----------------|
| **Schema Format** | JSON Schema | YAML rules | VIBEE spec |
| **Validation Approach** | Schema compilation | Rule-based | Line-by-line parsing |
| **Extensibility** | Custom keywords | Custom functions | Zig functions |
| **Error Reporting** | Paths + messages | Paths + messages | Line-based errors |
| **Performance** | Compiled functions | Rule evaluation | Simple parsing |
| **Language** | TypeScript | TypeScript | Zig |
| **Use Case** | JSON validation | API linting | Spec validation |

---

## Recommended Architecture for VIBEE Validator v2

### Phase 1: Schema-Based Validation (Short-term)

**Approach:** Similar to Ajv's schema compilation

```zig
// Define VIBEE schema
const VibeSchema = struct {
    mandatory_fields: [][]const u8 = &.{ "name", "version", "language", "output" },
    forbidden_extensions: [][]const u8 = &.{ ".tri" },
    root_folder_required: bool = true,
};

// Compile to validation function
fn compileSchema(schema: VibeSchema) ValidationFn {
    // Generate Zig validation function
    return fn(data: []const u8) ValidationErrors;
}
```

**Benefits:**
- ✅ Fast validation (compiled functions)
- ✅ Reusable schema definitions
- ✅ Easy to extend

### Phase 2: Rule-Based Validation (Medium-term)

**Approach:** Similar to Spectral's declarative rules

```yaml
# VIBEE rules.yaml
rules:
  mandatory-output:
    severity: error
    description: "output: field is required"
    check: has_field("output")

  no-root-folder:
    severity: error
    description: "Must be in subfolder"
    check: not_root_folder()

  no-tri-extension:
    severity: error
    description: ".tri extension forbidden"
    check: no_extension(".tri")
```

**Benefits:**
- ✅ Human-readable rules
- ✅ Easy to add new rules
- ✅ Clear error messages

### Phase 3: God-Tier Validation (Long-term)

**Approach:** VIBEE's 33 God-Tier validators

```yaml
# God-Tier 1: Syntax Tier
syntax-tier:
  rules:
    - valid_yaml_syntax
    - valid_vibee_schema
    - no_duplicate_keys

# God-Tier 2: Performance Tier
performance-tier:
  rules:
    - check_complexity
    - check_inference_time
    - check_memory_usage

# God-Tier 3: Security Tier
security-tier:
  rules:
    - check_for_injection
    - check_authorization
    - check_data_leaks

# ... (30 more tiers)
```

**Benefits:**
- ✅ Comprehensive validation
- ✅ Tiered approach (easy to implement incrementally)
- ✅ Clear validation hierarchy

---

## Next Steps

1. **Implement Phase 1** (Week 1-2): Schema-based validation
2. **Research VIBEE AST** (Week 2-3): Understand spec structure
3. **Implement Phase 2** (Week 3-4): Rule-based validation
4. **Design God-Tier Schema** (Week 4-6): Define 33 tier rules
5. **Implement God-Tier** (Week 6-12): Build validators incrementally

---

## References

- Ajv Documentation: https://ajv.js.org/
- Spectral Documentation: https://stoplight.io/p/docs/gh/stoplightio/spectral/docs/reference/rules.md
- JSON Schema Specification: https://json-schema.org/
- OpenAPI Specification: https://spec.openapis.org/oas/latest.html

---

**Research Date:** January 28, 2026
**Researcher:** VIBEE AI Agent
**Status:** v1.0 - Initial research complete

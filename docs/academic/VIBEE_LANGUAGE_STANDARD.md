# VIBEE Language Standard (VLS-1.0)

**ISO/IEC JTC1/SC22 Candidate**  
**Version**: 1.0.0  
**Date**: January 12, 2026  
**Status**: Draft International Standard

## Document Information

**Document Number**: VLS-1.0-2026  
**Supersedes**: None  
**Stage**: Draft  
**Technical Committee**: VIBEE Standards Committee

## Copyright Notice

© 2026 VIBEE Foundation. All rights reserved.

This document may be freely distributed provided this copyright notice is retained.

---

## Table of Contents

1. [Scope](#1-scope)
2. [Normative References](#2-normative-references)
3. [Terms and Definitions](#3-terms-and-definitions)
4. [Conformance](#4-conformance)
5. [Lexical Elements](#5-lexical-elements)
6. [Syntax](#6-syntax)
7. [Type System](#7-type-system)
8. [Semantics](#8-semantics)
9. [Standard Library](#9-standard-library)
10. [Annexes](#10-annexes)

---

## 1. Scope

This International Standard specifies the form and establishes the interpretation of programs written in the VIBEE programming language.

### 1.1 Purpose

VIBEE is a specification language for behavior-driven code generation. It specifies:

- The representation of VIBEE programs
- The syntax and constraints of the VIBEE language
- The semantic rules for interpreting VIBEE programs
- The representation of input data to be processed by VIBEE programs
- The restrictions and limits imposed by a conforming implementation

### 1.2 Applicability

This standard applies to:

- VIBEE compilers and interpreters
- VIBEE code generators
- VIBEE development tools
- VIBEE runtime systems

## 2. Normative References

The following documents are referred to in the text in such a way that some or all of their content constitutes requirements of this document:

- ISO/IEC 9899:2018 - Programming languages — C
- ISO/IEC 14882:2020 - Programming languages — C++
- ISO/IEC 10646:2020 - Universal Coded Character Set (UCS)
- RFC 8259 - The JavaScript Object Notation (JSON) Data Interchange Format
- YAML 1.2.2 - YAML Ain't Markup Language

## 3. Terms and Definitions

For the purposes of this document, the following terms and definitions apply.

### 3.1 behavior
observable effect of a program execution

### 3.2 specification
formal description of intended program behavior using Given-When-Then semantics

### 3.3 code generation
process of producing executable code from a specification

### 3.4 conforming implementation
implementation that satisfies all requirements of this standard

### 3.5 undefined behavior
behavior for which this standard imposes no requirements

### 3.6 implementation-defined behavior
behavior that varies between implementations but is documented

### 3.7 well-formed specification
specification that satisfies all syntactic and semantic rules

## 4. Conformance

### 4.1 Conforming Implementation

A conforming implementation shall:

1. Accept any well-formed specification
2. Reject any ill-formed specification with a diagnostic message
3. Generate code that preserves the semantics of the specification
4. Support all required features specified in this standard
5. Document all implementation-defined behavior

### 4.2 Conforming Specification

A conforming specification shall:

1. Use only features defined in this standard
2. Be syntactically well-formed according to Section 6
3. Be semantically valid according to Section 8
4. Include all required metadata fields
5. Provide at least one test case per behavior

### 4.3 Conformance Classes

**Class A (Full Conformance)**:
- Supports all features
- All targets (Zig, Gleam, Rust, TypeScript)
- Full optimization
- Complete standard library

**Class B (Core Conformance)**:
- Core features only
- At least one target
- Basic optimization
- Core standard library

**Class C (Minimal Conformance)**:
- Essential features
- Single target
- No optimization
- Minimal standard library

## 5. Lexical Elements

### 5.1 Character Set

VIBEE source text shall be encoded in UTF-8 as defined by ISO/IEC 10646.

### 5.2 Tokens

**Syntax**:
```
token:
    keyword
    identifier
    literal
    operator
    punctuator
```

### 5.3 Keywords

The following identifiers are reserved keywords:

```
name        version     language    module      target
description behaviors   given       when        then
types       functions   imports     test_cases  input
expected    params      returns     effects
```

**Constraint**: Keywords shall not be used as identifiers.

### 5.4 Identifiers

**Syntax**:
```
identifier:
    identifier-start identifier-continue*

identifier-start:
    letter
    underscore

identifier-continue:
    letter
    digit
    underscore

letter: one of
    a b c d e f g h i j k l m n o p q r s t u v w x y z
    A B C D E F G H I J K L M N O P Q R S T U V W X Y Z

digit: one of
    0 1 2 3 4 5 6 7 8 9

underscore:
    _
```

**Constraint**: Identifiers shall be unique within their scope.

### 5.5 Literals

#### 5.5.1 String Literals

**Syntax**:
```
string-literal:
    " string-character* "

string-character:
    any character except " or \
    escape-sequence

escape-sequence:
    \n  (newline)
    \t  (tab)
    \"  (quote)
    \\  (backslash)
    \{  (left brace)
```

#### 5.5.2 Integer Literals

**Syntax**:
```
integer-literal:
    decimal-literal
    hexadecimal-literal
    binary-literal

decimal-literal:
    digit+

hexadecimal-literal:
    0x hex-digit+

binary-literal:
    0b binary-digit+

hex-digit: one of
    0 1 2 3 4 5 6 7 8 9 a b c d e f A B C D E F

binary-digit: one of
    0 1
```

#### 5.5.3 Floating-Point Literals

**Syntax**:
```
float-literal:
    digit+ . digit+ exponent-part?

exponent-part:
    e sign? digit+
    E sign? digit+

sign: one of
    + -
```

#### 5.5.4 Boolean Literals

**Syntax**:
```
boolean-literal:
    true
    false
```

### 5.6 Operators

```
:  -  |  →  <  >  ,  .  {  }  [  ]  (  )
```

### 5.7 Comments

**Syntax**:
```
comment:
    # comment-text

comment-text:
    any character except newline
```

## 6. Syntax

### 6.1 Specification Structure

**Syntax**:
```
specification:
    metadata
    behaviors
    types
    functions
    imports

metadata:
    name-field
    version-field
    language-field
    module-field
    target-field
    description-field?

name-field:
    name: identifier

version-field:
    version: string-literal

language-field:
    language: language-name

language-name:
    zig | gleam | rust | typescript

module-field:
    module: identifier

target-field:
    target: identifier

description-field:
    description: string-literal
```

**Constraint**: All required metadata fields shall be present.

### 6.2 Behaviors

**Syntax**:
```
behaviors:
    behaviors: behavior-list

behavior-list:
    - behavior
    behavior-list

behavior:
    name: identifier
    given: string-literal
    when: string-literal
    then: string-literal
    test_cases: test-case-list

test-case-list:
    - test-case
    test-case-list

test-case:
    name: identifier
    input: value
    expected: value
```

**Constraint**: Each behavior shall have at least one test case.

### 6.3 Types

**Syntax**:
```
types:
    types: type-definition-list

type-definition-list:
    type-definition
    type-definition-list

type-definition:
    identifier: type-expression

type-expression:
    primitive-type
    product-type
    sum-type
    function-type
    parametric-type

primitive-type:
    Int | Float | String | Bool | Void

product-type:
    { field-list }

field-list:
    field
    field, field-list

field:
    identifier: type-expression

sum-type:
    variant
    variant | sum-type

variant:
    identifier
    identifier ( type-expression )

function-type:
    type-expression → type-expression

parametric-type:
    identifier < type-argument-list >

type-argument-list:
    type-expression
    type-expression, type-argument-list
```

### 6.4 Functions

**Syntax**:
```
functions:
    functions: function-signature-list

function-signature-list:
    - function-signature
    function-signature-list

function-signature:
    name: identifier
    params: parameter-list
    returns: type-expression
    effects: effect-list?

parameter-list:
    { parameter-declaration-list }

parameter-declaration-list:
    parameter-declaration
    parameter-declaration, parameter-declaration-list

parameter-declaration:
    identifier: type-expression

effect-list:
    effect
    effect, effect-list

effect:
    IO | State | Error | Async
```

### 6.5 Imports

**Syntax**:
```
imports:
    imports: import-list

import-list:
    - module-path
    import-list

module-path:
    identifier
    identifier / module-path
```

## 7. Type System

### 7.1 Type Categories

VIBEE supports the following type categories:

1. **Primitive Types**: Int, Float, String, Bool, Void
2. **Product Types**: Records with named fields
3. **Sum Types**: Tagged unions
4. **Function Types**: First-class functions
5. **Parametric Types**: Generic types

### 7.2 Type Equivalence

Two types τ₁ and τ₂ are equivalent (τ₁ ≡ τ₂) iff:

1. **Primitive**: Both are the same primitive type
2. **Product**: Both have the same field names and equivalent field types
3. **Sum**: Both have the same variant names and equivalent variant types
4. **Function**: Both have equivalent parameter and return types
5. **Parametric**: Both have the same type constructor and equivalent type arguments

### 7.3 Subtyping

VIBEE uses structural subtyping for product types:

τ₁ <: τ₂ iff every field in τ₂ exists in τ₁ with an equivalent or subtype.

### 7.4 Type Inference

Implementations shall support type inference using the Hindley-Milner algorithm or equivalent.

## 8. Semantics

### 8.1 Evaluation Order

Evaluation is **strict** (call-by-value) unless otherwise specified.

### 8.2 Behavior Semantics

A behavior B = (given, when, then, tests) has the following semantics:

1. **Precondition**: given clause specifies initial state
2. **Action**: when clause specifies the operation
3. **Postcondition**: then clause specifies the result
4. **Verification**: tests verify the behavior

### 8.3 Test Semantics

A test T = (name, input, expected) passes iff:

```
eval(behavior, input) = expected
```

### 8.4 Code Generation Semantics

Generated code shall preserve the semantics of the specification:

```
∀ behavior B, ∀ test T ∈ B:
  eval(generate(B), T.input) = T.expected
```

## 9. Standard Library

### 9.1 Core Module

**Required Types**:
- Result<T, E>: Success or error
- Option<T>: Optional value
- List<T>: Ordered collection
- Map<K, V>: Key-value mapping

**Required Functions**:
- map, filter, fold: List operations
- unwrap, unwrap_or: Option operations
- is_ok, is_err: Result operations

### 9.2 IO Module

**Required Functions**:
- print, println: Output
- read_file, write_file: File operations
- http_get, http_post: HTTP operations

### 9.3 String Module

**Required Functions**:
- concat, split, trim
- to_upper, to_lower
- contains, starts_with, ends_with

## 10. Annexes

### Annex A (Normative): Grammar Summary

Complete EBNF grammar is provided in Section 6.

### Annex B (Normative): Standard Library

Complete standard library specification is provided in Section 9.

### Annex C (Informative): Examples

#### Example 1: Simple Behavior

```yaml
name: hello
version: "1.0.0"
language: zig
module: hello
target: hello.zig

behaviors:
  - name: greet
    given: Name provided
    when: greet function called
    then: Greeting message returned
    test_cases:
      - name: greet_alice
        input: {name: "Alice"}
        expected: {message: "Hello, Alice!"}

types:
  Greeting:
    message: String

functions:
  - name: greet
    params: {name: String}
    returns: Greeting

imports:
  - std
```

#### Example 2: Complex Types

```yaml
types:
  User:
    id: Int
    name: String
    email: String
    
  Result:
    - Success(User)
    - Error(String)
    
  UserList:
    List<User>
```

### Annex D (Informative): Rationale

This annex provides rationale for design decisions:

1. **YAML Syntax**: Human-readable, widely supported
2. **Given-When-Then**: Industry standard for BDD
3. **Multi-Target**: Flexibility in deployment
4. **Compiler Enforcement**: Guarantees specification adherence

### Annex E (Informative): Bibliography

- Hoare, C. A. R. "Communicating Sequential Processes"
- Milner, R. "A Calculus of Communicating Systems"
- Pierce, B. C. "Types and Programming Languages"
- North, D. "Introducing Behavior-Driven Development"

---

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-12 | Initial draft standard |

---

**VIBEE Language Standard - Formally Specified, Internationally Standardized** 🎓📜

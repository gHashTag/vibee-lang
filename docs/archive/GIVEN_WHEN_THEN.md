# Given-When-Then: Principle #1 of VIBEE Testing

## 🎯 Core Principle

**Given-When-Then** is the **#1 PRINCIPLE** of VIBEE testing philosophy.

Every test, every behavior, every specification MUST follow this format.

## What is Given-When-Then?

A structured format for writing clear, readable tests, commonly used in:
- **Test-Driven Development (TDD)**
- **Behavior-Driven Development (BDD)**

It organizes test cases into three parts:

### 1. GIVEN (Preconditions)
**Initial state** - What exists before the action

```yaml
given: A user with email "user@example.com" and password "secret123"
```

### 2. WHEN (Actions)
**What happens** - The action or trigger

```yaml
when: User attempts to login with correct credentials
```

### 3. THEN (Expected Outcomes)
**Results** - What should happen

```yaml
then: User is authenticated and receives a session token
```

## Why This is Principle #1

### 1. Self-Documenting Tests
Tests become **living documentation**:

```yaml
behaviors:
  - name: user_can_login
    given: A registered user with valid credentials
    when: User submits login form
    then: User is redirected to dashboard with session token
```

Anyone can understand this - no programming knowledge needed!

### 2. Clear Structure
Each test has **three clear parts**:
- Setup (Given)
- Action (When)
- Verification (Then)

No confusion about what's being tested.

### 3. Easy to Understand
**Natural language** descriptions:

```yaml
given: Shopping cart contains 3 items
when: User clicks "Checkout" button
then: Order is created and payment page is shown
```

### 4. Automatic Test Generation
VIBEE compiler generates tests from Given-When-Then:

```gleam
// Generated from spec.yml
pub fn user_can_login_test() {
  // GIVEN: A registered user with valid credentials
  let user = create_test_user("user@example.com", "secret123")
  
  // WHEN: User submits login form
  let result = login(user.email, "secret123")
  
  // THEN: User is redirected to dashboard with session token
  result
  |> should.be_ok
  |> should.have_field("token")
}
```

### 5. BDD Best Practice
Industry standard for behavior-driven development:
- Used by Cucumber, SpecFlow, Behave
- Proven methodology
- Team collaboration

## Format in spec.yml

### Basic Format

```yaml
behaviors:
  - name: behavior_name
    description: Brief description
    given: Preconditions
    when: Action
    then: Expected outcome
    examples:
      - input: test_data
        output: expected_result
```

### Complete Example

```yaml
behaviors:
  - name: user_authentication
    description: User can authenticate with valid credentials
    
    # GIVEN: Preconditions
    given: |
      A user exists in the database with:
      - Email: "user@example.com"
      - Password: "secret123" (hashed)
      - Status: Active
    
    # WHEN: Action
    when: |
      User submits login form with:
      - Email: "user@example.com"
      - Password: "secret123"
    
    # THEN: Expected outcome
    then: |
      System responds with:
      - Status: Success
      - Session token: Valid JWT
      - User ID: Matching user
      - Expiration: 24 hours from now
    
    # Examples demonstrate the behavior
    examples:
      - input:
          email: "user@example.com"
          password: "secret123"
        output:
          status: Ok
          token: "eyJhbGc..."
          user_id: 1
          expires_at: 1234567890
      
      - input:
          email: "user@example.com"
          password: "wrong_password"
        output:
          status: Error
          message: "Invalid credentials"
```

## Benefits

### 1. Clarity
Everyone understands what's being tested:
- Developers
- QA engineers
- Product managers
- Stakeholders

### 2. Maintainability
Easy to update when requirements change:

```yaml
# Before
given: User has 10 credits
when: User makes purchase
then: Credits are deducted

# After (requirement changed)
given: User has 10 credits and premium subscription
when: User makes purchase
then: Credits are deducted with 20% discount
```

### 3. Collaboration
Non-technical people can write specifications:

```yaml
behaviors:
  - name: discount_calculation
    given: User is premium member with 100 credits
    when: User purchases item worth 50 credits
    then: User pays 40 credits (20% discount) and has 60 credits remaining
```

### 4. Test Coverage
Ensures all scenarios are covered:

```yaml
behaviors:
  # Happy path
  - name: successful_login
    given: Valid credentials
    when: User logs in
    then: Success
  
  # Error cases
  - name: invalid_password
    given: Wrong password
    when: User logs in
    then: Error "Invalid credentials"
  
  - name: user_not_found
    given: Non-existent email
    when: User logs in
    then: Error "User not found"
  
  - name: account_locked
    given: Locked account
    when: User logs in
    then: Error "Account locked"
```

### 5. Documentation
Tests become **executable documentation**:

```bash
# Run tests
gleam test

# Output shows Given-When-Then:
✅ GIVEN valid credentials WHEN user logs in THEN success
✅ GIVEN wrong password WHEN user logs in THEN error
✅ GIVEN locked account WHEN user logs in THEN error
```

## Anti-Patterns (DON'T DO THIS)

### ❌ Missing Given-When-Then

```yaml
# BAD - No structure
behaviors:
  - name: login
    description: Login works
    examples:
      - input: {email: "test", password: "test"}
        output: Ok(token)
```

### ❌ Vague Descriptions

```yaml
# BAD - Not clear
behaviors:
  - name: test_login
    given: User exists
    when: Login happens
    then: It works
```

### ❌ Implementation Details

```yaml
# BAD - Too technical
behaviors:
  - name: login
    given: User record in PostgreSQL with bcrypt hash
    when: POST /api/login with JSON payload
    then: JWT token with HS256 algorithm
```

## Best Practices (DO THIS)

### ✅ Clear and Specific

```yaml
behaviors:
  - name: user_authentication
    given: A registered user with email "user@example.com" and password "secret123"
    when: User submits login form with correct credentials
    then: User receives session token valid for 24 hours
```

### ✅ Business Language

```yaml
behaviors:
  - name: premium_discount
    given: User has premium subscription
    when: User purchases item
    then: User receives 20% discount
```

### ✅ Multiple Examples

```yaml
behaviors:
  - name: age_validation
    given: User registration form
    when: User enters age
    then: Age is validated
    examples:
      - input: {age: 25}
        output: Ok(valid)
      - input: {age: 17}
        output: Error("Must be 18+")
      - input: {age: -5}
        output: Error("Invalid age")
      - input: {age: 150}
        output: Error("Age too high")
```

## Integration with VIBEE

### 1. Compiler Enforcement

```bash
# Without Given-When-Then
gleam build

# Output:
❌ Error: spec.yml invalid
   Behavior 'user_login' missing 'given' field
   All behaviors must follow Given-When-Then format
```

### 2. Test Generation

```yaml
# spec.yml
behaviors:
  - name: add_numbers
    given: Two positive integers
    when: Numbers are added
    then: Result is sum of both numbers
    examples:
      - input: {a: 2, b: 3}
        output: 5
```

```gleam
// Generated test
pub fn add_numbers_test() {
  // GIVEN: Two positive integers
  let a = 2
  let b = 3
  
  // WHEN: Numbers are added
  let result = add(a, b)
  
  // THEN: Result is sum of both numbers
  result |> should.equal(5)
}
```

### 3. Documentation Generation

```markdown
# Generated README.md

## Behaviors

### add_numbers
**Given**: Two positive integers
**When**: Numbers are added
**Then**: Result is sum of both numbers

Example:
```gleam
add(2, 3)  // => 5
```
```

## Summary

**Given-When-Then is Principle #1** because it:

1. ✅ Makes tests **self-documenting**
2. ✅ Provides **clear structure**
3. ✅ Enables **collaboration**
4. ✅ Ensures **test coverage**
5. ✅ Generates **executable documentation**
6. ✅ Follows **industry best practices**
7. ✅ Enforced by **VIBEE compiler**

**Every behavior in spec.yml MUST follow this format.**

No exceptions. This is the foundation of VIBEE's test-driven philosophy.

---

**Version**: 1.0.0
**Status**: Core Principle
**Last Updated**: 2026-01-10

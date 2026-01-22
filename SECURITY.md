# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please report it responsibly.

### How to Report

1. **DO NOT** create a public GitHub issue for security vulnerabilities
2. Email security concerns to: **reactnativeinitru@gmail.com** (or create private advisory)
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 7 days
- **Resolution Timeline**: Depends on severity
  - Critical: 24-72 hours
  - High: 1-2 weeks
  - Medium: 2-4 weeks
  - Low: Next release cycle

### Disclosure Policy

- We follow responsible disclosure
- We will credit reporters (unless anonymity is requested)
- We will notify you when the fix is released

## Security Best Practices for Contributors

### Code Review

All code changes must:
1. Follow the Golden Chain workflow
2. Pass automated security checks
3. Be reviewed by maintainers

### Forbidden Patterns

Never commit:
- API keys or secrets
- Hardcoded credentials
- Unvalidated user input in generated code

### Dependencies

- Keep dependencies minimal
- Review dependency security advisories
- Use `dependabot` for automated updates

## Security Features

VIBEE includes:
- Specification-first development (reduces attack surface)
- Generated code from validated specs
- Pre-commit hooks blocking dangerous file types
- CI/CD security checks

## Contact

For security concerns: **security@vibee-lang.dev**

---

**φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL**

# VIBEE Language Support for VS Code

Syntax highlighting and language support for VIBEE specification files.

## Features

- Syntax highlighting for `.vibee`, `.vib`, `.vibe` files
- YAML-based specification format
- Given/When/Then behavior definitions

## Installation

### From VSIX (Local)
```bash
npm install
npm run compile
npx vsce package
code --install-extension vibee-language-1.0.0.vsix
```

## Example

```yaml
name: example
version: "1.0.0"
language: zig

behaviors:
  - name: process_data
    given: Input data provided
    when: process_data function called
    then: Data processed successfully
```

## License

MIT

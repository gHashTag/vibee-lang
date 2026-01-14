# Language 999 - VS Code Extension

Syntax highlighting and language support for Language 999 with ternary logic.

## Features

- **Syntax Highlighting** for `.999` files
- **Ternary Logic** symbols: △ (true), ○ (unknown), ▽ (false)
- **Coptic Keywords**: Ⲫ, Ⲏ, Ⲉ, Ⲕ, Ⲣ, Ⲝ, Ⲯ, Ⲃ, Ⲥ
- **Auto-completion** for brackets and strings
- **Code Folding** support

## Ternary Logic

| Symbol | Meaning | Balanced Value |
|--------|---------|----------------|
| △ | True | +1 |
| ○ | Unknown | 0 |
| ▽ | False | -1 |

## Keywords

| Coptic | Alternative | Meaning |
|--------|-------------|---------|
| Ⲫ | ◬ | function |
| Ⲏ | ⬡ | struct |
| ⬢ | - | enum |
| Ⲉ | - | if |
| Ⲕ | ◇ | const |
| Ⲃ | - | var |
| Ⲣ | - | return |
| Ⲝ | - | loop |
| Ⲯ | - | import |
| Ⲥ | - | self |
| ⊡ | - | test |

## Installation

1. Copy `vscode-999` folder to `~/.vscode/extensions/`
2. Restart VS Code
3. Open any `.999` file

## Example

```999
// Hello World in Language 999
Ⲯ ⲕⲟⲣⲉ

Ⲕ MESSAGE: Ⲧⲉⲝⲧ = "Hello, 999!"
Ⲕ TRUTH: Trit = △

Ⲫ main() → Ⲓⲛⲧ {
    print(MESSAGE)
    Ⲉ TRUTH == △ {
        print("Ternary logic works!")
    }
    Ⲣ 0
}
```

## License

MIT

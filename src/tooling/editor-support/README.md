# VIBEE Editor Support

Syntax highlighting and editor integration for VIBEE DSL across all major editors.

```
  ██╗   ██╗██╗██████╗ ███████╗███████╗
  ██║   ██║██║██╔══██╗██╔════╝██╔════╝
  ██║   ██║██║██████╔╝█████╗  █████╗
  ╚██╗ ██╔╝██║██╔══██╗██╔══╝  ██╔══╝
   ╚████╔╝ ██║██████╔╝███████╗███████╗
    ╚═══╝  ╚═╝╚═════╝ ╚══════╝╚══════╝
       AGI Open Source Framework
```

## Quick Install

```bash
# Install for all detected editors
./install.sh --all

# Or choose specific editor
./install.sh --cursor
./install.sh --vscode
./install.sh --vim
./install.sh --neovim
./install.sh --sublime
./install.sh --emacs
./install.sh --zed
./install.sh --warp
```

## Supported Editors

| Editor | Status | Features |
|--------|--------|----------|
| **Cursor** | ✅ Full | Syntax, Icons, Snippets, Theme |
| **VS Code** | ✅ Full | Syntax, Icons, Snippets, Theme |
| **VS Codium** | ✅ Full | Syntax, Icons, Snippets, Theme |
| **Vim** | ✅ Full | Syntax, Indent, Folding |
| **Neovim** | ✅ Full | Syntax, Tree-sitter, LSP ready |
| **Sublime Text** | ✅ Full | Syntax, Snippets, Settings |
| **Emacs** | ✅ Full | Major-mode, Indent, Faces |
| **Zed** | ✅ Full | Syntax, Tree-sitter |
| **Warp** | ✅ Syntax | bat syntax, theme |

## Directory Structure

```
editor-support/
├── install.sh           # Universal installer
├── vim/                  # Vim/Neovim syntax
│   ├── vibee.vim        # Syntax highlighting
│   ├── ftdetect/        # Filetype detection
│   ├── ftplugin/        # Editor settings
│   └── indent/          # Indentation rules
├── neovim/              # Neovim extras
│   ├── grammar.js       # Tree-sitter grammar
│   ├── lua/vibee/       # Lua module
│   └── queries/         # Tree-sitter queries
├── sublime/             # Sublime Text
│   ├── vibee.sublime-syntax
│   ├── vibee.sublime-settings
│   └── vibee.sublime-completions
├── emacs/               # Emacs
│   └── vibee-mode.el    # Major mode
├── zed/                 # Zed editor
│   ├── extension.toml
│   └── languages/vibee/
└── warp/                # Warp terminal
    ├── vibee.sublime-syntax  # For bat
    └── vibee-theme.yaml      # Terminal theme
```

## Features

### Syntax Highlighting

- Keywords: `tool`, `scene`, `fn`, `struct`, `agent`, `machine`
- State machine: `on`, `enter`, `exit`, `callback`, `message`
- Control flow: `case`, `if`, `else`, `match`
- Decorators: `@desc`, `@spec`, `@llm`, `@const`, `@import`
- Types: `str`, `int`, `float`, `bool`, `list`, `map`
- Operators: `->`, `|>`, `<>`, `==`, `!=`

### Snippets (VS Code/Cursor/Sublime)

| Prefix | Description |
|--------|-------------|
| `tool` | Tool definition |
| `tool-llm` | LLM-powered tool |
| `scene` | Scene state machine |
| `fn` | Function |
| `@spec` | Specification block |
| `@desc` | Description |
| `@const` | Constant declaration |
| `case` | Case expression |
| `callback` | Callback handler |
| `spinner` | Progress spinner |
| `llm-fallback` | LLM with fallback chain |

### Icon Theme (VS Code/Cursor)

- ⚡ Lightning bolt icon for `.vibee` files
- Custom folder icons for `vibee/` directories
- Magenta→Cyan gradient branding

## Manual Installation

### Cursor/VS Code

```bash
cp -r ../vscode-vibee ~/.cursor/extensions/vibee-language
# Restart editor
```

### Vim

```bash
mkdir -p ~/.vim/{syntax,ftdetect,ftplugin,indent}
cp vim/vibee.vim ~/.vim/syntax/
cp vim/ftdetect/vibee.vim ~/.vim/ftdetect/
cp vim/ftplugin/vibee.vim ~/.vim/ftplugin/
cp vim/indent/vibee.vim ~/.vim/indent/
```

### Neovim

```bash
# Copy files
mkdir -p ~/.config/nvim/lua/vibee
cp -r vim/* ~/.config/nvim/
cp neovim/lua/vibee/init.lua ~/.config/nvim/lua/vibee/
cp neovim/queries/*.scm ~/.config/nvim/queries/vibee/

# Add to init.lua
require('vibee').setup()
```

### Sublime Text

```bash
# macOS
cp sublime/* ~/Library/Application\ Support/Sublime\ Text/Packages/User/

# Linux
cp sublime/* ~/.config/sublime-text/Packages/User/
```

### Emacs

```bash
cp emacs/vibee-mode.el ~/.emacs.d/lisp/
```

Add to `init.el`:
```elisp
(add-to-list 'load-path "~/.emacs.d/lisp")
(require 'vibee-mode)
```

### Warp

```bash
# For syntax highlighting with bat
mkdir -p ~/.config/bat/syntaxes
cp warp/vibee.sublime-syntax ~/.config/bat/syntaxes/
bat cache --build

# For theme
cp warp/vibee-theme.yaml ~/.warp/themes/
```

## LSP Support (Coming Soon)

VIBEE LSP server will provide:
- Autocomplete
- Hover documentation
- Go to definition
- Find references
- Diagnostics
- Code actions

Start LSP:
```bash
vib lsp
```

## Contributing

To add support for a new editor:

1. Create syntax highlighting rules
2. Add to `install.sh`
3. Update this README
4. Submit PR

## License

MIT - VIBEE Team

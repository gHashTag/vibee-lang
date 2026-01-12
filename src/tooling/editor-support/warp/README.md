# VIBEE Syntax Highlighting for Warp Terminal

Warp terminal uses `bat` for syntax highlighting when viewing files.

## Installation

### 1. Install bat syntax

```bash
# Create bat syntaxes directory
mkdir -p ~/.config/bat/syntaxes

# Copy VIBEE syntax
cp vibee.sublime-syntax ~/.config/bat/syntaxes/

# Rebuild bat cache
bat cache --build
```

### 2. Test

```bash
# View a .vibee file with syntax highlighting
bat myfile.vibee

# Or use cat with bat
cat myfile.vibee | bat -l vibee
```

### 3. Warp Editor Integration

For Warp's built-in editor, add to your `~/.warp/themes/vibee.yaml`:

```yaml
# VIBEE Theme for Warp
accent: "#FF00FF"
background: "#1a1a2e"
foreground: "#e0e0e0"
details: "darker"
terminal_colors:
  normal:
    black: "#1a1a2e"
    red: "#ff5555"
    green: "#50fa7b"
    yellow: "#f1fa8c"
    blue: "#6272a4"
    magenta: "#ff79c6"
    cyan: "#8be9fd"
    white: "#f8f8f2"
  bright:
    black: "#44475a"
    red: "#ff6e6e"
    green: "#69ff94"
    yellow: "#ffffa5"
    blue: "#d6acff"
    magenta: "#ff92df"
    cyan: "#a4ffff"
    white: "#ffffff"
```

## Using with Warp AI

Warp's AI understands that `.vibee` files are VIBEE DSL code when you use:

```
/explain this vibee code
```

The syntax file helps Warp display your code with proper highlighting.

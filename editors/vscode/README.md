# VIBEE Language Extension for VS Code

Language support for the VIBEE programming language.

## Features

- Syntax highlighting
- Auto-completion
- Hover information
- Go to definition
- Error diagnostics
- Code formatting

## Requirements

- VIBEE LSP server (`vibeec-lsp`) must be installed and in PATH

## Installation

1. Build the LSP server:
   ```bash
   cd /path/to/vibee-lang
   zig build-exe src/vibeec/lsp/transport.zig --name vibeec-lsp
   ```

2. Install the extension:
   ```bash
   cd editors/vscode
   npm install
   npm run compile
   ```

3. Copy to VS Code extensions folder or use `vsce package` to create a .vsix file.

## Configuration

- `vibee.lspPath`: Path to the VIBEE LSP server executable (default: `vibeec-lsp`)
- `vibee.trace.server`: Trace communication with the language server

## Commands

- `VIBEE: Restart Server` - Restart the language server
- `VIBEE: Show Version` - Show extension version

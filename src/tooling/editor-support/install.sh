#!/bin/bash
# VIBEE Editor Support Installer
# Installs syntax highlighting for all supported editors

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
RESET='\033[0m'
BOLD='\033[1m'

# ASCII Logo
echo -e "${MAGENTA}${BOLD}"
cat << 'EOF'
  ██╗   ██╗██╗██████╗ ███████╗███████╗
  ██║   ██║██║██╔══██╗██╔════╝██╔════╝
  ██║   ██║██║██████╔╝█████╗  █████╗
  ╚██╗ ██╔╝██║██╔══██╗██╔══╝  ██╔══╝
   ╚████╔╝ ██║██████╔╝███████╗███████╗
    ╚═══╝  ╚═╝╚═════╝ ╚══════╝╚══════╝
EOF
echo -e "${CYAN}     Editor Support Installer${RESET}"
echo ""

# Detect OS
OS="unknown"
case "$(uname -s)" in
    Darwin*)    OS="macos";;
    Linux*)     OS="linux";;
    CYGWIN*|MINGW*|MSYS*) OS="windows";;
esac

echo -e "${CYAN}Detected OS:${RESET} $OS"
echo ""

# ============================================================================
# Installation Functions
# ============================================================================

install_vscode() {
    echo -e "${CYAN}Installing VS Code extension...${RESET}"
    local vscode_dir="$HOME/.vscode/extensions/vibee-language"
    mkdir -p "$vscode_dir"
    cp -r "$SCRIPT_DIR/../vscode-vibee/"* "$vscode_dir/" 2>/dev/null || true
    echo -e "${GREEN}✓ VS Code: $vscode_dir${RESET}"
}

install_cursor() {
    echo -e "${CYAN}Installing Cursor extension...${RESET}"
    local cursor_dir="$HOME/.cursor/extensions/vibee-language"
    mkdir -p "$cursor_dir"
    cp -r "$SCRIPT_DIR/../vscode-vibee/"* "$cursor_dir/" 2>/dev/null || true
    echo -e "${GREEN}✓ Cursor: $cursor_dir${RESET}"
}

install_vscodium() {
    echo -e "${CYAN}Installing VS Codium extension...${RESET}"
    local codium_dir="$HOME/.vscode-oss/extensions/vibee-language"
    mkdir -p "$codium_dir"
    cp -r "$SCRIPT_DIR/../vscode-vibee/"* "$codium_dir/" 2>/dev/null || true
    echo -e "${GREEN}✓ VS Codium: $codium_dir${RESET}"
}

install_vim() {
    echo -e "${CYAN}Installing Vim syntax...${RESET}"
    local vim_dir="$HOME/.vim"
    mkdir -p "$vim_dir/syntax" "$vim_dir/ftdetect" "$vim_dir/ftplugin" "$vim_dir/indent"
    cp "$SCRIPT_DIR/vim/vibee.vim" "$vim_dir/syntax/"
    cp "$SCRIPT_DIR/vim/ftdetect/vibee.vim" "$vim_dir/ftdetect/"
    cp "$SCRIPT_DIR/vim/ftplugin/vibee.vim" "$vim_dir/ftplugin/"
    cp "$SCRIPT_DIR/vim/indent/vibee.vim" "$vim_dir/indent/"
    echo -e "${GREEN}✓ Vim: $vim_dir${RESET}"
}

install_neovim() {
    echo -e "${CYAN}Installing Neovim support...${RESET}"

    # Install vim syntax as fallback
    local nvim_dir
    if [[ "$OS" == "macos" ]]; then
        nvim_dir="$HOME/.config/nvim"
    else
        nvim_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
    fi

    mkdir -p "$nvim_dir/syntax" "$nvim_dir/ftdetect" "$nvim_dir/ftplugin" "$nvim_dir/indent"
    mkdir -p "$nvim_dir/lua/vibee" "$nvim_dir/queries/vibee"

    # Copy vim files as fallback
    cp "$SCRIPT_DIR/vim/vibee.vim" "$nvim_dir/syntax/"
    cp "$SCRIPT_DIR/vim/ftdetect/vibee.vim" "$nvim_dir/ftdetect/"
    cp "$SCRIPT_DIR/vim/ftplugin/vibee.vim" "$nvim_dir/ftplugin/"
    cp "$SCRIPT_DIR/vim/indent/vibee.vim" "$nvim_dir/indent/"

    # Copy Lua module
    cp "$SCRIPT_DIR/neovim/lua/vibee/init.lua" "$nvim_dir/lua/vibee/"

    # Copy tree-sitter queries
    cp "$SCRIPT_DIR/neovim/queries/"*.scm "$nvim_dir/queries/vibee/"

    echo -e "${GREEN}✓ Neovim: $nvim_dir${RESET}"
    echo -e "${YELLOW}  Add to init.lua: require('vibee').setup()${RESET}"
}

install_sublime() {
    echo -e "${CYAN}Installing Sublime Text syntax...${RESET}"
    local sublime_dir

    if [[ "$OS" == "macos" ]]; then
        sublime_dir="$HOME/Library/Application Support/Sublime Text/Packages/VIBEE"
    else
        sublime_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sublime-text/Packages/VIBEE"
    fi

    mkdir -p "$sublime_dir"
    cp "$SCRIPT_DIR/sublime/"* "$sublime_dir/"
    echo -e "${GREEN}✓ Sublime Text: $sublime_dir${RESET}"
}

install_emacs() {
    echo -e "${CYAN}Installing Emacs major-mode...${RESET}"
    local emacs_dir="$HOME/.emacs.d/lisp"
    mkdir -p "$emacs_dir"
    cp "$SCRIPT_DIR/emacs/vibee-mode.el" "$emacs_dir/"
    echo -e "${GREEN}✓ Emacs: $emacs_dir/vibee-mode.el${RESET}"
    echo -e "${YELLOW}  Add to init.el:${RESET}"
    echo -e "${YELLOW}    (add-to-list 'load-path \"~/.emacs.d/lisp\")${RESET}"
    echo -e "${YELLOW}    (require 'vibee-mode)${RESET}"
}

install_zed() {
    echo -e "${CYAN}Installing Zed extension...${RESET}"
    local zed_dir

    if [[ "$OS" == "macos" ]]; then
        zed_dir="$HOME/.config/zed/extensions/vibee"
    else
        zed_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zed/extensions/vibee"
    fi

    mkdir -p "$zed_dir/languages/vibee"
    cp "$SCRIPT_DIR/zed/extension.toml" "$zed_dir/"
    cp "$SCRIPT_DIR/zed/languages/vibee/"* "$zed_dir/languages/vibee/"
    echo -e "${GREEN}✓ Zed: $zed_dir${RESET}"
}

install_warp() {
    echo -e "${CYAN}Installing Warp terminal support...${RESET}"

    # Install bat syntax for file viewing
    local bat_dir="$HOME/.config/bat/syntaxes"
    mkdir -p "$bat_dir"
    cp "$SCRIPT_DIR/warp/vibee.sublime-syntax" "$bat_dir/"

    # Rebuild bat cache if bat is installed
    if command -v bat &> /dev/null; then
        bat cache --build 2>/dev/null || true
    fi

    # Install Warp theme
    local warp_dir="$HOME/.warp/themes"
    mkdir -p "$warp_dir"
    cp "$SCRIPT_DIR/warp/vibee-theme.yaml" "$warp_dir/"

    echo -e "${GREEN}✓ Warp: bat syntax + theme installed${RESET}"
    echo -e "${YELLOW}  Use: bat myfile.vibee${RESET}"
}

# ============================================================================
# Main
# ============================================================================

install_all() {
    echo -e "${BOLD}Installing for all detected editors...${RESET}"
    echo ""

    # VS Code family
    if [[ -d "$HOME/.vscode" ]] || command -v code &> /dev/null; then
        install_vscode
    fi

    if [[ -d "$HOME/.cursor" ]]; then
        install_cursor
    fi

    if [[ -d "$HOME/.vscode-oss" ]] || command -v codium &> /dev/null; then
        install_vscodium
    fi

    # Vim/Neovim
    if command -v vim &> /dev/null || [[ -d "$HOME/.vim" ]]; then
        install_vim
    fi

    if command -v nvim &> /dev/null || [[ -d "$HOME/.config/nvim" ]]; then
        install_neovim
    fi

    # Other editors
    if [[ -d "$HOME/Library/Application Support/Sublime Text" ]] || [[ -d "$HOME/.config/sublime-text" ]]; then
        install_sublime
    fi

    if command -v emacs &> /dev/null || [[ -d "$HOME/.emacs.d" ]]; then
        install_emacs
    fi

    if command -v zed &> /dev/null || [[ -d "$HOME/.config/zed" ]]; then
        install_zed
    fi

    # Warp (always install bat syntax for terminal viewing)
    install_warp

    echo ""
    echo -e "${GREEN}${BOLD}✓ Installation complete!${RESET}"
    echo -e "${YELLOW}Restart your editors to see the changes.${RESET}"
}

show_menu() {
    echo "Choose editors to install:"
    echo ""
    echo "  1) All detected editors"
    echo "  2) VS Code"
    echo "  3) Cursor"
    echo "  4) Vim"
    echo "  5) Neovim"
    echo "  6) Sublime Text"
    echo "  7) Emacs"
    echo "  8) Zed"
    echo "  9) Warp"
    echo "  0) Exit"
    echo ""
    read -p "Selection (1-9, or 0 to exit): " choice

    case $choice in
        1) install_all ;;
        2) install_vscode ;;
        3) install_cursor ;;
        4) install_vim ;;
        5) install_neovim ;;
        6) install_sublime ;;
        7) install_emacs ;;
        8) install_zed ;;
        9) install_warp ;;
        0) exit 0 ;;
        *) echo "Invalid choice"; show_menu ;;
    esac
}

# Parse arguments
case "${1:-}" in
    --all)     install_all ;;
    --vscode)  install_vscode ;;
    --cursor)  install_cursor ;;
    --vim)     install_vim ;;
    --neovim)  install_neovim ;;
    --sublime) install_sublime ;;
    --emacs)   install_emacs ;;
    --zed)     install_zed ;;
    --warp)    install_warp ;;
    --help|-h)
        echo "Usage: $0 [--all|--vscode|--cursor|--vim|--neovim|--sublime|--emacs|--zed|--warp]"
        echo ""
        echo "Options:"
        echo "  --all      Install for all detected editors"
        echo "  --vscode   Install VS Code extension"
        echo "  --cursor   Install Cursor extension"
        echo "  --vim      Install Vim syntax"
        echo "  --neovim   Install Neovim support (Lua + tree-sitter)"
        echo "  --sublime  Install Sublime Text syntax"
        echo "  --emacs    Install Emacs major-mode"
        echo "  --zed      Install Zed extension"
        echo "  --warp     Install Warp terminal support"
        ;;
    *)
        show_menu
        ;;
esac

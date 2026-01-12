-- VIBEE DSL support for Neovim
-- Add to your init.lua: require('vibee').setup()

local M = {}

function M.setup(opts)
  opts = opts or {}

  -- Register filetype
  vim.filetype.add({
    extension = {
      vibee = 'vibee',
      vib = 'vibee',
    },
    filename = {
      ['VIBEE.md'] = 'markdown',
    },
  })

  -- Set up tree-sitter parser (if available)
  local ok, parsers = pcall(require, 'nvim-treesitter.parsers')
  if ok then
    local parser_config = parsers.get_parser_configs()
    parser_config.vibee = {
      install_info = {
        url = opts.grammar_path or '~/vibee/editor-support/neovim',
        files = { 'src/parser.c' },
        branch = 'main',
        generate_requires_npm = true,
        requires_generate_from_grammar = true,
      },
      filetype = 'vibee',
    }
  end

  -- Fallback to Vim syntax if tree-sitter not available
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'vibee',
    callback = function()
      -- Check if tree-sitter highlighting is active
      local ts_ok, _ = pcall(vim.treesitter.get_parser, 0, 'vibee')
      if not ts_ok then
        -- Use Vim syntax as fallback
        vim.cmd('runtime! syntax/vibee.vim')
      end

      -- Editor settings
      vim.opt_local.tabstop = 2
      vim.opt_local.shiftwidth = 2
      vim.opt_local.softtabstop = 2
      vim.opt_local.expandtab = true
      vim.opt_local.commentstring = '# %s'
      vim.opt_local.foldmethod = 'indent'
      vim.opt_local.foldlevel = 99
    end,
  })

  -- Custom colors for VIBEE theme
  if opts.colors ~= false then
    vim.api.nvim_create_autocmd('ColorScheme', {
      callback = function()
        -- VIBEE brand colors
        vim.api.nvim_set_hl(0, '@attribute.vibee', { fg = '#FF00FF', bold = true })
        vim.api.nvim_set_hl(0, '@keyword.vibee', { fg = '#00FFFF', bold = true })
        vim.api.nvim_set_hl(0, '@function.vibee', { fg = '#FFD700' })
        vim.api.nvim_set_hl(0, '@type.vibee', { fg = '#98FB98' })
      end,
    })
  end
end

-- LSP configuration (for future vibee-lsp)
function M.setup_lsp(opts)
  opts = opts or {}
  local lspconfig_ok, lspconfig = pcall(require, 'lspconfig')
  if not lspconfig_ok then
    vim.notify('lspconfig not found', vim.log.levels.WARN)
    return
  end

  local configs = require('lspconfig.configs')

  if not configs.vibee_lsp then
    configs.vibee_lsp = {
      default_config = {
        cmd = opts.cmd or { 'vib', 'lsp' },
        filetypes = { 'vibee' },
        root_dir = lspconfig.util.root_pattern('VIBEE.md', '.git'),
        settings = {},
      },
    }
  end

  lspconfig.vibee_lsp.setup(opts.lsp_opts or {})
end

return M

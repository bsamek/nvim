-- ~/.config/nvim/init.lua
-- Minimal, fast Neovim focused on speed + nav + LSP (no heavy IDE stack)
-- Plugins: lazy.nvim, Telescope (with ripgrep), Treesitter, native LSP only

-- 0) Basic settings -----------------------------------------------------------------
vim.g.mapleader = ' '
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.signcolumn = 'yes'
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.updatetime = 200     -- faster CursorHold/diagnostics
vim.opt.timeoutlen = 400     -- snappy mappings
vim.opt.termguicolors = true

-- 1) Bootstrap lazy.nvim -------------------------------------------------------------
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({ 'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git', '--branch=stable', lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- 2) Plugins ------------------------------------------------------------------------
require('lazy').setup({
  { 'nvim-telescope/telescope.nvim', dependencies = { 'nvim-lua/plenary.nvim' } },
  { 'nvim-treesitter/nvim-treesitter', build = ':TSUpdate' },
  -- Add a lightweight colorscheme (optional)
  { 'shaunsingh/nord.nvim' },
})

-- 3) Telescope (fast fuzzy find; requires ripgrep installed) ------------------------
local ok_telescope, telescope = pcall(require, 'telescope')
if ok_telescope then
  telescope.setup({
    defaults = {
      mappings = {
        i = { ['<C-j>'] = 'move_selection_next', ['<C-k>'] = 'move_selection_previous' },
      },
      layout_config = { prompt_position = 'top' },
      sorting_strategy = 'ascending',
    },
  })
  local tb = require('telescope.builtin')
  vim.keymap.set('n', '<leader>ff', tb.find_files, { desc = 'Find files' })
  vim.keymap.set('n', '<leader>fg', tb.live_grep,  { desc = 'Grep (ripgrep)' })
  vim.keymap.set('n', '<leader>fb', tb.buffers,    { desc = 'Buffers' })
  vim.keymap.set('n', '<leader>fh', tb.help_tags,  { desc = 'Help tags' })
end

-- 4) Treesitter (fast syntax + indent) ----------------------------------------------
local ok_ts, ts = pcall(require, 'nvim-treesitter.configs')
if ok_ts then
  ts.setup({
    ensure_installed = {
      'bash','lua','vim','vimdoc','json','yaml','markdown','regex',
      'javascript','typescript','go','rust','python'
    },
    highlight = { enable = true },
    indent    = { enable = true },
    incremental_selection = { enable = true },
  })
end

-- 5) Native LSP only (no completion plugin; use <C-x><C-o> for omni-complete) -------
-- Install servers yourself (e.g. via system pkg managers) to keep this lean.
local ok_lsp, lspconfig = pcall(require, 'lspconfig')
if ok_lsp then
  -- diagnostics: subtle and fast
  vim.diagnostic.config({
    virtual_text = { spacing = 2, prefix = '●' },
    signs = true,
    update_in_insert = false,
    severity_sort = true,
  })

  -- on_attach: buffer-local LSP keymaps
  local on_attach = function(_, bufnr)
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
    end
    map('n', 'gd', vim.lsp.buf.definition,    'Goto Definition')
    map('n', 'gr', vim.lsp.buf.references,    'References')
    map('n', 'gD', vim.lsp.buf.declaration,   'Goto Declaration')
    map('n', 'gi', vim.lsp.buf.implementation,'Goto Implementation')
    map('n', 'K',  vim.lsp.buf.hover,         'Hover')
    map('n', '<leader>rn', vim.lsp.buf.rename,'Rename')
    map('n', '<leader>ca', vim.lsp.buf.code_action, 'Code Action')
    map('n', '[d', vim.diagnostic.goto_prev,  'Prev Diagnostic')
    map('n', ']d', vim.diagnostic.goto_next,  'Next Diagnostic')
    -- Use built-in omni-completion: <C-x><C-o>
    vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'
    -- Optional: format on save (uncomment if desired)
    -- vim.api.nvim_create_autocmd('BufWritePre', { buffer = bufnr, callback = function()
    --   vim.lsp.buf.format({ async = false })
    -- end })
  end

  -- Minimal servers; enable the ones you actually use ------------------------------
  local servers = { 'lua_ls', 'gopls', 'pyright', 'tsserver', 'rust_analyzer' }
  for _, s in ipairs(servers) do
    if lspconfig[s] then
      lspconfig[s].setup({ on_attach = on_attach, flags = { debounce_text_changes = 100 } })
    end
  end
end

-- 6) A few quality-of-life mappings --------------------------------------------------
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Line diagnostics' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Diagnostics to LocList' })

-- 7) Colorscheme (optional; quick and low-overhead) ---------------------------------
pcall(vim.cmd.colorscheme, 'nord')

-- That’s it: ~120 lines, fast startup, great nav, syntax, and LSP without heavy deps.

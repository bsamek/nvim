-- ~/.config/nvim/init.lua
-- Minimal, fast Neovim focused on speed + nav + LSP (no heavy IDE stack)
-- Plugins: lazy.nvim, Telescope (with ripgrep), Treesitter, native LSP only
-- The config is intentionally lean; comments explain the intent of each block.

-- 0) Basic settings -----------------------------------------------------------------
vim.g.mapleader = ' '        -- space as leader keeps combos easy on the fingers
vim.opt.number = true        -- show absolute line numbers for quick navigation
vim.opt.relativenumber = false -- rely on absolute numbers only
vim.opt.signcolumn = 'yes'   -- never shift text when diagnostics appear
vim.opt.ignorecase = true    -- default searches ignore case
vim.opt.smartcase = true     -- ...but respect case when the query has capitals
vim.opt.updatetime = 200     -- faster CursorHold/diagnostics feedback
vim.opt.timeoutlen = 400     -- shorten mapped key timeout for a snappier feel
vim.opt.termguicolors = false  -- rely on terminal palette so colors follow the terminal

-- 1) Bootstrap lazy.nvim -------------------------------------------------------------
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  -- Install lazy.nvim on first run; this avoids manual bootstrap steps
  vim.fn.system({ 'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git', '--branch=stable', lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- 2) Plugins ------------------------------------------------------------------------
-- Keep the plugin list tiny: fuzzy finding, syntax trees, and dependencies.
require('lazy').setup({
  { 'nvim-telescope/telescope.nvim', dependencies = { 'nvim-lua/plenary.nvim' } },
  { 'nvim-treesitter/nvim-treesitter', build = ':TSUpdate' },
  {
    'hrsh7th/nvim-cmp',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'L3MON4D3/LuaSnip',
      'saadparwaiz1/cmp_luasnip',
    },
  },
})

-- 3) Telescope (fast fuzzy find; requires ripgrep installed) ------------------------
local ok_telescope, telescope = pcall(require, 'telescope')
if ok_telescope then
  -- Telescope gives fuzzy finding over files, text, buffers, etc.
  telescope.setup({
    defaults = {
      -- Move through lists with Ctrl+j / Ctrl+k in insert mode
      mappings = {
        i = { ['<C-j>'] = 'move_selection_next', ['<C-k>'] = 'move_selection_previous' },
      },
      layout_config = { prompt_position = 'top' },
      sorting_strategy = 'ascending',
    },
  })
  local tb = require('telescope.builtin')
  -- Leader shortcuts to the most common pickers
  vim.keymap.set('n', '<leader>ff', tb.find_files, { desc = 'Find files' })
  vim.keymap.set('n', '<leader>fg', tb.live_grep,  { desc = 'Grep (ripgrep)' })
  vim.keymap.set('n', '<leader>fb', tb.buffers,    { desc = 'Buffers' })
  vim.keymap.set('n', '<leader>fh', tb.help_tags,  { desc = 'Help tags' })
end

-- 4) Treesitter (fast syntax + indent) ----------------------------------------------
local ok_ts, ts = pcall(require, 'nvim-treesitter.configs')
if ok_ts then
  -- Install parsers for the languages used most often. Add or remove as needed.
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
    -- Prefix and spacing keep virtual text readable without clutter
    virtual_text = { spacing = 2, prefix = '●' },
    signs = true,
    update_in_insert = false,
    severity_sort = true,
  })

  -- on_attach: buffer-local LSP keymaps
  local on_attach = function(_, bufnr)
    local map = function(mode, lhs, rhs, desc)
      -- All LSP keymaps share silent and buffer-local options
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
    end
    -- Single-key goto commands keep navigation tight
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
  -- Merge completion capabilities so cmp can advertise itself to the servers.
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local ok_cmp_caps, cmp_nvim_lsp = pcall(require, 'cmp_nvim_lsp')
  if ok_cmp_caps then
    capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
  end
  -- Iterate through the list and set up each server only if available.
  local servers = { 'lua_ls', 'gopls', 'pyright', 'tsserver', 'rust_analyzer' }
  for _, s in ipairs(servers) do
    if lspconfig[s] then
      lspconfig[s].setup({
        on_attach = on_attach,
        flags = { debounce_text_changes = 100 },
        capabilities = capabilities,
      })
    end
  end
end

-- 6) Completion (nvim-cmp + LuaSnip) -------------------------------------------------
local ok_cmp, cmp = pcall(require, 'cmp')
if ok_cmp then
  local ok_luasnip, luasnip = pcall(require, 'luasnip')
  cmp.setup({
    snippet = {
      expand = function(args)
        if ok_luasnip then
          luasnip.lsp_expand(args.body)
        elseif vim.snippet then
          vim.snippet.expand(args.body)
        end
      end,
    },
    mapping = cmp.mapping.preset.insert({
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<CR>'] = cmp.mapping.confirm({ select = true }),
      ['<Tab>'] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_next_item()
        elseif ok_luasnip and luasnip.expand_or_jumpable() then
          luasnip.expand_or_jump()
        else
          fallback()
        end
      end, { 'i', 's' }),
      ['<S-Tab>'] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_prev_item()
        elseif ok_luasnip and luasnip.jumpable(-1) then
          luasnip.jump(-1)
        else
          fallback()
        end
      end, { 'i', 's' }),
    }),
    sources = cmp.config.sources({
      { name = 'nvim_lsp' },
      { name = 'path' },
    }, {
      { name = 'buffer' },
    }),
  })
end

-- 7) A few quality-of-life mappings --------------------------------------------------
-- Quickly inspect diagnostics without leaving normal mode.
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Line diagnostics' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Diagnostics to LocList' })

-- 8) Colors inherit from the terminal palette --------------------------------------
-- No explicit colorscheme so Neovim mirrors whichever terminal theme is active.
-- That’s it: ~120 lines, fast startup, great nav, syntax, and LSP without heavy deps.

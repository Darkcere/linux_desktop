" =========================
" TTY / Foot terminal mode
" =========================
set notermguicolors
" =========================
" Leader
" =========================
let mapleader = " "

" =========================
" Basics
" =========================
set number
set autoindent
set hlsearch
set clipboard=unnamedplus
set expandtab
set shiftwidth=2
set tabstop=2

" =========================
" Delete without yanking
" =========================
nnoremap d "_d
nnoremap x "_x
vnoremap d "_d
nnoremap <leader>d d
vnoremap <leader>d d

" =========================
" Plugins (vim-plug)
" =========================
call plug#begin()

" LSP + Autocomplete
Plug 'neovim/nvim-lspconfig'
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-buffer'

" Snippets
Plug 'L3MON4D3/LuaSnip'

" Auto pairs
Plug 'windwp/nvim-autopairs'

"Menu
Plug 'folke/noice.nvim'
Plug 'MunifTanjim/nui.nvim'
Plug 'rcarriga/nvim-notify'
call plug#end()

" =========================
" Autocomplete setup
" =========================
lua << EOF
local cmp = require'cmp'

cmp.setup({
  mapping = {
    ['<Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      else
        fallback()
      end
    end, { "i", "s" }),

    ['<S-Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      else
        fallback()
      end
    end, { "i", "s" }),

    ['<CR>'] = cmp.mapping.confirm({ select = true }),
  },

  sources = {
    { name = 'nvim_lsp' },
    { name = 'path' },
    { name = 'buffer' },
  }
})
EOF

" =========================
" LSP setup
" =========================
lua << EOF
-- Enable LSP servers using new API

vim.lsp.enable('pyright')
vim.lsp.enable('tsserver')
vim.lsp.enable('lua_ls')

-- Lua settings (for nvim config)
vim.lsp.config('lua_ls', {
  settings = {
    Lua = {
      diagnostics = {
        globals = { 'vim' }
      }
    }
  }
})
EOF
" =========================
" Auto pairs
" =========================
lua << EOF
require('nvim-autopairs').setup{}
EOF

" =========================
" Better UI behavior
" =========================
set completeopt=menu,menuone,noselect

" =========================
" Menu box for commands
" =========================
lua << EOF
require("noice").setup({
  cmdline = {
    view = "cmdline_popup", -- for :
  },

  views = {
    cmdline_popup = {
      position = {
        row = "30%",
        col = "50%",
      },
      size = {
        width = 60,
        height = "auto",
      },
      border = {
        style = "rounded",
      },
    },
  },

  cmdline_format = {
    cmdline = { pattern = "^:", icon = "", lang = "vim" },
    search_down = {
      kind = "search",
      pattern = "^/",
      icon = " ",
      lang = "regex",
    },
    search_up = {
      kind = "search",
      pattern = "^%?",
      icon = " ",
      lang = "regex",
    },
  },
})
EOF

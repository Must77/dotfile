set nocompatible

" Turn on syntax highlighting.
syntax on

" Disable the default Vim startup message.
set shortmess+=I

" Show lines
set number
set relativenumber

" Always show the status line at the bottom, even if you only have one window open.
set laststatus=2

" The backspace key has slightly unintuitive behavior by default. For example,
" by default, you can't backspace before the insertion point set with 'i'.
" This configuration makes backspace behave more reasonably, in that you can
" backspace over anything.
set backspace=indent,eol,start

" By default, Vim doesn't let you hide a buffer (i.e. have a buffer that isn't
" shown in any window) that has unsaved changes. This is to prevent you from "
" forgetting about unsaved changes and then quitting e.g. via `:qa!`. We find
" hidden buffers helpful enough to disable this protection. See `:help hidden`
" for more information on this.
set hidden

" case-insensitive
set ignorecase
set smartcase

" keyboard
nmap Q <Nop> " 'Q' in normal mode enters Ex mode. You almost never want this.
inoremap jk <ESC>  " jk --> <ESC>

" annoyed bell
set noerrorbells visualbell t_vb=

" mouse
set mouse+=a

" reconfirm
set confirm


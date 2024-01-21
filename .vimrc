" Vim-Only
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

" Anytime backspace
set backspace=indent,eol,start

" hide buffer
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


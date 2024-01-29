set nocompatible

" Pay attention!
" Ctrl+V: Block Visual Mode

" Turn on syntax highlighting.
syntax on

" Disable the default Vim startup message.
set shortmess+=I

" Show lines
set number
set relativenumber

" Always show the status line at the bottom
set laststatus=2

" Anytime backspace
set backspace=indent,eol,start

" hide buffer
set hidden

" case-insensitive
set ignorecase
set smartcase

" keyboard
" 'Q' in normal mode enters Ex mode
nmap Q <Nop>
" jk --> <ESC>
inoremap jk <ESC>  

" annoyed bell
set noerrorbells visualbell t_vb=

" mouse
set mouse+=a

" reconfirm
set confirm


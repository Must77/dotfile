set nocompatible

" Pay attention!
" Ctrl+V: Block Visual Mode

" Turn on syntax highlighting.
syntax on

" language aware indent
filetype plugin indent on

" Show lines
set number
set relativenumber

" Always show the status line at the bottom
set laststatus=2

" Anytime backspace
set backspace=indent,eol,start

" hide buffer
set hidden

" tabs display at 8 columns, you type four spaces
set tabstop=8
set shiftwidth=4
set expandtab

" inherit tab
set autoindent

" keep the file's own indent style
set copyindent preserveindent

" case-insensitive
set ignorecase
set smartcase

" keyboard
" 'Q' in normal mode enters Ex mode
nmap Q <Nop>
" jk --> <ESC>
inoremap jk <ESC>

" no bell
set belloff=all

" mouse
set mouse+=a

" reconfirm
set confirm

" restore cursor position when reopening a file
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

" show matching brackets
set showmatch

" indent settings
set softtabstop=4
set shiftround

" highlight search results
set hlsearch

" don't wrap searches around end of file
set nowrapscan

" show partial command in status line
set showcmd

" incremental search
set incsearch

" report all changes
set report=0

" F2 to toggle paste mode
set pastetoggle=<F2>

" keep lines above/below cursor when scrolling
set scrolloff=8

" already defaults in modern vim, kept for reference
set shortmess+=I
set showmode
set ttyfast

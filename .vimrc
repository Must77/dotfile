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

" display tab as four space width
set tabstop=4
set shiftwidth=4
set expandtab 

" inherit tab
set autoindent 

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

" restore cursor position when reopening a file
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

" show matching brackets
set showmatch

" indent settings
set softtabstop=4
set shiftround

" show current mode
set showmode

" highlight search results
set hlsearch

" don't wrap searches around end of file
set nowrapscan

" ensure temp directories exist before enabling backup/undo
silent! call mkdir(expand('~/.vim/files/backup'), 'p')
silent! call mkdir(expand('~/.vim/files/swap'), 'p')
silent! call mkdir(expand('~/.vim/files/undo'), 'p')
silent! call mkdir(expand('~/.vim/files/info'), 'p')

" centralize temp files
set backup
set backupdir   =~/.vim/files/backup//
set backupext   =-vimbackup
set backupskip  =
set directory   =~/.vim/files/swap//
set updatecount =100
set undofile
set undodir     =~/.vim/files/undo//
set viminfo     ='100,n~/.vim/files/info/viminfo

" show partial command in status line
set showcmd

" incremental search
set incsearch

" fast terminal
set ttyfast

" report all changes
set report=0

" F2 to toggle paste mode
set pastetoggle=<F2>

" keep lines above/below cursor when scrolling
set scrolloff=8


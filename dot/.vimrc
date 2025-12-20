set backupdir=~/.vimtmp/backup//
set directory=~/.vimtmp/swap//
set undodir=~/.vimtmp/undo//

" Set cursor shapes for different modes
set guicursor=n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50

set ignorecase
set ruler
set list
filetype on
set mouse=a

"set foldmethod=indent
set nocompatible
syntax on
set modelines=0
set number
set encoding=utf-8
set wrap

set tabstop=2
set shiftwidth=2
set softtabstop=2
set autoindent
set copyindent
set expandtab
set noshiftround

set hlsearch
set incsearch
set showmatch
set smartcase

set hidden
set ttyfast
set laststatus=2

set showcmd
set background=dark

" Copy to system clipboard
vnoremap <leader>y "+y
nnoremap <leader>Y "+yg_

" Paste from system clipboard
nnoremap <leader>p "+p
nnoremap <leader>P "+P

set clipboard=unnamedplus
set t_Co=256

" autosave
:au FocusLost * silent! wa
set updatetime=15000  " 15 second
:au CursorHold * silent! update

" Autosave when switching buffers or when focus is lost
:set autowrite
:set autowriteall


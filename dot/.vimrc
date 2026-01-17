" Must be first: disables vi compatibility and enables Vim features
set nocompatible

" Create central directories if they don't exist (run once or keep in vimrc)
silent !mkdir -p ~/.vimtmp/backup ~/.vimtmp/swap ~/.vimtmp/undo > /dev/null 2>&1

" Centralize backup, swap, and undo files
set backupdir=~/.vimtmp/backup//
set directory=~/.vimtmp/swap//
set undodir=~/.vimtmp/undo//
set undofile                " Enable persistent undo

" Basic UI and editing
syntax on
filetype plugin indent on   " Better than just 'on'
set number
set ruler
set showcmd
set wildmenu                " Better command-line completion
set encoding=utf-8
set background=dark
set t_Co=256                " 256-color support
set mouse=a                 " Mouse support in all modes
set hidden                  " Allow hidden buffers with unsaved changes
set ttyfast                 " Faster terminal redraw
set laststatus=2            " Always show status line
set backspace=indent,eol,start  " Modern backspace behavior

" Search
set ignorecase smartcase
set incsearch
set hlsearch
set showmatch

" Indentation (2-space soft tabs)
set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab
set autoindent
set copyindent

" Display
set wrap
set list                    " Show invisible chars
set listchars=tab:>\ ,trail:~,extends:>,precedes:<  " Common visible chars

" Clipboard: Use system clipboard for all yank/delete/change by default
set clipboard=unnamedplus   " On Linux (requires +clipboard build); works like * and + registers

" Simplified autosave: Save on focus loss and after 4s idle (common modern value)
set updatetime=4000
autocmd FocusLost,CursorHold,CursorHoldI * silent! update   " Save current buffer if modified

" Optional: Clear search highlight with <C-l>
nnoremap <silent> <C-l> :nohlsearch<CR><C-l>

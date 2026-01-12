" Vim ftplugin file
" Language: VIBEE DSL

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

" Indentation
setlocal tabstop=2
setlocal shiftwidth=2
setlocal softtabstop=2
setlocal expandtab
setlocal autoindent
setlocal smartindent

" Comments
setlocal commentstring=#\ %s
setlocal comments=:#

" Folding
setlocal foldmethod=indent
setlocal foldlevel=99

" Match pairs
setlocal matchpairs+=<:>

" Keywords for completion
setlocal iskeyword+=@-@

" Undo settings when switching filetypes
let b:undo_ftplugin = "setlocal tabstop< shiftwidth< softtabstop< expandtab< autoindent< smartindent< commentstring< comments< foldmethod< foldlevel< matchpairs< iskeyword<"

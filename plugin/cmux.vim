" cmux.vim: Send file references from Vim to AI CLI (Claude Code / Gemini CLI) via cmux
" Maintainer: tanabee
" License: MIT

if exists('g:loaded_cmux')
  finish
endif
let g:loaded_cmux = 1

" Command definitions
command! CmuxSendFile call cmux#send_file()
command! CmuxSendPos call cmux#send_pos()
command! -range CmuxSendRange call cmux#send_range(<line1>, <line2>)
command! CmuxSetSurface call cmux#set_surface()
command! CmuxDetect call cmux#detect()

" <Plug> mappings (allows user remapping)
nnoremap <Plug>(cmux-send-file) :CmuxSendFile<CR>
nnoremap <Plug>(cmux-send-pos) :CmuxSendPos<CR>
vnoremap <Plug>(cmux-send-range) :<C-u>'<,'>CmuxSendRange<CR>

" Default key mappings (only set if not already mapped by user)
if !hasmapto('<Plug>(cmux-send-file)')
  nmap <C-\> <Plug>(cmux-send-file)
endif
if !hasmapto('<Plug>(cmux-send-range)')
  vmap <C-\> <Plug>(cmux-send-range)
endif

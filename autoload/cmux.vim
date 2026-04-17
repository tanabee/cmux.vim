" cmux.vim: autoload functions
" Send file references from Vim to AI CLI (Claude Code / Gemini CLI) via cmux API

" Send file path as a reference chip
function! cmux#send_file()
  let l:path = cmux#_get_relative_path()
  call cmux#_send_ref(l:path, '')
endfunction

" Send file path with cursor line number
function! cmux#send_pos()
  let l:path = cmux#_get_relative_path()
  let l:line = line('.')
  call cmux#_send_ref(l:path, ':L' . l:line)
endfunction

" Send file path with line range
function! cmux#send_range(line1, line2)
  let l:path = cmux#_get_relative_path()
  if a:line1 == a:line2
    call cmux#_send_ref(l:path, ':L' . a:line1)
  else
    call cmux#_send_ref(l:path, ':L' . a:line1 . '-' . a:line2)
  endif
endfunction

" Auto-detect the surface running AI CLI (Claude Code / Gemini CLI)
function! cmux#detect()
  let l:my_surface = $CMUX_SURFACE_ID

  " Get all surface refs via the tree command
  let l:tree_output = system('cmux tree')
  if v:shell_error != 0
    echohl ErrorMsg
    echom 'cmux.vim: Failed to run cmux tree. Make sure you are running inside cmux.'
    echohl None
    return
  endif

  " Extract surface:N patterns from tree output
  let l:surface_refs = []
  for l:line in split(l:tree_output, '\n')
    let l:matches = matchlist(l:line, '\(surface:[0-9]\+\)')
    if !empty(l:matches)
      call add(l:surface_refs, l:matches[1])
    endif
  endfor

  for l:sid in l:surface_refs
    " Skip own surface
    if l:sid ==# l:my_surface
      continue
    endif

    " Read the latest 30 lines from the screen
    let l:screen = system('cmux read-screen --surface ' . l:sid . ' --lines 30')
    if v:shell_error != 0
      continue
    endif

    " Detect Claude Code specific patterns
    if l:screen =~# '\vclaude|Claude Code|anthropic|opus|sonnet|haiku|\/help|╭|╰'
      let g:cmux_surface = l:sid
      let g:cmux_cli_name = 'Claude Code'
      echo 'cmux.vim: Detected Claude Code -> ' . l:sid
      return
    endif

    " Detect Gemini CLI specific patterns
    if l:screen =~# '\vgemini|Gemini|google|✦'
      let g:cmux_surface = l:sid
      let g:cmux_cli_name = 'Gemini CLI'
      echo 'cmux.vim: Detected Gemini CLI -> ' . l:sid
      return
    endif
  endfor

  echohl WarningMsg
  echom 'cmux.vim: No AI CLI found. Please set manually with :CmuxSetSurface.'
  echohl None
endfunction

" Manually set the target surface ID
function! cmux#set_surface()
  let l:surface = input('Enter target surface ID (e.g. surface:1): ')
  if l:surface !=# ''
    let g:cmux_surface = l:surface
    echom 'cmux.vim: Surface set to ' . l:surface
  endif
endfunction

" Get relative path from git root
function! cmux#_get_relative_path()
  let l:abs_path = expand('%:p')
  let l:git_root = trim(system('git rev-parse --show-toplevel 2>/dev/null'))
  if v:shell_error == 0 && l:git_root !=# ''
    return substitute(l:abs_path, '^' . escape(l:git_root . '/', '/.'), '', '')
  endif
  return l:abs_path
endfunction

" Send file reference via cmux CLI (chip format + optional line info)
function! cmux#_send_ref(path, line_info)
  let l:surface = get(g:, 'cmux_surface', '')
  if l:surface ==# ''
    " If not set, try auto-detection
    call cmux#detect()
    let l:surface = get(g:, 'cmux_surface', '')
    if l:surface ==# ''
      return
    endif
  endif

  " Clear the input field before sending (overwrite previous reference)
  call system('cmux send-key --surface ' . l:surface . ' ctrl+u')

  " Send @filepath + line info together
  let l:text = '@' . a:path . a:line_info . ' '
  let l:escaped = shellescape(l:text)
  call system('cmux send --surface ' . l:surface . ' ' . l:escaped)

  if v:shell_error != 0
    echohl ErrorMsg
    echom 'cmux.vim: Failed to send. Please check the surface ID.'
    echohl None
    return
  endif

  " Also send Enter key if auto_enter is enabled
  if get(g:, 'cmux_auto_enter', 0)
    call system('cmux send-key --surface ' . l:surface . ' enter')
  endif

  redraw
  echo 'cmux.vim: Sent -> @' . a:path . a:line_info
endfunction

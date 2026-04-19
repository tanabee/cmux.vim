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
  " Get own surface ref via cmux identify (env var is UUID, tree uses refs)
  let l:my_surface = cmux#_get_my_surface_ref()

  " Get all surface refs via the tree command
  let l:tree_output = system('cmux tree')
  if v:shell_error != 0
    echohl ErrorMsg
    echom 'cmux.vim: Failed to run cmux tree. Make sure you are running inside cmux.'
    echohl None
    return
  endif

  let l:surface_refs = map(cmux#_parse_tree(l:tree_output), 'v:val[1]')

  for l:sid in l:surface_refs
    " Skip own surface
    if l:sid ==# l:my_surface
      continue
    endif

    " Read the latest 30 lines from the screen
    let l:screen = system('cmux read-screen --surface ' . shellescape(l:sid) . ' --lines 30')
    if v:shell_error != 0
      continue
    endif

    " Detect Claude Code specific patterns
    if l:screen =~# '\vclaude|Claude Code|anthropic|\/help|╭|╰'
      let g:cmux_surface = l:sid
      let g:cmux_cli_name = 'Claude Code'
      echo 'cmux.vim: Detected Claude Code -> ' . l:sid
      return
    endif

    " Detect Gemini CLI specific patterns
    if l:screen =~# '\vgemini|Gemini|✦'
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
    return substitute(l:abs_path, '\V' . escape(l:git_root . '/', '\'), '', '')
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
  call system('cmux send-key --surface ' . shellescape(l:surface) . ' ctrl+u')

  " Send @filepath + line info together
  let l:text = '@' . a:path . a:line_info . ' '
  let l:escaped = shellescape(l:text)
  call system('cmux send --surface ' . shellescape(l:surface) . ' ' . l:escaped)

  if v:shell_error != 0
    echohl ErrorMsg
    echom 'cmux.vim: Failed to send. Please check the surface ID.'
    echohl None
    return
  endif

  " Also send Enter key if auto_enter is enabled
  if get(g:, 'cmux_auto_enter', 0)
    call system('cmux send-key --surface ' . shellescape(l:surface) . ' enter')
  endif

  " Focus the target surface pane if auto_focus is enabled
  if get(g:, 'cmux_auto_focus', 1)
    call cmux#_focus_surface(l:surface)
  endif

  redraw
  echo 'cmux.vim: Sent -> @' . a:path . a:line_info
endfunction

" Focus the pane containing the given surface
function! cmux#_focus_surface(surface)
  let l:tree_output = system('cmux tree')
  if v:shell_error != 0
    return
  endif

  for [l:pane, l:sid] in cmux#_parse_tree(l:tree_output)
    if l:sid ==# a:surface
      call system('cmux focus-pane --pane ' . shellescape(l:pane))
      return
    endif
  endfor
endfunction

" Get own surface ref (e.g. surface:1) from cmux identify
function! cmux#_get_my_surface_ref()
  let l:output = system('cmux identify')
  if v:shell_error == 0
    let l:ref = matchstr(l:output, 'surface:[0-9]\+')
    if l:ref !=# ''
      return l:ref
    endif
  endif
  return $CMUX_SURFACE_ID
endfunction

" Parse `cmux tree` output into a list of [pane, surface] pairs
function! cmux#_parse_tree(output)
  let l:entries = []
  let l:current_pane = ''
  for l:line in split(a:output, '\n')
    let l:pane = matchstr(l:line, 'pane:[0-9]\+')
    if l:pane !=# ''
      let l:current_pane = l:pane
    endif
    let l:surface = matchstr(l:line, 'surface:[0-9]\+')
    if l:surface !=# '' && l:current_pane !=# ''
      call add(l:entries, [l:current_pane, l:surface])
    endif
  endfor
  return l:entries
endfunction

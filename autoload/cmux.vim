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
" within the caller's workspace, by inspecting the processes attached to
" each surface's tty.
function! cmux#detect()
  let l:me = cmux#_get_my_identity()
  let l:my_surface_id = l:me.surface_id
  let l:my_workspace = l:me.workspace_ref

  let l:terminals = cmux#_list_terminals()
  if empty(l:terminals)
    echohl ErrorMsg
    echom 'cmux.vim: Failed to read cmux tree. Make sure you are running inside cmux.'
    echohl None
    return
  endif

  for l:t in l:terminals
    if l:my_workspace !=# '' && l:t.workspace_ref !=# l:my_workspace
      continue
    endif
    if l:t.surface_id !=# '' && l:t.surface_id ==# l:my_surface_id
      continue
    endif
    if l:t.tty ==# ''
      continue
    endif

    let l:procs = system('ps -t ' . shellescape(l:t.tty) . ' -o command=')
    if v:shell_error != 0
      continue
    endif

    if l:procs =~# '\v[/ ]claude(-code)?(\s|$)'
      let g:cmux_surface = l:t.surface_id
      let g:cmux_workspace = l:t.workspace_ref
      let g:cmux_cli_name = 'Claude Code'
      echo 'cmux.vim: Detected Claude Code -> ' . l:t.surface_ref
      return
    endif

    if l:procs =~# '\v[/ ]gemini(\s|$)'
      let g:cmux_surface = l:t.surface_id
      let g:cmux_workspace = l:t.workspace_ref
      let g:cmux_cli_name = 'Gemini CLI'
      echo 'cmux.vim: Detected Gemini CLI -> ' . l:t.surface_ref
      return
    endif
  endfor

  echohl WarningMsg
  echom 'cmux.vim: No AI CLI found. Please set manually with :CmuxSetSurface.'
  echohl None
endfunction

" Manually set the target surface. Accepts a UUID or a ref (surface:N).
" Looks up the matching workspace so cross-workspace targeting works.
function! cmux#set_surface()
  let l:input = input('Enter target surface (UUID or surface:N): ')
  if l:input ==# ''
    return
  endif

  for l:t in cmux#_list_terminals()
    if l:t.surface_id ==# l:input || l:t.surface_ref ==# l:input
      let g:cmux_surface = l:t.surface_id
      let g:cmux_workspace = l:t.workspace_ref
      echom 'cmux.vim: Surface set to ' . l:t.surface_ref
            \ . ' (' . l:t.workspace_ref . ')'
      return
    endif
  endfor

  echohl ErrorMsg
  echom 'cmux.vim: Surface not found: ' . l:input
  echohl None
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
    call cmux#detect()
    let l:surface = get(g:, 'cmux_surface', '')
    if l:surface ==# ''
      return
    endif
  endif

  let l:target = cmux#_target_flags(l:surface)

  " Clear the input field before sending (overwrite previous reference)
  call system('cmux send-key ' . l:target . ' ctrl+u')

  " Send @filepath + line info together
  let l:text = '@' . a:path . a:line_info . ' '
  let l:escaped = shellescape(l:text)
  call system('cmux send ' . l:target . ' ' . l:escaped)

  if v:shell_error != 0
    echohl ErrorMsg
    echom 'cmux.vim: Failed to send. Please check the surface ID.'
    echohl None
    return
  endif

  " Also send Enter key if auto_enter is enabled
  if get(g:, 'cmux_auto_enter', 0)
    call system('cmux send-key ' . l:target . ' enter')
  endif

  " Focus the target surface pane if auto_focus is enabled
  if get(g:, 'cmux_auto_focus', 1)
    call cmux#_focus_surface(l:surface)
  endif

  redraw!
  echo 'cmux.vim: Sent -> @' . a:path . a:line_info
endfunction

" Build `--workspace <ref> --surface <id>` flags. Falls back to surface-only
" when the workspace is not known (e.g. user set g:cmux_surface manually).
function! cmux#_target_flags(surface)
  let l:workspace = get(g:, 'cmux_workspace', '')
  if l:workspace ==# ''
    for l:t in cmux#_list_terminals()
      if l:t.surface_id ==# a:surface || l:t.surface_ref ==# a:surface
        let l:workspace = l:t.workspace_ref
        break
      endif
    endfor
  endif

  let l:flags = '--surface ' . shellescape(a:surface)
  if l:workspace !=# ''
    let l:flags = '--workspace ' . shellescape(l:workspace) . ' ' . l:flags
  endif
  return l:flags
endfunction

" Focus the pane containing the given surface (UUID or ref)
function! cmux#_focus_surface(surface)
  for l:t in cmux#_list_terminals()
    if l:t.surface_id ==# a:surface || l:t.surface_ref ==# a:surface
      let l:flags = '--pane ' . shellescape(l:t.pane_id)
      if l:t.workspace_ref !=# ''
        let l:flags = '--workspace ' . shellescape(l:t.workspace_ref) . ' ' . l:flags
      endif
      call system('cmux focus-pane ' . l:flags)
      return
    endif
  endfor
endfunction

" Get own identity from cmux identify. Returns a dict with surface_id and
" workspace_ref; falls back to env vars when the JSON is not parseable.
function! cmux#_get_my_identity()
  let l:result = {'surface_id': $CMUX_SURFACE_ID, 'workspace_ref': ''}
  let l:output = system('cmux --id-format both identify')
  if v:shell_error == 0
    try
      let l:json = json_decode(l:output)
      if type(l:json) == type({}) && has_key(l:json, 'caller')
            \ && type(l:json.caller) == type({})
        let l:result.surface_id = get(l:json.caller, 'surface_id', l:result.surface_id)
        let l:result.workspace_ref = get(l:json.caller, 'workspace_ref', '')
      endif
    catch
    endtry
  endif
  return l:result
endfunction

" List all terminal surfaces from `cmux tree`. Returns a list of dicts with
" keys: surface_id, surface_ref, pane_id, pane_ref, workspace_ref, tty.
function! cmux#_list_terminals()
  let l:out = []
  let l:raw = system('cmux --id-format both tree --json')
  if v:shell_error != 0
    return l:out
  endif

  try
    let l:tree = json_decode(l:raw)
  catch
    return l:out
  endtry

  if type(l:tree) != type({}) || !has_key(l:tree, 'windows')
    return l:out
  endif

  for l:window in l:tree.windows
    for l:workspace in get(l:window, 'workspaces', [])
      let l:ws_ref = get(l:workspace, 'ref', '')
      for l:pane in get(l:workspace, 'panes', [])
        let l:pane_id = get(l:pane, 'id', '')
        let l:pane_ref = get(l:pane, 'ref', '')
        for l:surface in get(l:pane, 'surfaces', [])
          if get(l:surface, 'type', '') !=# 'terminal'
            continue
          endif
          call add(l:out, {
                \ 'surface_id':    get(l:surface, 'id', ''),
                \ 'surface_ref':   get(l:surface, 'ref', ''),
                \ 'pane_id':       l:pane_id,
                \ 'pane_ref':      l:pane_ref,
                \ 'workspace_ref': l:ws_ref,
                \ 'tty':           get(l:surface, 'tty', ''),
                \ })
        endfor
      endfor
    endfor
  endfor
  return l:out
endfunction

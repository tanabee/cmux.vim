# cmux.vim

A Vim plugin for sending file references from Vim to AI CLI (Claude Code / Gemini CLI) on [cmux](https://github.com/manaflow-ai/cmux).

## Features

- Send current file path to AI CLI as an `@mention` reference
- Send with cursor line number
- Send visually selected line range
- Auto-detect Claude Code / Gemini CLI surface

## Installation

### vim-plug

```vim
Plug 'tanabee/cmux.vim'
```

### Manual

```bash
git clone https://github.com/tanabee/cmux.vim.git ~/.vim/pack/plugins/start/cmux.vim
```

## Update

### vim-plug

```vim
:PlugUpdate cmux.vim
```

### Manual

```bash
git -C ~/.vim/pack/plugins/start/cmux.vim pull
```

## Usage

Open two tabs in cmux — one for Vim and the other for AI CLI (Claude Code or Gemini CLI).

### Key Mappings

| Key | Mode | Action | Example |
|-----|------|--------|---------|
| `<C-s>` | Normal | Send file reference | `@src/main.ts ` |
| `<C-s>` | Visual | Send file + line range | `@src/main.ts:L42-55 ` |

The default mapping is `<C-s>`, but it can be customized via `<Plug>` mappings (see below).
The AI CLI surface is auto-detected on the first invocation.

### Commands

| Command | Description |
|---------|-------------|
| `:CmuxSendFile` | Send file path |
| `:CmuxSendPos` | Send file path + line number |
| `:'<,'>CmuxSendRange` | Send file path + line range |
| `:CmuxDetect` | Re-detect AI CLI surface |
| `:CmuxSetSurface` | Manually set surface ID |

## Configuration

```vim
" Manually specify target surface (usually not needed due to auto-detection)
let g:cmux_surface = 'surface:2'

" Automatically focus the target surface pane after sending (default: 1)
let g:cmux_auto_focus = 0

" Automatically press Enter after sending (default: 0)
let g:cmux_auto_enter = 1
```

## Customizing Key Mappings

If you define `<Plug>` mappings in your `.vimrc`, the default `<C-s>` bindings are automatically disabled.

```vim
nmap <C-\> <Plug>(cmux-send-file)
nmap <C-g> <Plug>(cmux-send-pos)
vmap <C-\> <Plug>(cmux-send-range)
```

## Prerequisites

- [cmux](https://github.com/manaflow-ai/cmux) must be installed
- Vim and AI CLI (Claude Code or Gemini CLI) must be running on cmux

## License

MIT

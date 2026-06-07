# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A tmux plugin (TPM-compatible) that lets users switch to any session, window, or pane across all sessions using fzf as a fuzzy finder. Two files do all the work:

- `select_pane.tmux` — sourced by tmux at startup; reads user config options via `tmux show-option`, then registers a key binding that calls `select_pane.sh` with the resolved options as arguments.
- `select_pane.sh` — invoked by tmux when the key binding fires; builds a combined list of sessions, windows, and panes, runs fzf, then switches to the selected target via `tmux switch-client`.

## How the two scripts connect

`select_pane.tmux` passes ten shell-quoted positional arguments to `select_pane.sh`:

1. `preview_pane` (`true`/`false`)
2. `fzf_window_position` (passed to `fzf --tmux`)
3. `fzf_preview_window_position` (passed to `fzf --preview-window`)
4. `session_icon` (Nerd Font icon for session entries)
5. `window_icon` (Nerd Font icon for window entries)
6. `pane_icon` (Nerd Font icon for pane entries)
7. `indent` (prepended once for windows, twice for panes)
8. `separator` (shown between session/window/pane names)
9. `highlight_color` (RGB triplet for the current item)
10. `activity_color` (RGB triplet for unread activity indicators)

`select_pane.sh` combines output from `tmux list-sessions`, `tmux list-windows -a`, and `tmux list-panes -a` into a single fzf list. Each line's first field (hidden via `--with-nth=2..`) is the tmux target passed to `tmux switch-client -t`: a session ID (`$0`), window ID (`@1`), or pane ID (`%4`).

## Testing

There is no automated test suite. Test manually inside a live tmux session:

```bash
# Reload the plugin after changes
tmux source-file ~/.tmux.conf

# Or invoke select_pane.sh directly for quick iteration
bash select_pane.sh true center,70%,80% right,,,nowrap '󰐱' '󰖲' '󰆍' '▪  ' '/' '166;227;161' '249;226;175'

# Without Nerd Fonts
bash select_pane.sh true center,70%,80% right,,,nowrap 'S' 'W' 'P' '  ' '/' '166;227;161' '249;226;175'
```

## Version-gated fzf features

`select_pane.sh` uses `vercomp` to detect fzf version at runtime and enables richer border/label styling (≥0.58.0) and ghost text (≥0.61.0) only when available. Keep this pattern when adding features that depend on a minimum fzf version.

## Configurable tmux options

All user-facing options use the prefix `@fzf_pane_switch_` and are read with `get_tmux_option` in `select_pane.tmux`. The defaults are defined as `default_*` variables at the top of that file.

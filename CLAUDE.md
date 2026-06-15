# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A tmux plugin (TPM-compatible) that lets users switch to any session, window, or pane across all sessions using fzf as a fuzzy finder. Two scripts do the work, backed by a shared defaults file:

- `select_pane.tmux` — run by tmux with `run-shell`; reads user config options via `tmux show-option`, then registers a key binding that calls `select_pane.sh` with the resolved options as arguments. This file is Bash, not tmux config, so do not load it with `tmux source-file`.
- `select_pane.sh` — invoked by tmux when the key binding fires; builds a combined list of sessions, windows, and panes, runs fzf, then switches to the selected target via `tmux switch-client`.
- `defaults.sh` — single source of truth for the `default_*` option values, sourced by both scripts. Edit defaults here, not in the consuming scripts.

`get_tmux_option` distinguishes a set-but-empty option from an unset one (via `tmux show-option -gq`), so an option explicitly set to `""` overrides the default instead of falling back to it.

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

If the optional `tmux-attention` plugin is installed, `select_pane.sh` also reads each window's `@agent_attention` option from tmux formats and shows the matching status icon on window and pane rows. Supported states are `input`, `blocked`, `review`, and `done`. Icons come from `@tmux_attention_icon_input`, `@tmux_attention_icon_blocked`, `@tmux_attention_icon_review`, and `@tmux_attention_icon_done`, with local fallbacks matching tmux-attention defaults.

## Testing

Run the smoke test before changing behavior:

```bash
tests/check.sh
```

The check script runs ShellCheck, Bash syntax validation, the `--version` check, fixture assertions, and an isolated tmux server check that verifies `prefix + j` is bound through `run-shell` (including that an option set to `""` overrides its default). The same checks run in CI (`.github/workflows/ci.yml`) on every push and pull request.

For manual testing inside a live tmux session:

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

All user-facing options use the prefix `@fzf_pane_switch_` and are read with `get_tmux_option` in `select_pane.tmux`. The defaults are the `default_*` variables in `defaults.sh`.

## Versioning and releases

SemVer, tracked in `CHANGELOG.md`; the current version lives in `VERSION` and is printable via `select_pane.sh --version`. Cut a release with `scripts/release.sh <x.y.z>` (bumps `VERSION`, promotes the changelog `[Unreleased]` section, runs the checks, commits, and tags). Pushing a `v*` tag triggers `.github/workflows/release.yml`, which re-runs the checks, verifies the tag matches `VERSION`, and publishes a GitHub release from that version's changelog section.

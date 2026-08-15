# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A tmux plugin (TPM-compatible) that lets users switch to any session, window, or pane across all sessions using fzf as a fuzzy finder. Two scripts do the work, backed by a shared defaults file:

- `select_pane.tmux` — run by tmux with `run-shell`; reads user config options via `tmux show-option`, then registers a key binding that calls `select_pane.sh` with the resolved options as arguments. This file is Bash, not tmux config, so do not load it with `tmux source-file`.
- `select_pane.sh` — invoked by tmux when the key binding fires; builds a combined list of sessions, windows, and panes, runs fzf, then switches to the selected target via `tmux switch-client`.
- `defaults.sh` — single source of truth for the `default_*` option values, sourced by both scripts. Edit defaults here, not in the consuming scripts. It also owns `resolve_fzj_options`, which reads the eleven `@fzf_pane_switch_*` options into `fzj_opt_*` (falling back to the defaults), and `fzj_option_args`, which emits them in positional order. Both entry points call these, so the key binding and a direct no-argument invocation always agree.

`get_tmux_option` distinguishes a set-but-empty option from an unset one (via `tmux show-option -gq`), so an option explicitly set to `""` overrides the default instead of falling back to it.

## How the two scripts connect

`select_pane.tmux` passes eleven shell-quoted positional arguments to `select_pane.sh`:

1. `preview_pane` (`true`/`false`)
2. `preview_min_width` (preview starts hidden below this `#{client_width}`)
3. `fzf_window_position` (passed to `fzf --tmux`)
4. `fzf_preview_window_position` (passed to `fzf --preview-window`)
5. `session_icon` (Nerd Font icon for session entries)
6. `window_icon` (Nerd Font icon for window entries)
7. `pane_icon` (Nerd Font icon for pane entries)
8. `indent` (prepended once for windows, twice for panes)
9. `separator` (shown between session/window/pane names)
10. `highlight_color` (RGB triplet for the current item)
11. `activity_color` (RGB triplet for unread activity indicators)

`select_pane.sh` combines output from `tmux list-sessions`, `tmux list-windows -a`, and `tmux list-panes -a` into a single fzf list. Each line's first field (hidden via `--with-nth=2..`) is the tmux target passed to `tmux switch-client -t`: a session ID (`$0`), window ID (`@1`), or pane ID (`%4`).

If the optional `tmux-attention` plugin is installed, `select_pane.sh` reads each window's derived `@agent_attention` and `@agent_context_active` summary options, plus each pane's authoritative `@agent_pane_attention` and `@agent_pane_context_active` options. The matching status icon replaces the normal icon on both window and pane rows. Supported attention states are `input`, `blocked`, `review`, and `done`; they take precedence over the working icon for an active agent turn. Icons come from `@tmux_attention_icon_input`, `@tmux_attention_icon_blocked`, `@tmux_attention_icon_review`, `@tmux_attention_icon_done`, and `@tmux_attention_icon_working`, with local fallbacks matching tmux-attention defaults. Pane labels retain the session name, then use `@pane_name` when explicitly set and otherwise fall back to `pane_current_command`. The pane rename action sets both `@pane_name` and native `pane_title`. When a marker also carries `@agent_pane_attention_reason`, the reason is appended dimmed after the pane label.

Sessions whose name matches the `@fzf_pane_switch_exclude-sessions` glob (empty by default) are hidden from the list.

## In-picker actions and reload

The picker binds `ctrl-x`/`ctrl-r`/`ctrl-n`/`ctrl-d` (kill/rename/new/detach) to `select_pane.sh --action <verb> <target>`, then refreshes the list with `reload(bash -c _fzj_list)`. That reload runs `_fzj_list` in a **fresh bash**: the function itself and every function it calls must be `export -f`'d (currently `_fzj_list` and `get_tmux_option` — forgetting one silently degrades the reloaded list), and everything else it needs arrives via exported `_FZJ_*` environment variables. Keep both in mind when extending `_fzj_list`.

`select_pane.sh` also has dev/test entry points: `--fixture` prints a static, fully-styled list for assertions, `--fixture-fzf` pipes it through fzf for a visual check, and `--test` runs the real picker with the resolved `@fzf_pane_switch_*` options (an alias of running with no arguments).

## Testing

Run the smoke test before changing behavior:

```bash
tests/check.sh
```

The check script runs ShellCheck, Bash syntax validation, the `--version` check, fixture assertions, and an isolated tmux server check that verifies `prefix + j` is bound through `run-shell` (including that an option set to `""` overrides its default). The same checks run in CI (`.github/workflows/ci.yml`) on every push and pull request.

Assertion gotcha: tmux >= 3.7 prints nothing for `list-keys -T prefix j` (the trailing key-filter form), so the check greps the full `list-keys -T prefix` table instead — write new binding assertions the same way. An ERR trap reports the failing line; without it `set -e` + `grep -q` fails with no output at all.

For manual testing inside a live tmux session:

```bash
# Reload the plugin after changes
tmux source-file ~/.tmux.conf

# Or invoke select_pane.sh directly for quick iteration
bash select_pane.sh true 100 center,70%,80% right,,,nowrap '󰐱' '󰖲' '󰆍' '▪  ' '/' '166;227;161' '249;226;175'

# Without Nerd Fonts
bash select_pane.sh true 100 center,70%,80% right,,,nowrap 'S' 'W' 'P' '  ' '/' '166;227;161' '249;226;175'
```

## Version-gated fzf features

`select_pane.sh` uses `vercomp` to detect fzf version at runtime and enables richer border/label styling (≥0.58.0) and ghost text (≥0.61.0) only when available. Keep this pattern when adding features that depend on a minimum fzf version.

## Configurable tmux options

All user-facing options use the prefix `@fzf_pane_switch_` and are read with `get_tmux_option` via `resolve_fzj_options` in `defaults.sh`. The defaults are the `default_*` variables in the same file. `@fzf_pane_switch_bind-key` is the exception: it selects which key runs the picker rather than how it renders, so it stays in `select_pane.tmux`.

## Pre-commit

`.pre-commit-config.yaml` runs ShellCheck over the scripts and then the
integration suite. Enable it once with `pre-commit install` (requires
[pre-commit](https://pre-commit.com) and `shellcheck` on PATH).

## Versioning and releases

SemVer, tracked in `CHANGELOG.md`; the current version lives in `VERSION` and is printable via `select_pane.sh --version`.

**Keep the changelog current:** every user-facing change adds a bullet to the `## [Unreleased]` section of `CHANGELOG.md` in the same commit that makes the change. `git release` promotes and dates that section but does **not** author the notes — write them as work lands.

Cut a release with the maintainer's `git release <x.y.z>` helper (bumps `VERSION`, promotes the changelog `[Unreleased]` section, runs the checks, commits, and tags) — or do those steps by hand. Pushing a `v*` tag triggers `.github/workflows/release.yml`, which re-runs the checks, verifies the tag matches `VERSION`, and publishes a GitHub release from that version's changelog section.

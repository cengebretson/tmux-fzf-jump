# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Window rows always use the native tmux window name instead of replacing it with inferred
  tmux-attention project context. Attention and active-turn state still control the row icon.

## [2.9.1] - 2026-08-20

### Documentation

- Document the Bash 4+ runtime requirement and the attention-only CLI view in
  the maintainer guidance.

## [2.9.0] - 2026-08-18

### Changed

- Window rows prefer the agent context label (`@agent_context_project` during a turn, else
  `@agent_context_idle_project`) over `window_name`, falling back to `window_name` when neither
  is set. Window names are usually a directory, so several worktrees of one repo looked
  identical in the picker.
- Pane rows prefer `@agent_pane_context_project` while that pane's agent is active, then the
  existing `@pane_name`, then the running command.

### Added

- Row-rendering assertions for the window label. The awk program is extracted from
  `select_pane.sh` rather than retyped so the test cannot drift from the code.

### Requires

- tmux-attention 0.7.0 or newer for the idle label. Older versions leave the field empty and
  rows fall back to `window_name` exactly as before.

## [2.8.2] - 2026-08-15

### Fixed

- Resolve the `@fzf_pane_switch_*` options on the no-argument code path.
  `select_pane.tmux` resolved them to build the key binding, but running
  `select_pane.sh` directly fell back to the raw defaults, so `prefix + j` and a
  direct invocation rendered differently as soon as any option was set. Both
  entry points now share `resolve_fzj_options` in `defaults.sh`. This also
  applies to `--test`, which remains an alias of the no-argument invocation.

## [2.8.1] - 2026-08-06

### Fixed

- Remove the unused `_fzj_list` positional-argument path so current ShellCheck
  versions do not fail CI with `SC2119` and `SC2120`.

## [2.8.0] - 2026-08-06

### Added

- Add a flat attention view for pane-local `input`, `blocked`, `review`, and
  `done` markers, sorted by state priority and marker recency. Open it directly
  with `select_pane.sh --view attention` or toggle it from the normal hierarchy
  with `ctrl-a` while preserving the current search query.
- Show attention reason and marker age in the focused view, include marked panes
  from single-pane windows, and report `No agents need attention` instead of
  opening an empty attention popup.

### Fixed

- Match the fallback blocked and done icons to tmux-attention's warning and
  check-mark defaults.

## [2.7.0] - 2026-08-04

### Changed

- Use a compact navigation-only layout below the configured preview width:
  the preview starts hidden as before, and fzf 0.60.2 or newer now hides the
  search input section too.

## [2.6.0] - 2026-08-03

### Added

- Show tmux-attention's configurable working icon for active agent turns,
  replacing the normal icon on both window and pane rows,
  while keeping attention states higher priority. Pane rows consume
  tmux-attention's pane-local state so multiple agents sharing a window render
  independently.
- Simplify pane rows to `<session> / <@pane_name-or-process>` instead of repeating
  the window name, working directory, and command. Retaining the session keeps
  it available for fuzzy matching, and the pane rename action now records
  `@pane_name` alongside the native pane title.
- Remove child-count text from session and window rows so values such as
  `3 windows` or `2 panes` do not pollute fuzzy matching; pane counts still
  control whether child rows appear.

## [2.5.0] - 2026-07-12

### Changed

- Collapsed `select_pane.sh`'s argument dispatch: `--test` and the no-argument
  invocation share one defaults branch, and the eleven picker arguments now
  pass through as `"$@"` instead of being copied into named variables.
- Extracted an `fzf_at_least` helper for the fzf version gates, replacing the
  repeated `vercomp` + `$?` comparisons.
- Small cleanups in `select_pane.sh`: rely on the cleanup trap instead of a
  redundant `rm -f` of the help-state file, drop a defensive `tail -1` after
  fzf (it emits a single line without `--multi`/`--print-query`), extract the
  selected target with a parameter expansion instead of `echo | awk`, and use
  `$FZF_PREVIEW_LINES` directly in the preview command without the arithmetic
  wrapper.
- Removed the dead cancel-fallback branch in `select_pane.sh`'s target
  dispatch (`tmux switch-client` back to the originating pane) along with the
  `current_pane` lookup that only fed it. It was a relic of a pre-popup fzf
  invocation; since the picker always runs via `fzf --tmux`, the client never
  leaves the current pane, so cancelling (Esc) already left nothing to switch
  back to.

## [2.4.0] - 2026-07-12

### Fixed

- Home-directory shortening in pane rows now uses a literal prefix replacement
  instead of an awk regex `sub()`, so a `$HOME` containing regex metacharacters
  (e.g. a dot) can no longer mangle the displayed path.

### Changed

- Dropped the unused `#{pane_title}` field from the pane listing (it was
  fetched but never rendered), and clarified in the README that pane rows show
  the window name, working directory, and running command — renaming a pane
  still sets its tmux pane title, which appears in pane borders, not in the
  picker list.
- Deduplicated `shell_quote` and `get_tmux_option` into the shared
  `defaults.sh` (the two copies had drifted; the safer `printf`-based
  `get_tmux_option` is kept).

## [2.3.1] - 2026-07-06

### Fixed

- Export `get_tmux_option` alongside `_fzj_list` so fzf's reload bindings
  (kill/rename/new/detach) keep honoring `@fzf_pane_switch_exclude-sessions`
  instead of silently dropping the filter after the first in-picker action.
- `shell_quote` in `select_pane.sh` now quotes values containing single quotes
  correctly (bash `printf` collapsed the `\'` escape in the format string,
  producing broken quoting).
- `tests/check.sh` passes on tmux >= 3.7, where `list-keys -T prefix j` (with
  the trailing key filter) prints nothing; assertion failures now report the
  failing line instead of exiting silently.

### Added

- Pre-commit config (`.pre-commit-config.yaml`) running ShellCheck and the
  integration tests; enable with `pre-commit install`.

## [2.3.0] - 2026-06-24

### Added

- Surface tmux-attention's `@agent_attention_reason` dimmed next to the state
  icon on window and pane rows, so the picker shows *why* a window wants
  attention, not just that it does.

### Changed

- Build the picker's current-target context with a single `tmux display-message`
  call instead of three.
- Harden the fzf version comparison against non-numeric version suffixes (e.g. a
  packager's `0.65.1-1`).

## [2.2.0] - 2026-06-24

### Added

- `@fzf_pane_switch_exclude-sessions`: hide sessions whose name matches a glob
  (e.g. `phone-*`) from the picker. Empty by default, so nothing is hidden.
  Useful for grouped or mirror sessions that share windows with a parent and
  would otherwise duplicate every window and pane in the list.

## [2.1.4] - 2026-06-22

### Added

- Adaptive preview width: `@fzf_pane_switch_preview-min-width` hides the pane
  preview by default on narrow tmux clients while keeping `ctrl-p` preview
  toggling available.

## [2.1.3] - 2026-06-17

### Fixed

- Prompt for confirmation before killing a selected session, window, or pane
  from the picker.
- Validate direct `select_pane.sh` arguments and default no-argument
  invocation to the standard picker options.
- Require and validate `fzf` in CI/release smoke checks, and cover the
  in-picker action dispatcher against an isolated tmux server.

## [2.1.2] - 2026-06-16

### Fixed

- A single-window session now lists its window row in the picker instead of
  collapsing into just the session row. This restores the documented "windows
  beneath their session" behavior (only panes collapse on count) and, crucially,
  stops a single-window session's `tmux-attention` marker and activity indicator
  from being hidden.

## [2.1.1] - 2026-06-15

### Changed

- Releases are now cut with the shared `git release` command; the in-repo `scripts/release.sh` was removed (the release process is otherwise unchanged).

## [2.1.0] - 2026-06-15

### Added

- tmux-attention integration: `input`, `blocked`, `review`, and `done` state icons shown on windows and panes (`@agent_attention`).
- In-picker action dispatcher with `ctrl-n` (new), `ctrl-r` (rename), `ctrl-d` (detach), and `ctrl-x` (kill), all context-sensitive to the selected session/window/pane.
- Activity (`●`) indicators for windows and panes with unread changes, plus pane working directory and running command in each row.
- Recent-session sort (most recently attached first) and a hierarchical list grouping windows and panes under their session.
- Configurable highlight and activity colors, icons, indent, and separator.
- fzf version-gated styling: border/label styling (>= 0.58.0) and ghost text (>= 0.61.0).
- `?` toggle showing the in-picker key binding help.
- `select_pane.sh --version`, reading the shared `VERSION` file.
- Continuous integration (ShellCheck, `bash -n`, fixture assertions, isolated tmux binding check) and a tag-driven GitHub release workflow.

### Fixed

- Options explicitly set to an empty string now override the default instead of falling back to it (e.g. `set -g @fzf_pane_switch_indent ""` now yields no indent, as documented).
- Selecting a pane now focuses that exact pane (`select-window` + `select-pane` after `switch-client`), rather than only switching to its window.
- List ordering now groups a session's windows and panes together even when multiple sessions share a `session_last_attached` timestamp.
- The help-state temp file is removed on interrupt/termination, not only on a clean exit.

### Changed

- Default option values are consolidated into a single shared `defaults.sh` to remove duplication between `select_pane.tmux` and `select_pane.sh`.
- Documented minimum tmux requirement raised to 3.4 (the picker uses `#{pane_unseen_changes}`).

## [2.0.0]

- Baseline release of the fzf-based session/window/pane switcher.

[Unreleased]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.9.1...HEAD
[2.9.1]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.9.0...v2.9.1
[2.9.0]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.8.2...v2.9.0
[2.8.2]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.8.1...v2.8.2
[2.8.1]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.8.0...v2.8.1
[2.8.0]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.7.0...v2.8.0
[2.7.0]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.6.0...v2.7.0
[2.6.0]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.5.0...v2.6.0
[2.5.0]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.4.0...v2.5.0
[2.4.0]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.3.1...v2.4.0
[2.3.1]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.1.4...v2.2.0
[2.1.4]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.1.3...v2.1.4
[2.1.3]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.1.2...v2.1.3
[2.1.2]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.1.1...v2.1.2
[2.1.1]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/cengebretson/tmux-fzf-jump/releases/tag/v2.0.0

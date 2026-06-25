# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.2.0...HEAD
[2.2.0]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.1.4...v2.2.0
[2.1.4]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.1.3...v2.1.4
[2.1.3]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.1.2...v2.1.3
[2.1.2]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.1.1...v2.1.2
[2.1.1]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/cengebretson/tmux-fzf-jump/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/cengebretson/tmux-fzf-jump/releases/tag/v2.0.0

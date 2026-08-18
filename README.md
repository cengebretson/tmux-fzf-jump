<h1 align="center">
    🔀 tmux-fzf-jump
</h1>

![Demonstration of tmux-fzf-pane-switch in action](assets/demo.gif)

Switch to any tmux session, window, or pane using fzf. The list is grouped hierarchically — sessions at the top (sorted by most recently used), windows beneath their session, and panes beneath their window (only shown when a window has more than one pane). Windows and panes with unread activity are marked with a `●` indicator. Optional [tmux-attention](https://github.com/cengebretson/tmux-attention) states replace the normal icon on window and pane rows. Pane rows retain the session name for fuzzy matching, followed by an explicit `@pane_name` when set or the pane's current process.

## Requirements

* [fzf](https://github.com/junegunn/fzf) >= 0.53.0 (requires `--tmux`; >= 0.58.0 for border styling as shown above).
* [tmux](https://github.com/tmux/tmux) >= 3.4 (uses `#{pane_unseen_changes}`).
* A [Nerd Font](https://www.nerdfonts.com/) for the default icons (configurable — see below).

## Installation

### Using TPM (recommended)

1. Install [TPM (Tmux Plugin Manager)](https://github.com/tmux-plugins/tpm).

2. Add `tmux-fzf-jump` to your `~/.tmux.conf`:

    ```bash
    set -g @plugin 'cengebretson/tmux-fzf-jump'
    ```

3. Inside a running tmux session, press `<prefix> + I` (capital I, as in Install) to fetch the plugin.

    Press `<prefix> + U` (capital U, as in Update) to update it later.

### Manual installation

1. Clone this repository to your desired location:

    ```bash
    git clone https://github.com/cengebretson/tmux-fzf-jump.git ~/.tmux/plugins/tmux-fzf-jump
    ```

2. Add the following to your `~/.tmux.conf`:

    ```bash
    run-shell ~/.tmux/plugins/tmux-fzf-jump/select_pane.tmux
    ```

    Any configuration variables should be set **before** the `run-shell` line so they're correctly sourced.

3. Reload your tmux configuration:

    ```bash
    tmux source-file ~/.tmux.conf
    ```

## Usage

Press `<prefix> + j` (the default key binding) to open the switcher. Type to fuzzy-search, use arrow keys to navigate, and press Enter to switch. Run `select_pane.sh --view attention` to open directly in the attention-only view.

### In-picker key bindings

| Key | Action |
|---|---|
| `ctrl-a` | Toggle between the complete hierarchy and panes needing attention |
| `ctrl-n` | New session / window / pane (context-sensitive) |
| `ctrl-r` | Rename selected session / window / pane |
| `ctrl-d` | Detach all clients from selected session |
| `ctrl-x` | Kill selected session / window / pane after confirmation |
| `ctrl-p` | Toggle preview pane |
| `?` | Toggle key binding help |

Renaming a pane sets its tmux pane title (visible in pane borders when enabled); pane titles are not shown in the picker list itself.

The attention view is a flat queue of pane-local `input`, `blocked`, `review`, and `done` markers. It includes marked panes from single-pane windows, sorts them by state priority and marker recency, and shows the session, window, pane label, reason, and marker age. Opening directly in this view displays `No agents need attention` instead of opening an empty popup when the queue is clear. Toggling with `ctrl-a` preserves the current search query.

For example, these no-prefix bindings open the normal and attention views:

```tmux
bind-key -n M-j run-shell "~/.tmux/plugins/tmux-fzf-jump/select_pane.sh"
bind-key -n M-J run-shell "~/.tmux/plugins/tmux-fzf-jump/select_pane.sh --view attention"
```

## Configuration

All options are set in `~/.tmux.conf`. Quick reference:

| Option | Default | Description |
|---|---|---|
| `@fzf_pane_switch_bind-key` | `j` | Key binding (with prefix) |
| `@fzf_pane_switch_window-position` | `center,70%,80%` | fzf popup position |
| `@fzf_pane_switch_preview-pane` | `true` | Show pane preview |
| `@fzf_pane_switch_preview-min-width` | `100` | Hide preview and search input below this terminal width |
| `@fzf_pane_switch_preview-pane-position` | `right,,,nowrap` | Preview window position |
| `@fzf_pane_switch_session-icon` | `󰐱` | Icon for session entries |
| `@fzf_pane_switch_window-icon` | `󰖲` | Icon for window entries |
| `@fzf_pane_switch_pane-icon` | `󰆍` | Icon for pane entries |
| `@fzf_pane_switch_indent` | `▪  ` | Indent string for hierarchy |
| `@fzf_pane_switch_separator` | `/` | Separator between session/window/pane names |
| `@fzf_pane_switch_highlight-color` | `166;227;161` | RGB color for the current item highlight |
| `@fzf_pane_switch_activity-color` | `249;226;175` | RGB color for the activity indicator `●` |
| `@fzf_pane_switch_exclude-sessions` | (empty) | Hide sessions whose name matches this glob (e.g. `phone-*`); empty shows all. Useful for grouped/mirror sessions that would otherwise duplicate every window and pane. |

### Key binding

```bash
set -g @fzf_pane_switch_bind-key "key binding"
```

Default is `prefix + j`. This key is unbound in vanilla tmux, so it won't override any built-in binding.

### fzf popup position

```bash
set -g @fzf_pane_switch_window-position "position"
```

Default is `center,70%,80%`. Accepts any value from the [`--tmux` option](https://man.archlinux.org/man/fzf.1.en#tmux) in the fzf man page.

### Pane preview

```bash
set -g @fzf_pane_switch_preview-pane "[true|false]"
```

Default is `true`. Can also be toggled on the fly with `ctrl-p` inside the picker.

### Adaptive pane preview

```bash
set -g @fzf_pane_switch_preview-min-width "100"
```

Default is `100`. When the attached tmux client is narrower than this many
columns, the picker starts with the preview pane hidden and, on fzf 0.60.2 or
newer, hides the search input entirely. This leaves the list as a compact
navigation-only selector on mobile clients. Set it to `0` to keep the desktop
layout at every width.

### Pane preview position

Only applies when `@fzf_pane_switch_preview-pane` is `true`.

```bash
set -g @fzf_pane_switch_preview-pane-position "position"
```

Default is `right,,,nowrap`. Accepts any value from the [`--preview-window` option](https://man.archlinux.org/man/fzf.1.en#preview~3) in the fzf man page.

### Icons

Each entry type has a configurable icon. The defaults require a [Nerd Font](https://www.nerdfonts.com/).

```bash
set -g @fzf_pane_switch_session-icon "󰐱"
set -g @fzf_pane_switch_window-icon  "󰖲"
set -g @fzf_pane_switch_pane-icon    "󰆍"
```

Any string works — including plain text fallbacks if you don't have a Nerd Font:

```bash
set -g @fzf_pane_switch_session-icon "S"
set -g @fzf_pane_switch_window-icon  "W"
set -g @fzf_pane_switch_pane-icon    "P"
```

### Indent

The indent string is prepended to the icon once for windows and twice for panes, creating the visual hierarchy.

```bash
set -g @fzf_pane_switch_indent "▪  "
```

Default is `▪  `. Set to an empty string for no indentation, or use any character(s) you prefer (e.g. `· `, `▸ `, `  `).

### Separator

The separator string appears between session, window, and pane names in each list entry.

```bash
set -g @fzf_pane_switch_separator "/"
```

Default is `/`.

### Colors

Colors are specified as RGB triplets in the form `R;G;B` (used in ANSI 24-bit color escapes).

```bash
set -g @fzf_pane_switch_highlight-color "166;227;161"  # current item (default: Catppuccin green)
set -g @fzf_pane_switch_activity-color  "249;226;175"  # activity dot (default: Catppuccin yellow)
```

### tmux-attention integration

If [tmux-attention](https://github.com/cengebretson/tmux-attention) is installed, a matching summary icon replaces the normal window icon and each pane's own status icon replaces its normal pane icon. Attention states take precedence; otherwise an active agent turn renders the working icon. Window rows also show the agent's context label in place of the window name when one is known (the active turn's project, else tmux-attention's idle label), which distinguishes worktrees of the same repo; pane rows show a pane's project while its agent is active. Both fall back to the previous behaviour when tmux-attention is absent or older than 0.7.0. Multiple agents in separate panes are displayed independently. The integration is optional, and the normal window or pane icon remains when neither state is active or the matching state icon is configured as empty.

Pane labels use `<session> / <name>`, with the explicit pane option `@pane_name` falling back to `pane_current_command`. The in-picker rename action sets both `@pane_name` and tmux's native pane title so intentional names remain stable even when terminal applications update `pane_title`:

```bash
tmux set-option -p -t %12 @pane_name "api"
```

The supported states are `input`, `blocked`, `review`, and `done`. The attention view shows those pane-local states directly. Icon overrides are read from tmux-attention's existing options:

```bash
set -g @tmux_attention_icon_input   "󱐋"
set -g @tmux_attention_icon_blocked ""
set -g @tmux_attention_icon_review  "󰛨"
set -g @tmux_attention_icon_done    ""
set -g @tmux_attention_icon_working "󰚩"
```

When a marker also records a reason (tmux-attention's `@agent_attention_reason`, e.g. `approval_required`), it is shown dimmed next to the icon on that window/pane row.

You can preview representative rows from the repository without creating tmux sessions:

```bash
./select_pane.sh --fixture
```

Or inspect the same rows through fzf:

```bash
./select_pane.sh --fixture-fzf
```

## Testing

Run the smoke checks before changing behavior:

```bash
tests/check.sh
```

The script runs ShellCheck, Bash syntax validation, fixture assertions, and an isolated tmux binding check. The same checks run in CI on every push and pull request.

## Versioning

This project follows [Semantic Versioning](https://semver.org). Notable changes are recorded in [CHANGELOG.md](CHANGELOG.md), and the installed version can be printed with:

```bash
./select_pane.sh --version
```

To cut a release, move the changelog's `[Unreleased]` entries under a new `## [x.y.z]` heading, set the matching value in `VERSION`, then tag and push:

```bash
git tag -a v2.1.0 -m v2.1.0
git push origin main --follow-tags
```

Pushing a `v*` tag triggers the release workflow, which re-runs the checks, verifies the tag matches `VERSION`, and publishes a GitHub release using that version's changelog section as the notes.

## Demo setup

* tmux theme: [catppuccin](https://github.com/catppuccin/tmux) mocha.
* Shell prompt: [starship](https://starship.rs).
* fzf theme: [catppuccin](https://github.com/catppuccin/fzf) mocha.

## Related projects

* [tmux-attention](https://github.com/cengebretson/tmux-attention) — a companion tmux plugin for marking windows that need attention.

## Origins

This is a fork of [kristijan/fzf-pane-switch.tmux](https://github.com/kristijan/fzf-pane-switch.tmux), which itself was inspired by the [brokenricefilms/tmux-fzf-session-switch](https://github.com/brokenricefilms/tmux-fzf-session-switch) TPM plugin. If you're looking for something to switch tmux sessions only, go check it out.

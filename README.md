<h1 align="center">
    🔀 tmux-fzf-jump
</h1>

![Demonstration of tmux-fzf-pane-switch in action](assets/demo.gif)

Switch to any tmux session, window, or pane using fzf. The list is grouped hierarchically — sessions at the top (sorted by most recently used), windows beneath their session, and panes beneath their window (only shown when a window has more than one pane). Windows and panes with unread activity are marked with a `●` indicator, and panes show the current working directory and running command alongside their name.

## Requirements

* [fzf](https://github.com/junegunn/fzf) >= 0.53.0 (requires `--tmux`; >= 0.58.0 for border styling as shown above).
* [tmux](https://github.com/tmux/tmux) >= 3.3.
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

Press `<prefix> + j` (the default key binding) to open the switcher. Type to fuzzy-search, use arrow keys to navigate, and press Enter to switch.

### In-picker key bindings

| Key | Action |
|---|---|
| `ctrl-n` | New session / window / pane (context-sensitive) |
| `ctrl-r` | Rename selected session / window / pane |
| `ctrl-d` | Detach all clients from selected session |
| `ctrl-x` | Kill selected session / window / pane |
| `ctrl-p` | Toggle preview pane |
| `?` | Toggle key binding help |

## Configuration

All options are set in `~/.tmux.conf`. Quick reference:

| Option | Default | Description |
|---|---|---|
| `@fzf_pane_switch_bind-key` | `j` | Key binding (with prefix) |
| `@fzf_pane_switch_window-position` | `center,70%,80%` | fzf popup position |
| `@fzf_pane_switch_preview-pane` | `true` | Show pane preview |
| `@fzf_pane_switch_preview-pane-position` | `right,,,nowrap` | Preview window position |
| `@fzf_pane_switch_session-icon` | `󰐱` | Icon for session entries |
| `@fzf_pane_switch_window-icon` | `󰖲` | Icon for window entries |
| `@fzf_pane_switch_pane-icon` | `󰆍` | Icon for pane entries |
| `@fzf_pane_switch_indent` | `▪  ` | Indent string for hierarchy |
| `@fzf_pane_switch_separator` | `/` | Separator between session/window/pane names |
| `@fzf_pane_switch_highlight-color` | `166;227;161` | RGB color for the current item highlight |
| `@fzf_pane_switch_activity-color` | `249;226;175` | RGB color for the activity indicator `●` |

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

## Demo setup

* tmux theme: [catppuccin](https://github.com/catppuccin/tmux) mocha.
* Shell prompt: [starship](https://starship.rs).
* fzf theme: [catppuccin](https://github.com/catppuccin/fzf) mocha.

## Origins

This is a fork of [kristijan/fzf-pane-switch.tmux](https://github.com/kristijan/fzf-pane-switch.tmux), which itself was inspired by the [brokenricefilms/tmux-fzf-session-switch](https://github.com/brokenricefilms/tmux-fzf-session-switch) TPM plugin. If you're looking for something to switch tmux sessions only, go check it out.

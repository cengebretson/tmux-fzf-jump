#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values and shared helpers (shell_quote, get_tmux_option),
# shared with select_pane.sh.
# shellcheck source=defaults.sh
source "${CURRENT_DIR}/defaults.sh"

# The bind key is resolved here rather than in resolve_fzj_options: it selects
# which key runs the picker, not how the picker renders, so select_pane.sh has
# no use for it.
tmux_bind_key="@fzf_pane_switch_bind-key"

set_switch_pane_bindings() {
    local bind_key command arg
    bind_key="$(get_tmux_option "${tmux_bind_key}" "${default_bind_key}")"

    resolve_fzj_options

    command="$(shell_quote "${CURRENT_DIR}/select_pane.sh")"
    while IFS= read -r arg; do
        command+=" $(shell_quote "${arg}")"
    done < <(fzj_option_args)

    tmux bind-key "${bind_key}" run-shell "${command}"
}

set_switch_pane_bindings

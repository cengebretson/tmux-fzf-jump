#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values (shared with select_pane.sh)
# shellcheck source=defaults.sh
source "${CURRENT_DIR}/defaults.sh"

# User overridable options
tmux_bind_key="@fzf_pane_switch_bind-key"
tmux_preview_pane="@fzf_pane_switch_preview-pane"
tmux_preview_min_width="@fzf_pane_switch_preview-min-width"
tmux_fzf_window_position="@fzf_pane_switch_window-position"
tmux_fzf_preview_window_position="@fzf_pane_switch_preview-pane-position"
tmux_session_icon="@fzf_pane_switch_session-icon"
tmux_window_icon="@fzf_pane_switch_window-icon"
tmux_pane_icon="@fzf_pane_switch_pane-icon"
tmux_indent="@fzf_pane_switch_indent"
tmux_separator="@fzf_pane_switch_separator"
tmux_highlight_color="@fzf_pane_switch_highlight-color"
tmux_activity_color="@fzf_pane_switch_activity-color"

get_tmux_option() {
    local option="${1}"
    local default_value="${2}"
    # `show-option -gq <name>` prints a line only when the option is set, which
    # lets us tell "set to empty" apart from "unset" (both yield empty -gqv).
    if [ -n "$(tmux show-option -gq "${option}")" ]; then
        tmux show-option -gqv "${option}"
    else
        echo "${default_value}"
    fi
}

shell_quote() {
    local value="${1}"
    printf "'"
    while [[ "${value}" == *"'"* ]]; do
        printf "%s'\\\\''" "${value%%\'*}"
        value="${value#*\'}"
    done
    printf "%s'" "${value}"
}

set_switch_pane_bindings() {
    local bind_key preview_pane preview_min_width fzf_window_position fzf_preview_window_position command
    local session_icon window_icon pane_icon indent separator highlight_color activity_color
    bind_key="$(get_tmux_option "${tmux_bind_key}" "${default_bind_key}")"
    preview_pane="$(get_tmux_option "${tmux_preview_pane}" "${default_preview_pane}")"
    preview_min_width="$(get_tmux_option "${tmux_preview_min_width}" "${default_preview_min_width}")"
    fzf_window_position="$(get_tmux_option "${tmux_fzf_window_position}" "${default_fzf_window_position}")"
    fzf_preview_window_position="$(get_tmux_option "${tmux_fzf_preview_window_position}" "${default_fzf_preview_window_position}")"
    session_icon="$(get_tmux_option "${tmux_session_icon}" "${default_session_icon}")"
    window_icon="$(get_tmux_option "${tmux_window_icon}" "${default_window_icon}")"
    pane_icon="$(get_tmux_option "${tmux_pane_icon}" "${default_pane_icon}")"
    indent="$(get_tmux_option "${tmux_indent}" "${default_indent}")"
    separator="$(get_tmux_option "${tmux_separator}" "${default_separator}")"
    highlight_color="$(get_tmux_option "${tmux_highlight_color}" "${default_highlight_color}")"
    activity_color="$(get_tmux_option "${tmux_activity_color}" "${default_activity_color}")"

    command="$(shell_quote "${CURRENT_DIR}/select_pane.sh")"
    command+=" $(shell_quote "${preview_pane}")"
    command+=" $(shell_quote "${preview_min_width}")"
    command+=" $(shell_quote "${fzf_window_position}")"
    command+=" $(shell_quote "${fzf_preview_window_position}")"
    command+=" $(shell_quote "${session_icon}")"
    command+=" $(shell_quote "${window_icon}")"
    command+=" $(shell_quote "${pane_icon}")"
    command+=" $(shell_quote "${indent}")"
    command+=" $(shell_quote "${separator}")"
    command+=" $(shell_quote "${highlight_color}")"
    command+=" $(shell_quote "${activity_color}")"

    tmux bind-key "${bind_key}" run-shell "${command}"
}

set_switch_pane_bindings

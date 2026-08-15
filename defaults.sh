#!/usr/bin/env bash
# Single source of truth for default option values and small shared helpers.
# Sourced by select_pane.tmux (binding setup) and select_pane.sh (runtime + tests).
# This file is meant to be sourced, not executed.
#
# shellcheck disable=SC2034  # consumed by the sourcing scripts, not here

default_bind_key='j'
default_preview_pane='true'
default_preview_min_width='100'
default_fzf_window_position='center,70%,80%'
default_fzf_preview_window_position='right,,,nowrap'
default_session_icon='󰐱'
default_window_icon='󰖲'
default_pane_icon='󰆍'
default_indent='▪  '
default_separator='/'
default_highlight_color='166;227;161'
default_activity_color='249;226;175'
default_attention_icon_input='󱐋'
default_attention_icon_blocked=''
default_attention_icon_review='󰛨'
default_attention_icon_done=''
default_attention_icon_working='󰚩'

shell_quote() {
    local value="${1}"
    printf "'"
    while [[ "${value}" == *"'"* ]]; do
        # Double the backslash: bash printf collapses \' in a format string, so
        # a single one would emit ''' instead of the POSIX '\'' quote dance.
        printf "%s'\\\\''" "${value%%\'*}"
        value="${value#*\'}"
    done
    printf "%s'" "${value}"
}

get_tmux_option() {
    local option="${1}"
    local default_value="${2}"
    # `show-option -gq <name>` prints a line only when the option is set, which
    # lets us tell "set to empty" apart from "unset" (both yield empty -gqv).
    if [[ -n "$(tmux show-option -gq "${option}")" ]]; then
        tmux show-option -gqv "${option}"
    else
        printf "%s\n" "${default_value}"
    fi
}

# Resolve the eleven user-facing @fzf_pane_switch_* options into fzj_opt_*,
# falling back to the default_* values above.
#
# Both entry points call this, which is the point: select_pane.tmux resolves
# them to build the key binding's argument list, and select_pane.sh's
# no-argument path resolves them at launch. Previously only the former did, so
# `prefix + j` honored these options while a direct `select_pane.sh` call
# silently used raw defaults — two entry points that agreed only while every
# option happened to be unset.
resolve_fzj_options() {
    fzj_opt_preview_pane="$(get_tmux_option '@fzf_pane_switch_preview-pane' "${default_preview_pane}")"
    fzj_opt_preview_min_width="$(get_tmux_option '@fzf_pane_switch_preview-min-width' "${default_preview_min_width}")"
    fzj_opt_fzf_window_position="$(get_tmux_option '@fzf_pane_switch_window-position' "${default_fzf_window_position}")"
    fzj_opt_fzf_preview_window_position="$(get_tmux_option '@fzf_pane_switch_preview-pane-position' "${default_fzf_preview_window_position}")"
    fzj_opt_session_icon="$(get_tmux_option '@fzf_pane_switch_session-icon' "${default_session_icon}")"
    fzj_opt_window_icon="$(get_tmux_option '@fzf_pane_switch_window-icon' "${default_window_icon}")"
    fzj_opt_pane_icon="$(get_tmux_option '@fzf_pane_switch_pane-icon' "${default_pane_icon}")"
    fzj_opt_indent="$(get_tmux_option '@fzf_pane_switch_indent' "${default_indent}")"
    fzj_opt_separator="$(get_tmux_option '@fzf_pane_switch_separator' "${default_separator}")"
    fzj_opt_highlight_color="$(get_tmux_option '@fzf_pane_switch_highlight-color' "${default_highlight_color}")"
    fzj_opt_activity_color="$(get_tmux_option '@fzf_pane_switch_activity-color' "${default_activity_color}")"
}

# The eleven resolved values, in the positional order select_pane.sh expects.
# Keep this order in lockstep with select_pane's parameter list.
fzj_option_args() {
    printf '%s\n' \
        "${fzj_opt_preview_pane}" \
        "${fzj_opt_preview_min_width}" \
        "${fzj_opt_fzf_window_position}" \
        "${fzj_opt_fzf_preview_window_position}" \
        "${fzj_opt_session_icon}" \
        "${fzj_opt_window_icon}" \
        "${fzj_opt_pane_icon}" \
        "${fzj_opt_indent}" \
        "${fzj_opt_separator}" \
        "${fzj_opt_highlight_color}" \
        "${fzj_opt_activity_color}"
}

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
default_attention_icon_blocked=''
default_attention_icon_review='󰛨'
default_attention_icon_done=''

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

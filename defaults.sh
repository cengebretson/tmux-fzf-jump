#!/usr/bin/env bash
# Single source of truth for default option values.
# Sourced by select_pane.tmux (binding setup) and select_pane.sh (runtime + tests).
# This file is meant to be sourced, not executed.
#
# shellcheck disable=SC2034  # consumed by the sourcing scripts, not here

default_bind_key='j'
default_preview_pane='true'
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

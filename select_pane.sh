#!/usr/bin/env bash

_FZJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values (shared with select_pane.tmux)
# shellcheck source=defaults.sh
source "${_FZJ_DIR}/defaults.sh"

function shell_quote() {
    local value="${1}"
    printf "'"
    while [[ "${value}" == *"'"* ]]; do
        printf "%s'\\''" "${value%%\'*}"
        value="${value#*\'}"
    done
    printf "%s'" "${value}"
}

function get_tmux_option() {
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

function select_pane() {
    local fzf_version fzf_version_comparison has_border_styling=false
    local current_pane pane target

    current_pane=$(tmux display-message -p '#{pane_id}')

    local -a fzf_args
    fzf_args=(--exit-0 --reverse --ansi --tmux "${2}" --with-nth=2..)

    fzf_version=$(fzf --version | awk '{print $1}')

    vercomp '0.53.0' "${fzf_version}"
    if [[ $? -eq 1 ]]; then
        echo "tmux-fzf-jump requires fzf >= 0.53.0 (found ${fzf_version})" >&2
        return 1
    fi

    vercomp '0.58.0' "${fzf_version}"
    fzf_version_comparison=$?
    if [[ ${fzf_version_comparison} -ne 1 ]]; then
        fzf_args+=(
            --input-border --input-label=' Search (? for help) ' --info=inline-right
            --list-border --list-label=' Tmux '
            --preview-border --preview-label=' Preview '
        )
        has_border_styling=true
    fi
    vercomp '0.61.0' "${fzf_version}"
    fzf_version_comparison=$?
    if [[ ${fzf_version_comparison} -ne 1 ]]; then
        fzf_args+=(--ghost 'type to search...')
    fi
    [[ "${has_border_styling}" = false ]] && fzf_args+=(--preview-label=preview)

    if [[ "${1}" = 'true' ]]; then
        fzf_args+=(
            --preview "tmux capture-pane -ep -S -\$(( \${FZF_PREVIEW_LINES:-30} )) -t {1} | awk \"{a[NR]=\\\$0} END{for(i=NR;i>0;i--) if(a[i]~/[^ \\t]/){for(j=1;j<=i;j++) print a[j]; exit}}\" | tail -n \$(( \${FZF_PREVIEW_LINES:-30} ))"
            --preview-window="${3}"
        )
    fi

    local session_icon="${4}" window_icon="${5}" pane_icon="${6}" indent="${7}" separator="${8}"
    local highlight_color="${9}" activity_color="${10}"
    local attention_icon_input attention_icon_blocked attention_icon_review attention_icon_done
    attention_icon_input="$(get_tmux_option '@tmux_attention_icon_input' "${default_attention_icon_input}")"
    attention_icon_blocked="$(get_tmux_option '@tmux_attention_icon_blocked' "${default_attention_icon_blocked}")"
    attention_icon_review="$(get_tmux_option '@tmux_attention_icon_review' "${default_attention_icon_review}")"
    attention_icon_done="$(get_tmux_option '@tmux_attention_icon_done' "${default_attention_icon_done}")"

    export _FZJ_SI="${session_icon}" _FZJ_WI="${window_icon}" _FZJ_PI="${pane_icon}"
    export _FZJ_IN="${indent}" _FZJ_SEP="${separator}"
    export _FZJ_HC="${highlight_color}" _FZJ_AC="${activity_color}"
    export _FZJ_AI="${attention_icon_input}" _FZJ_AB="${attention_icon_blocked}"
    export _FZJ_AR="${attention_icon_review}" _FZJ_AD="${attention_icon_done}"

    _fzj_list() {
        local cs cw cp
        cs=$(tmux display-message -p '#{session_name}')
        cw=$(tmux display-message -p '#{window_index}')
        cp=$(tmux display-message -p '#{pane_id}')
        {
            # Sessions sorted by most recently attached (newest first via inverted timestamp)
            tmux list-sessions -F $'#{session_last_attached}\t#{session_name}\t#{session_id}\t#{session_windows}' | \
                awk -F'\t' -v icon="${_FZJ_SI}" -v cur="${cs}" -v hc="${_FZJ_HC}" '{
                    ts = 9999999999 - $1
                    b = ($2==cur) ? "\033[1;38;2;" hc "m" : ""; r = b!="" ? "\033[0m" : ""
                    printf "%010d:%s:00000:00000:0 %s %s%s %s  %s%s\n", ts, $3, $3, b, icon, $2, ($4==1?"":$4" windows"), r
                }'
            # Always list every window beneath its session — including the sole
            # window of a single-window session — so its activity and
            # tmux-attention marker are never hidden. (Panes below still collapse
            # when a window has only one.)
            tmux list-windows -aF $'#{session_last_attached}\t#{session_name}\t#{window_index}\t#{window_id}\t#{window_name}\t#{window_panes}\t#{session_windows}\t#{window_activity_flag}\t#{@agent_attention}\t#{session_id}' | \
                awk -F'\t' -v icon="${_FZJ_IN}${_FZJ_WI}" -v sep="${_FZJ_SEP}" -v cur_s="${cs}" -v cur_w="${cw}" -v hc="${_FZJ_HC}" -v ac="${_FZJ_AC}" -v ai="${_FZJ_AI}" -v ab="${_FZJ_AB}" -v ar="${_FZJ_AR}" -v ad="${_FZJ_AD}" '{
                    ts = 9999999999 - $1
                    b = ($2==cur_s && $3==cur_w) ? "\033[1;38;2;" hc "m" : ""; r = b!="" ? "\033[0m" : ""
                    act = ($8=="1") ? " \033[38;2;" ac "m●\033[0m" : ""
                    att = ($9=="input") ? ai : (($9=="blocked") ? ab : (($9=="review") ? ar : (($9=="done") ? ad : "")))
                    att = (att=="") ? "" : " \033[38;2;" ac "m" att "\033[0m"
                    printf "%010d:%s:%05d:00000:1 %s %s%s %s %s %s  %s%s%s%s\n", ts, $10, $3, $4, b, icon, $2, sep, $5, ($6==1?"":$6" panes"), r, act, att
                }'
            tmux list-panes -aF $'#{session_last_attached}\t#{session_name}\t#{window_index}\t#{pane_index}\t#{pane_id}\t#{window_name}\t#{pane_title}\t#{window_panes}\t#{pane_current_command}\t#{pane_unseen_changes}\t#{pane_current_path}\t#{@agent_attention}\t#{session_id}' | \
                awk -F'\t' -v icon="${_FZJ_IN}${_FZJ_IN}${_FZJ_PI}" -v sep="${_FZJ_SEP}" -v cur="${cp}" -v hc="${_FZJ_HC}" -v ac="${_FZJ_AC}" -v home="${HOME}" -v ai="${_FZJ_AI}" -v ab="${_FZJ_AB}" -v ar="${_FZJ_AR}" -v ad="${_FZJ_AD}" '$8 > 1 {
                    ts = 9999999999 - $1
                    b = ($5==cur) ? "\033[1;38;2;" hc "m" : ""; r = b!="" ? "\033[0m" : ""
                    act = ($10=="1") ? " \033[38;2;" ac "m●\033[0m" : ""
                    att = ($12=="input") ? ai : (($12=="blocked") ? ab : (($12=="review") ? ar : (($12=="done") ? ad : "")))
                    att = (att=="") ? "" : " \033[38;2;" ac "m" att "\033[0m"
                    cmd = ($9 ~ /^(bash|sh|zsh|fish|dash)$/) ? "" : " \033[2m(" $9 ")\033[0m"
                    p = $11
                    if (home != "" && index(p, home) == 1) sub(home, "~", p)
                    n = split(p, parts, "/")
                    if (n <= 2) short_path = p
                    else { prefix = (parts[1] == "~") ? "~/" : ""; short_path = prefix parts[n-1] "/" parts[n] }
                    printf "%010d:%s:%05d:%05d:2 %s %s%s %s %s %s %s %s%s%s%s%s\n", ts, $13, $3, $4, $5, b, icon, $2, sep, $6, sep, short_path, cmd, r, act, att
                }'
        } | sort | cut -d' ' -f2-
    }
    export -f _fzj_list

    local full_hdr='  ctrl-x : kill\n  ctrl-r : rename\n  ctrl-n : new\n  ctrl-d : detach\n  ctrl-p : toggle preview\n  ?      : close'
    local short_hdr=''
    [[ "${has_border_styling}" = false ]] && short_hdr='  ctrl-p: preview  ?: help'
    local _help_state
    _help_state=$(mktemp)
    # shellcheck disable=SC2064  # bake the path in now; the var is local
    trap "rm -f '${_help_state}'" EXIT INT TERM
    local action_cmd
    action_cmd="$(shell_quote "${BASH_SOURCE[0]}") --action"

    [[ -n "${short_hdr}" ]] && fzf_args+=(--header "${short_hdr}")
    fzf_args+=(
        --bind "?:transform(if [ \"\$(cat '${_help_state}')\" = 1 ]; then echo 0 > '${_help_state}'; echo 'change-header(${short_hdr})'; else echo 1 > '${_help_state}'; echo 'change-header(${full_hdr})'; fi)"
        --bind "ctrl-x:execute(${action_cmd} kill {1})+reload(bash -c _fzj_list)"
        --bind "ctrl-r:execute(${action_cmd} rename {1})+reload(bash -c _fzj_list)"
        --bind "ctrl-n:execute(${action_cmd} new {1})+reload(bash -c _fzj_list)"
        --bind "ctrl-d:execute-silent(${action_cmd} detach {1})+reload(bash -c _fzj_list)"
        --bind 'ctrl-p:toggle-preview'
    )

    pane=$(
        _fzj_list |
        SHELL=/bin/sh fzf "${fzf_args[@]}" |
        tail -1
    )
    rm -f "${_help_state}"

    target=$(echo "${pane}" | awk '{print $1}')

    case "${target}" in
        \$*|@*)
            tmux switch-client -t "${target}"
            ;;
        %*)
            # switch-client moves to the pane's session; select-window and
            # select-pane ensure focus lands on that exact pane.
            tmux switch-client -t "${target}"
            tmux select-window -t "${target}"
            tmux select-pane -t "${target}"
            ;;
        *)
            tmux switch-client -t "${current_pane}"
            ;;
    esac
}

function target_type() {
    local target="${1}"
    case "${target}" in
        \$*) printf "session\n" ;;
        %*) printf "pane\n" ;;
        @*) printf "window\n" ;;
        *) printf "unknown\n" ;;
    esac
}

function action_kill() {
    local target="${1}"
    local type
    type="$(target_type "${target}")"

    case "${type}" in
        session|window|pane) ;;
        *) return 1 ;;
    esac

    printf "Kill %s %s? [y/N]: " "${type}" "${target}"
    local confirm
    read -r confirm
    case "${confirm}" in
        y|Y|yes|YES) ;;
        *) return 0 ;;
    esac

    case "${type}" in
        session) tmux kill-session -t "${target}" ;;
        pane) tmux kill-pane -t "${target}" ;;
        window) tmux kill-window -t "${target}" ;;
    esac
}

function action_rename() {
    local target="${1}"
    local current_name new_name

    case "$(target_type "${target}")" in
        session)
            current_name=$(tmux display-message -p -t "${target}" '#{session_name}')
            printf "Rename session [%s]: " "${current_name}"
            read -r new_name
            [[ -n "${new_name}" ]] && tmux rename-session -t "${target}" "${new_name}"
            ;;
        pane)
            current_name=$(tmux display-message -p -t "${target}" '#{pane_title}')
            printf "Rename pane [%s]: " "${current_name}"
            read -r new_name
            [[ -n "${new_name}" ]] && tmux select-pane -t "${target}" -T "${new_name}"
            ;;
        window)
            current_name=$(tmux display-message -p -t "${target}" '#{window_name}')
            printf "Rename window [%s]: " "${current_name}"
            read -r new_name
            [[ -n "${new_name}" ]] && tmux rename-window -t "${target}" "${new_name}"
            ;;
    esac
}

function action_new() {
    local target="${1}"
    local session_name window_target new_name

    case "$(target_type "${target}")" in
        session)
            printf "New session name: "
            read -r new_name
            [[ -n "${new_name}" ]] && tmux new-session -d -s "${new_name}"
            ;;
        pane)
            window_target=$(tmux display-message -p -t "${target}" '#{session_name}:#{window_index}')
            tmux split-window -t "${window_target}" -d
            ;;
        window)
            session_name=$(tmux display-message -p -t "${target}" '#{session_name}')
            printf "New window name: "
            read -r new_name
            if [[ -n "${new_name}" ]]; then
                tmux new-window -t "${session_name}:" -n "${new_name}" -d
            else
                tmux new-window -t "${session_name}:" -d
            fi
            ;;
    esac
}

function action_detach() {
    local target="${1}"
    [[ "$(target_type "${target}")" = "session" ]] && tmux detach-client -s "${target}"
}

function run_action() {
    local action="${1}"
    local target="${2}"

    [[ -n "${target}" ]] || return 0

    case "${action}" in
        kill) action_kill "${target}" ;;
        rename) action_rename "${target}" ;;
        new) action_new "${target}" ;;
        detach) action_detach "${target}" ;;
        *) return 1 ;;
    esac
}

function usage() {
    cat <<EOF
Usage:
  ${0##*/} [--version|--fixture|--fixture-fzf|--test]
  ${0##*/} --action <kill|rename|new|detach> <target>
  ${0##*/} <preview-pane> <fzf-window-position> <preview-window-position> <session-icon> <window-icon> <pane-icon> <indent> <separator> <highlight-color> <activity-color>

Run with no arguments to use the default picker options.
EOF
}

function vercomp() {
  local v1="$1"
  local v2="$2"

  IFS='.' read -r -a ver1 <<< "$v1"
  IFS='.' read -r -a ver2 <<< "$v2"

  for i in 0 1 2; do
    local num1="${ver1[i]:-0}"
    local num2="${ver2[i]:-0}"

    if (( num1 > num2 )); then
      return 1
    elif (( num1 < num2 )); then
      return 2
    fi
  done

  return 0
}

function print_fixture() {
    local session_icon="${default_session_icon}" window_icon="${default_window_icon}" pane_icon="${default_pane_icon}"
    local indent="${default_indent}" separator="${default_separator}"
    local highlight_color="${default_highlight_color}" activity_color="${default_activity_color}"
    local reset=$'\033[0m'
    local highlight=$'\033[1;38;2;166;227;161m'
    local activity=$'\033[38;2;249;226;175m'
    local dim=$'\033[2m'

    printf "\$1 %s%s workspace  3 windows%s\n" "${highlight}" "${session_icon}" "${reset}"
    printf "@1 %s%s workspace%s dashboard 2 panes  %s●%s %s%s%s\n" "${highlight}" "${indent}${window_icon}" "${separator}" "${activity}" "${reset}" "${activity}" "${default_attention_icon_input}" "${reset}"
    printf "%%1 %s%s workspace%s dashboard%s tmux-fzf-jump %s(node)%s %s%s%s\n" "${highlight}" "${indent}${indent}${pane_icon}" "${separator}" "${separator}" "${dim}" "${reset}" "${activity}" "${default_attention_icon_input}" "${reset}"
    printf "%%2 %s workspace%s dashboard%s tmux-attention %s%s%s\n" "${indent}${indent}${pane_icon}" "${separator}" "${separator}" "${activity}" "${default_attention_icon_input}" "${reset}"
    printf "@2 %s project%s api 1 pane  %s%s%s\n" "${indent}${window_icon}" "${separator}" "${activity}" "${default_attention_icon_blocked}" "${reset}"
    printf "@3 %s project%s review 1 pane  %s%s%s\n" "${indent}${window_icon}" "${separator}" "${activity}" "${default_attention_icon_review}" "${reset}"
    printf "\$2 %s archive  1 window\n" "${session_icon}"
    printf "@4 %s archive%s done 1 pane  %s%s%s\n" "${indent}${window_icon}" "${separator}" "${activity}" "${default_attention_icon_done}" "${reset}"
}

if [[ "${1:-}" == '--version' ]]; then
    cat "${_FZJ_DIR}/VERSION"
    exit
fi

if [[ "${1:-}" == '--fixture' ]]; then
    print_fixture
    exit
fi

if [[ "${1:-}" == '--fixture-fzf' ]]; then
    print_fixture | fzf --ansi --with-nth=2.. --reverse
    exit
fi

command -v tmux >/dev/null 2>&1 || { echo "tmux not found"; exit 1; }

if [[ "${1:-}" == '--action' ]]; then
    if [[ $# -ne 3 ]]; then
        usage >&2
        exit 2
    fi
    run_action "${2}" "${3}"
    exit
fi

command -v fzf >/dev/null 2>&1 || { echo "fzf not found"; exit 1; }

if [[ "${1:-}" == '--test' ]]; then
    select_pane "${default_preview_pane}" "${default_fzf_window_position}" "${default_fzf_preview_window_position}" \
        "${default_session_icon}" "${default_window_icon}" "${default_pane_icon}" "${default_indent}" "${default_separator}" \
        "${default_highlight_color}" "${default_activity_color}"
    exit
fi

if [[ $# -eq 0 ]]; then
    preview_pane="${default_preview_pane}"
    fzf_window_position="${default_fzf_window_position}"
    fzf_preview_window_position="${default_fzf_preview_window_position}"
    session_icon="${default_session_icon}"
    window_icon="${default_window_icon}"
    pane_icon="${default_pane_icon}"
    indent="${default_indent}"
    separator="${default_separator}"
    highlight_color="${default_highlight_color}"
    activity_color="${default_activity_color}"
elif [[ $# -eq 10 ]]; then
    preview_pane="${1}"
    fzf_window_position="${2}"
    fzf_preview_window_position="${3}"
    session_icon="${4}"
    window_icon="${5}"
    pane_icon="${6}"
    indent="${7}"
    separator="${8}"
    highlight_color="${9}"
    activity_color="${10}"
else
    usage >&2
    exit 2
fi

select_pane "${preview_pane}" "${fzf_window_position}" "${fzf_preview_window_position}" \
    "${session_icon}" "${window_icon}" "${pane_icon}" "${indent}" "${separator}" \
    "${highlight_color}" "${activity_color}"

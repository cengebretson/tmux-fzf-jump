#!/usr/bin/env bash

_FZJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values and shared helpers (shell_quote, get_tmux_option),
# shared with select_pane.tmux.
# shellcheck source=defaults.sh
source "${_FZJ_DIR}/defaults.sh"

function select_pane() {
    local fzf_version has_border_styling=false
    local pane target preview_pane preview_min_width client_width preview_window
    local narrow_client=false preview_starts_hidden=false input_hidden=false
    local initial_view="${12:-all}" list_label

    preview_pane="${1}"
    preview_min_width="${2}"
    list_label=' Tmux '
    [[ "${initial_view}" = 'attention' ]] && list_label=' Attention '

    if [[ "${preview_min_width}" =~ ^[0-9]+$ && "${preview_min_width}" -gt 0 ]]; then
        client_width="$(tmux display-message -p '#{client_width}')"
        if [[ "${client_width}" =~ ^[0-9]+$ && "${client_width}" -lt "${preview_min_width}" ]]; then
            narrow_client=true
            [[ "${preview_pane}" = 'true' ]] && preview_starts_hidden=true
        fi
    fi

    local -a fzf_args
    fzf_args=(--exit-0 --reverse --ansi --tmux "${3}" --with-nth=2..)

    fzf_version=$(fzf --version | awk '{print $1}')

    if ! fzf_at_least '0.53.0'; then
        echo "tmux-fzf-jump requires fzf >= 0.53.0 (found ${fzf_version})" >&2
        return 1
    fi

    if [[ "${narrow_client}" = true ]] && fzf_at_least '0.60.2'; then
        fzf_args+=(--no-input)
        input_hidden=true
    fi

    if fzf_at_least '0.58.0'; then
        if [[ "${input_hidden}" = false ]]; then
            fzf_args+=(--input-border --input-label=' Search (? for help) ' --info=inline-right)
        fi
        fzf_args+=(
            --list-border --list-label="${list_label}"
            --preview-border --preview-label=' Preview '
        )
        has_border_styling=true
    fi
    if [[ "${input_hidden}" = false ]] && fzf_at_least '0.61.0'; then
        fzf_args+=(--ghost 'type to search...')
    fi
    [[ "${has_border_styling}" = false ]] && fzf_args+=(--preview-label=preview)

    if [[ "${preview_pane}" = 'true' ]]; then
        preview_window="${4}"
        [[ "${preview_starts_hidden}" = true ]] && preview_window+=",hidden"
        fzf_args+=(
            --preview "tmux capture-pane -ep -S -\${FZF_PREVIEW_LINES:-30} -t {1} | awk \"{a[NR]=\\\$0} END{for(i=NR;i>0;i--) if(a[i]~/[^ \\t]/){for(j=1;j<=i;j++) print a[j]; exit}}\" | tail -n \${FZF_PREVIEW_LINES:-30}"
            --preview-window="${preview_window}"
        )
    fi

    local session_icon="${5}" window_icon="${6}" pane_icon="${7}" indent="${8}" separator="${9}"
    local highlight_color="${10}" activity_color="${11}"
    local attention_icon_input attention_icon_blocked attention_icon_review attention_icon_done attention_icon_working
    attention_icon_input="$(get_tmux_option '@tmux_attention_icon_input' "${default_attention_icon_input}")"
    attention_icon_blocked="$(get_tmux_option '@tmux_attention_icon_blocked' "${default_attention_icon_blocked}")"
    attention_icon_review="$(get_tmux_option '@tmux_attention_icon_review' "${default_attention_icon_review}")"
    attention_icon_done="$(get_tmux_option '@tmux_attention_icon_done' "${default_attention_icon_done}")"
    attention_icon_working="$(get_tmux_option '@tmux_attention_icon_working' "${default_attention_icon_working}")"

    export _FZJ_SI="${session_icon}" _FZJ_WI="${window_icon}" _FZJ_PI="${pane_icon}"
    export _FZJ_IN="${indent}" _FZJ_SEP="${separator}"
    export _FZJ_HC="${highlight_color}" _FZJ_AC="${activity_color}"
    export _FZJ_AI="${attention_icon_input}" _FZJ_AB="${attention_icon_blocked}"
    export _FZJ_AR="${attention_icon_review}" _FZJ_AD="${attention_icon_done}"
    export _FZJ_AW="${attention_icon_working}"

    _fzj_list() {
        local cs cw cp view
        view="${1:-}"
        if [[ -z "${view}" && -n "${_FZJ_VIEW_FILE:-}" && -f "${_FZJ_VIEW_FILE}" ]]; then
            view="$(<"${_FZJ_VIEW_FILE}")"
        fi
        [[ -n "${view}" ]] || view='all'

        # One display-message for all three current-target fields rather than three.
        IFS=$'\t' read -r cs cw cp <<< "$(tmux display-message -p $'#{session_name}\t#{window_index}\t#{pane_id}')"
        # Optional: hide sessions whose name matches @fzf_pane_switch_exclude-sessions
        # (a glob such as "phone-*"). Empty by default, so nothing is hidden. Lets a
        # caller exclude derived/mirror sessions without this plugin knowing about them.
        local excl_pat; excl_pat="$(get_tmux_option '@fzf_pane_switch_exclude-sessions' '')"
        local -a excl=()
        [ -n "${excl_pat}" ] && excl=(-f "#{?#{m:${excl_pat},#{session_name}},0,1}")

        if [[ "${view}" = 'attention' ]]; then
            # Attention is pane-scoped, so this view intentionally flattens the
            # hierarchy and includes marked panes even in single-pane windows.
            # Sort by tmux-attention's priority, then newest marker first.
            tmux list-panes -a "${excl[@]}" -F $'#{session_name}\t#{window_index}\t#{pane_index}\t#{pane_id}\t#{window_name}\t#{pane_current_command}\t#{@agent_pane_attention}\t#{session_id}\t#{@agent_pane_attention_reason}\t#{@pane_name}\t#{@agent_pane_attention_updated_at}' | \
                awk -F'\t' -v pane_icon="${_FZJ_PI}" -v sep="${_FZJ_SEP}" -v cur="${cp}" -v hc="${_FZJ_HC}" -v ac="${_FZJ_AC}" -v ai="${_FZJ_AI}" -v ab="${_FZJ_AB}" -v ar="${_FZJ_AR}" -v ad="${_FZJ_AD}" -v now="$(date +%s)" '
                    function marker_age(updated, delta) {
                        if (updated !~ /^[0-9]+$/ || updated == 0) return ""
                        delta = now - updated
                        if (delta < 0) delta = 0
                        if (delta < 60) return delta "s"
                        if (delta < 3600) return int(delta / 60) "m"
                        if (delta < 86400) return int(delta / 3600) "h"
                        return int(delta / 86400) "d"
                    }
                    $7=="input" || $7=="blocked" || $7=="review" || $7=="done" {
                        priority = ($7=="input") ? 0 : (($7=="blocked") ? 1 : (($7=="review") ? 2 : 3))
                        updated = ($11 ~ /^[0-9]+$/) ? $11 : 0
                        newest = 9999999999 - updated
                        b = ($4==cur) ? "\033[1;38;2;" hc "m" : ""; r = b!="" ? "\033[0m" : ""
                        state_icon = ($7=="input") ? ai : (($7=="blocked") ? ab : (($7=="review") ? ar : ad))
                        if (state_icon == "") state_icon = pane_icon
                        row_icon = "\033[38;2;" ac "m" state_icon "\033[0m" b
                        label = $1 " " sep " " $5 " " sep " " (($10 != "") ? $10 : $6)
                        rsn = ($9 != "") ? " \033[2m(" $9 ")\033[0m" : ""
                        age = marker_age(updated)
                        age_text = (age != "") ? " \033[2m" age "\033[0m" : ""
                        printf "%d:%010d:%s:%05d:%05d %s %s%s [%s] %s%s%s%s\n", priority, newest, $8, $2, $3, $4, b, row_icon, $7, label, r, rsn, age_text
                    }' | sort | cut -d' ' -f2-
            return
        fi

        {
            # Sessions sorted by most recently attached (newest first via inverted timestamp).
            # "${excl[@]}" applies the @fzf_pane_switch_exclude-sessions filter when set.
            tmux list-sessions "${excl[@]}" -F $'#{session_last_attached}\t#{session_name}\t#{session_id}' | \
                awk -F'\t' -v icon="${_FZJ_SI}" -v cur="${cs}" -v hc="${_FZJ_HC}" '{
                    ts = 9999999999 - $1
                    b = ($2==cur) ? "\033[1;38;2;" hc "m" : ""; r = b!="" ? "\033[0m" : ""
                    printf "%010d:%s:00000:00000:0 %s %s%s %s%s\n", ts, $3, $3, b, icon, $2, r
                }'
            # Always list every window beneath its session — including the sole
            # window of a single-window session — so its activity and
            # tmux-attention marker are never hidden. (Panes below still collapse
            # when a window has only one.)
            tmux list-windows -a "${excl[@]}" -F $'#{session_last_attached}\t#{session_name}\t#{window_index}\t#{window_id}\t#{window_name}\t#{window_panes}\t#{session_windows}\t#{window_activity_flag}\t#{@agent_attention}\t#{session_id}\t#{@agent_attention_reason}\t#{@agent_context_active}' | \
                awk -F'\t' -v indent="${_FZJ_IN}" -v window_icon="${_FZJ_WI}" -v sep="${_FZJ_SEP}" -v cur_s="${cs}" -v cur_w="${cw}" -v hc="${_FZJ_HC}" -v ac="${_FZJ_AC}" -v ai="${_FZJ_AI}" -v ab="${_FZJ_AB}" -v ar="${_FZJ_AR}" -v ad="${_FZJ_AD}" -v aw="${_FZJ_AW}" '{
                    ts = 9999999999 - $1
                    b = ($2==cur_s && $3==cur_w) ? "\033[1;38;2;" hc "m" : ""; r = b!="" ? "\033[0m" : ""
                    act = ($8=="1") ? " \033[38;2;" ac "m●\033[0m" : ""
                    known = ($9=="input" || $9=="blocked" || $9=="review" || $9=="done")
                    state_icon = known ? (($9=="input") ? ai : (($9=="blocked") ? ab : (($9=="review") ? ar : ad))) : (($12=="1") ? aw : "")
                    row_icon = indent window_icon
                    if (state_icon != "") row_icon = indent "\033[38;2;" ac "m" state_icon "\033[0m" b
                    rsn = (known && $11!="") ? " \033[2m(" $11 ")\033[0m" : ""
                    printf "%010d:%s:%05d:00000:1 %s %s%s %s %s %s%s%s%s\n", ts, $10, $3, $4, b, row_icon, $2, sep, $5, r, act, rsn
                }'
            tmux list-panes -a "${excl[@]}" -F $'#{session_last_attached}\t#{session_name}\t#{window_index}\t#{pane_index}\t#{pane_id}\t#{window_name}\t#{window_panes}\t#{pane_current_command}\t#{pane_unseen_changes}\t#{pane_current_path}\t#{@agent_pane_attention}\t#{session_id}\t#{@agent_pane_attention_reason}\t#{@agent_pane_context_active}\t#{@pane_name}' | \
                awk -F'\t' -v indent="${_FZJ_IN}${_FZJ_IN}" -v pane_icon="${_FZJ_PI}" -v sep="${_FZJ_SEP}" -v cur="${cp}" -v hc="${_FZJ_HC}" -v ac="${_FZJ_AC}" -v ai="${_FZJ_AI}" -v ab="${_FZJ_AB}" -v ar="${_FZJ_AR}" -v ad="${_FZJ_AD}" -v aw="${_FZJ_AW}" '$7 > 1 {
                    ts = 9999999999 - $1
                    b = ($5==cur) ? "\033[1;38;2;" hc "m" : ""; r = b!="" ? "\033[0m" : ""
                    act = ($9=="1") ? " \033[38;2;" ac "m●\033[0m" : ""
                    known = ($11=="input" || $11=="blocked" || $11=="review" || $11=="done")
                    state_icon = known ? (($11=="input") ? ai : (($11=="blocked") ? ab : (($11=="review") ? ar : ad))) : (($14=="1") ? aw : "")
                    row_icon = indent pane_icon
                    if (state_icon != "") row_icon = indent "\033[38;2;" ac "m" state_icon "\033[0m" b
                    rsn = (known && $13!="") ? " \033[2m(" $13 ")\033[0m" : ""
                    label = $2 " " sep " " (($15 != "") ? $15 : $8)
                    printf "%010d:%s:%05d:%05d:2 %s %s%s %s%s%s%s\n", ts, $12, $3, $4, $5, b, row_icon, label, r, act, rsn
                }'
        } | sort | cut -d' ' -f2-
    }
    # Export get_tmux_option too: the reload() bindings run _fzj_list in a fresh
    # bash, which otherwise lacks it and silently drops the session-exclusion
    # filter after any kill/rename/new/detach action.
    export -f _fzj_list get_tmux_option

    local full_hdr='  ctrl-a : all / attention\n  ctrl-x : kill\n  ctrl-r : rename\n  ctrl-n : new\n  ctrl-d : detach\n  ctrl-p : toggle preview\n  ?      : close'
    local short_hdr=''
    [[ "${has_border_styling}" = false ]] && short_hdr='  ctrl-a: view  ctrl-p: preview  ?: help'
    local _help_state _view_state
    _help_state=$(mktemp)
    _view_state=$(mktemp)
    printf '%s\n' "${initial_view}" > "${_view_state}"
    export _FZJ_VIEW_FILE="${_view_state}"
    # shellcheck disable=SC2064  # bake the path in now; the var is local
    trap "rm -f '${_help_state}' '${_view_state}'" EXIT INT TERM
    local action_cmd toggle_cmd
    action_cmd="$(shell_quote "${BASH_SOURCE[0]}") --action"
    toggle_cmd="$(shell_quote "${BASH_SOURCE[0]}") --toggle-view $(shell_quote "${_view_state}") $(shell_quote "${has_border_styling}")"

    [[ -n "${short_hdr}" ]] && fzf_args+=(--header "${short_hdr}")
    fzf_args+=(
        --bind "?:transform(if [ \"\$(cat '${_help_state}')\" = 1 ]; then echo 0 > '${_help_state}'; echo 'change-header(${short_hdr})'; else echo 1 > '${_help_state}'; echo 'change-header(${full_hdr})'; fi)"
        --bind "ctrl-a:transform(${toggle_cmd})"
        --bind "ctrl-x:execute(${action_cmd} kill {1})+reload(bash -c _fzj_list)"
        --bind "ctrl-r:execute(${action_cmd} rename {1})+reload(bash -c _fzj_list)"
        --bind "ctrl-n:execute(${action_cmd} new {1})+reload(bash -c _fzj_list)"
        --bind "ctrl-d:execute-silent(${action_cmd} detach {1})+reload(bash -c _fzj_list)"
        --bind 'ctrl-p:toggle-preview'
    )

    local initial_list
    initial_list="$(_fzj_list)"
    if [[ "${initial_view}" = 'attention' && -z "${initial_list}" ]]; then
        tmux display-message 'No agents need attention'
        return 0
    fi

    pane=$(
        printf '%s\n' "${initial_list}" |
        SHELL=/bin/sh fzf "${fzf_args[@]}"
    )

    target="${pane%% *}"

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
            # Empty or unrecognized target (e.g. fzf was cancelled with Esc):
            # the picker runs in a popup via `fzf --tmux`, so the client never
            # left the current pane and there's nothing to switch back to.
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
            current_name=$(tmux display-message -p -t "${target}" '#{@pane_name}')
            printf "Rename pane [%s]: " "${current_name}"
            read -r new_name
            if [[ -n "${new_name}" ]]; then
                tmux set-option -p -t "${target}" @pane_name "${new_name}"
                tmux select-pane -t "${target}" -T "${new_name}"
            fi
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
  ${0##*/} [--view all|attention] [--test]
  ${0##*/} --action <kill|rename|new|detach> <target>
  ${0##*/} <preview-pane> <preview-min-width> <fzf-window-position> <preview-window-position> <session-icon> <window-icon> <pane-icon> <indent> <separator> <highlight-color> <activity-color>

Run with no arguments to use the default picker options.
EOF
}

function print_toggle_view_action() {
    local state_file="${1}" has_border_styling="${2}" current_view next_view next_label

    [[ -f "${state_file}" && ! -L "${state_file}" ]] || return 1
    current_view="$(<"${state_file}")"
    case "${current_view}" in
        all)
            next_view='attention'
            next_label=' Attention '
            ;;
        attention)
            next_view='all'
            next_label=' Tmux '
            ;;
        *) return 1 ;;
    esac

    printf '%s\n' "${next_view}" > "${state_file}"
    printf 'reload(bash -c _fzj_list)'
    if [[ "${has_border_styling}" = 'true' ]]; then
        printf '+change-list-label(%s)' "${next_label}"
    fi
    printf '\n'
}

function vercomp() {
  local v1="$1"
  local v2="$2"

  IFS='.' read -r -a ver1 <<< "$v1"
  IFS='.' read -r -a ver2 <<< "$v2"

  for i in 0 1 2; do
    local num1="${ver1[i]:-0}"
    local num2="${ver2[i]:-0}"
    # Strip any non-numeric suffix (e.g. a packager's "0.65.1-1") so the
    # arithmetic comparison below never chokes on a build-metadata tag.
    num1="${num1%%[!0-9]*}"; num1="${num1:-0}"
    num2="${num2%%[!0-9]*}"; num2="${num2:-0}"

    if (( num1 > num2 )); then
      return 1
    elif (( num1 < num2 )); then
      return 2
    fi
  done

  return 0
}

# True when the detected fzf version (${fzf_version}, a local of the calling
# select_pane, visible here via bash dynamic scoping) is >= the given minimum.
# vercomp returns 1 only when its first argument is the newer version.
function fzf_at_least() {
    vercomp "$1" "${fzf_version}"
    [[ $? -ne 1 ]]
}

function print_fixture() {
    local session_icon="${default_session_icon}" window_icon="${default_window_icon}" pane_icon="${default_pane_icon}"
    local indent="${default_indent}" separator="${default_separator}"
    local highlight_color="${default_highlight_color}" activity_color="${default_activity_color}"
    local reset=$'\033[0m'
    local highlight=$'\033[1;38;2;166;227;161m'
    local activity=$'\033[38;2;249;226;175m'
    local dim=$'\033[2m'

    printf "\$1 %s%s workspace%s\n" "${highlight}" "${session_icon}" "${reset}"
    printf "@1 %s workspace %s dashboard%s %s●%s\n" "${highlight}${indent}${activity}${default_attention_icon_input}${reset}${highlight}" "${separator}" "${reset}" "${activity}" "${reset}"
    printf "%%1 %s workspace %s api-agent%s %s(task_running)%s\n" "${highlight}${indent}${indent}${activity}${default_attention_icon_input}${reset}${highlight}" "${separator}" "${reset}" "${dim}" "${reset}"
    printf "%%2 %s workspace %s codex\n" "${indent}${indent}${activity}${default_attention_icon_working}${reset}" "${separator}"
    printf "%%3 %s workspace %s fish\n" "${indent}${indent}${pane_icon}" "${separator}"
    printf "@2 %s project %s api %s(approval_required)%s\n" "${indent}${window_icon}" "${separator}" "${dim}" "${reset}"
    printf "@3 %s project %s review\n" "${indent}${activity}${default_attention_icon_review}${reset}" "${separator}"
    printf "@5 %s project %s active-agent\n" "${indent}${activity}${default_attention_icon_working}${reset}" "${separator}"
    printf "\$2 %s archive\n" "${session_icon}"
    printf "@4 %s archive %s done\n" "${indent}${window_icon}" "${separator}"
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

if [[ "${1:-}" == '--toggle-view' ]]; then
    if [[ $# -ne 3 ]]; then
        usage >&2
        exit 2
    fi
    print_toggle_view_action "${2}" "${3}"
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

initial_view='all'
if [[ "${1:-}" == '--view' ]]; then
    if [[ $# -lt 2 ]]; then
        usage >&2
        exit 2
    fi
    initial_view="${2}"
    shift 2
elif [[ "${1:-}" == --view=* ]]; then
    initial_view="${1#--view=}"
    shift
fi

case "${initial_view}" in
    all|attention) ;;
    *)
        printf 'Unknown picker view: %s\n' "${initial_view}" >&2
        usage >&2
        exit 2
        ;;
esac

# --test is an alias of the no-argument invocation: both run the picker with
# all defaults. Eleven arguments come from select_pane.tmux and pass through
# positionally unchanged.
if [[ $# -eq 0 || "${1:-}" == '--test' ]]; then
    select_pane "${default_preview_pane}" "${default_preview_min_width}" "${default_fzf_window_position}" "${default_fzf_preview_window_position}" \
        "${default_session_icon}" "${default_window_icon}" "${default_pane_icon}" "${default_indent}" "${default_separator}" \
        "${default_highlight_color}" "${default_activity_color}" "${initial_view}"
elif [[ $# -eq 11 ]]; then
    select_pane "$@" "${initial_view}"
else
    usage >&2
    exit 2
fi

#!/usr/bin/env bash

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

function select_pane() {
    local fzf_version fzf_version_comparison has_border_styling=false
    local current_pane pane target

    current_pane=$(tmux display-message -p '#{pane_id}')

    local -a fzf_args
    fzf_args=(--exit-0 --print-query --reverse --ansi --tmux "${2}" --with-nth=2..)

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

    export _FZJ_SI="${session_icon}" _FZJ_WI="${window_icon}" _FZJ_PI="${pane_icon}"
    export _FZJ_IN="${indent}" _FZJ_SEP="${separator}"
    export _FZJ_HC="${highlight_color}" _FZJ_AC="${activity_color}"

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
                    printf "%010d:00000:00000:0 %s %s%s %s  %s%s\n", ts, $3, b, icon, $2, ($4==1?"":$4" windows"), r
                }'
            tmux list-windows -aF $'#{session_last_attached}\t#{session_name}\t#{window_index}\t#{session_name}:#{window_index}\t#{window_name}\t#{window_panes}\t#{session_windows}\t#{window_activity_flag}' | \
                awk -F'\t' -v icon="${_FZJ_IN}${_FZJ_WI}" -v sep="${_FZJ_SEP}" -v cur_s="${cs}" -v cur_w="${cw}" -v hc="${_FZJ_HC}" -v ac="${_FZJ_AC}" '$7 > 1 {
                    ts = 9999999999 - $1
                    b = ($2==cur_s && $3==cur_w) ? "\033[1;38;2;" hc "m" : ""; r = b!="" ? "\033[0m" : ""
                    act = ($8=="1") ? " \033[38;2;" ac "m●\033[0m" : ""
                    printf "%010d:%05d:00000:1 %s %s%s %s %s %s  %s%s%s\n", ts, $3, $4, b, icon, $2, sep, $5, ($6==1?"":$6" panes"), r, act
                }'
            tmux list-panes -aF $'#{session_last_attached}\t#{session_name}\t#{window_index}\t#{pane_index}\t#{pane_id}\t#{window_name}\t#{pane_title}\t#{window_panes}\t#{pane_current_command}\t#{pane_unseen_changes}\t#{pane_current_path}' | \
                awk -F'\t' -v icon="${_FZJ_IN}${_FZJ_IN}${_FZJ_PI}" -v sep="${_FZJ_SEP}" -v cur="${cp}" -v hc="${_FZJ_HC}" -v ac="${_FZJ_AC}" -v home="${HOME}" '$8 > 1 {
                    ts = 9999999999 - $1
                    b = ($5==cur) ? "\033[1;38;2;" hc "m" : ""; r = b!="" ? "\033[0m" : ""
                    act = ($10=="1") ? " \033[38;2;" ac "m●\033[0m" : ""
                    cmd = ($9 ~ /^(bash|sh|zsh|fish|dash)$/) ? "" : " \033[2m(" $9 ")\033[0m"
                    p = $11
                    if (home != "" && index(p, home) == 1) sub(home, "~", p)
                    n = split(p, parts, "/")
                    if (n <= 2) short_path = p
                    else { prefix = (parts[1] == "~") ? "~/" : ""; short_path = prefix parts[n-1] "/" parts[n] }
                    printf "%010d:%05d:%05d:2 %s %s%s %s %s %s %s %s%s%s%s\n", ts, $3, $4, $5, b, icon, $2, sep, $6, sep, short_path, cmd, r, act
                }'
        } | sort | cut -d' ' -f2-
    }
    export -f _fzj_list

    local full_hdr='  ctrl-x : kill\n  ctrl-r : rename\n  ctrl-n : new\n  ctrl-d : detach\n  ctrl-p : toggle preview\n  ?      : close'
    local short_hdr=''
    [[ "${has_border_styling}" = false ]] && short_hdr='  ctrl-p: preview  ?: help'
    local _help_state
    _help_state=$(mktemp)

    [[ -n "${short_hdr}" ]] && fzf_args+=(--header "${short_hdr}")
    fzf_args+=(
        --bind "?:transform(if [ \"\$(cat '${_help_state}')\" = 1 ]; then echo 0 > '${_help_state}'; echo 'change-header(${short_hdr})'; else echo 1 > '${_help_state}'; echo 'change-header(${full_hdr})'; fi)"
        --bind $'ctrl-x:execute-silent(t={1}; case $t in \\$*) tmux kill-session -t "$t";; %*) tmux kill-pane -t "$t";; *) tmux kill-window -t "$t";; esac)+reload(bash -c _fzj_list)'
        --bind $'ctrl-r:execute(t={1}; case $t in \\$*) cur=$(tmux display-message -p -t "$t" \'#{session_name}\'); printf "Rename session [%s]: " "$cur"; read -r n; [ -n "$n" ] && tmux rename-session -t "$t" "$n";; %*) cur=$(tmux display-message -p -t "$t" \'#{pane_title}\'); printf "Rename pane [%s]: " "$cur"; read -r n; [ -n "$n" ] && tmux select-pane -t "$t" -T "$n";; *) cur=$(tmux display-message -p -t "$t" \'#{window_name}\'); printf "Rename window [%s]: " "$cur"; read -r n; [ -n "$n" ] && tmux rename-window -t "$t" "$n";; esac)+reload(bash -c _fzj_list)'
        --bind $'ctrl-n:execute(t={1}; case $t in \\$*) printf "New session name: "; read -r n; [ -n "$n" ] && tmux new-session -d -s "$n";; %*) win=$(tmux display-message -p -t "$t" \'#{session_name}:#{window_index}\'); tmux split-window -t "$win" -d;; *) sess=${t%%:*}; printf "New window name: "; read -r n; if [ -n "$n" ]; then tmux new-window -t "$sess:" -n "$n" -d; else tmux new-window -t "$sess:" -d; fi;; esac)+reload(bash -c _fzj_list)'
        --bind $'ctrl-d:execute-silent(t={1}; case $t in \\$*) tmux detach-client -s "$t";; esac)+reload(bash -c _fzj_list)'
        --bind 'ctrl-p:toggle-preview'
    )

    pane=$(
        _fzj_list |
        SHELL=/bin/sh fzf "${fzf_args[@]}" |
        tail -1
    )
    rm -f "${_help_state}"

    target=$(echo "${pane}" | awk '{print $1}')

    if [[ -z "${target}" ]]; then
        tmux switch-client -t "${current_pane}"
    else
        tmux switch-client -t "${target}"
    fi
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

# Check for required commands
command -v tmux >/dev/null 2>&1 || { echo "tmux not found"; exit 1; }
command -v fzf >/dev/null 2>&1 || { echo "fzf not found"; exit 1; }

if [[ "${1}" == '--test' ]]; then
    select_pane "${default_preview_pane}" "${default_fzf_window_position}" "${default_fzf_preview_window_position}" \
        "${default_session_icon}" "${default_window_icon}" "${default_pane_icon}" "${default_indent}" "${default_separator}" \
        "${default_highlight_color}" "${default_activity_color}"
    exit
fi

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

select_pane "${preview_pane}" "${fzf_window_position}" "${fzf_preview_window_position}" \
    "${session_icon}" "${window_icon}" "${pane_icon}" "${indent}" "${separator}" \
    "${highlight_color}" "${activity_color}"

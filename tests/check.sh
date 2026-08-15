#!/usr/bin/env bash
set -euo pipefail

# Without this, a failed assertion under `set -e` exits 1 with no output at all.
trap 'printf "check failed at line %s\n" "$LINENO" >&2' ERR

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"
source "${ROOT_DIR}/defaults.sh"

shellcheck select_pane.sh select_pane.tmux defaults.sh
bash -n select_pane.sh select_pane.tmux defaults.sh
grep -q -- '--action' select_pane.sh

test "$(./select_pane.sh --version)" = "$(cat VERSION)"

if command -v fzf >/dev/null 2>&1; then
    fzf_version="$(fzf --version | awk '{print $1}')"
    highest_version="$(printf '%s\n%s\n' "0.53.0" "${fzf_version}" | sort -V | tail -1)"
    test "${highest_version}" = "${fzf_version}"
else
    printf "fzf not found\n" >&2
    exit 1
fi

if ./select_pane.sh --action >/dev/null 2>&1; then
    printf "--action without arguments should fail\n" >&2
    exit 1
fi

if ./select_pane.sh true center >/dev/null 2>&1; then
    printf "partial picker arguments should fail\n" >&2
    exit 1
fi

if ./select_pane.sh --view unknown --test >/dev/null 2>&1; then
    printf "unknown picker view should fail\n" >&2
    exit 1
fi

view_state="$(mktemp)"
printf 'all\n' > "${view_state}"
toggle_output="$(./select_pane.sh --toggle-view "${view_state}" true)"
test "$(<"${view_state}")" = "attention"
grep -q 'reload(bash -c _fzj_list)' <<< "${toggle_output}"
grep -q 'change-list-label( Attention )' <<< "${toggle_output}"
toggle_output="$(./select_pane.sh --toggle-view "${view_state}" false)"
test "$(<"${view_state}")" = "all"
if grep -q 'change-list-label' <<< "${toggle_output}"; then
    printf "legacy fzf toggle should not emit a list-label action\n" >&2
    exit 1
fi
rm -f "${view_state}"

fixture_output="$(./select_pane.sh --fixture)"
# shellcheck disable=SC2016  # matching a literal $1 session id, not expanding
grep -q '^\$1 ' <<< "${fixture_output}"
grep -q '^@1 ' <<< "${fixture_output}"
grep -q '^%1 ' <<< "${fixture_output}"
grep -q 'workspace' <<< "${fixture_output}"
grep -q 'archive' <<< "${fixture_output}"
# A single-window session ($2 'archive') still lists its window row (@4), so a
# window's activity/attention marker is never hidden by single-window collapse.
# shellcheck disable=SC2016  # matching a literal $2 session id, not expanding
grep -q '^\$2 ' <<< "${fixture_output}"
grep -q '^@4 ' <<< "${fixture_output}"
# When tmux-attention records a reason, the picker surfaces it dimmed alongside
# the attention marker on the relevant window/pane row.
grep -q 'approval_required' <<< "${fixture_output}"
grep -q 'task_running' <<< "${fixture_output}"
grep -q 'active-agent' <<< "${fixture_output}"
if grep -Eq '[0-9]+ (panes?|windows?)' <<< "${fixture_output}"; then
    printf "session and window rows should not expose child counts to fzf search\n" >&2
    exit 1
fi
first_pane_line="$(grep '^%1 ' <<< "${fixture_output}")"
grep -q 'workspace / ' <<< "${first_pane_line}"
grep -q 'api-agent' <<< "${first_pane_line}"
grep -Fq "${default_attention_icon_input}" <<< "${first_pane_line}"
if grep -Fq "${default_pane_icon}" <<< "${first_pane_line}"; then
    printf "attention pane should replace the pane icon with its state icon\n" >&2
    exit 1
fi
second_pane_line="$(grep '^%2 ' <<< "${fixture_output}")"
grep -q 'workspace / ' <<< "${second_pane_line}"
grep -q 'codex' <<< "${second_pane_line}"
grep -Fq "${default_attention_icon_working}" <<< "${second_pane_line}"
if grep -Fq "${default_pane_icon}" <<< "${second_pane_line}"; then
    printf "working pane should replace the pane icon with the working icon\n" >&2
    exit 1
fi
third_pane_line="$(grep '^%3 ' <<< "${fixture_output}")"
grep -q 'workspace / ' <<< "${third_pane_line}"
grep -q 'fish' <<< "${third_pane_line}"
grep -Fq "${default_pane_icon}" <<< "${third_pane_line}"
active_agent_line="$(grep '^@5 ' <<< "${fixture_output}")"
grep -Fq "${default_attention_icon_working}" <<< "${active_agent_line}"
if grep -Fq "${default_window_icon}" <<< "${active_agent_line}"; then
    printf "active-agent window should replace the window icon with the working icon\n" >&2
    exit 1
fi

if command -v tmux >/dev/null 2>&1; then
    real_tmux="$(command -v tmux)"
    socket_path="/tmp/tmux-fzj-check-$$"
    shim_dir="$(mktemp -d)"
    cleanup() {
        tmux -S "${socket_path}" kill-server >/dev/null 2>&1 || true
        rm -f "${socket_path}"
        rm -rf "${shim_dir}"
    }
    trap cleanup EXIT

    printf '#!/usr/bin/env bash\nif [[ -n "${FZJ_TEST_CLIENT_WIDTH:-}" && "${1:-}" == "display-message" && "${*: -1}" == "#{client_width}" ]]; then\n    printf "%%s\\n" "${FZJ_TEST_CLIENT_WIDTH}"\n    exit 0\nfi\nexec %q -S %q "$@"\n' "${real_tmux}" "${socket_path}" > "${shim_dir}/tmux"
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'if [[ "${1:-}" == "--version" ]]; then printf "0.74.2\\n"; exit; fi' \
        'if [[ -n "${FZJ_TEST_FZF_ARGS:-}" ]]; then printf "%s\\n" "$@" > "${FZJ_TEST_FZF_ARGS}"; fi' \
        'if [[ -n "${FZJ_ARGS_CAPTURE:-}" ]]; then printf "%s\\n" "$@" > "${FZJ_ARGS_CAPTURE}"; fi' \
        'if [[ -n "${FZJ_LIST_CAPTURE:-}" ]]; then cat > "${FZJ_LIST_CAPTURE}"; else cat >/dev/null; fi' > "${shim_dir}/fzf"
    chmod +x "${shim_dir}/tmux"
    chmod +x "${shim_dir}/fzf"

    tmux -S "${socket_path}" -f /dev/null new-session -d -s fzj-check || true

    if tmux -S "${socket_path}" has-session -t fzj-check >/dev/null 2>&1; then
        tmux -S "${socket_path}" run-shell "${ROOT_DIR}/select_pane.tmux"

        # tmux >= 3.7 prints nothing for `list-keys -T prefix j` (trailing key
        # filter), so grep the full table for the j binding instead.
        binding="$(tmux -S "${socket_path}" list-keys -T prefix | awk '$4 == "j"')"
        grep -q 'select_pane.sh' <<< "${binding}"
        grep -q "'100'" <<< "${binding}"
        grep -q 'center,70%,80%' <<< "${binding}"

        # An option explicitly set to empty must override the default, not fall
        # back to it. The separator arg sits immediately before the highlight
        # color, so an empty separator renders as "'' '166;227;161'".
        tmux -S "${socket_path}" set-option -g @fzf_pane_switch_separator ""
        tmux -S "${socket_path}" set-option -g @fzf_pane_switch_preview-min-width "72"
        tmux -S "${socket_path}" run-shell "${ROOT_DIR}/select_pane.tmux"
        empty_binding="$(tmux -S "${socket_path}" list-keys -T prefix | awk '$4 == "j"')"
        grep -q "'72'" <<< "${empty_binding}"
        grep -q "'' '166;227;161'" <<< "${empty_binding}"

        # The no-argument path must resolve the same options the binding does,
        # so running this script directly matches pressing the bound key.
        # Asserts on the session icon: this server still has a single-pane
        # window, so only session and window rows render here.
        option_list_capture="$(mktemp)"
        tmux -S "${socket_path}" set-option -g @fzf_pane_switch_session-icon "ZZ"
        FZJ_LIST_CAPTURE="${option_list_capture}" PATH="${shim_dir}:${PATH}" \
            ./select_pane.sh >/dev/null
        grep -Fq "ZZ" "${option_list_capture}"
        if grep -Fq "${default_session_icon}" "${option_list_capture}"; then
            printf "no-argument path ignored @fzf_pane_switch_session-icon\n" >&2
            exit 1
        fi

        # Restore defaults: the assertions below render through the no-argument
        # path, which now reads these options rather than ignoring them.
        tmux -S "${socket_path}" set-option -gu @fzf_pane_switch_session-icon
        tmux -S "${socket_path}" set-option -gu @fzf_pane_switch_separator
        tmux -S "${socket_path}" set-option -gu @fzf_pane_switch_preview-min-width

        mobile_fzf_args="${shim_dir}/mobile-fzf-args"
        FZJ_TEST_CLIENT_WIDTH=80 FZJ_TEST_FZF_ARGS="${mobile_fzf_args}" PATH="${shim_dir}:${PATH}" \
            ./select_pane.sh true 100 center,70%,80% right,,,nowrap S W P '  ' / '166;227;161' '249;226;175' >/dev/null
        grep -Fxq -- '--no-input' "${mobile_fzf_args}"
        grep -Fxq -- '--preview-window=right,,,nowrap,hidden' "${mobile_fzf_args}"
        if grep -Fxq -- '--input-border' "${mobile_fzf_args}"; then
            printf "narrow picker should not render the search input border\n" >&2
            exit 1
        fi
        if grep -Fxq -- '--ghost' "${mobile_fzf_args}"; then
            printf "narrow picker should not configure hidden search ghost text\n" >&2
            exit 1
        fi

        desktop_fzf_args="${shim_dir}/desktop-fzf-args"
        FZJ_TEST_CLIENT_WIDTH=120 FZJ_TEST_FZF_ARGS="${desktop_fzf_args}" PATH="${shim_dir}:${PATH}" \
            ./select_pane.sh true 100 center,70%,80% right,,,nowrap S W P '  ' / '166;227;161' '249;226;175' >/dev/null
        grep -Fxq -- '--input-border' "${desktop_fzf_args}"
        grep -Fxq -- '--ghost' "${desktop_fzf_args}"
        grep -Fxq -- '--preview-window=right,,,nowrap' "${desktop_fzf_args}"
        if grep -Fxq -- '--no-input' "${desktop_fzf_args}"; then
            printf "desktop picker should retain its search input\n" >&2
            exit 1
        fi

        session_id="$(tmux -S "${socket_path}" display-message -p -t fzj-check '#{session_id}')"
        window_id="$(tmux -S "${socket_path}" display-message -p -t fzj-check:0 '#{window_id}')"
        pane_id="$(tmux -S "${socket_path}" display-message -p -t fzj-check:0.0 '#{pane_id}')"

        all_list_capture="$(mktemp)"
        all_args_capture="$(mktemp)"
        FZJ_LIST_CAPTURE="${all_list_capture}" FZJ_ARGS_CAPTURE="${all_args_capture}" \
            PATH="${shim_dir}:${PATH}" ./select_pane.sh --test >/dev/null
        # shellcheck disable=SC2016  # matching literal tmux target prefixes
        grep -Eq '^[$@%]' "${all_list_capture}"
        grep -q 'ctrl-a:transform' "${all_args_capture}"
        grep -q -- '--list-label= Tmux ' "${all_args_capture}"

        printf 'named-pane\n' | PATH="${shim_dir}:${PATH}" ./select_pane.sh --action rename "${pane_id}" >/dev/null
        test "$(tmux -S "${socket_path}" show-options -pqv -t "${pane_id}" @pane_name)" = "named-pane"

        printf 'renamed-session\n' | PATH="${shim_dir}:${PATH}" ./select_pane.sh --action rename "${session_id}" >/dev/null
        tmux -S "${socket_path}" has-session -t renamed-session

        printf 'renamed-window\n' | PATH="${shim_dir}:${PATH}" ./select_pane.sh --action rename "${window_id}" >/dev/null
        test "$(tmux -S "${socket_path}" display-message -p -t renamed-session:0 '#{window_name}')" = "renamed-window"

        tmux -S "${socket_path}" set-option -pq -t "${pane_id}" @agent_pane_attention done
        tmux -S "${socket_path}" set-option -pq -t "${pane_id}" @agent_pane_attention_reason task_complete
        tmux -S "${socket_path}" set-option -pq -t "${pane_id}" @agent_pane_attention_updated_at "$(date +%s)"
        attention_list_capture="$(mktemp)"
        attention_args_capture="$(mktemp)"
        FZJ_LIST_CAPTURE="${attention_list_capture}" FZJ_ARGS_CAPTURE="${attention_args_capture}" \
            PATH="${shim_dir}:${PATH}" ./select_pane.sh --view attention --test >/dev/null
        grep -Fq "${pane_id} " "${attention_list_capture}"
        grep -Fq "${default_attention_icon_done}" "${attention_list_capture}"
        grep -Fq '[done]' "${attention_list_capture}"
        grep -q 'renamed-session / renamed-window / named-pane' "${attention_list_capture}"
        grep -q 'task_complete' "${attention_list_capture}"
        if grep -Eq '^[$@]' "${attention_list_capture}"; then
            printf "attention view should contain pane targets only\n" >&2
            exit 1
        fi
        grep -q 'ctrl-a:transform' "${attention_args_capture}"
        grep -q -- '--list-label= Attention ' "${attention_args_capture}"

        printf 'created-session\n' | PATH="${shim_dir}:${PATH}" ./select_pane.sh --action new "${session_id}" >/dev/null
        tmux -S "${socket_path}" has-session -t created-session

        printf 'created-window\n' | PATH="${shim_dir}:${PATH}" ./select_pane.sh --action new "${window_id}" >/dev/null
        tmux -S "${socket_path}" list-windows -t renamed-session -F '#{window_name}' | grep -q '^created-window$'

        pane_count_before="$(tmux -S "${socket_path}" list-panes -t "${window_id}" | wc -l | tr -d ' ')"
        PATH="${shim_dir}:${PATH}" ./select_pane.sh --action new "${pane_id}" >/dev/null
        pane_count_after="$(tmux -S "${socket_path}" list-panes -t "${window_id}" | wc -l | tr -d ' ')"
        test "${pane_count_after}" -gt "${pane_count_before}"

        tmux -S "${socket_path}" new-window -t renamed-session: -n kill-cancel -d
        kill_cancel_id="$(tmux -S "${socket_path}" display-message -p -t renamed-session:kill-cancel '#{window_id}')"
        printf 'n\n' | PATH="${shim_dir}:${PATH}" ./select_pane.sh --action kill "${kill_cancel_id}" >/dev/null
        tmux -S "${socket_path}" list-windows -t renamed-session -F '#{window_name}' | grep -q '^kill-cancel$'

        tmux -S "${socket_path}" new-window -t renamed-session: -n kill-confirm -d
        kill_confirm_id="$(tmux -S "${socket_path}" display-message -p -t renamed-session:kill-confirm '#{window_id}')"
        printf 'yes\n' | PATH="${shim_dir}:${PATH}" ./select_pane.sh --action kill "${kill_confirm_id}" >/dev/null
        if tmux -S "${socket_path}" list-windows -t renamed-session -F '#{window_name}' | grep -q '^kill-confirm$'; then
            printf "confirmed kill should remove selected window\n" >&2
            exit 1
        fi

        rm -f "${all_list_capture}" "${all_args_capture}" "${attention_list_capture}" "${attention_args_capture}"
    else
        printf "skipping tmux smoke check: could not create isolated tmux server\n" >&2
    fi
fi

printf "ok\n"

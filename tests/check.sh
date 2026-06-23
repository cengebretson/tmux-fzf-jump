#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

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

fixture_output="$(./select_pane.sh --fixture)"
grep -q '^\$1 ' <<< "${fixture_output}"
grep -q '^@1 ' <<< "${fixture_output}"
grep -q '^%1 ' <<< "${fixture_output}"
grep -q 'workspace' <<< "${fixture_output}"
grep -q 'archive' <<< "${fixture_output}"
# A single-window session ($2 'archive') still lists its window row (@4), so a
# window's activity/attention marker is never hidden by single-window collapse.
grep -q '^\$2 ' <<< "${fixture_output}"
grep -q '^@4 ' <<< "${fixture_output}"

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

    printf '#!/usr/bin/env bash\nexec %q -S %q "$@"\n' "${real_tmux}" "${socket_path}" > "${shim_dir}/tmux"
    chmod +x "${shim_dir}/tmux"

    tmux -S "${socket_path}" -f /dev/null new-session -d -s fzj-check || true

    if tmux -S "${socket_path}" has-session -t fzj-check >/dev/null 2>&1; then
        tmux -S "${socket_path}" run-shell "${ROOT_DIR}/select_pane.tmux"

        binding="$(tmux -S "${socket_path}" list-keys -T prefix j)"
        grep -q 'select_pane.sh' <<< "${binding}"
        grep -q "'100'" <<< "${binding}"
        grep -q 'center,70%,80%' <<< "${binding}"

        # An option explicitly set to empty must override the default, not fall
        # back to it. The separator arg sits immediately before the highlight
        # color, so an empty separator renders as "'' '166;227;161'".
        tmux -S "${socket_path}" set-option -g @fzf_pane_switch_separator ""
        tmux -S "${socket_path}" set-option -g @fzf_pane_switch_preview-min-width "72"
        tmux -S "${socket_path}" run-shell "${ROOT_DIR}/select_pane.tmux"
        empty_binding="$(tmux -S "${socket_path}" list-keys -T prefix j)"
        grep -q "'72'" <<< "${empty_binding}"
        grep -q "'' '166;227;161'" <<< "${empty_binding}"

        session_id="$(tmux -S "${socket_path}" display-message -p -t fzj-check '#{session_id}')"
        window_id="$(tmux -S "${socket_path}" display-message -p -t fzj-check:0 '#{window_id}')"
        pane_id="$(tmux -S "${socket_path}" display-message -p -t fzj-check:0.0 '#{pane_id}')"

        printf 'renamed-session\n' | PATH="${shim_dir}:${PATH}" ./select_pane.sh --action rename "${session_id}" >/dev/null
        tmux -S "${socket_path}" has-session -t renamed-session

        printf 'renamed-window\n' | PATH="${shim_dir}:${PATH}" ./select_pane.sh --action rename "${window_id}" >/dev/null
        test "$(tmux -S "${socket_path}" display-message -p -t renamed-session:0 '#{window_name}')" = "renamed-window"

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
    else
        printf "skipping tmux smoke check: could not create isolated tmux server\n" >&2
    fi
fi

printf "ok\n"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

shellcheck select_pane.sh select_pane.tmux
bash -n select_pane.sh select_pane.tmux
grep -q -- '--action' select_pane.sh

fixture_output="$(./select_pane.sh --fixture)"
grep -q '^\$1 ' <<< "${fixture_output}"
grep -q '^@1 ' <<< "${fixture_output}"
grep -q '^%1 ' <<< "${fixture_output}"
grep -q 'workspace' <<< "${fixture_output}"
grep -q 'archive' <<< "${fixture_output}"

if command -v tmux >/dev/null 2>&1; then
    socket_path="/tmp/tmux-fzj-check-$$"
    cleanup() {
        tmux -S "${socket_path}" kill-server >/dev/null 2>&1 || true
        rm -f "${socket_path}"
    }
    trap cleanup EXIT

    tmux -S "${socket_path}" -f /dev/null new-session -d -s fzj-check || true

    if tmux -S "${socket_path}" has-session -t fzj-check >/dev/null 2>&1; then
        tmux -S "${socket_path}" run-shell "${ROOT_DIR}/select_pane.tmux"

        binding="$(tmux -S "${socket_path}" list-keys -T prefix j)"
        grep -q 'select_pane.sh' <<< "${binding}"
        grep -q 'center,70%,80%' <<< "${binding}"
    else
        printf "skipping tmux smoke check: could not create isolated tmux server\n" >&2
    fi
fi

printf "ok\n"

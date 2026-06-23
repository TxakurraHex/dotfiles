#!/usr/bin/env bash
# fleet-dashboard.sh — a 4-pane "health dashboard" for ONE device over SSH,
# aimed at the avail / modem / GPS debugging you do. Layout:
#
#   ┌─────────────────────┬─────────────────────┐
#   │ journalctl -u avail │ kernel ring (dmesg) │   ← service log | driver msgs
#   ├─────────────────────┼─────────────────────┤
#   │ modem signal loop   │ htop                │   ← mmcli signal | resources
#   └─────────────────────┴─────────────────────┘
#
# Usage:
#   ./fleet-dashboard.sh device-01
#   ./fleet-dashboard.sh -u my-service device-01     # different systemd unit
#
# Edit the PANE_* commands below to match each platform (these are sensible
# embedded-Linux defaults; some boxes use mmcli, others raw AT over /dev/tty*).
set -euo pipefail

UNIT="avail"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--unit) UNIT="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) HOST="$1"; shift ;;
  esac
done
: "${HOST:?usage: fleet-dashboard.sh [-u unit] <host>}"

SESSION="dash-${HOST//[^A-Za-z0-9_]/_}"

# ── Per-pane remote commands (edit freely) ───────────────────────────────────
PANE_LOG="journalctl -u ${UNIT} -f --no-pager -o short-precise"
PANE_DMESG="dmesg -w --human --color=always 2>/dev/null || sudo dmesg -w"
# Modem signal once every 2s. Falls back to a hint if ModemManager isn't present.
PANE_MODEM='while true; do clear; (mmcli -m any 2>/dev/null | grep -Ei "signal|state|access tech|operator" || echo "mmcli unavailable — wire up AT/qmicli here"); sleep 2; done'
PANE_TOP="htop 2>/dev/null || top"

if tmux has-session -t "$SESSION" 2>/dev/null; then
  exec tmux attach -t "$SESSION"
fi

# Helper: ssh that drops to a shell instead of closing on disconnect/exit.
rcmd() { echo "ssh -t ${HOST} '$1' || true; echo '[pane exited — press enter for shell]'; read; exec \$SHELL -l"; }

tmux new-session -d -s "$SESSION" -n "$HOST"
P="$SESSION:0"

# Top-left = service log (pane 1, already created)
tmux send-keys -t "${P}.1" "$(rcmd "$PANE_LOG")" C-m
tmux select-pane -t "${P}.1" -T "${UNIT} log"

# Top-right = dmesg
tmux split-window -h -t "$P"
tmux send-keys -t "$P" "$(rcmd "$PANE_DMESG")" C-m
tmux select-pane -t "$P" -T "kernel/dmesg"

# Bottom-left = modem signal (split the left pane)
tmux split-window -v -t "${P}.1"
tmux send-keys -t "$P" "$(rcmd "$PANE_MODEM")" C-m
tmux select-pane -t "$P" -T "modem"

# Bottom-right = htop (split the right pane)
tmux split-window -v -t "${P}.2"
tmux send-keys -t "$P" "$(rcmd "$PANE_TOP")" C-m
tmux select-pane -t "$P" -T "resources"

tmux select-layout -t "$P" tiled >/dev/null
tmux setw -t "$P" pane-border-status top
tmux setw -t "$P" pane-border-format " #{pane_title} "
tmux select-pane -t "${P}.1"

exec tmux attach -t "$SESSION"

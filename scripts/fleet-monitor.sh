#!/usr/bin/env bash
# fleet-monitor.sh — open a tmux session with one SSH pane per device, tiled.
#
# Reads hosts (one per line, blank lines and #comments ignored) from:
#   1) a file passed as $1, or
#   2) ~/.config/fleet/hosts  (default)
#
# Each line is passed straight to `ssh`, so it can be a Host alias from your
# ~/.ssh/config (recommended) or user@ip. Example hosts file:
#
#     # ~/.config/fleet/hosts
#     device-01
#     device-02
#     responder-van-7
#     pi@10.0.0.42
#
# Usage:
#   ./fleet-monitor.sh                      # use default hosts file
#   ./fleet-monitor.sh path/to/hosts        # use a specific list
#   ./fleet-monitor.sh -c 'journalctl -u avail -f' device-0{1,2}   # inline cmd
#
# Inside the session:
#   prefix + e   toggle broadcast (type once, run on every device)
#   prefix + h/j/k/l   move between device panes
set -euo pipefail

SESSION="fleet"
REMOTE_CMD=""          # optional command to run on each host after connecting
HOSTS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/fleet/hosts"

# ── arg parsing ──────────────────────────────────────────────────────────────
HOSTS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--command) REMOTE_CMD="$2"; shift 2 ;;
    -s|--session) SESSION="$2";   shift 2 ;;
    -h|--help)    grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) if [[ -f "$1" ]]; then HOSTS_FILE="$1"; else HOSTS+=("$1"); fi; shift ;;
  esac
done

# Hosts from a file unless any were passed positionally.
if [[ ${#HOSTS[@]} -eq 0 ]]; then
  [[ -f "$HOSTS_FILE" ]] || { echo "No hosts given and $HOSTS_FILE not found." >&2; exit 1; }
  while IFS= read -r line; do
    line="${line%%#*}"; line="${line//[[:space:]]/}"
    [[ -n "$line" ]] && HOSTS+=("$line")
  done < "$HOSTS_FILE"
fi
[[ ${#HOSTS[@]} -gt 0 ]] || { echo "Host list is empty." >&2; exit 1; }

# Reuse an existing session instead of stacking duplicates.
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Session '$SESSION' exists; attaching."
  exec tmux attach -t "$SESSION"
fi

# Build the ssh invocation for a host. Keep the pane alive if ssh exits so a
# dropped link doesn't silently close the pane — gives you a shell to retry.
ssh_pane() {
  local host="$1"
  if [[ -n "$REMOTE_CMD" ]]; then
    echo "ssh -t ${host} '${REMOTE_CMD}; exec \$SHELL -l' || exec \$SHELL -l"
  else
    echo "ssh -t ${host} || true; exec \$SHELL -l"
  fi
}

# First host opens the window; the rest split into it, re-tiling each time.
tmux new-session -d -s "$SESSION" -n devices
tmux send-keys  -t "$SESSION:devices.1" "$(ssh_pane "${HOSTS[0]}")" C-m
tmux select-pane -t "$SESSION:devices.1" -T "${HOSTS[0]}"

for host in "${HOSTS[@]:1}"; do
  tmux split-window -t "$SESSION:devices" -c "#{pane_current_path}"
  tmux select-layout -t "$SESSION:devices" tiled >/dev/null
  tmux send-keys  -t "$SESSION:devices" "$(ssh_pane "$host")" C-m
  tmux select-pane -t "$SESSION:devices" -T "$host"
done

tmux select-layout -t "$SESSION:devices" tiled >/dev/null
tmux setw -t "$SESSION:devices" pane-border-status top
tmux setw -t "$SESSION:devices" pane-border-format " #{pane_title} "
tmux select-pane -t "$SESSION:devices.1"

echo "Connected to ${#HOSTS[@]} device(s). prefix+e = broadcast toggle."
exec tmux attach -t "$SESSION"

# ~/.zshrc
# zsh + Starship + fzf/zoxide/atuin + two ergonomic plugins.
# POSIX-compatible interactive shell; keep bash as your scripting target.
# Run ./zsh/install-plugins.sh once to fetch the plugins this file sources.

# ── Environment ──────────────────────────────────────────────────────────────
export EDITOR="${EDITOR:-nvim}"
export VISUAL="$EDITOR"
export PAGER="less"
export LESS="-R"                 # keep ANSI colors in pagers (bat/delta output)

# Homebrew (Apple Silicon path). Harmless if already on PATH.
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"

# Personal bins.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# ── History ──────────────────────────────────────────────────────────────────
# atuin owns interactive history search (below); these keep a sane on-disk file.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt SHARE_HISTORY            # share across concurrent sessions / splits
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY              # expand !! etc. before running
setopt EXTENDED_HISTORY         # timestamps

# ── Sensible zsh options ─────────────────────────────────────────────────────
setopt AUTO_CD                  # `..` / `projects` instead of `cd ..`
setopt AUTO_PUSHD PUSHD_IGNORE_DUPS
setopt INTERACTIVE_COMMENTS     # allow `# comments` at the prompt
setopt NO_BEEP

# ── Completion ───────────────────────────────────────────────────────────────
autoload -Uz compinit
# Cache compinit dump for faster startup; rebuild at most once a day.
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'   # case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ── Plugins (cloned by install-plugins.sh) ───────────────────────────────────
ZSH_PLUGIN_DIR="${ZDOTDIR:-$HOME}/.zsh/plugins"
# Autosuggestions: fish-style inline suggestions from history.
if [[ -f "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
fi
# Syntax highlighting MUST be sourced last to wrap the line editor correctly.
if [[ -f "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# ── Modern CLI tool init ─────────────────────────────────────────────────────
# Order matters: init fzf first (binds Ctrl-T / Alt-C / Ctrl-R), then let atuin
# reclaim Ctrl-R so you get its SQLite-backed, syncable history search.
command -v fzf    >/dev/null && source <(fzf --zsh)
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
command -v atuin  >/dev/null && eval "$(atuin init zsh)"   # owns Ctrl-R

# Starship prompt last so it wraps everything.
command -v starship >/dev/null && eval "$(starship init zsh)"

# ── Aliases (modern replacements) ────────────────────────────────────────────
if command -v eza >/dev/null; then
  alias ls='eza --group-directories-first --icons=auto'
  alias ll='eza -lah --git --group-directories-first --icons=auto'
  alias lt='eza --tree --level=2 --icons=auto'
fi
command -v bat    >/dev/null && alias cat='bat --paging=never'
command -v fd     >/dev/null && alias find='fd'
command -v rg     >/dev/null && alias grep='rg'
command -v zoxide >/dev/null && alias cd='z'

# git with delta diffs assumed configured in ~/.gitconfig:
#   [core] pager = delta   [interactive] diffFilter = delta --color-only

# ── Embedded helpers (examples — edit device names/paths to taste) ───────────
# Open a serial console to a modem/MCU. Needs `picocom` (brew install picocom).
#   serial /dev/tty.usbserial-XXXX 115200
serial() { picocom --baud "${2:-115200}" "${1:?usage: serial <device> [baud]}"; }

# Follow a remote service log over SSH (survives nothing — use tmux for that).
#   rlog device-01 avail
rlog() { ssh "${1:?host}" -- journalctl -u "${2:?unit}" -f --no-pager; }

# Quick modem state over SSH via ModemManager.
#   modemstat device-01
modemstat() { ssh "${1:?host}" -- 'mmcli -m any 2>/dev/null || echo "no modem / mmcli"'; }

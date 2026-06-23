#!/usr/bin/env bash
# Fetch the two zsh plugins .zshrc sources. No plugin-manager dependency —
# just git clones into ~/.zsh/plugins so the setup stays reproducible and
# trivially syncable (Syncthing the dotfiles repo, run this per machine).
set -euo pipefail

PLUGIN_DIR="${ZDOTDIR:-$HOME}/.zsh/plugins"
mkdir -p "$PLUGIN_DIR"

clone_or_update() {
  local repo="$1" dest="$PLUGIN_DIR/$2"
  if [[ -d "$dest/.git" ]]; then
    echo "==> updating $2"
    git -C "$dest" pull --ff-only --quiet
  else
    echo "==> cloning  $2"
    git clone --depth=1 --quiet "$repo" "$dest"
  fi
}

clone_or_update https://github.com/zsh-users/zsh-autosuggestions      zsh-autosuggestions
clone_or_update https://github.com/zsh-users/zsh-syntax-highlighting  zsh-syntax-highlighting

echo "Done. Plugins in $PLUGIN_DIR"

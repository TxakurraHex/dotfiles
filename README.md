# Terminal dotfiles — Ghostty + zsh + Starship + tmux

A reproducible terminal setup tuned for SSH-heavy embedded work: large log
buffers, prominent SSH hostnames (so you don't fat-finger a command on the
wrong fleet device), truecolor TUIs, and tmux layouts for monitoring devices.

Everything is plain text — drop this in a git repo, Syncthing it between the
M4 (work) and M5 (personal), and run the install steps once per machine.

```
dotfiles/
├── ghostty/config          → ~/.config/ghostty/config
├── zsh/.zshrc              → ~/.zshrc
├── zsh/install-plugins.sh  (fetches the two zsh plugins, no framework)
├── starship.toml           → ~/.config/starship.toml
├── tmux/tmux.conf          → ~/.tmux.conf
└── scripts/
    ├── fleet-monitor.sh    (one SSH pane per device + broadcast)
    └── fleet-dashboard.sh  (4-pane health view for one device)
```

## 1. Dependencies

```bash
brew install --cask ghostty
brew install starship tmux fzf zoxide atuin eza bat fd ripgrep git-delta picocom
```

zsh ships with macOS. Ghostty bundles JetBrains Mono Nerd Font, so no font
install is needed for Starship glyphs.

## 2. Link the configs

Symlinks (so edits in the repo are live):

```bash
DOT="$PWD"   # run from the dotfiles/ dir
mkdir -p ~/.config/ghostty ~/.config
ln -sf "$DOT/ghostty/config"  ~/.config/ghostty/config
ln -sf "$DOT/zsh/.zshrc"      ~/.zshrc
ln -sf "$DOT/starship.toml"   ~/.config/starship.toml
ln -sf "$DOT/tmux/tmux.conf"  ~/.tmux.conf
```

## 3. Fetch zsh plugins

```bash
./zsh/install-plugins.sh        # clones autosuggestions + syntax-highlighting
```

## 4. One-time tool setup

- **atuin**: `atuin import auto` to pull existing history. Sync is optional and
  self-hostable — worth it given you already run Syncthing and prefer to own
  your data. `atuin register` only if you use the hosted sync.
- **delta**: add to `~/.gitconfig`:
  ```ini
  [core]
      pager = delta
  [interactive]
      diffFilter = delta --color-only
  [delta]
      navigate = true
      line-numbers = true
  ```

Open a fresh Ghostty window and you're done.

## 5. Fleet scripts

Create a host list (SSH aliases from `~/.ssh/config` recommended):

```bash
mkdir -p ~/.config/fleet
cat > ~/.config/fleet/hosts <<'EOF'
device-01
device-02
responder-van-7
EOF
```

```bash
# One SSH pane per device, tiled. prefix+e broadcasts your keystrokes to all.
./scripts/fleet-monitor.sh

# Run the same command across every device at once:
./scripts/fleet-monitor.sh -c 'mmcli -m any | grep -i signal'

# Deep-dive one device: service log + dmesg + modem signal + htop.
./scripts/fleet-dashboard.sh device-01 -u avail
```

Both scripts keep panes alive if SSH drops (you get a local shell to retry
from) and run inside tmux, so the session survives a disconnect — reattach
with `tmux attach -t fleet`.

## Customization notes

- **Ghostty theme**: `ghostty +list-themes` to browse; edit the `theme = …`
  line. All options: `ghostty +show-config --default --docs`.
- **tmux prefix**: defaults to `C-a` here; comment the top 3 lines of
  `tmux.conf` to keep stock `C-b`.
- **Dashboard commands**: the per-pane commands in `fleet-dashboard.sh` are
  embedded-Linux defaults (journalctl/dmesg/mmcli/htop). Edit `PANE_*` for
  boxes that need raw AT or `qmicli` instead of ModemManager.
- **Prompt**: hostname goes **bold red over SSH only** — the single most useful
  safety cue when you're hopping between local and a dozen remote devices.

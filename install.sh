#!/usr/bin/env bash
set -euo pipefail
#
# Install the dotfiles.

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

git pull origin master

doSync() {
  rsync --exclude ".git/" \
    --exclude ".DS_Store" \
    --exclude "install.sh" \
    --exclude "README.md" \
    --exclude "LICENSE.txt" \
    --exclude "dotfiles.code-workspace" \
    -avh --no-perms . ~
}

# ssh has no XDG support, so point its default config path at the XDG one.
# A symlink (instead of a shell alias) means non-interactive callers get it too.
linkSshConfig() {
  # Hardcoded ~/.config because that is where doSync just put it.
  local target="$HOME/.config/ssh/config"
  local link="$HOME/.ssh/config"

  [ -f "$target" ] || return 0

  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  if [ "$(readlink "$link" 2>/dev/null)" = "$target" ]; then
    return 0
  fi

  # Anything already there gets moved aside, never clobbered.
  if [ -e "$link" ] || [ -L "$link" ]; then
    local backup="$link.backup-$(date +%Y%m%d%H%M%S)"
    local n=1
    while [ -e "$backup" ] || [ -L "$backup" ]; do
      backup="$link.backup-$(date +%Y%m%d%H%M%S)-$n"
      n=$((n + 1))
    done
    echo "Backing up existing $link to $backup"
    mv "$link" "$backup"
  fi

  ln -s "$target" "$link"
  echo "Linked $link -> $target"
}

# Vundle installs plugins but never removes ones dropped from the vimrc, so a
# removed plugin lingers on every machine that already had it. Run the sync
# under vim when it is available: its plugin list is a superset of neovim's
# (vim-sensible and vim-dispatch are vim-only), so PluginClean! under neovim
# would delete those two.
syncVimPlugins() {
  local -a editor
  if hash vim 2>/dev/null; then
    editor=(vim)
  elif hash nvim 2>/dev/null; then
    editor=(nvim --headless)
  else
    return 0
  fi

  echo "Syncing vim plugins"
  if ! "${editor[@]}" +PluginClean! +PluginInstall +qall; then
    echo "warning: vim plugin sync failed" >&2
  fi
}

if [ "${1:-}" = "--force" ] || [ "${1:-}" = "-f" ]; then
  doSync
  linkSshConfig
  syncVimPlugins
else
  read -rp "This may overwrite existing files in your home directory. Are you sure? (y/n) "
  echo ""
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    doSync
    linkSshConfig
    syncVimPlugins
  fi
fi

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

if [ "${1:-}" = "--force" ] || [ "${1:-}" = "-f" ]; then
  doSync
  linkSshConfig
else
  read -rp "This may overwrite existing files in your home directory. Are you sure? (y/n) "
  echo ""
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    doSync
    linkSshConfig
  fi
fi

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

if [ "${1:-}" = "--force" ] || [ "${1:-}" = "-f" ]; then
  doSync
else
  read -rp "This may overwrite existing files in your home directory. Are you sure? (y/n) "
  echo ""
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    doSync
  fi
fi

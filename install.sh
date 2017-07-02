#!/bin/bash
#
# Install the dotfiles.

cd "$(dirname "${BASH_SOURCE}")" || exit

git pull origin master

doSync() {
  rsync --exclude ".git/" \
    --exclude ".DS_Store" \
    --exclude "install.sh" \
    --exclude "README.md" \
    --exclude "LICENSE.txt" \
    -avh --no-perms . ~;
  . ~/.bash_profile
}

if [ "$1" = "--force" ] || [ "$1" = "-f" ]; then
  doSync
else
  read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) "
  echo ""
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    doSync
  fi;
fi;
unset doSync

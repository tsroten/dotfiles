#!/usr/bin/env bash
set -euo pipefail
#
# Install the dotfiles.

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

git pull origin main

doSync() {
  rsync --exclude ".git/" \
    --exclude ".DS_Store" \
    --exclude "install.sh" \
    --exclude "README.md" \
    --exclude "LICENSE.txt" \
    --exclude "dotfiles.code-workspace" \
    -avh --no-perms . ~
}

# Move whatever is at a link path out of the way instead of clobbering it. Shared
# by the link steps below, which all want the same numbered-backup naming.
backupAside() {
  local path=$1
  local backup
  local n=1
  backup="$path.backup-$(date +%Y%m%d%H%M%S)"
  while [ -e "$backup" ] || [ -L "$backup" ]; do
    backup="$path.backup-$(date +%Y%m%d%H%M%S)-$n"
    n=$((n + 1))
  done
  echo "Backing up existing $path to $backup"
  mv "$path" "$backup"
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
    backupAside "$link"
  fi

  ln -s "$target" "$link"
  echo "Linked $link -> $target"
}

# Point ~/.<name> at ~/.config/<name> for tools that hardcode the dotted home
# path. Deliberately not shared with linkSshConfig above: that one links a single
# file that this repo owns and doSync has already written, so it can require the
# target to exist and replace whatever it finds. These directories are the
# opposite on both counts, and reconciling the two would take more flags than
# either case saves.
linkXdgDir() {
  local name=$1
  local target="$HOME/.config/$name"
  local link="$HOME/.$name"
  local current

  # Trailing slash tolerated so a link made by hand still counts as correct,
  # rather than being backed up and recreated on every run.
  current=$(readlink "$link" 2>/dev/null || true)
  if [ "${current%/}" = "$target" ]; then
    return 0
  fi

  # Created here rather than relying on doSync: none of these directories are
  # tracked, since they hold credentials and installed state rather than config.
  # 700 because nothing here is meant to be read outside this account.
  mkdir -p "$target"
  chmod 700 "$target"

  # A real directory at the link path is the tool's own state. Renaming that
  # aside would read as data loss, so this case reports and stops instead --
  # merging two directories is a judgment call, not a backup.
  if [ -d "$link" ] && [ ! -L "$link" ]; then
    echo "warning: $link is a real directory, not a link to $target" >&2
    echo "warning: merge it into $target by hand, then re-run install.sh" >&2
    return 0
  fi

  # A link pointing somewhere else, or a stray file, is ours to move.
  if [ -e "$link" ] || [ -L "$link" ]; then
    backupAside "$link"
  fi

  ln -s "$target" "$link"
  echo "Linked $link -> $target"
}

# Claude Code reaches the XDG directory only through CLAUDE_CONFIG_DIR, which in
# turn only reaches processes that inherit the shell exports. Anything else --
# a launchd agent, an editor's integrated terminal, a login shell that skipped
# the profile -- falls back to ~/.claude, and that isn't merely untidy: OAuth
# credentials are keyed by config directory, so a session that missed the export
# looks unauthenticated and logs in to a second store of its own.
linkClaudeConfig() {
  linkXdgDir claude
}

# The skills CLI (npx skills) has no equivalent of CLAUDE_CONFIG_DIR: its
# install root is always homedir() + "/.agents", so a link is the only way to
# move it. Being env-independent is an advantage here, since every caller
# follows the link whether or not it sourced the profile. Note the skills live
# in ~/.agents/skills while every agent gets a relative symlink pointing through
# ~/.agents, so those keep resolving once this link is in place.
linkAgentsDir() {
  linkXdgDir agents
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
  linkClaudeConfig
  linkAgentsDir
  syncVimPlugins
else
  read -rp "This may overwrite existing files in your home directory. Are you sure? (y/n) "
  echo ""
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    doSync
    linkSshConfig
    linkClaudeConfig
    syncVimPlugins
  fi
fi

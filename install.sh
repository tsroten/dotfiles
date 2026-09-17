#!/usr/bin/env bash
set -euo pipefail
#
# Install the dotfiles.

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

git pull origin main

# .claude/, .agents/, and .pi/ are excluded because they are the link paths the
# linkXdgDir steps below manage. This repo carries its own .claude/ holding the
# project-local Claude Code settings, and syncing that would recreate ~/.claude
# as a real directory on every run -- which linkClaudeConfig then refuses to
# touch, so the link could never be made. The rsync copies untracked files too,
# so .pi/ is excluded on the same grounds even though nothing here commits one:
# pi writes a project-local .pi/ into whatever repo it runs in, including this
# one. The tracked pi config is at .config/pi/, which is the link target rather
# than the link path and so syncs normally.
doSync() {
  rsync --exclude ".git/" \
    --exclude ".claude/" \
    --exclude ".agents/" \
    --exclude ".pi/" \
    --exclude ".config/pi/agent/settings.json" \
    --exclude ".DS_Store" \
    --exclude "install.sh" \
    --exclude "README.md" \
    --exclude "TODO.md" \
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

# pi has PI_CODING_AGENT_DIR, set in shell/exports, but it is the same deal as
# CLAUDE_CONFIG_DIR: only processes that sourced the profile see it, and pi's
# auth.json is per config directory, so a run that missed the export starts out
# logged out and re-authenticates into a second ~/.pi/agent. Linking the whole
# ~/.pi (not ~/.pi/agent) keeps that fallback path pointing at the same state.
# Skills are unaffected: the skills CLI resolves parent symlinks before writing
# its relative links, so ~/.pi/agent/skills/* keep resolving into ~/.agents.
linkPiConfig() {
  linkXdgDir pi
}

# pi reads exactly one global settings.json, with no include or extends
# directive, so the machine-local seam every other tool here gets by sourcing an
# untracked file has to be produced before pi starts. Three layers go into it:
#
#   1. the live ~/.config/pi/agent/settings.json, which is why doSync excludes
#      that path -- pi writes its own state there (lastChangelogVersion today,
#      whatever it adds tomorrow), and a plain copy would erase it on every run
#   2. the tracked settings.json in this repo, the config both machines share
#   3. settings.local.json, untracked, for what only this machine has -- the
#      claude-bridge package and the provider and model that come with it
#
# Layers 2 and 3 win over layer 1 key by key, so the tracked config is
# authoritative for everything it declares while state pi owns is left alone.
# Combining 2 and 3 concatenates arrays, deliberately unlike pi's own project
# overrides, which replace them: replacing would mean repeating every shared
# package in the local file and silently missing any added to the tracked one
# later. Applying the result over layer 1 does replace, so dropping a package
# from the tracked file or the local file actually removes it.
mergePiSettings() {
  # Hardcoded ~/.config because that is where the link points and doSync writes.
  local live="$HOME/.config/pi/agent/settings.json"
  local tracked="$PWD/.config/pi/agent/settings.json"
  local overrides="$HOME/.config/pi/agent/settings.local.json"

  [ -f "$tracked" ] || return 0

  # Not fatal: start-day is expected to keep going. With no live settings to
  # preserve there is nothing to merge, so the tracked copy is used as-is.
  if ! hash python3 2>/dev/null; then
    echo "warning: python3 not found, skipping pi settings merge" >&2
    if [ ! -f "$live" ]; then
      mkdir -p "$(dirname "$live")"
      cp "$tracked" "$live"
      echo "warning: installed $tracked unmerged" >&2
    else
      echo "warning: $live left as it was" >&2
    fi
    return 0
  fi

  if python3 - "$live" "$tracked" "$overrides" <<'PY'; then
import json
import os
import sys

live_path, tracked_path, overrides_path = sys.argv[1], sys.argv[2], sys.argv[3]


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def merge(base, overrides, extend_lists):
    if isinstance(base, dict) and isinstance(overrides, dict):
        merged = dict(base)
        for key, value in overrides.items():
            if key in base:
                merged[key] = merge(base[key], value, extend_lists)
            else:
                merged[key] = value
        return merged
    if extend_lists and isinstance(base, list) and isinstance(overrides, list):
        merged = list(base)
        for item in overrides:
            if item not in merged:
                merged.append(item)
        return merged
    return overrides


managed = merge(load(tracked_path), load(overrides_path), extend_lists=True)
result = merge(load(live_path), managed, extend_lists=False)

# Written to a temporary file and renamed so a running pi never reads a
# half-written settings.json.
os.makedirs(os.path.dirname(live_path), exist_ok=True)
tmp_path = live_path + ".tmp"
with open(tmp_path, "w") as f:
    json.dump(result, f, indent=2)
    f.write("\n")
os.replace(tmp_path, live_path)
PY
    echo "Merged pi settings into $live"
  else
    echo "warning: pi settings merge failed, $live left as it was" >&2
  fi
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
  linkPiConfig
  linkAgentsDir
  mergePiSettings
  syncVimPlugins
else
  read -rp "This may overwrite existing files in your home directory. Are you sure? (y/n) "
  echo ""
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    doSync
    linkSshConfig
    linkClaudeConfig
    linkPiConfig
    linkAgentsDir
    mergePiSettings
    syncVimPlugins
  fi
fi

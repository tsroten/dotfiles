# dotfiles

Personal configuration for macOS: shell (bash/zsh), vim/neovim, tmux, git,
alacritty, and a handful of CLI tools. The repo mirrors the layout of `$HOME`,
so installing is just an `rsync` of this tree into your home directory.

Everything is [XDG][xdg]-first: config lives under `~/.config`, caches under
`~/.cache`, data under `~/.local/share`, and state under `~/.local/state`. Tools
that don't support XDG natively are coaxed into it with environment variables,
aliases, or (for ssh) a symlink.

[xdg]: https://specifications.freedesktop.org/basedir-spec/latest/

## Install

```sh
git clone https://github.com/tsroten/dotfiles.git ~/code/dotfiles
~/code/dotfiles/install.sh
```

`install.sh` pulls the latest `master`, then:

1. rsyncs the tree into `~` (excluding `.git/`, `install.sh`, `README.md`, and
   editor cruft). **Existing files are overwritten**, so it prompts for
   confirmation first — pass `--force`/`-f` to skip the prompt.
2. Symlinks `~/.ssh/config` → `~/.config/ssh/config`, backing up anything
   already at that path to `~/.ssh/config.backup-<timestamp>`. ssh has no XDG
   support and a symlink (unlike an alias) also applies to non-interactive
   callers such as git.
3. Syncs vim plugins with `:PluginClean! :PluginInstall`. This runs under `vim`
   when available and falls back to headless `nvim`, because the vimrc's plugin
   list for vim is a superset of neovim's — running `PluginClean!` under neovim
   would delete the vim-only plugins.

Since the install is a copy rather than a symlink farm, edits made directly in
`~` don't flow back. Change files here and re-run `install.sh`.

### Packages

```sh
brew install coreutils neovim python@3 python@3.12 pipx rsync terraform tfenv tmux urlview

brew --cask install alacritty claude claude-code gcloud-cli google-cloud-sdk zed

pipx install --python python3.12 "headroom-ai[all]"
```

## Layout

| Path | What it is |
| --- | --- |
| `.bashrc`, `.bash_profile`, `.zshrc`, `.zprofile` | Thin entry points; each sources `~/.config/shell/profile` plus its shell-specific config. |
| `.config/shell/` | Shell config shared by bash and zsh: `profile` (XDG vars, homebrew, nvm, sourcing order), `exports`, `aliases`, `path`. |
| `.config/bash/exports`, `.config/zsh/exports` | Shell-specific settings only — prompt, history mechanics, keybindings. |
| `.config/vim/vimrc` | vim/neovim config, Vundle-managed plugins. |
| `.config/vim/syntax/sql.vim` | Vendored SQL syntax file (see below). |
| `.config/tmux/` | `tmux.conf`, TPM plugin list, and the `cmus-status` / `mail-count` status-line scripts. |
| `.config/git/` | `config`, global `ignore`, and a `template/` with ctags hooks. |
| `.config/alacritty/alacritty.toml` | Terminal: IBM Plex Mono, Nord colors, readline-style Alt-key bindings. |
| `.config/ssh/config` | Agent/keychain defaults; includes `~/.config/ssh/config.d/*`. |
| `.config/mysql/`, `.config/mycli/`, `.config/pgcli/` | Database client config. |
| `.config/python/startup.py` | `PYTHONSTARTUP` hook that puts REPL history under `$XDG_DATA_HOME`. |
| `.config/twine/pypirc` | PyPI upload config. |
| `.local/bin/start-day` | Morning maintenance script (see below). |

The color scheme throughout is [Nord][nord] — vim (`nord-vim`), tmux
(`nord-tmux`), and alacritty (colors inlined in the TOML).

[nord]: https://www.nordtheme.com/

## Machine-local overrides

Several files intentionally source paths that this repo does **not** track, so
per-machine or secret settings stay out of version control:

| File | Sourced by |
| --- | --- |
| `~/.config/shell/secrets` | `shell/profile` — API keys, tokens |
| `~/.config/git/local` | `git/config` — email, signing key, per-host settings |
| `~/.config/vim/localrc` | `vim/vimrc`, sourced last |
| `~/.config/ssh/config.d/*` | `ssh/config` |

All are optional; nothing breaks if they're absent.

## Shells

Config is split by portability, and the split is strict:

- **`shell/`** holds everything that works in both shells — XDG variables,
  aliases, PATH, `$EDITOR`. Nothing shell-specific belongs here.
- **`bash/exports`** and **`zsh/exports`** hold only what genuinely differs:
  prompt syntax (`\[\033[33;1m\]\W` vs `%F{yellow}%1d%f`), history mechanics
  (`HISTCONTROL`/`HISTFILESIZE` vs `setopt`/`SAVEHIST`), and zsh's `bindkey -e`.

Both shells enter through `shell/profile`, which sets the XDG variables
(creating the directories if needed), sources `exports`, `aliases`, `secrets`,
and `path` in that order, then runs homebrew's `shellenv` and a lazy nvm load
(`--no-use`, to keep zsh startup fast). Each shell's rc file then layers its own
`exports` on top. `.bashrc` additionally pulls in git-aware-prompt, git
completion, autojump, and pyenv when they're installed.

One wrinkle worth knowing: macOS ships an `/etc/zshrc` that sets `SAVEHIST=1000`
before any of this runs, which would otherwise silently cap saved history well
below the `HISTSIZE` set in `shell/exports`. `zsh/exports` resets it to match.

Most aliases exist to force XDG paths on tools that don't support them
(`tmux`, `gpg`, `sqlite3`, `mysql`, `mycli`, `twine`, `pip`). The rest are
shorthand: `v`/`vi` → `$EDITOR`, `c` → `claude`, `g` → `git`, `ls` → `ls -lhFG`.
`$EDITOR` prefers `nvim` and falls back to `vim`.

## vim

Plugins are managed by [Vundle][vundle], which bootstraps itself on first launch
if `~/.config/vim/bundle/Vundle.vim` is missing. `vim-sensible` and
`vim-dispatch` load only under vim; neovim additionally gets
`nvim-treesitter`. Leader is `<Space>`; there are mappings for tabs/buffers,
CtrlP (files, buffers, tags, command palette), Ack (project-aware, backed by
`ag` when installed), and fugitive.

`runtimepath` is prepended to rather than replaced, so neovim keeps its libdir
and the bundled treesitter parsers its built-in ftplugins expect.

`syntax/sql.vim` is vendored from the `magicalbanana/vim-sql-syntax` plugin
whose repo no longer exists, with a local fix making PostGIS function keywords
non-`contained` so `st_union()` and friends stop highlighting as errors. Details
are in the file header.

[vundle]: https://github.com/VundleVim/Vundle.vim

## tmux

Prefix is `C-Space`. Windows and panes are 1-indexed and renumbered on close;
splits use `|` and `-` and inherit the current pane's path; `H`/`J`/`K`/`L`
resize. Copy mode is vi-style with `v` to select and `C-v` for rectangles.
`prefix R` reloads the config.

Note that tmux is aliased to `tmux -f $XDG_CONFIG_HOME/tmux/tmux.conf`. Because
that `-f` bypasses TPM's usual assumptions, plugins are declared with the older
`@tpm_plugins` string rather than individual `set -g @plugin` lines. TPM
installs itself on first run.

The status line on the right shows the current cmus track (`cmus-status`),
unread mail count from `~/mail` (`mail-count`), and the date. Those status and
window-format overrides live in `tmux.conf` directly and are set before TPM
loads, so the nord-tmux plugin theme applies underneath them.

## git

`config` sets the basics — osxkeychain credentials, `push.default
= simple`, `autoSetupRemote`, rename/copy detection — plus short aliases
(`b`, `c`, `co`, `d`, `s`, `l`, `nb` to branch-and-push, `undo-commit`).

`init.templatedir` points at `.config/git/template`, so every newly created or
cloned repo gets hooks that rebuild a ctags index in the background after
commit, checkout, merge, and rebase.

## start-day

`~/.local/bin/start-day` is a morning maintenance run. Each step degrades to a
warning rather than aborting when a tool is missing:

- re-runs `install.sh --force`
- `brew update && brew upgrade`, then `brew cleanup`
- verifies gcloud auth + application-default credentials, and `gh auth status`,
  prompting for login if either is missing
- updates gcloud components
- `git pull --ff-only` in every repo directly under `~/code`, skipping any with
  uncommitted changes
- `nvm install --lts`
- `pnpm install --frozen-lockfile` in `~/code/platform` if it exists
- `npx skills update -g`
- `docker system prune -f --filter until=24h`

Override the defaults with the `DOTFILES`, `CODE`, and `NVM_DIR` environment
variables.

# dotfiles

Personal configuration for macOS: shell (bash/zsh), vim/neovim, tmux, git,
alacritty, and a handful of CLI tools. The repo mirrors the layout of `$HOME`,
so installing is just an `rsync` of this tree into your home directory.

## Goals

These are the standing principles; when a change here has to break a tie, it
breaks in favor of one of them.

- **Idempotent install.** `install.sh` is safe to run repeatedly and is run
  unattended by `start-day`. It backs up rather than clobbers, and re-running it
  is the normal way to apply a change.
- **`start-day` converges the machine.** One command brings everything current —
  dotfiles, packages, credentials, repos. It never aborts, never prompts (auth
  being the deliberate exception), and never destroys work; anything needing
  attention is flagged in a summary at the end.
- **Close the gap to Linux servers.** macOS ships BSD userland; GNU coreutils
  goes first on `PATH` so flags, output, and muscle memory match the servers.
- **One theme everywhere.** [Nord][nord], currently — vim, tmux, and alacritty.
- **System clipboard everywhere.** `clipboard=unnamed` in vim, tmux-yank in
  tmux, so yanking means the same thing in every context.
- **Shell-agnostic where it can be.** Anything that works in both bash and zsh
  lives in `shell/`; only genuinely divergent settings go in `bash/` or `zsh/`.
- **[XDG][xdg]-first, to keep `$HOME` clean.** Config in `~/.config`, caches in
  `~/.cache`, data in `~/.local/share`, state in `~/.local/state`. Tools without
  native XDG support are coaxed into it with environment variables, aliases, or
  (for ssh, Claude Code, and the skills CLI) a symlink.
- **Current practice over inherited habit.** Prefer the maintained tool and the
  supported auth mechanism; delete config that no longer does anything.

### Two machines

This is installed on a personal and a work laptop. They share a GitHub account
and nothing else — no shared credentials, accounts, or cloud access, and the
work machine runs additional security software. So anything machine-specific
stays out of this repo entirely and lives in the untracked local override files
described under [Machine-local overrides](#machine-local-overrides). Config that
is committed here has to work on both, which is why optional tooling is always
probed for rather than assumed.

[xdg]: https://specifications.freedesktop.org/basedir-spec/latest/
[nord]: https://www.nordtheme.com/

## Install

```sh
git clone https://github.com/tsroten/dotfiles.git ~/code/dotfiles
~/code/dotfiles/install.sh
```

`install.sh` pulls the latest `main`, then:

1. rsyncs the tree into `~` (excluding `.git/`, `install.sh`, `README.md`, and
   editor cruft). **Existing files are overwritten**, so it prompts for
   confirmation first — pass `--force`/`-f` to skip the prompt. `.claude/` and
   `.agents/` are excluded too: they are the link paths steps 3 and 4 manage,
   and this repo's own `.claude/` would otherwise recreate `~/.claude` as a real
   directory on every run, blocking the link permanently.
2. Symlinks `~/.ssh/config` → `~/.config/ssh/config`, backing up anything
   already at that path to `~/.ssh/config.backup-<timestamp>`. ssh has no XDG
   support and a symlink (unlike an alias) also applies to non-interactive
   callers such as git.
3. Symlinks `~/.claude` → `~/.config/claude`, for much the same reason. Claude
   Code is XDG-aware only through `CLAUDE_CONFIG_DIR`, which reaches only the
   processes that inherited the shell exports, and its OAuth credentials are
   keyed by config directory; a session that missed the export therefore looks
   unauthenticated and logs in to a second store of its own. Unlike the ssh
   config, a real directory already at `~/.claude` is left alone with a warning
   rather than moved aside, because merging two sets of credentials and session
   state is a judgment call rather than a backup.
4. Symlinks `~/.agents` → `~/.config/agents`, where the [skills CLI][skills]
   installs agent skills. That CLI honors `XDG_STATE_HOME` for its lockfile but
   hardcodes the install root as `~/.agents`, so a link is the only way to move
   it, and an env-independent one at that, unlike `CLAUDE_CONFIG_DIR` above.
   Skills stay at `~/.agents/skills`, and each agent gets a relative symlink
   pointing through `~/.agents`, so those keep resolving. Shares the
   backup-and-warn behavior of the Claude Code link, for the same reason.
5. Syncs vim plugins with `:PluginClean! :PluginInstall`. This runs under `vim`
   when available and falls back to headless `nvim`, because the vimrc's plugin
   list for vim is a superset of neovim's — running `PluginClean!` under neovim
   would delete the vim-only plugins.

Since the install is a copy rather than a symlink farm, edits made directly in
`~` don't flow back. Change files here and re-run `install.sh`.

[skills]: https://skills.sh/

### Packages

```sh
brew install coreutils gh neovim node pipx python@3 python@3.12 rsync ruff \
  terraform tfenv the_silver_searcher tmux universal-ctags urlview

brew --cask install 1password 1password-cli alacritty claude claude-code \
  copilot-cli font-ibm-plex-mono gcloud-cli spacectl zed

pipx install --python python3.12 "headroom-ai[all]"
```

What the less obvious ones are for: `coreutils` backs the GNU-first `PATH`,
`universal-ctags` the git tag hooks, `the_silver_searcher` vim's `<leader>*`
project search, `ruff` the python linter `ale` picks up, `font-ibm-plex-mono` the
font alacritty asks for, and `gh`, `node`, `1password-cli`, `claude-code`,
`copilot-cli`, and `spacectl` are used by `start-day`. `1password-cli` needs the
`1password` app alongside it: `op` authenticates through the desktop app's CLI
integration rather than holding its own credentials, and installing both from
Homebrew keeps `op` on the `brew upgrade` step instead of its own self-updater.
`google-cloud-sdk` is gone from the cask list because Homebrew renamed it — it
and `gcloud-cli` are the same cask.

Optional, and probed for rather than required: `cmus` and `fpp` (tmux status
line and plugin), `docker` (pruned by `start-day` when present), and `uv`,
`pre-commit`, and Xcode, whose caches `start-day` prunes on whichever machine
has them.

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

Several files intentionally source paths that this repo does **not** track. This
is the seam between the two machines: anything that differs between personal and
work — work email and signing key, per-host ssh, credentials — goes in one of
these and never gets committed.

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
(creating the directories if needed), sources `exports`, `path`, `aliases`, and
`secrets` in that order, then runs homebrew's `shellenv`. Each shell's rc file
layers its own `exports` on top. `.bashrc` additionally pulls in
git-aware-prompt and git completion when they're installed.

That order matters in one place: `path` runs before `aliases` because the `ls`
alias branches on what it finds. `shell/path` puts GNU coreutils ahead of the
BSD tools, and `-G` means *colorize* to BSD `ls` but *`--no-group`* to GNU's, so
the alias picks `--color=auto` or `-G` based on which one is actually on `PATH`.

macOS also ships an `/etc/zshrc` that sets `SAVEHIST=1000` before any of this
runs, which would otherwise silently cap saved history well below the `HISTSIZE`
in `shell/exports`. `zsh/exports` resets it to match.

Most aliases exist to force XDG paths on tools that don't support them
(`tmux`, `gpg`, `sqlite3`, `mysql`, `mycli`, `twine`, `pip`). The rest are
shorthand: `v`/`vi` → `$EDITOR`, `c` → `claude`, `g` → `git`. `$EDITOR` prefers
`nvim` and falls back to `vim`; nothing else hardcodes an editor, so git picks
it up through the same variable.

## vim

Plugins are managed by [Vundle][vundle], which bootstraps itself on first launch
if `~/.config/vim/bundle/Vundle.vim` is missing. `vim-sensible` and
`vim-dispatch` load only under vim; neovim additionally gets
`nvim-treesitter`. Leader is `<Space>`; there are mappings for tabs/buffers,
CtrlP (files, buffers, tags, command palette), Ack (project-aware, backed by
`ag` when installed), and fugitive.

`runtimepath` is prepended to rather than replaced, so neovim keeps its libdir
and the bundled treesitter parsers its built-in ftplugins expect.

Syntax highlighting comes from the editors themselves rather than a bundle:
`vim-polyglot` was dropped once vim 9.1 and neovim shipped everything it was
covering here, and because it conflicts with `nvim-treesitter`. The one
exception is the vendored `syntax/sql.vim` below.

`python-mode` was dropped for the same reason and because it needs a python3
interpreter neither editor here has — Apple's vim is built `-python3`, and
neovim's provider needs `pynvim` installed — so it raised `E319` on every `.py`
buffer while every feature it offered was already dead. Python linting is `ale`'s
job now, via `ruff`.

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
`core.editor` is deliberately unset so git falls through to `$EDITOR`.

`init.templatedir` points at `.config/git/template`, so every newly created or
cloned repo gets hooks that rebuild a ctags index in the background after
commit, checkout, merge, and rebase. Two caveats: the hooks only reach repos
created *after* the template is in place, and they need `universal-ctags` —
macOS's `/usr/bin/ctags` is a BSD build that rejects the flags involved, so the
hook checks and exits quietly rather than failing invisibly in the background.

## start-day

`~/.local/bin/start-day` is a morning convergence run, governed by three rules.

**Nothing ends the run.** Every step degrades to a warning, whether the tool is
missing or the command fails outright. That second case is routine on the work
machine, where endpoint security software intermittently blocks installs — a
blocked `pnpm install` shouldn't cost you the Docker prune. Steps that report
status say what is actually true, so a failed login prints a warning rather than
a checkmark over an empty account name.

**Nothing prompts**, so the run can be left to finish on its own:
`HOMEBREW_NO_ASK` for Homebrew's upgrade confirmation, `GIT_TERMINAL_PROMPT=0`
so a repo needing credentials fails instead of stalling mid-pull,
`COREPACK_ENABLE_DOWNLOAD_PROMPT=0`, `npx --yes`, `--force` on the Docker prune
and the dotfiles install, `--quiet` on the gcloud component update.

*Auth is the deliberate exception.* A login has to be interactive, and there's
no point converging a machine you then can't use — so the 1Password, gcloud,
GitHub, Claude, Copilot, and (where it's configured) Spacelift steps still open a
login when credentials are missing.

Every auth step probes rather than trusting a status command, because most of
them report on the credentials on disk rather than on whether those credentials
still work: `gcloud auth list` keeps an account `ACTIVE` after the org's reauth
policy has expired its session, `claude auth status` keeps saying `loggedIn`
just the same, and `spacectl profile current` goes on naming a profile whose
token expired days ago. The probe is whatever fails when a real command would.
For gcloud that's minting a token, for `gh` an API call, and for `spacectl`
`whoami`, all free. The two agent CLIs have no free equivalent (Copilot has no
status command at all), so they are probed with a one-token prompt on Haiku, no
tools and no MCP servers loaded, which costs a rounding error against the Claude
subscription and about one AI credit against Copilot's quota per run. Each is
probed once on the happy path, and API-key and token environment variables are
cleared for the probe so it exercises the account login rather than something
that outranks it. If one of those variables is set, the run says so as a
follow-up, since it silently wins over the account credentials the rest of the
time. Spacelift is the exception there: a `SPACELIFT_API_*` key that works means
`spacectl` works, which is all that step is asking, so its probe is left to use
whichever credentials it would normally pick.

The Spacelift step is also the one piece of the run that's opt-in, because an
endpoint names a specific account and so belongs to the machine rather than to
this repo. It does nothing until `SPACECTL_LOGIN_ENDPOINT` is set — in
`~/.config/shell/secrets`, which isn't tracked here — and skips quietly
otherwise rather than warning, since a machine that does no Spacelift work
shouldn't be nagged about it every morning. That's `spacectl`'s own variable, so
the same value serves a hand-run `spacectl profile login`. The local profile
alias is derived from the endpoint rather than configured separately, taking the
first label of the host: `https://acme.app.us.spacelift.io` logs in as `acme`.

**Nothing destructive.** Anything that would discard work reports it instead:
repos with uncommitted changes are skipped rather than stashed or reset, pulls
are `--ff-only` so they can't rewrite history, and the Docker prune passes
neither `-a` nor `--volumes`, so images in use and every named volume survive.

The reclaim steps are drawn along the same line. What the run does on its own is
each tool's own garbage collector — `npm cache verify`, `pre-commit gc`, `uv
cache prune`, and `simctl delete unavailable`, which only drops simulators whose
runtime Xcode has already removed and which therefore can't be booted. What it
won't do is the `rm -rf` cleanups, however much they'd reclaim: old Xcode
`DeviceSupport` builds, `DerivedData`, and `docker system prune -a --volumes`
stay yours to run.

Homebrew is the one place the run is deliberately more aggressive than the
default. `brew cleanup` keeps downloads for 120 days, so running it every
morning reclaimed nothing at all while the bottle cache grew to 11 GB;
`--prune=all` takes the cache down to tens of megabytes. The cost is that
reinstalling a *current* version needs the network again, which is rarer than
needing the disk.

Because nothing aborts, the run is long and something 200 lines up is easy to
miss — so it all comes back in a `Summary` step at the end, in two halves.
**Warnings** are a record of what went wrong, tagged with the step. **Follow-ups**
are the things left for you to do, each with the command to do it — this is
where rules 2 and 3 surface, since anything the run won't decide or won't
destroy on your behalf ends up here. Follow-ups print last, because they're the
half worth acting on:

```
==> Summary
  1 warning(s) across 17 steps:
    ! Installing platform dependencies: platform dependency install failed, continuing
  2 thing(s) to follow up on:
    → gcloud ADC unavailable — run: gcloud auth application-default login
    → dive-sites: uncommitted changes, not pulled — commit or stash
```

The summary runs from an `EXIT` trap, so it still prints if something unexpected
kills the run, and says so when that happens.

- re-runs `install.sh --force`
- `brew update && brew upgrade` (unattended), then `brew cleanup --prune=all`
- signs in to 1Password if the session is missing (first of the auth steps, so
  shell plugins can hand credentials to the CLIs checked after it)
- verifies gcloud auth + application-default credentials, and `gh auth status`,
  prompting for login if either is missing
- verifies Claude and Copilot with a throwaway prompt, running `claude auth login
  --claudeai` or `copilot login` if the session no longer works
- verifies Spacelift with `spacectl whoami`, running `spacectl profile login` if
  the token has expired — only on a machine that has set
  `SPACECTL_LOGIN_ENDPOINT`
- updates gcloud components
- `git pull --ff-only` in every repo directly under `~/code`, skipping any with
  uncommitted changes
- `nvm install --lts`
- `pnpm install --frozen-lockfile` in `~/code/platform` if it exists
- `npx skills update -g`
- prunes tool caches — `npm cache verify`, `pre-commit gc`, `uv cache prune` —
  skipping any that aren't installed, silently
- `xcrun simctl delete unavailable`, dropping simulators whose runtime Xcode has
  since removed
- `docker system prune -f --filter until=24h`

Override the defaults with the `DOTFILES`, `CODE`, and `NVM_DIR` environment
variables. `SPACECTL_LOGIN_ENDPOINT` has no default and turns the Spacelift step
on.

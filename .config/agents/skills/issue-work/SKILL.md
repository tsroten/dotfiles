---
name: issue-work
description: Implement a feature or fix a bug in a Git repo through subagents, from scoping to merge and cleanup. Use when asked to work on an issue, an epic, or an epic's sub-issues (often several in parallel or overnight), to "start on #N", "do #N and #M", or to continue through a batch while the owner is away. Also use to work on an item from a repo's internal work-tracking file (a markdown TODO, backlog or issues list).
---

# Issue work

The main session orchestrates and keeps its own context small: it reads no item bodies and no
code itself, it briefs agents, relays their questions, sequences merges, and talks to the owner.
Everything below applies to a single item. *Running several at once* adds what parallel work
needs on top.

It is written for Claude Code and Codex alike, and names the tool where they differ. It assumes
nothing about the repo's language, build system, platforms or tracker. The repo's own rules are
its `AGENTS.md` or `CLAUDE.md` (root, plus any nested one for a directory); don't restate them in
briefs, tell agents to read them. The agent types are `scout` (finds and reports, changes
nothing), `implementer`, `careful-implementer` and `adversary` (reviews). A repo's own definitions
of the same names, or its delegation rules, override these.

An **item** is one unit of work: a GitHub issue, or an entry in the repo's tracking file. An
**epic** is an item with sub-items.

## The tracker

Find out which one the repo uses before briefing anyone: the instructions files name it, else look
for a tracking file (`TODO.md`, `BACKLOG.md`, `ISSUES.md`, `docs/issues.md`, `docs/plans/`) and
check `gh issue list -L 3` for a remote with issues. If it is still unclear, ask the owner once.
The steps below say *read*, *record*, *close* and *reference*; this is what each means:

| Operation | GitHub issues | Tracking file |
|---|---|---|
| **Read an item** | `gh issue view <N> --comments` (the body alone omits owner decisions), and the parent's the same way | The item's entry, its parent's, and any notes or plan it links |
| **Relationships** | The header's `parent`, `blocked-by`, `blocking` | Whatever the file uses: nesting, "depends on", ordering. Read it as the order of work |
| **Record a decision** | A comment on the item | Append it to the item's entry, dated |
| **Close** | `Closes #N` in the PR, or `gh issue close` | Mark the entry done and say where it landed (branch or merge commit) |
| **Refer to it** | `#N` | Its id, or its heading if it has none |

**With a tracking file, the lead is its only writer.** Agents never edit it, because parallel
branches that all touch one file conflict on every merge. The lead updates it on the default
branch as each item lands, with the same landing path as docs-only changes. Branch names use the
item's number, or a short slug if it has none.

## Before anything runs

1. **Keep the machine awake for the whole run, without asking**, if it sleeps on idle. A run
   spends hours between turns waiting on agents, and a sleeping laptop stalls them. Claude Code
   holds its own `caffeinate` only while a turn runs, and Codex's `prevent_idle_sleep` is off by
   default. On macOS, start one at the beginning and stop it when the run ends or pauses for the
   owner: `nohup caffeinate -is >/dev/null 2>&1 & echo $! > <scratchpad>/caffeinate.pid`, then
   `kill "$(cat <scratchpad>/caffeinate.pid)"`; confirm with `pgrep -fl caffeinate`. On Linux
   use `systemd-inhibit` the same way. On a server or CI box, skip this.
2. **Run from the main checkout of the repo, not from a worktree session.** In Claude Code a
   worktree-isolated session pins every subagent's git to its own worktree, so an agent briefed
   into a sibling worktree can edit there but not commit, and a reviewer can end up mutating the
   tree it was told to leave alone.
3. **Read each item with its decisions and relationships**, through a `scout` rather
   than in the main session (the table above says what that is for this tracker). The
   relationships set the order: what can start now, what waits, and which branch a dependent
   item stacks on. If the repo has a triage or readiness convention (a `ready` label, a status
   column), an item that doesn't meet it goes through that before an agent builds it.
4. **Scope through the agent that will implement it:** `implementer`, or `careful-implementer`
   for code where a mistake is expensive to undo or notice (security, credentials, money, data
   migrations, wire formats, concurrency); the repo's instructions usually say which directories
   those are. It reads the item, the plan and the code, then stops with
   questions. Resume the same agent to implement once they're answered.
5. **Ask every decision question up front, in one round**, before the owner leaves. Include
   **who merges and pushes (the lead or the owner), whether PRs are used, and whether the lead
   may deploy.** Pushes, PRs, remote-branch deletion, merges and deploys are outward-facing: the
   lead does one only with that authorization, from this answer or the repo's instructions, and
   otherwise stops at a local commit and hands the owner the command. Include
   "anything I should decide ahead of time?" for later items in the batch. Record each answer
   on its item (see the table) so docs have a record to cite, and in the rules file (below).

## The rules file

Write one rules file per batch in the session scratchpad, from
`references/implementer-rules.md`, and fill in its placeholders. Every brief opens with *"FIRST
read <path>. It binds you."* That keeps each brief to what is specific to its item.

Fill the toolchain and isolation sections from what the repo actually has: look at its build
files, test commands, CI config and instructions. Delete the sections that don't apply (no
database, no emulators, no UI) rather than leaving them for agents to puzzle over.

Add to it as the run teaches you: a new owner decision, a port range after a collision, a
toolchain change. Tell running agents about the addition (`SendMessage` in Claude Code); agents
spawned later read it anyway.

## Each item's loop

Brief templates for each step are in `references/briefs.md`.

1. **Worktree.** Off the default branch (`origin/<default>`, or the local branch if there is no
   remote), or stacked on a parent item's branch when it depends on work not yet merged. Use the
   repo's convention if it names one; otherwise a sibling directory,
   `<repo-parent>/<repo-name>-worktrees/issue-<N>-<slug>`, on branch `issue-<N>-<slug>`. The
   brief names the commit it must start at: an agent's worktree has been found 157 commits stale,
   so it checks `git log --oneline -1` and resets if it's wrong.
2. **Implement.** Commits go in the worktree; the agent never pushes. If the item has something
   to look at (a screen, a page, a CLI's output, an API response), ask for a way to see it in the
   report as soon as it works, and hand it to the owner straight away.
3. **Review.** If the repo's instructions lay out a review or merge process (named reviewers,
   a fixed question list, a round limit, self-assigning the item, testing new tests in both
   directions), that process replaces steps 3 to 6 wherever it is stricter; this is the baseline
   for repos that have none. Use one or more `adversary` agents in their own detached worktrees at the
   branch's head, split by dimension for anything large (correctness, concurrency, security,
   wording, tests), with one of them running the thing for real if it has a UI, a device or a
   service. Give them the claims to attack and the findings already fixed.
   **Review runs when implementation finishes, whatever the landing path.** "Commit locally",
   "no PR" and "merge and push" change the landing step and leave this step in place; only the
   owner saying to skip review skips it.
4. **Sort the findings.** A *defect in what was proposed* gets fixed. *Work the proposal did not
   include* goes to the owner with a recommendation; reviewers argue for completeness, and the
   trade is the owner's call.
5. **Fix round.** Small and local: resume the implementer. Large, or the implementer's context
   is already big: a fresh `implementer` briefed from the findings and the handoff note. Every
   test written to close a finding is mutation-checked: revert the fix and confirm that test,
   and only that test, fails.
6. **Verify** the fixes with a short `adversary` round aimed only at them.
7. **Strings.** If the branch added or changed text a user sees (UI copy, error messages, CLI
   output, emails), list every string before merge: verbatim, the old wording for a changed one,
   where it lives (file's symbol) and when it shows. Prefer reusing an existing sentence.
8. **Docs that cite code come last.** A doc written in parallel with the code it cites goes
   stale by construction; re-derive its citations once the code settles.
9. **Land it.** Follow the repo's rules, and the authorization from step 5 of *Before anything
   runs*, if they state a path; otherwise:
   - Docs and tracker only: merge to the default branch directly, with no PR, if the owner is
     content with that. Ask once per batch.
   - Code, with a remote that uses PRs: push the branch, open a PR, wait for CI, then merge
     (`references/briefs.md`, *Merge and clean up*, for a cheap agent to do it). The PR says
     `Closes #N`, or `Part of #N` when the item keeps something open.
   - Code, with no remote or no PRs: merge locally (`references/briefs.md`, *Merge to local
     default branch without pushing*). A local merge moves the branch ref, and the main
     checkout's files must follow it or `git status` there shows the merge as staged reverse
     changes; the merge is not done until they match.
   - Whatever the path, the repo's gates (tests, linters, formatters, CI) pass on the merged
     result, and the tracker is updated.
10. **Clean up straight after the merge:** the worktree, its build output (a Rust `target/` is
    14–22 GB; `node_modules`, Gradle and Xcode caches add up too), the local and remote branch,
    review worktrees, and any simulators, emulators, containers or databases the item created.

**Don't hold an item open for hardware.** When everything has run except a check that needs a
physical device or an environment you don't have, move that item to the epic's hardware or
manual-verification item (create one if the owner agrees), and close or narrow the feature item.

## Running several at once

- **What can start now:** a blocker protects completion and integration, not prototyping or
  decision work. Start the parts of a dependent item that don't read the blocker's output, and
  stack the rest on the blocker's branch.
- **Give each agent its own of everything it writes to:** worktree, build output directory (for
  example `CARGO_TARGET_DIR`, or a `dist` or `build` path), test database (`<db-name>_test_<n>`),
  scratch subdirectory, container names, dev-server and emulator ports, and simulator or emulator
  name prefix. The session scratchpad is shared by every agent in it, and test binaries read the
  tree they were built in. List only the kinds this repo has.
- **Merge order:** whichever branch goes green first merges; the others rebase onto the default
  branch. Shared docs, such as a tracking file, a changelog, a lockfile or a generated file, are
  where the conflicts land; the rebasing agent keeps both sides, regenerates what is generated,
  and reruns everything. A stacked branch rebases once its parent merges.
- **The main checkout is shared with other sessions.** Before merging there, check `git branch
  --show-current` and `git worktree list`. Never push another session's local commits; merge
  into a detached worktree on `origin/<default>` and push that commit. Before saying another
  session's commit came through, check `git merge-base --is-ancestor <sha> HEAD`.
- **Watch the disk.** Run `df -h /` at every merge; a full disk takes the shell, containers and
  test databases down together.
- **A collision is a rules-file entry.** When two agents meet on a port, a database or a file,
  re-run whatever the loser measured, and add the fix to the rules file before the next spawn.

## Talking to the owner

- **Status messages:** short, by item, saying what's running, merged or waiting, and on what.
- **Before the owner leaves:** confirm there's nothing left to decide. When they return, give a
  summary that separates what ran from what was only written, lists what's still open per item
  and why, and lists the strings to approve if there are any.
- **Hand over credential steps:** anything needing a secrets manager, a production shell, a
  deploy or a cloud login goes to the owner as a command to run themselves (in Claude Code, typed
  after a leading `!`), never run unattended. Those prompts appear on the owner's screen, and
  approving one approves whatever the agent is about to do with it.

## Long runs

Each turn the orchestrator takes re-reads its whole context. At a batch boundary, write
`HANDOFF.md` in the scratchpad: what's merged, open, running and decided, and the rules file's
path. Suggest the owner start a fresh session from it rather than run one session for a day.

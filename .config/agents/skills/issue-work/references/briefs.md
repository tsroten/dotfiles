# Brief templates

Fill in each `<placeholder>`. Keep a brief to what is specific to its item; the rules file
carries everything shared. `<read item>` is the tracker's read command from `SKILL.md`'s table
(`gh issue view <N> --comments`, or "the entry for <id> in <tracking file>"). `<main>` is the main
checkout's absolute path and `<default>` is the default branch.

## Scope, then implement (`implementer` or `careful-implementer`)

```
You are implementing <#N | item id>, "<title>" (parent <epic>), in the <repo-name> repository.

FIRST read <rules file>. It binds you.

Your worktree is <path>, on branch <branch>, at <commit> (<subject>). <Stacked on <M>'s branch,
which merges first; the lead will tell you when to rebase onto <default>.>

Read first: <read item> and the same for <epic> (read-only; owner decisions are there),
<plan sections>, <rows and decisions it owns>, <the reference implementation's files, if this
ports behavior from another platform or module>.

The owner has decided the following. Do not reopen it:
- <decision>

Scope first. Report what the item needs, what you'd build, and every question whose answer
changes what you build. Then stop and wait. Don't implement until the lead resumes you.

Tests: <what must be proved, and where: unit, integration, end to end, device, failure injection>.
Out of scope: <the neighboring items' work>.
```

## Adversarial review (`adversary`)

```
Adversarial review of branch <branch> at <head>, implementing <#N | item id>, "<title>". <Stacked
on <M> at <base>; review only the commits after <base>.>

Its worktree, <path>, is read-only to you. Work in your own:
`git -C <main> worktree add --detach <your path> <head>`.
<Your dimension: <one of: correctness of X / concurrency and lifecycle / security / wording and
guards / behavior of the running thing, the only reviewer who runs it, on ports <range>>.>

Claims to attack:
- <a property the branch asserts>

Already fixed, so hunt new ground: <list, or "nothing yet">.

Use <your own build directory, database, port range, simulator prefix: only the kinds the rules
file lists>. Clean up your worktree, its build output and anything you started before you finish.
```

## Fix round (fresh `implementer`)

```
Fix the review findings on branch <branch> in <worktree>, which is at <head>.
FIRST read <rules file>, then <scratch>/<item>/HANDOFF.md for the branch's state.

Findings to fix (defects in what was proposed):
1. <finding: the failure, and where>

Not to fix (out of scope, going to the owner): <list>.

Mutation-check each test you add to close a finding: revert the fix and confirm that test, and
only that test, fails. Report per finding: the fix, the test, and the mutation result.
```

## Merge and clean up (`implementer`; cheap and mechanical)

Use this when the repo has a remote and the branch went through a PR.

```
Merge a reviewed, CI-green branch into <default> and clean up. The repo is <main>, the main
checkout, which other sessions also use: never switch its branch, never push its local <default>,
and never discard its files. Send long output to a file and read only what you need.

1. `git -C <main> fetch -q origin`, then
   `git -C <main> worktree add -q --detach <tmp> origin/<default>`.
2. In <tmp>: `git merge --no-ff -q -F <message file> origin/<branch>`. On a conflict, run
   `git merge --abort`, remove <tmp>, and report the conflicting files. Don't resolve them.
3. `m=$(git rev-parse HEAD); git push -q origin "${m}:refs/heads/<default>"`. Quote it exactly
   like that, because zsh reads `$m:r` as a modifier. If the push is rejected because
   origin/<default> moved, recreate <tmp> and redo step 2 once.
4. Remove <tmp>.
5. If `git -C <main> branch --show-current` is `<default>` and
   `git status --porcelain --untracked-files=no` is empty there, run `merge -q --no-edit
   origin/<default>` in it. Otherwise skip this step and say why.
6. Check that `gh pr view <PR> --json state -q .state` says MERGED. (Skip if the host isn't
   GitHub; use its equivalent.)
7. For each of <worktrees and branches>: confirm `git merge-base --is-ancestor <branch>
   origin/<default>`, then `git worktree remove --force` and `git branch -D`. Delete the remote
   branch if `git ls-remote --heads origin <branch>` lists it. Touch no other worktree.
8. Delete only the simulators, emulators, containers and databases named <prefixes>, and only if
   none is running. Keep <anything a release or gate script owns>.
9. Report `df -h / | tail -1`.

Reply briefly: the merge commit on origin/<default>, whether local <default> moved, what was
removed, and what was skipped and why.
```

## Merge to local default branch without pushing (`implementer`)

Use this when there is no remote, or the owner pushes themselves and local `<default>` is ahead of
`origin/<default>`. It differs from the brief above in what it merges onto and in how the main
checkout is brought along.

```
Merge a reviewed branch into LOCAL <default> of <main> and never push. The main checkout is
shared with other sessions: never switch its branch, never discard its files, and never run
`git reset --hard` in it. Send long output to a file and read only what you need.

1. `old=$(git -C <main> rev-parse <default>)`, then
   `git -C <main> worktree add -q --detach <tmp> "$old"`.
2. In <tmp>: `git merge --no-ff -q -F <message file> <branch>`. On a conflict, keep both sides
   where the files are shared docs or ledgers and say so; otherwise abort and report the files.
3. Run the repo's gates (<build, test and lint commands>) in <tmp>, with your own build
   directory and database.
4. `new=$(git rev-parse HEAD)`. Then advance <default>, by one of two routes, chosen by the main
   checkout's state:
   - If `git -C <main> branch --show-current` is `<default>` and
     `git -C <main> status --porcelain --untracked-files=no` is empty, run
     `git -C <main> merge --ff-only "$new"`. It moves the pointer and the checkout's files
     together. `new` descends from `old`, so it fast-forwards; if <default> moved meanwhile it
     refuses, and you redo from step 1 on the new <default>.
   - Otherwise run `git -C <main> update-ref refs/heads/<default> "$new" "$old"`, which moves
     the pointer only. Never run it on a clean checkout that is on `<default>`: it leaves the
     checkout's index and files at the old tree, so `git status` there shows the whole merge as
     staged reverse changes and the next commit undoes it. Report `old`, `new` and the checkout's
     exact state, and leave the checkout alone: the lead repairs it (below).
5. Remove <tmp>, then the branch's worktree, its build output and the local branch
   (`git branch -d`).

The merge is not done until the main checkout matches `<default>`. After the `update-ref` route
the lead runs `git -C <main> read-tree -u -m "$old" "$new"`. It updates the index and the files
the merge changed, keeps another session's unstaged edits to other files, and refuses rather
than overwrites if the merge touches a file with local edits (then stop and ask the owner). The
classifier may ask for the owner's go-ahead on it. Afterwards
`git status --porcelain --untracked-files=no` shows only edits that are not part of the merge.
Do this before any push and before reporting the merge as landed.
```

## Update the tracking file (lead, when the repo uses one)

The lead does this, not an agent, on the default branch after each item lands: mark the entry
done, add where it landed (merge commit or branch), carry over any follow-ups the review sent to
the owner as new entries, and record the owner's decisions under the entry they belong to.

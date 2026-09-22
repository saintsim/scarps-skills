---
name: roadmap-item
description: Pick up a roadmap item by bare id and build it in the current code repo. Use whenever the user names a bare item from the repo they are standing in — "work on #41", "do RM-27", "lets work on RM-18 next" — without explaining what it is. The item is either a GitHub Issue on the code repo itself (`.roadmap` says `kind: github-issues`) or an Open-Road markdown item the repo's `.roadmap` points at; this skill reads the pointer and follows the matching flow.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, AskUserQuestion, Skill, Agent, SendMessage, mcp__github__issue_read, mcp__github__issue_write, mcp__github__list_issues, mcp__github__search_issues, mcp__github__add_issue_comment, mcp__github__list_pull_requests, mcp__github__search_pull_requests
---

The user says no more than `work on #41` or `work on RM-25` — everything below is what they should
not have to re-explain each time.

There are two kinds of roadmap, and the code repo's `.roadmap` file says which. **Read it first,
then read exactly one of the two flows in this skill's own directory and follow it end to end.**

```sh
grep -E '^(repo|kind|path):' "$(git rev-parse --show-toplevel)/.roadmap"
```

- **`kind: github-issues`** — the roadmap is the code repo's own issues: the issue number is the id,
  a migrated issue also answers to its old `RM-NN` id as a title alias, intent is a label or the
  closed state, and at pick-up a session posts a **start comment**, adds `in-progress` and sets
  **`intent:now`** — the three marks a board such as Sidebar or SidePocket reads to say who has what
  in hand, and on which machine. They go on **the moment the item resolves**, before the item is
  read in depth, before Gate 1 and before branching, so a pick-up is visible from its first minute.
  Read **`issues.md`**.
- **No `kind:` line, or `kind: markdown`** — the roadmap is an
  [Open-Road](https://github.com/saintsim/Open-Road) folder of markdown items the pointer names.
  Read **`markdown.md`**, and on the go-ahead **`after-go-ahead.md`**.
- **No `.roadmap` at all** — `markdown.md` §1 says how a companion repo resolves its project by
  matching its remote against each item's `repos:`; follow that, and if it resolves to nothing, ask.

Both flows share the same shape — resolve the item, mark the pick-up (issues flow), read before you
build, Gate 1 if the item is too thin, branch, implement, verify, Gate 2 for the user to test, then
**`/ship` to a draft PR, `/review-loop` over that PR**, and record the result — and
the same rules: **`intent` is hand-owned** — the only word either flow writes is `intent:now` at
pick-up on the issues flow, because *work on #41* is the owner instructing that the item is current
rather than anything read off the code, and the markdown flow writes no intent at pick-up at all;
neither ever writes `next`, `later` or `idea`, or closes an item. PRs open as **drafts**;
British English. What differs is where the item lives and how completion is recorded (a paired
Open-Road PR for markdown; a Delivered comment on the issue for issues, with the owner's
`/roadmap-done` closing it once the PR has merged).

## On a Mac, the pick-up happens in a worktree — both flows, every time

A cloud session gets a container and a clone of its own, so its checkout is already private. **A Mac
session does not.** Two sessions in one checkout share a HEAD: the second `git switch` moves the
first one's branch under it mid-edit, and uncommitted work goes with it. So when the surface is
local, the branch is cut in a **worktree** and the main checkout is left exactly where it is.

1. **Already isolated? Nothing to do.** True when the session was started with `claude --worktree`
   (or the desktop app's worktree option), or when `git rev-parse --git-common-dir` is not `.git`.
2. **Otherwise ask for one**: call **`EnterWorktree`** naming it for the item (`41-issues-roadmap`,
   `rm-25-<slug>`). It creates `.claude/worktrees/<name>/` and moves the session there. **It refuses
   unless a worktree was asked for by the user or by a `CLAUDE.md`** — the README says the one line
   to put in `~/.claude/CLAUDE.md` so every local pick-up qualifies. If it is unavailable or
   refuses, fall back to git and work from that path:

   ```sh
   git worktree add .claude/worktrees/<branch> -b <branch> origin/<default-branch>
   ```
3. **Check the branch name inside the worktree and fix it if it is wrong.** `claude --worktree <name>`
   creates its branch as `worktree-<name>` (Claude Code's worktree documentation, read 2026-09-22),
   which is not the `<N>-<slug>` the rest of the loop — and every skill that resolves an item from a
   branch — expects. `git branch --show-current`; if it is not the item's branch, `git switch -c` it
   there.
4. **`.claude/worktrees/` must be ignored**, or the main checkout shows the worktree as untracked
   files. Add it to `.gitignore` in your branch when the repo is one of ours, `.git/info/exclude`
   when it is not, and say which you did.

**Never remove a worktree you did not create, and never call `ExitWorktree` unasked** — the session
that owns a worktree is the one that decides when its work is disposable.

If the user's opening message waives the second gate — "don't wait for me to test", "go all the way
through", or equivalent — say so at the start and run straight through, in either flow.

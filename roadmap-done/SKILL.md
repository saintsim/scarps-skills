---
name: roadmap-done
description: Close a roadmap item — a GitHub Issue on the current code repo — as done, once its pull request has actually merged. Use when the user says "#41 is done", "close RM-27", "the PR merged, finish it off", "mark it done" after shipping. Proves the merge from GitHub before closing, refuses on an open, draft or closed-but-unmerged PR, records the merge evidence in a closing comment, and takes `in-progress` off if it is still on. Leaves the item's `intent:` label exactly as it is — the closed state is what says done — and never merges anything itself.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion, mcp__github__issue_read, mcp__github__issue_write, mcp__github__list_issues, mcp__github__search_issues, mcp__github__add_issue_comment, mcp__github__list_pull_requests, mcp__github__search_pull_requests, mcp__github__pull_request_read, mcp__github__get_commit
---

The last step of the loop, and the owner's to trigger: `/roadmap-item` ships a **draft** PR and
leaves the issue open on purpose, because a PR body says `Refs #N` and never `Closes #N` — a merge
must not write intent. Once the owner has merged it, this closes the item.

**It is the one skill that closes an item as completed**, and it does so only when told to and only
against a merge it has proved. Everything else about intent stays where it was: `/roadmap-item` and
`/roadmap-checkin` write `intent:now` at pick-up, and nothing here rewrites it.

**The one hard rule: prove the merge before closing.** A closed PR is not a merged PR, a draft is
not a merged PR, and "the build was green" is not a merged PR. If the merge cannot be proved from
GitHub, this skill closes nothing and says exactly what it found.

Items are GitHub Issues on the repo you are standing in; `.roadmap` must carry `kind: github-issues`:

```sh
git remote get-url origin                                     # <owner>/<repo> — the project
grep -E '^kind:' "$(git rev-parse --show-toplevel)/.roadmap"  # must say github-issues, else stop
```

A repo whose roadmap is Open-Road markdown records completion in its own paired roadmap PR
(`roadmap-item`'s `after-go-ahead.md`), not here — say so and stop.

**GitHub access:** the `mcp__github__*` tools if available (the web), else `gh` on a Mac. If neither
works, **print the exact close — issue, state reason, label to remove, comment text — and ask the
user to apply it.**

## 1. Resolve the item

In order: the id in the **user's message** (`#41`, `RM-27`); else the **current branch** — `<N>-*` is
issue `N`, `rm-NN-*` is the alias `RM-NN`; else **ask**, with one AskUserQuestion. Resolve an alias
by searching open **and closed** titles for the prefix `RM-NN —` and matching the start of the title
(`search_issues` with `repo:<owner>/<repo> in:title "RM-NN —"`, or `gh issue list --state all
--search '…'`). **Read the issue and show its number and title before changing anything** — closing
the wrong issue is silent and the board will believe it.

**An issue without the `roadmap` label is not a roadmap item** — say so and stop rather than closing
it; ordinary bugs in the same tracker are not this skill's to finish.

**Already closed?** Say so — state reason, when, and by whom — and stop. Do not re-close, and never
reopen to tidy anything up.

## 2. Prove the PR merged — the whole point of this skill

Find every PR that claims this item, from all three places, because any one of them can be missing:

```sh
gh pr list --state all --search 'Refs #41'            # or search_pull_requests: repo:<o>/<r> is:pr "Refs #41"
gh pr list --state all --head 41-<slug>               # or list_pull_requests with the branch
```

and the issue's own **Delivered comment** (`<!-- sidebar:delivered -->`), which carries the PR URL
`/roadmap-item` captured at ship time. Read each candidate (`pull_request_read`, or `gh pr view <N>
--json state,isDraft,merged,mergedAt,mergeCommit,baseRefName,url,title`).

A PR counts as merged only when GitHub says **`merged: true`**. Capture its **URL**, **merge commit
sha**, **`mergedAt`** and **base branch**. Then:

- **Merged into the repo's default branch** (`git remote show origin | sed -n 's/.*HEAD branch: //p'`)
  → go on to §3.
- **Merged into some other branch** → say which, and **ask** whether that counts as delivered here;
  a merge into a release or feature branch may mean the work has not reached the trunk yet.
- **Open, or a draft** → **close nothing.** Report its state, whether it is still a draft, and what
  is outstanding (review, CI, conflicts) if that is visible. The owner merges it, then runs this
  again.
- **Closed but not merged** → **close nothing.** That is work abandoned, not delivered: if the item
  really is dropped, that is `/roadmap-edit` closing it as *not planned*, which is a different
  decision and the owner's to say out loud.
- **Several PRs** → every one that delivers the item must be merged. If some are merged and others
  are not, name them and ask.
- **No PR at all** → **close nothing.** Ask, with one AskUserQuestion, whether the item was
  delivered another way (a direct commit, work folded into another item's PR, or delivered outside
  this repo) and only continue on an explicit answer naming what delivered it — record that answer,
  verbatim in substance, as the evidence in §3 in place of a merge commit.

**Never merge, re-open, re-target or push anything to get to a mergeable state.** This skill reads
GitHub and writes one comment, one close and one label removal. Nothing else.

## 3. Close it — comment, state, label

In this order, so the evidence lands even if a later call fails.

1. **The closing comment**, naming what proved the merge. No new `sidebar:` marker — the board reads
   the closed state for *done*; this comment is the audit trail for a reader a year from now.

   ```markdown
   **Done** · merged 2026-09-18T14:22Z · PR <url> · commit `a1b2c3d` on `main`

   <one or two lines: what shipped, and anything a reader should know — a follow-up issue raised,
   something the review deferred, a part of the item delivered elsewhere>
   ```

   Cite the file and the thing, never a line number. Record what you observed, never a cause you
   did not observe.
2. **Close as completed** — `issue_write` (method `update`) with `state: closed` and `state_reason:
   completed`, or `gh issue close <N> --reason completed`. **`completed`, never `not planned`**:
   dropping an item is a different decision and lives in `/roadmap-edit`.
3. **Remove `in-progress`** if it is on — `issue_write` with the label omitted from the list, or
   `gh issue edit <N> --remove-label in-progress`.

**Never touch an `intent:` label**, in either direction — and expect the item to be carrying
`intent:now`, because the pick-up put it there and delivery deliberately left it on. That is not
untidiness to clean up on the way past:

- **The closed state is what says *done*.** A board reads the state; a closed item is finished
  whatever label it wears, which is why there is no `intent:done` and this skill does not invent
  one. A fifth intent value would duplicate the state, have to be created in every repo the skills
  touch, and be wrong the first time the two disagreed.
- **Putting it back to `later` or `next` would be worse than leaving it**, since it files delivered
  work behind work nobody has started, and the intent labels are the owner's word about what they
  mean to do — never this skill's to rewrite, tidy or clear.

If the owner wants a different label on a closed item, that is one explicit `/roadmap-edit`.

## 4. Say what it unblocked — report only, change nothing

Open roadmap issues whose `Depends on:` line names this one may now be unblocked. List them —
number, title, and whether **all** their other dependencies are closed as completed too — and name
the one you would pick up next, in a line, with why.

**Do not apply `intent:next`.** The owner does that themselves, with one word to `/roadmap-edit`.

## Report

The item (number, alias, title); the **merged** PR URL, merge commit and base branch, or the
evidence accepted in its place; the closing comment URL; that the issue is closed as **completed**
and `in-progress` is off; what is now unblocked and what you would pick up next. If the item was not
closed, say plainly **why not** and what has to happen first — never leave a run ambiguous about
whether the board moved.

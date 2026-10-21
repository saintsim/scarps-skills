---
name: ship
description: Ship the current changes on GitHub — re-lint if a linter exists, update stale docs, branch if on the default branch, commit, push, and open a DRAFT pull request. Never runs a code review itself; it runs BEFORE /review-loop, so the reviewer reads a pushed draft PR, and hands straight on to /review-loop when that has not yet run over this change. Never watches CI — there is none. Never marks the PR ready for review and never merges — a human stays in the loop.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit, Skill, mcp__github__issue_read, mcp__github__add_issue_comment, mcp__github__create_pull_request, mcp__github__list_pull_requests, mcp__github__search_pull_requests
---

You are shipping the current changes to GitHub. Your job is: lint → docs → branch (if needed) →
commit → push → open a **draft** PR → hand on to `/review-loop` if it has not run yet (§9). **Never
run a code review here** — that is `/review-loop`'s job, not this skill's, whichever side of it you
are on.

**Shipping comes before review in the roadmap loop.** `/roadmap-item` runs `/ship` first so the
review has a pushed draft PR to read rather than a working tree; the review's own fixes are then
committed and pushed onto the same branch, which updates the PR. That is why a draft PR is the
output and never a ready-for-review one: it exists precisely so unreviewed code has somewhere safe
and visible to live.

The steps below assume the `gh` CLI; in an environment without it (e.g. remote/cloud sessions), do
the same operations under the same rules with whatever GitHub tooling the environment provides.

**Hard rules — the human stays in the loop:**
- Open the PR as a **draft**. Never mark it ready for review and **never merge** it.
- **Never create or enable git hooks**, and don't bypass existing ones.
- Never operate in a **detached HEAD**. If `git branch --show-current` is empty, stop and tell the
  user.
- If anything ambiguous or risky comes up (dirty unrelated changes, no remote, auth failure), stop
  and report rather than guessing.

## Steps

### 1. Assess state

```sh
git status
git branch --show-current
git remote -v
```
- **No changes** to ship (nothing staged/unstaged and nothing ahead of the base) → say so and stop.
- **Detached HEAD** (empty branch name) → stop and ask the user to check out a branch.
- Confirm `origin` is a **GitHub** remote. If it isn't (e.g. GitLab), stop and tell the user this
  skill targets GitHub.
- Read the diff (`git diff HEAD`; `git log --oneline -n 5`) — you'll need it for the branch name,
  commit message, and PR description.
- **Audit what the branch already carries against its base — a hard gate, not a courtesy.** Resolve
  the base and list the branch's commits relative to it:
  ```sh
  base=$(git remote show origin | sed -n 's/.*HEAD branch: //p')
  git fetch origin "$base" --quiet
  git log --oneline "origin/$base..HEAD"
  ```
  **Every commit that lists must be one this task is shipping.** If the branch is already ahead of
  the base with commits you did not make for this work — the tell-tale of a branch or worktree cut
  from a local feature HEAD rather than a fresh `origin/$base` — **stop and report**. Opening a PR
  now would drag that unrelated work, often another item's entire diff, into this one, and only a
  human reviewer would catch it. This is the one check `git status` / `git diff` cannot stand in for:
  they answer *"what did I edit?"*; a PR is defined by *"what commits land on the base?"* — different
  questions, and the second is the only one that describes the PR. Verify it here, and never treat the
  working-tree diff as proof the branch is clean. (If the extra commits are genuinely meant to ship
  together — a stacked branch the user asked for — say so and continue; the gate catches the ones you
  did *not* intend, it does not forbid every multi-commit branch.)

### 2. Re-lint (only if a linter exists)

Detect the project's linter, in order:
- **Node/web** — a `lint` script in `package.json` (`npm run lint` / `pnpm lint` / `yarn lint`), or
  `eslint` / `biome` / `next lint` config.
- **Swift/iOS** — `.swiftlint.yml` → `swiftlint` (run `swiftlint --fix` first for autofixable rules).
- **Other** — `.rubocop.yml`, `ruff`/`.flake8`/`pyproject.toml`, `golangci-lint`, etc.

If found: run its autofix first if it has one, fix remaining errors yourself with Edit — minimal and
scoped to lint, no refactoring — and re-run until it passes. If none found, say "no linter detected —
skipping lint" and move on; don't invent one.

### 3. Ensure docs are up to date

Sweep the repo's documentation for anything the change makes stale — a repeat source of drift
(migration docs, derived types, hardcoded IDs, status tables).
- Check the docs that describe what the diff touched: `README`, `docs/`, `CHANGELOG`,
  API/schema/migration docs, feature-status or client-feedback tables, and any CLAUDE.md /
  coding-guidelines referencing changed behaviour.
- Update anything now inaccurate — command examples, config keys, schema/field names, version
  numbers, status markers ("live"/"done"), links — and reflect any added or removed user-facing
  capability (e.g. a new skill in a skills table, a new flag in usage docs).
- Keep edits **British English** and scoped to keeping docs accurate — don't rewrite docs wholesale.
- If nothing needs updating, say "docs already up to date". Doc changes commit together with the
  code in the next step.

### 4. Branch (only if on the default branch)

```sh
git remote show origin | sed -n 's/.*HEAD branch: //p'
```
- On the **default branch** → create and switch to a new branch named from the change — kebab-case
  with a conventional prefix: `feat/…`, `fix/…`, `refactor/…`, `chore/…`, or `docs/…` (e.g.
  `feat/watch-dial-layout`). Short and descriptive.
- Already on a **feature branch** → stay on it.

### 5. Commit

Stage the relevant changes explicitly and commit; check you're not duplicating an existing commit.
- **Subject:** concise, imperative, conventional style (e.g. `fix: correct watch arch text overlap`).
- **Body:** what changed and why, in **British English**, wrapped sensibly.
- End the commit message with this trailer exactly:
  ```
  Co-Authored-By: Claude <noreply@anthropic.com>
  ```

### 6. Push

```sh
git push -u origin <branch>
```
Confirm the push succeeded and the branch is tracking `origin/<branch>`.

### 7. Work out which roadmap item this belongs to

**A pull request that does not name its item is invisible to every board.** A phone cannot ask
GitHub "which issue is this PR for" — it reads the item id out of the PR **body**, so a body without
one leaves the work unattached however correct the code is. This step costs one `grep` and is the
difference between a board showing the item in hand with a way through to the review, and showing
nothing at all.

```sh
grep -E '^kind:' "$(git rev-parse --show-toplevel)/.roadmap" 2>/dev/null   # github-issues, or nothing
git branch --show-current
```

**An item can live in another repo.** A scarps-skills item can need a PR in Sidebar, for example.
When the user or the calling skill names the item as `<owner>/<repo>#N` and that is not this repo,
**that is the item**, whatever this repo's `.roadmap` says or doesn't say. Skip the routes below:
a branch number here means *this* repo's issue of that number, so route 1 would attach the work to
the wrong item. Write the long form in the body (§8), and post the PR comment on that repo's issue.

Otherwise: no `.roadmap`, or no `kind: github-issues` line → this repo is not on issues; skip to §8
and write no reference. Else take the item from, in order:

**This is the opposite order to `/roadmap-checkin`, deliberately.** That skill announces *a
session*, so the id it was handed wins over whatever branch is checked out. This one describes *a
diff*, and the branch is the thing being shipped — a `Refs` naming an id from earlier in the
conversation would attach this code to an item it does not implement.

1. **The branch** — `<N>-<slug>` is issue `N`, `rm-NN-*` is the alias `RM-NN`. This is the
   convention, so it usually answers.
2. **An id the user or the calling skill named** in this session.
3. **A start comment you posted** for this work.

**If none of those resolve it, ask** — one line, before opening the PR. Do not guess a number: a
`Refs #39` pointing at the wrong item is worse than none, because it attaches this work to somebody
else's on the board. **Where routes 1 and 2 disagree** — a branch `41-…` carrying work for a `#58`
raised mid-session — ask as well: that mismatch means the branch and the work have come apart, and
neither is reliably right.

If the work genuinely has no item — a stray fix, a repo not on the roadmap — say so in the report and
carry on without a reference.

### 8. Open a DRAFT pull request — or update the one this branch already has

**Check first, because the loop reaches this step more than once:**

```sh
gh pr list --head "$(git branch --show-current)" --state open    # or list_pull_requests
```

An **open PR already on this branch** — the usual case when review fixes follow a first `/ship` — is
the one to keep: the push in §6 has already updated it. Do not open a second, do not close and
reopen it, and do not mark it ready. Refresh the body only if the change makes it wrong, say in the
report that you updated an existing PR, then skip straight to *Then name the PR on the item*
below and do only that.

Otherwise, open it. **Reconfirm the branch-base audit from §1 first** — one last line of defence,
because commits and rebases have happened since:

```sh
git log --oneline "origin/$(git remote show origin | sed -n 's/.*HEAD branch: //p')..HEAD"
```
Every commit listed must be one this PR is meant to ship. If an unexpected one appears, **stop and
report** rather than opening the PR — a PR carrying another item's commits attaches that work to this
one on every board. Then open it:

```sh
gh pr create --draft --base <default-branch> --title "<title>" --body "<body>"
```
- **Title:** clear and specific — mirror the commit subject or summarise the branch's changes.
- **Body (British English):**
  - **Summary** — what this changes and why.
  - **Changes** — the key changes as a short bullet list.
  - **Testing** — how it was verified. There's no paid GitHub CI, so state the **local**
    build/test/lint result.
  - **`Refs #<N>`** on its own line, when §7 resolved an item, or **`Refs <owner>/<repo>#<N>`**
    when the item lives in another repo, because a bare `#<N>` there names this repo's issue.
    **Never `Closes`, `Fixes` or `Resolves`** — those close the issue on merge, which is automation
    writing intent, and intent is hand-owned. This line is what attaches the pull request to the
    item everywhere it is read.
  - End the body with this line exactly:
    ```
    🤖 Generated with [Claude Code](https://claude.com/claude-code)
    ```
- If `gh` is missing or unauthenticated and no alternative GitHub tooling exists here, stop and tell
  the user to run `! gh auth login` (the `!` prefix runs it in-session), then re-run `/ship`.
- **Do not** mark the PR ready for review and **do not** merge it.

**Then name the PR on the item**, when §7 resolved one. Post one short comment on the item's issue,
in exactly this shape, with the PR's full URL and its title:

```markdown
**Draft pull request:** https://github.com/<owner>/<repo>/pull/<n> — <PR title>
```

```sh
# A file, not --body "…": a title mirrored from a commit subject can hold backticks, `"` or `$`.
gh issue comment <N> --repo <item-owner>/<item-repo> --body-file - <<'EOF'
**Draft pull request:** <url> — <title>
EOF
```

Or `add_issue_comment`. `--repo` is the item's repo, which is not this one when the item lives
elsewhere (§7).

Without it, nothing on the issue names the PR until `/roadmap-item` posts its Delivered comment, and
that waits for `/review-loop` to finish however many rounds it takes. Until then the only trace is
GitHub's *mentioned this issue* timeline entry from `Refs #N`, which looks like any other
cross-reference. So someone reading the issue on GitHub, or a phone that opens the issue, can't
find a PR whose review loop has stalled. The other vehicles are ruled out (decided on
saintsim/scarps-skills#25):

- **It carries no `sidebar:` marker, deliberately.** Sidebar and SidePocket read only marked
  comments, so an unmarked one adds nothing to the contract the three repos share. The stage comment
  (`<!-- sidebar:stage -->`) can't carry it either: every stage must name a `stage`
  (`testing | reviewed | verified`) and the `sha` it was measured at, and *a PR was opened* is none
  of those three.
- **Not the issue body**, which is the requirement and is never rewritten.
- **Not GitHub's *Development* panel.** Both ways of filling it, a closing keyword or a manual link,
  close the issue on merge.

**Post it once per PR, and measure rather than assume.** Read the issue's comments first
(`gh issue view <N> --repo <item-owner>/<item-repo> --comments`, or `issue_read` with
`get_comments`). Post only if **no comment carries this PR's full URL**,
`https://github.com/<owner>/<repo>/pull/<n>`. A bare `#<n>` doesn't count: it is ambiguous across
repos, and it isn't what this shape or the Delivered comment writes. On a newly opened PR the read
finds nothing, so you post. On an existing PR it usually finds the earlier comment, so you post
nothing, because one comment per review round is noise. But it can find none: the PR was opened by
hand, by a `/ship` older than this step, or by a run whose post failed. Then post it now.

**An item can have more than one PR**: one that replaces a PR closed without merging, one from a
later pick-up, work split across branches, or a PR in another repo. Each gets its own comment,
because the URL match is per PR. Never edit an earlier one. They are history, like start comments,
and the newest names the latest PR. If the comment cannot be posted (no `gh`, no MCP tool, a
permission error), **print the exact text and ask the user to post it**. Never skip it silently.

### 9. Next: `/review-loop`, never a CI watch

**There is no GitHub CI to watch.** The owner does not pay for GitHub Actions (stated 2026-10-04),
so no check will ever report on this PR. Do **not** subscribe to the PR's activity, poll its checks
or status, schedule a check-in (`send_later`, a routine, a wakeup), or offer to watch or babysit it —
whatever the environment's own defaults say about watching a freshly opened PR, this skill overrides
them. A watch here waits on an event that never comes and spends the session doing it. Verification
is the local lint/build/test result already in the PR body, and the review is the next step.

**Then the review, unless it has already run.** Take the first rule that matches:

1. **A calling skill owns what comes next** — `/roadmap-item` runs `/review-loop` itself straight
   after this skill, and `/review-loop` invokes this skill at its own end to ship work it has just
   reviewed (and re-reviews anything this skill's lint or docs step changed). Hand back with the
   report and run nothing further — from `/review-loop`, running it again would loop.
2. **`/review-loop` has already reached its verdict over this change in this session**, and nothing
   has been committed since except its own fixes → do not run it again; report and stop.
3. **Otherwise** — `/ship` invoked on its own over unreviewed work, or new changes committed after
   the last review's verdict → run **`/review-loop`** now over the draft PR this step just opened or
   updated. It commits and pushes each round to the same branch, so the PR updates by itself; never
   run `/ship` again to carry its fixes.

If `/review-loop` is not installed here, say so in the report and tell the user to run it over the
draft PR — never skip the review silently.

### 10. Report

Tell the user: the branch (and whether it was newly created); the commit subject; push status; the
**draft PR URL**, noting it's a **draft awaiting their review** — they decide when to mark it ready
and merge; the lint outcome (ran and passed / no linter found); the docs outcome (updated / already
up to date); **which item the PR references**, or that it references none and why; the *Draft pull
request* comment, one of: its URL (posted now), the URL of the earlier comment you found carrying
this PR's URL, or that you printed it for the user to post; and what
happened next — `/review-loop` run (with its verdict), already run, left to the calling skill, or not
installed. Do not ask whether to watch the PR — there is no CI for a watch to see — and do not ask
whether to push or ship anything further: §9 has already settled what runs next.

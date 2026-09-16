---
name: ship
description: Ship the current changes on GitHub — re-lint if a linter exists, update stale docs, branch if on the default branch, commit, push, and open a DRAFT pull request. Assumes code review is already done (does NOT run one). Never marks the PR ready for review and never merges — a human stays in the loop.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit, mcp__github__issue_read, mcp__github__create_pull_request, mcp__github__list_pull_requests, mcp__github__search_pull_requests
---

You are shipping the current changes to GitHub. **Review is assumed already done** (e.g. via
`/review-loop`) — do **not** run another code review here. Your job is: lint → docs → branch (if
needed) → commit → push → open a **draft** PR, then hand back to the human.

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

No `.roadmap`, or no `kind: github-issues` line → this repo is not on issues; skip to §8 and write no
reference. Otherwise take the item from, in order:

1. **The branch** — `<N>-<slug>` is issue `N`, `rm-NN-*` is the alias `RM-NN`. This is the
   convention, so it usually answers.
2. **An id the user or the calling skill named** in this session.

**This is the opposite order to `/roadmap-checkin`, deliberately.** That skill announces *a session*,
so the id it was handed wins over whatever branch happens to be checked out. This one describes *a
diff*, and the branch is the thing being shipped — a `Refs` naming an id from earlier in the
conversation would attach this code to an item it does not implement. Where the two disagree — a
branch `41-…` carrying work for a `#58` raised mid-session — **stop and ask**; that mismatch means
the branch and the work have come apart, and neither skill should guess which is right.
3. **A start comment you posted** for this work.

**If none of those resolve it, ask** — one line, before opening the PR. Do not guess a number: a
`Refs #39` pointing at the wrong item is worse than none, because it attaches this work to somebody
else's on the board.

If the work genuinely has no item — a stray fix, a repo not on the roadmap — say so in the report and
carry on without a reference.

### 8. Open a DRAFT pull request

```sh
gh pr create --draft --base <default-branch> --title "<title>" --body "<body>"
```
- **Title:** clear and specific — mirror the commit subject or summarise the branch's changes.
- **Body (British English):**
  - **Summary** — what this changes and why.
  - **Changes** — the key changes as a short bullet list.
  - **Testing** — how it was verified. There's no paid GitHub CI, so state the **local**
    build/test/lint result.
  - **`Refs #<N>`** on its own line, when §7 resolved an item. **Never `Closes`, `Fixes` or
    `Resolves`** — those close the issue on merge, which is automation writing intent, and intent is
    hand-owned. This line is what attaches the pull request to the item everywhere it is read.
  - End the body with this line exactly:
    ```
    🤖 Generated with [Claude Code](https://claude.com/claude-code)
    ```
- If `gh` is missing or unauthenticated and no alternative GitHub tooling exists here, stop and tell
  the user to run `! gh auth login` (the `!` prefix runs it in-session), then re-run `/ship`.
- **Do not** mark the PR ready for review and **do not** merge it.

### 9. Report

Tell the user: the branch (and whether it was newly created); the commit subject; push status; the
**draft PR URL**, noting it's a **draft awaiting their review** — they decide when to mark it ready
and merge; the lint outcome (ran and passed / no linter found); the docs outcome (updated / already
up to date); and **which item the PR references**, or that it references none and why.

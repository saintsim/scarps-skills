---
name: ship
description: Ship the current changes on GitHub — re-lint if a linter exists, update stale docs, branch if on the default branch, commit, push, and open a DRAFT pull request. Assumes code review is already done (does NOT run one). Never marks the PR ready for review and never merges — a human stays in the loop.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit
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

### 7. Open a DRAFT pull request

```sh
gh pr create --draft --base <default-branch> --title "<title>" --body "<body>"
```
- **Title:** clear and specific — mirror the commit subject or summarise the branch's changes.
- **Body (British English):**
  - **Summary** — what this changes and why.
  - **Changes** — the key changes as a short bullet list.
  - **Testing** — how it was verified. There's no paid GitHub CI, so state the **local**
    build/test/lint result.
  - End the body with this line exactly:
    ```
    🤖 Generated with [Claude Code](https://claude.com/claude-code)
    ```
- If `gh` is missing or unauthenticated and no alternative GitHub tooling exists here, stop and tell
  the user to run `! gh auth login` (the `!` prefix runs it in-session), then re-run `/ship`.
- **Do not** mark the PR ready for review and **do not** merge it.

### 8. Report

Tell the user: the branch (and whether it was newly created); the commit subject; push status; the
**draft PR URL**, noting it's a **draft awaiting their review** — they decide when to mark it ready
and merge; the lint outcome (ran and passed / no linter found); and the docs outcome (updated /
already up to date).

---
name: ship
description: Ship the current changes on GitHub. Assumes code review is already done (does NOT run a review). Re-runs the project's linter if one exists and fixes lint issues, ensures the repo's docs are up to date with the change, creates a branch if on the default branch, commits, pushes, and opens a DRAFT pull request with an appropriate title and description. Never marks the PR ready for review and never merges — a human stays in the loop.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit
---

You are shipping the current changes to GitHub. **Review is assumed already done** (e.g. via `/review-loop`) — do **not** run another code review here. Your job is: lint → branch (if needed) → commit → push → open a **draft** PR, then hand back to the human.

**Hard rules — the human stays in the loop:**
- Open the PR as a **draft** (`--draft`). Never mark it ready for review (`gh pr ready`) and **never merge** it (`gh pr merge`).
- **Never create or enable git hooks**, and don't bypass existing ones.
- Never operate in a **detached HEAD**. If `git branch --show-current` is empty, stop and tell the user.
- If anything ambiguous or risky comes up (dirty unrelated changes, no remote, auth failure), stop and report rather than guessing.

## Steps

### 1. Assess state

```sh
git status
git branch --show-current
git remote -v
```
- If there are **no changes** to ship (nothing staged/unstaged and nothing ahead of the base), say so and stop.
- If **detached HEAD** (empty branch name), stop and ask the user to check out a branch.
- Confirm `origin` is a **GitHub** remote. If it isn't (e.g. GitLab), stop and tell the user this skill targets GitHub.
- Look at the diff so you understand what you're shipping — you'll need it for the branch name, commit message, and PR description:
  ```sh
  git diff HEAD
  git log --oneline -n 5
  ```

### 2. Re-lint (only if a linter exists)

Detect the project's linter, then run it. Check, in order:
- **Node/web** — a `lint` script in `package.json` (`npm run lint` / `pnpm lint` / `yarn lint`), or `eslint` / `biome` / `next lint` config.
- **Swift/iOS** — `.swiftlint.yml` → `swiftlint` (and `swiftlint --fix` for autofixable rules).
- **Other** — `.rubocop.yml`, `ruff`/`.flake8`/`pyproject.toml`, `golangci-lint`, etc.

If a linter is found:
1. Run its **autofix** first if it has one (`--fix`), then re-run to see what's left.
2. **Fix remaining lint errors** yourself with Edit — keep fixes minimal and scoped to lint, don't refactor.
3. Re-run until the linter passes.

If **no linter** is found, say "no linter detected — skipping lint" and move on. Don't invent one.

### 3. Ensure docs are up to date

Before committing, sweep the repo's documentation for anything the change makes stale — this repeatedly bites (stale migration docs, out-of-date derived types, hardcoded IDs, wrong status tables).
- Look at what the diff touched, then check docs that describe it: `README`, `docs/`, `CHANGELOG`, API/schema/migration docs, feature-status or client-feedback tables, and any CLAUDE.md / coding-guidelines that reference changed behaviour.
- Update anything now inaccurate — command examples, config keys, schema/field names, version numbers, status markers ("live"/"done"), and links.
- If the change adds or removes a user-facing capability, make sure it's reflected (e.g. a new skill in a skills table, a new flag in usage docs).
- Keep edits **British English** and scoped to keeping docs accurate — don't rewrite docs wholesale.
- If nothing needs updating, say "docs already up to date" and move on. Any doc changes get committed together with the code in the next step.

### 4. Branch (only if on the default branch)

Determine the default branch (usually `main`, sometimes `master`):
```sh
git remote show origin | sed -n 's/.*HEAD branch: //p'
```
- If the **current branch is the default branch**, create and switch to a new branch named from the change — kebab-case, with a conventional prefix: `feat/…`, `fix/…`, `refactor/…`, `chore/…`, or `docs/…` (e.g. `feat/watch-dial-layout`). Keep it short and descriptive.
- If already on a **feature branch**, stay on it.

### 5. Commit

Stage the relevant changes and commit. Verify you're not creating a duplicate of an existing commit.
- **Subject:** concise, imperative, conventional style (e.g. `fix: correct watch arch text overlap`).
- **Body:** what changed and why, in **British English**, wrapped sensibly.
- End the commit message with this trailer exactly:
  ```
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  ```

### 6. Push

```sh
git push -u origin <branch>
```
Confirm the push succeeded and the branch now has an upstream (`git status` shows it's tracking `origin/<branch>`).

### 7. Open a DRAFT pull request

Use the GitHub CLI:
```sh
gh pr create --draft --base <default-branch> --title "<title>" --body "<body>"
```
- **Title:** clear and specific — mirror the commit subject or summarise the branch's changes.
- **Body (British English):**
  - **Summary** — what this changes and why.
  - **Changes** — the key changes as a short bullet list.
  - **Testing** — how it was verified (build/tests/lint status). You don't pay for GitHub CI, so state the **local** verification result.
  - End the body with this line exactly:
    ```
    🤖 Generated with [Claude Code](https://claude.com/claude-code)
    ```
- If `gh` is missing or not authenticated, stop and tell the user to run `! gh auth login` (the `!` prefix runs it in-session), then re-run `/ship`.
- **Do not** run `gh pr ready` or `gh pr merge`.

### 8. Report

Tell the user:
- Branch name (and whether it was newly created).
- Commit subject.
- Push status.
- The **draft PR URL**, and an explicit note that it's a **draft awaiting their review** — they decide when to mark it ready and merge.
- Lint outcome (ran and passed / no linter found).
- Docs outcome (which docs were updated / already up to date).

---
name: roadmap-new
description: Create a new roadmap item as a GitHub Issue on the current code repo. Use when the user says "add an item", "new roadmap item", "raise an item for …", "park an idea", or describes work that belongs on the roadmap but has no issue yet. Searches for duplicates first; the one skill that writes an intent label, and only at creation.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion, mcp__github__issue_read, mcp__github__issue_write, mcp__github__list_issues, mcp__github__search_issues
---

An item is a GitHub Issue on the repo you are standing in (`git remote get-url origin`); the
`.roadmap` file must carry `kind: github-issues`, else say the repo is not on issues yet and stop.

**GitHub access:** the `mcp__github__*` tools if available (the web), else `gh` on a Mac. If neither
works, **print the exact title, body and labels and ask the user to create it.**

## 1. Search for duplicates first

```sh
gh issue list --state all --search '<key words from the request>' --limit 10
```

Or `search_issues` with `repo:<owner>/<repo> <key words>`. **Show near matches** — number, title,
state — before creating anything. If one plainly covers the request, offer `/roadmap-edit` on it
instead and stop unless the user says otherwise.

## 2. Compose the issue

- **Title** — a short noun phrase for the work. **No `RM-` prefix**: the alias exists only on
  migrated issues, and a new item's id is its number.
- **Body** — this template, in this order. The `Depends on:` line is the **first line of the body**
  and present **only when there are dependencies**; each is an existing issue number, checked with
  `issue_read` / `gh issue view` before it is written.

  ```markdown
  Depends on: #12, #15

  ## Why

  <the problem, in the user's terms — what is wrong or missing today, and for whom>

  ## Scope

  <what is built, and what is deliberately not>

  ## Done when

  <checkable conditions — a reader can say yes or no to each>
  ```

- **Labels** — **always `roadmap`**, plus an intent. The `roadmap` label is what makes an issue a
  roadmap item at all: most repos' trackers already hold ordinary bugs and features, and the board
  reads only labelled issues, so an item created without it is invisible. Then `intent:later` **by
  default**; `intent:idea` when the user says *park it*, *idea*,
  *someday*, or equivalent. This is the one place a skill writes an intent label, because an open
  issue with none is a validation finding and the user asked for the item in this message. Never
  `intent:now` or `intent:next` here — those are the owner's, via `/roadmap-edit`.
- **Milestone** — none, unless the user names a phase (`Phase 0` … `Phase 4`).

If *Why* or *Done when* cannot be written from what the user said, ask once, with one
AskUserQuestion, rather than inventing them — the body is read as the requirement by whoever builds
it.

## 3. Create it

One `issue_write` (method `create`) with title, body and labels — or:

```sh
gh issue create --title '<title>' --body-file <file> \
  --label roadmap --label intent:later [--milestone '<phase>']
```

## Report

The issue **number, title and URL**, the label set, the milestone if any, and the `Depends on:`
line as written. Nothing else changes: no branch, no comment, no other issue.

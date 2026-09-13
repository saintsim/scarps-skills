---
name: roadmap-checkin
description: Post the start comment for a roadmap item this session is ALREADY mid-way through and has never announced — a pick-up that predates the move to GitHub Issues, one made by hand, or one pulled down from the web with `claude --teleport` so the board still names claude.ai as the machine. Use when the user says "check in", "mark this as started", "post the start comment", "I teleported this", or asks why the board does not show this work as in hand, or shows it on the wrong machine. Never writes an intent label and never closes an issue.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion, mcp__github__issue_read, mcp__github__issue_write, mcp__github__list_issues, mcp__github__search_issues, mcp__github__add_issue_comment, mcp__github__list_pull_requests, mcp__github__search_pull_requests
---

A session that picked an item up before the roadmap moved to issues has no start comment, so
nothing on any machine knows the item is in hand. This posts that comment, once, with the real
state of the work as its paragraph. It does **not** build anything — `/roadmap-item` does that.

**GitHub access:** the `mcp__github__*` tools if available (the web), else `gh` on a Mac. If neither
works, **print the exact comment text and ask the user to post it.**

## 1. Work out the item

```sh
git remote get-url origin                                    # <owner>/<repo> — the project
grep -E '^kind:' "$(git rev-parse --show-toplevel)/.roadmap"  # must say github-issues, else stop
git branch --show-current
```

In order: the **current branch** — `rm-NN-*` is the alias `RM-NN`, `<N>-*` is issue `N`; else the
**user's message** (`#41` or `RM-27`); else **ask**, with one AskUserQuestion. Resolve an alias by
searching open and closed titles for the prefix `RM-NN —` and matching the start of the title
(`search_issues` with `repo:<owner>/<repo> in:title "RM-NN —"`, or `gh issue list --state all
--search '…'`). **Confirm the issue exists and show its number and title** before going on; a wrong
issue gets a comment nobody will notice is misplaced.

**An issue without the `roadmap` label is not a roadmap item.** Most repos' trackers hold ordinary
bugs and feature requests that predate the roadmap — PackRight had 66 — and the board reads only
labelled issues. If the id you are given resolves to an unlabelled issue, say so and stop rather
than picking it up: either it is not roadmap work, or it needs promoting first (`/roadmap-edit`,
which adds the label).

## 2. Gather the state — three to six lines

```sh
git status --short --branch
git log --oneline @{upstream}..HEAD 2>/dev/null || git log --oneline origin/HEAD..HEAD   # unpushed
gh pr list --head "$(git branch --show-current)" --state all       # or list_pull_requests / search_pull_requests
```

What is built, what remains, what is uncommitted or unpushed, and whether a PR exists and its URL.
Read the repo, not memory — the paragraph is what a reader on another machine will trust.

## 3. Post the start comment, then add `in-progress`

- **Web** — `CLAUDE_CODE_ENTRYPOINT=remote`, `CLAUDE_CODE_REMOTE_SESSION_ID=cse_<id>`; the session
  URL is `https://claude.ai/code/session_<id>`. **Prefer the URL your system prompt supplied**
  (an attribution line naming `https://claude.ai/code/session_…`); only if absent, replace `cse_`
  with `session_` and say in the paragraph that the link was derived. `host: claude.ai`.
- **Local (Mac)** — `CLAUDE_CODE_ENTRYPOINT` is `cli` or unset. `CLAUDE_CODE_SESSION_ID` is expected
  to hold the transcript uuid — **not yet measured on a Mac**. If empty, take the newest `*.jsonl`
  under `~/.claude/projects/` modified in the last minute and say the uuid was inferred.
  `host` is `hostname -s`; `link` is `http://<host>.local:8787/session/<uuid>`.

**Remote Control does not change either of those.** A local session with `/rc` on keeps running on
the Mac; claude.ai is a second keyboard on it, not a second machine. `surface` stays `local`,
`host` stays the hostname, and `remote_control:` records the one thing it adds — reachability from
a phone:

```sh
env | grep -i 'remote.control' || true          # a URL or id here, or nothing
```

Write it only when Remote Control is on for this session: a URL if one is there, else
`remote_control: enabled`. **Never ask the user to paste the URL**, and omit the key entirely
when `/rc` is off, so its absence reliably means "not reachable".

Timestamp UTC ISO 8601 to the minute (`date -u +%Y-%m-%dT%H:%MZ`). Marker, yaml fence and keys
**verbatim** — Sidebar parses them.

````markdown
<!-- sidebar:start -->
**Started** on **web** · 2026-09-09T12:04Z

```yaml
surface: web            # web | local
session: session_017wSwKg7FYMenuCMUTo5Grw
link: https://claude.ai/code/session_017wSwKg7FYMenuCMUTo5Grw
host: claude.ai
branch: 41-issues-roadmap
```

<the state from §2: what is built, what is uncommitted or unpushed, whether a PR exists and its URL>
````

For local: `surface: local`, `session: <uuid>`, `link: http://<host>.local:8787/session/<uuid>`,
`host: <hostname>`. **Never edit an earlier start comment** — if one already exists, this is a
resume and still posts a new one.

Then `issue_write` with `labels` = existing labels plus `in-progress`, or `gh issue edit <N>
--add-label in-progress`.

**A session pulled down with `claude --teleport` is exactly what this skill is for.** The terminal
gets its own copy of the session and new work there never reaches the cloud one again, so the web
start comment already on the issue now names claude.ai as the machine and links to a copy that has
stopped moving. Check in from the Mac and the latest comment says where the work actually is; say in
the paragraph that it was teleported from the web session.

**Never write an `intent:` label. Never close the issue.** Those are the owner's.

## Report

Say which issue (number, alias, title), that the start comment was posted, its **URL**, and that
`in-progress` is on. If a step could not run, say which and what the user has to post by hand.

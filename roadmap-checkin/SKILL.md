---
name: roadmap-checkin
description: Announce that this session has a roadmap item in hand — post its start comment, add `in-progress`, set `intent:now` — for work ALREADY under way that was never announced: a pick-up that predates the move to GitHub Issues, one made by hand, one raised by `/roadmap-new` for work already going on, or one pulled down from the web with `claude --teleport` so the board still names claude.ai as the machine. Use when the user says "check in", "mark this as started", "post the start comment", "I teleported this", or asks why the board does not show this work as in hand, or shows it on the wrong machine. Never writes `next`, `later` or `idea`, and never closes an issue.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion, mcp__github__issue_read, mcp__github__issue_write, mcp__github__list_issues, mcp__github__search_issues, mcp__github__add_issue_comment, mcp__github__list_pull_requests, mcp__github__search_pull_requests
---

A session that picked an item up before the roadmap moved to issues has no start comment, so
nothing on any machine knows the item is in hand. This posts that comment, once, with the real
state of the work as its paragraph, and marks the item accordingly. It does **not** build
anything — `/roadmap-item` does that.

**GitHub access:** the `mcp__github__*` tools if available (the web), else `gh` on a Mac. If neither
works, **print the exact comment text and ask the user to post it.**

## 1. Work out the item

```sh
git remote get-url origin                                    # <owner>/<repo> — the project
grep -E '^kind:' "$(git rev-parse --show-toplevel)/.roadmap"  # must say github-issues, else stop
git branch --show-current
```

In order: **an id you were given** — in the user's message (`#41`, `RM-27`) or by the skill that
invoked you, `/roadmap-new` being the one that does; else the **current branch** — `rm-NN-*` is the
alias `RM-NN`, `<N>-*` is issue `N`; else **ask**, with one AskUserQuestion. **A named id outranks
the branch**, and the ordering is load-bearing: a session on `41-board-and-auth` that has just
raised #58 for something else would otherwise check in against #41 and tell the board the wrong
thing about both.

Resolve an alias by searching open and closed titles for the prefix `RM-NN —` and matching the start
of the title (`search_issues` with `repo:<owner>/<repo> in:title "RM-NN —"`, or `gh issue list
--state all --search '…'`). **Confirm the issue exists and show its number and title** before going
on; a wrong issue gets a comment nobody will notice is misplaced.

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

## 3. Post the start comment, then add `in-progress` and `intent:now`

**Work out the surface first, and measure it — never assume.** Run this before writing anything:

```sh
uname -s                                    # Darwin = a Mac; anything else is not
echo "${CLAUDE_CODE_REMOTE:-}"              # true on a cloud session
echo "${CLAUDE_CODE_ENTRYPOINT:-}"          # remote, remote_mobile, cli, or unset
```

- **Web (claude.ai), when `CLAUDE_CODE_REMOTE` is `true` or `CLAUDE_CODE_ENTRYPOINT` *starts with*
  `remote`.** Measured 2026-09-16 in a session opened from the iPhone app: `remote_mobile`, so
  matching `remote` exactly misses it. `surface: web`, `host: claude.ai`. The session id is
  `CLAUDE_CODE_REMOTE_SESSION_ID=cse_<id>` and the URL is `https://claude.ai/code/session_<id>` with
  the same `<id>` — verified against a live session. **Prefer the URL the harness supplied** in your
  system prompt (an attribution line naming `https://claude.ai/code/session_…`); only if absent,
  derive it by replacing `cse_` with `session_`, and say in the paragraph that the link was derived.
- **Local, only when `uname -s` is `Darwin`.** `surface: local`, `host` is `hostname -s`, `link` is
  `http://<host>.local:8787/session/<uuid>`. The uuid is `CLAUDE_CODE_SESSION_ID`; if it is empty,
  take the newest `*.jsonl` under `~/.claude/projects/` modified in the last minute and say in the
  paragraph that the uuid was inferred. **If that finds nothing either — an ordinary state for a
  session running for hours — write neither `session:` nor `link:`, and say in the paragraph that
  the session could not be identified.** A made-up uuid is a link that fails; an absent key is
  readable as "not known".
- **Anything else: stop and ask.** Not a Mac and not a cloud session means the environment is one
  nothing here has measured, and there are **exactly three** valid machine shapes — `claude.ai`, and
  one per Mac. Guessing mints a fourth that the owner has never heard of and cannot get rid of.

**`CLAUDE_CODE_SESSION_ID` is not evidence of a Mac.** It is populated on cloud sessions too
(measured, same session as above), so a model that reads it as the local branch's signature writes
`surface: local` with `host: vm` and a link to a machine that does not exist. `uname -s` is the
test; nothing else is.

**`host` is `hostname -s` verbatim** — never a friendly name, never with `.local` appended, never
invented. A board keys the machine on that exact string, so one session writing `Simons-Mac-mini`
and another writing `mac-mini` puts the same Mac on the phone twice, under two names. The web's
`host` is always the literal `claude.ai`.

**Never mark the pick-up anywhere else** — not GitHub's Assignee field, which holds a GitHub *user*
and so can only ever name the owner's login whichever machine is working; not a plain comment, not
the title. `surface` and `host` in the block below are the only place a machine is ever recorded.

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

**The heading names the machine, not the author.** `claude.ai` for a web session, the hostname for
a local one — the same words the board uses, so the comment reads the same on a phone and on the
issue page. GitHub itself cannot help here: it attributes every issue and comment to whoever's token
posted, which is the owner's on both surfaces, so the issue page will say *saintsim* whatever
machine did the work. This line and the `yaml` block below it are the only places the real answer
is ever written down.

````markdown
<!-- sidebar:start -->
**Started** on **claude.ai** · 2026-09-09T12:04Z

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

**`branch:` names the item's own branch, or is omitted entirely.** The example above carries one
because a check-in usually happens mid-build. When the work is still on the default branch — which
is the ordinary case for the `/roadmap-new` hand-off, since the item did not exist when the work
started — **leave the key out**. Writing `branch: main` tells a board that `main` is the delivering
branch, which is worse than saying nothing.

Then the labels, in **one** edit. **Compose the target set from the labels you actually read** —
everything the issue carries, minus any `intent:` label it carries, plus `in-progress` and
`intent:now` — rather than sending a blind delta:

```sh
gh issue edit <N> --add-label in-progress,intent:now \
  --remove-label <only the intent: labels this issue actually has>
```

**Never name a label the issue does not carry.** `gh` resolves every name against the repo's label
list, so one `--remove-label intent:idea` on a repo that never created `intent:idea` fails the whole
command and **both marks are lost together** — the comment posted, the labels not, which is the
original complaint with extra steps. On the web this is safe by construction: `issue_write` takes
the whole label list, so build it from the labels read and send that.

**A label that does not exist cannot be added either**, so create the two first on a Mac — both are
no-ops when they are already there:

```sh
gh label create intent:now --color d93f0b --description 'intent: now — in hand, hand-owned' 2>/dev/null || true
gh label create in-progress --color 0e8a16 --description 'a session has this item in hand' 2>/dev/null || true
```

The web MCP server has no label-create call: if the edit then fails for a missing label, **say which
one and ask the user to add it** rather than dropping it and leaving a start comment nothing
corroborates. An item already carrying `intent:now` needs no change to it; say so rather than
claiming an edit.

**A session pulled down with `claude --teleport` is exactly what this skill is for.** The terminal
gets its own copy of the session and new work there never reaches the cloud one again, so the web
start comment already on the issue now names claude.ai as the machine and links to a copy that has
stopped moving. Check in from the Mac and the latest comment says where the work actually is; say in
the paragraph that it was teleported from the web session.

**Why `intent:now`, when intent is hand-owned.** The hand is the one that told this session to do
the work; the check-in only records what it was already told. The rule that matters is intact —
intent is never read off the code, not from a green build, a merged PR, a passing review or a branch
that exists — and it is what keeps the other three the owner's: **never write `intent:next`,
`intent:later` or `intent:idea` here, and never close the issue.** `next` in particular sequences
what has **not** started, which is the opposite of what this skill knows.

An item already carrying `intent:now` needs no change; say so rather than claiming an edit.

## Report

Say which issue (number, alias, title), that the start comment was posted, its **URL**, and that
`in-progress` and `intent:now` are on — naming the intent it replaced, if it replaced one, so the
user can put it back in one `/roadmap-edit` if the item was not really in hand. If a step could not
run, say which and what the user has to post or set by hand.

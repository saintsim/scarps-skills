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
alias `RM-NN`, `<N>-*` is issue `N`, and a leading `worktree-` is stripped first, since
`claude --worktree 41-board` puts the session on `worktree-41-board` (Claude Code's worktree
documentation, read 2026-09-22); else **ask**, with one AskUserQuestion. **A named id outranks
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
uname -s                                    # Darwin = a Mac. First test, and it wins.
echo "${CLAUDE_CODE_REMOTE:-}"              # true on a cloud (CCR) session
echo "${CLAUDE_CODE_ENTRYPOINT:-}"          # remote, remote_mobile, cli, local-agent, or unset
```

Take the **first** of these that matches. The order is load-bearing:

1. **`uname -s` is `Darwin` → `surface: local`.** Darwin decides, and nothing overrides it. A Mac is
   a Mac whether the keyboard is in front of it, on a phone through Remote Control, or running a
   self-hosted runner on that same machine — all three keep the work on the Mac, which is exactly
   what the `/rc` rule below says. Testing the remote variables first would label the Mac mini
   `claude.ai` on any of them.
   `host` is `hostname -s`; `link` is `http://<host>.local:8787/session/<uuid>`. The uuid is
   `CLAUDE_CODE_SESSION_ID`, or — when that is empty — the newest `*.jsonl` under
   `~/.claude/projects/` modified in the last minute, saying in the paragraph that it was inferred.
2. **`CLAUDE_CODE_REMOTE` is `true`, or `CLAUDE_CODE_ENTRYPOINT` *starts with* `remote` →
   `surface: web`, `host: claude.ai`.** *Starts with*, not equals: the entrypoint names the client,
   and measured 2026-09-16 from the iPhone app it is `remote_mobile`. `remote_desktop` and
   `remote_trigger` are others. The session id is `CLAUDE_CODE_REMOTE_SESSION_ID=cse_<id>` and the
   URL is `https://claude.ai/code/session_<id>` with the same `<id>` — verified against a live
   session. **Prefer the URL the harness supplied** in your system prompt (an attribution line
   naming `https://claude.ai/code/session_…`); only if absent, derive it by replacing `cse_` with
   `session_`, and say in the paragraph that the link was derived.
3. **Neither → stop and ask**, naming what a good answer is: which machine this is, spelled as its
   own `hostname -s` gives it, or that it is a cloud session. There are **exactly three** shapes —
   `claude.ai`, and one per Mac — so a Linux container, a devcontainer or CI is an environment
   nothing here has measured, and guessing mints a fourth the owner never had and cannot remove.
   Put the answer in the paragraph so the next session does not have to ask again.

**`CLAUDE_CODE_SESSION_ID` identifies nothing on its own.** It is populated on cloud sessions as
well as local ones (measured 2026-09-16), so a model reading it as the local branch's signature
writes `surface: local` with `host: vm` and a link to a machine that does not exist.

**If the uuid cannot be found on a Mac, do not post the comment at all.** The phone drops a start
whose `session` is missing or empty: SidePocket's `IssueParsing.swift` guards `surface` and
`session` strictly and every other key leniently, because half a start is a row claiming a session
that may not exist. A comment written without it is not a weaker mark — it is **no mark, reported as
posted**. Add `in-progress` and `intent:now`, then say plainly that the session could not be
identified, so the item shows in hand with the machine unknown and the owner knows why.

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

**A start with no `session:` value is never posted, on either surface.** The phone drops it whole
(`IssueParsing.swift` guards `surface` and a non-empty `session` strictly), so it would be no mark
wearing the appearance of one. If the id cannot be established — the Mac uuid is not discoverable,
or a cloud session carries no `CLAUDE_CODE_REMOTE_SESSION_ID` and the harness supplied no URL —
post nothing, add the two labels, and say so. That applies to every comment written from this file,
including a teleport's second one and any printed for the user to post by hand.

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

On a Mac, substitute the issue's own `intent:` labels into the remove list — and when it carries
none, **drop the `--remove-label` flag entirely** rather than passing it an empty argument:

```
gh issue edit <N> --add-label in-progress,intent:now --remove-label intent:later
gh issue edit <N> --add-label in-progress,intent:now            # carried no intent label
```

**Never name a label the issue does not carry.** `gh` resolves label names against the repo's own
list, so naming one the repo never created is expected to fail the whole command — and then **both
marks are lost together**: the comment posted, the labels not, which is the original complaint with
extra steps. (Expected, not measured — treat it as the reason for the shape rather than as an
observation.) Composing from what you read is correct either way. On the web it is safe by
construction: `issue_write` takes the whole label list, so build it from the labels read and send
that.

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

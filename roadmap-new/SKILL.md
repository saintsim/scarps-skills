---
name: roadmap-new
description: Create a new roadmap item as a GitHub Issue on the current code repo. Use when the user says "add an item", "new roadmap item", "raise an item for …", "park an idea", or describes work that belongs on the roadmap but has no issue yet. Searches for duplicates first, then sets the item's intent at creation — `intent:later` for work nobody has started, `intent:now` plus a start comment when this session is already building the thing the item describes.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion, Skill, mcp__github__issue_read, mcp__github__issue_write, mcp__github__list_issues, mcp__github__search_issues, mcp__github__add_issue_comment, mcp__github__list_pull_requests, mcp__github__search_pull_requests
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
state — before creating anything. If one plainly covers the request, do not create a second item.

- **If this session is already building the thing** (the `now` test in §2), the existing item is
  exactly what `/roadmap-checkin` is for: invoke it with that issue number, so the work gets its
  three marks. This is the commonest real case — the item was filed weeks ago and nobody ever marked
  it — and stopping here instead would leave it showing as though nobody had started.
- **Otherwise** offer `/roadmap-edit` on it and stop unless the user says otherwise.

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
  reads only labelled issues, so an item created without it is invisible. An open issue with no
  intent is a validation finding, so one is always written here; which one is the question.

  - **`intent:now`** when this session is **already building the thing this item describes** — the
    user asked for the work first and the item second, or said "raise an item for what you're
    doing". Filing that as `later` is a claim the board then repeats to a phone: work being written
    this minute, drawn in the queue nobody has started. §5 finishes the job by announcing it.
  - **`intent:idea`** when the user says *park it*, *idea*, *someday*, or equivalent.
  - **`intent:later`** otherwise, and it is the ordinary case — work noticed in passing, a bug
    logged on the way past, anything nobody is on.

  **The `now` test is the work, not how busy the session is.** A session deep in #41 that raises an
  item for adjacent work it is **not** doing writes `later` like anyone else. And never
  `intent:next` here: sequencing what has not started is the owner's, via `/roadmap-edit`.
- **Milestone** — none, unless the user names a phase (`Phase 0` … `Phase 4`).

If *Why* or *Done when* cannot be written from what the user said, ask once, with one
AskUserQuestion, rather than inventing them — the body is read as the requirement by whoever builds
it.

## 3. Make sure the labels exist

A repo whose roadmap is new may not carry them yet, and `gh issue create --label roadmap` fails
outright on a label that does not exist — so the item never gets made. Create what is missing; both
commands are no-ops when the label is already there.

Create `roadmap` and **the intent label this item is about to carry** — `intent:idea` on the park-it
path, `intent:now` on the already-on-it path, `intent:later` otherwise. Ensuring only `later` leaves
"park an idea" dying on a fresh repo, which is the same failure one step along.

```sh
gh label create roadmap --color 5319e7 --description 'a roadmap item, not an ordinary issue' 2>/dev/null || true
gh label create intent:later --color 8b949e --description 'intent: later — queued, hand-owned' 2>/dev/null || true
gh label create intent:idea --color fbca04 --description 'intent: idea — parked, hand-owned' 2>/dev/null || true
```

On the `now` path, `in-progress` and `intent:now` are both about to be written by §5, and a label
that does not exist fails the whole edit — so create those two as well:

```sh
gh label create intent:now --color d93f0b --description 'intent: now — in hand, hand-owned' 2>/dev/null || true
gh label create in-progress --color 0e8a16 --description 'a session has this item in hand' 2>/dev/null || true
```

On the web the MCP server has no label-create call: if the create then fails for a missing label,
say so and ask the user to add it rather than dropping the label and filing an item the board
cannot see.

## 4. Create it

One `issue_write` (method `create`) with title, body and labels — or:

```sh
gh issue create --title '<title>' --body-file <file> \
  --label roadmap --label intent:<now|later|idea> [--milestone '<phase>']
```

## 5. If you are already on it, announce it

An `intent:now` item with no start comment is half a signal. The board has been told the work is
current and still cannot say that anybody holds it, on which machine, or how to reach that session —
which is the whole of what a phone wants from it. Both halves or neither.

So when §2 filed the item `intent:now`, invoke **`/roadmap-checkin`** with the new issue number
(the **Skill** tool) and let it run to its report. It posts the start comment — surface, session,
link, host, and a paragraph saying what is already built — adds `in-progress`, and confirms
`intent:now`. It is the only writer of that comment on purpose: the shape is parsed by Sidebar, by
SidePocket and by the skills here, and a second copy of it in this file would be a fourth place to
forget.

**If `/roadmap-checkin` is not available here, do not stop with the item half-marked.** Cloud
installs are per-skill snapshots, so one skill present and its sibling absent is an ordinary state
rather than an edge. In that case add `in-progress` yourself (the labels are already composed in
§4), then **print the exact start comment for the user to post**, saying plainly that the item is
`intent:now` and labelled but that nothing yet names the machine. An item announced by nothing is
the "half a signal" this section exists to prevent, and silence about it is worse than the gap.

**Nothing to do on the `later` and `idea` paths.** An item nobody has started gets no start comment
and no `in-progress`, which is exactly what keeps a quiet board quiet.

## Report

The issue **number, title and URL**, the label set, the milestone if any, and the `Depends on:`
line as written. On the `now` path, also the start comment URL and that `in-progress` is on — and
say which of the three intents it got and why, in one line, since that is the call the user is most
likely to want to correct. Nothing else changes: no branch, no other issue.

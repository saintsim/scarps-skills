# scarps-skills

Claude Code skills to use across my projects.

Each skill lives in its own directory with a `SKILL.md`. Install by symlinking each
skill directory into `~/.claude/skills/`, so this repo stays the source of truth and
every project picks the skills up automatically.

## Skills

| Skill | Invoke | What it does |
| --- | --- | --- |
| [`roadmap-item`](roadmap-item/SKILL.md) | `work on #41` / `work on RM-25` / `/roadmap-item #41` | Picks up a roadmap item by bare id and builds it in whichever code repo you're standing in. Reads the repo's `.roadmap` and follows one of two flows: **`kind: github-issues`** ([`issues.md`](roadmap-item/issues.md)) — the item is an issue on the code repo, a migrated one also answers to its old `RM-NN` alias, and the skill **posts a start comment and adds `in-progress` the moment the item resolves** — before reading it in depth, before any question, before branching — so the pick-up is visible from any machine within the first minute; or **Open-Road markdown** ([`markdown.md`](roadmap-item/markdown.md)) — resolves the project from the pointer (or a companion repo's remote against each item's `repos:`). Either way: read the item and its authorities, ask only if the item is too thin, branch off the freshly fetched default branch, implement, **build and run the unit tests**, stop for you to test. On your go-ahead: `/review-loop` → `/ship` (draft PR, `Refs #N`) → a **Delivered comment** on the issue (issues flow) or a paired **draft** Open-Road PR (markdown flow). Never writes an intent label, never closes an issue — `/roadmap-done` does that once the PR has merged. Say "don't wait for me to test" to run straight through. |
| [`roadmap-checkin`](roadmap-checkin/SKILL.md) | `/roadmap-checkin` | For a session **already mid-way through an item** that never announced itself — a pick-up from before the roadmap moved to issues, one made by hand, or one **teleported down from the web**, where the issue still names claude.ai as the machine and links to a copy that has stopped moving. Works out the issue (from the branch, the message, or asks), gathers the real state from git and any PR, posts the start comment with that state, adds `in-progress`. Builds nothing. |
| [`roadmap-new`](roadmap-new/SKILL.md) | `/roadmap-new` | Creates a roadmap item as an issue on the current code repo: searches for duplicates first, composes *Why / Scope / Done when* with a `Depends on:` line only when there are dependencies, and labels it `roadmap` plus `intent:later` (or `intent:idea` when you say park it) — the one place a skill writes an intent label, and only at creation. |
| [`roadmap-edit`](roadmap-edit/SKILL.md) | `/roadmap-edit` | Changes one item exactly as you instruct — retitle, rewrite a section, change `Depends on:`, set intent (`make #41 next`), close as done or not planned. One named edit per change, echoed back. Intent is never inferred from a merged PR, a green build or a Delivered comment. |
| [`roadmap-done`](roadmap-done/SKILL.md) | `/roadmap-done` | Closes a delivered item — **after you have merged its PR**. Resolves the item, finds every PR that claims it (the `Refs #N` search, the branch, the Delivered comment), and closes **only** on GitHub saying `merged: true`: an open PR, a draft, or one closed without merging closes nothing and gets reported instead. Then a closing comment carrying the merge commit and date, `state_reason: completed`, and `in-progress` off. Never merges anything, never touches an `intent:` label, and says which items it just unblocked without promoting one. |
| [`review-loop`](review-loop/SKILL.md) | `/review-loop [scope]` | Loops an **independent Fable sub-agent** code review + fix cycle until Fable judges the changes clean and good to ship. Fable reviews only; you fix every finding; the same Fable sub-agent re-reviews; repeat until clean. Findings too big to fix now are **recorded, never silently ignored** — as a `deferred`-labelled issue on the repo where the roadmap is its own issues (promotion to an item is then one `/roadmap-edit`), else in the project's markdown deferred-review log wherever its conventions put it. Runs unattended. |
| [`plan-review`](plan-review/SKILL.md) | `/plan-review [scope]` | The plans counterpart of `review-loop`, for **intent-only repos** (e.g. Open-Road). Same independent Fable loop, but reviewing markdown plans against the repo's schema and conventions: frontmatter validity, repo invariants, dangling references, spec/item consistency, ambiguity an implementer would diverge on, sequencing, and evidence discipline. Owner-only fixes (intent, ordering, renumbering) are recorded, never made. Runs unattended. |
| [`swift-verify`](swift-verify/SKILL.md) | `/swift-verify` | **Swift/Xcode projects, locally.** Runs the fixed ladder — **SwiftLint → `build` → `build-for-testing` → the unit (non-UI) tests** — fixing failures and re-running until green. Usual entry is straight after a `/teleport` from a web session, where nothing has been compiled by a real toolchain yet. Scheme, test targets and simulator are discovered at run time, and a repo that pins a particular runtime in its own docs gets honoured. Never gets green by weakening the check (no skipped, disabled or loosened tests), never commits, never launches the app. Records the run in `.git/swift-verify-state.json` so the UI skill can pick up from it. |
| [`swift-verify-ui`](swift-verify-ui/SKILL.md) | `/swift-verify-ui` | The **UI-test** counterpart. Run it straight after `/swift-verify` and it runs **only the UI suites** — it checks the recorded run against `HEAD` plus a working-tree fingerprint, so an untouched tree skips the ladder and any edit since re-runs it. Pulls failure screenshots and the UI hierarchy out of the result bundle before theorising, distinguishes "the app is broken" from "the test is looking in the wrong place", names flakes instead of re-running until one passes, and re-runs the unit suites when a fix touched app code. |
| [`ship`](ship/SKILL.md) | `/ship` | Ships the current changes on **GitHub** (assumes review is done). Re-lints if a linter exists, ensures repo docs are up to date, branches off the default branch, commits, pushes, and opens a **draft** PR with a title + description. Never marks ready-for-review and never merges — human stays in the loop. |
| [`move-raise-feedback`](move-raise-feedback/SKILL.md) | `/move-raise-feedback` | **MoveIt** — from a client repo (iOS/web-desk), composes the client's backend feedback and delivers it into the `MoveIt-API` inbox via a **draft PR**. |
| [`move-apply-feedback`](move-apply-feedback/SKILL.md) | `/move-apply-feedback` | **MoveIt** — from a client repo, pulls the backend's latest reply, implements the changes it enables, updates the scoreboard, drafts a reply back. |
| [`move-answer-feedback`](move-answer-feedback/SKILL.md) | `/move-answer-feedback` | **MoveIt** — from `MoveIt-API`, addresses the clients' inbound feedback and writes dated `backend-response-<client>` replies with a status table. |
| [`setup`](setup/SKILL.md) | `/setup` | Installs every skill in this repo onto the current machine by symlinking each skill directory into `~/.claude/skills/`. Idempotent — safe to re-run after pulling new skills. |

### Local verification after a teleport

Web and cloud sessions have no Xcode and no simulator, so code written there is *unverified* by
definition — it has never been compiled by the toolchain that ships it. `/teleport` brings that work
down to the Mac; `swift-verify` is what proves it:

```
/teleport  →  /swift-verify      lint → build → build-for-testing → unit tests → fix → green
           →  /swift-verify-ui   (UI suites only, if the tree hasn't changed since)
```

The pair is deliberately split because the UI suites cost minutes the unit suites don't, and most
runs don't need them. Running them back to back does not repeat work: `swift-verify` records the
run in `.git/swift-verify-state.json` — HEAD, a working-tree fingerprint, and what each stage did —
and `swift-verify-ui` reuses it when the tree is untouched, or re-runs the whole ladder when it
isn't. The fingerprint is the safety catch: one edit in between and the earlier pass no longer
counts, which is exactly how a run would otherwise declare green over code nobody compiled.

Both need Xcode and a simulator, so they only do anything on a Mac — there is no point uploading
them to claude.ai for cloud sessions. Neither commits, pushes or opens a PR — `/ship` does that
when you ask for it.

### Roadmap loop

A code repo says where its roadmap lives with a `.roadmap` file at its root, and there are two
kinds. **GitHub Issues on the code repo itself** (`kind: github-issues`) — the issue number is the
id, intent is an `intent:` label or the closed state, `Depends on:` is a body line, and every
pick-up leaves a **start comment** naming its surface (web or a Mac) with a link back, so a board
such as Sidebar can show who has what in hand — and a session moved between the two, by
`claude --teleport` or otherwise, leaves a second one rather than editing the first, so the latest
comment is always the machine the work is on now. Or **Open-Road markdown** — [Open-Road](https://github.com/saintsim/Open-Road)
holds intent, one folder per project, and the pointer names the folder. `roadmap-item` reads the
pointer and follows the matching flow; the four `roadmap-*` companions — `checkin`, `new`, `edit`,
`done` — are issues-only.

```
issues:   work on #41   → resolve issue → start comment + in-progress (first thing)
                        → read issue + deps + CLAUDE.md → branch 41-<slug>
                        → implement → build + test → STOP, you test
          (go-ahead)    → /review-loop → /ship (draft PR, Refs #41) → Delivered comment
                        → in-progress off; the issue stays open
          you merge     → /roadmap-done → proves the merge → closes it as completed

markdown: work on RM-25 → resolve project (.roadmap, else repos:) → read item + conventions
                        → branch rm-25-<slug> → implement → build + test → STOP, you test
          (go-ahead)    → /review-loop → /ship (draft code PR)
                        → Open-Road draft PR: intent done, evidence, README row, next item
```

**The `roadmap` label is what makes an issue an item.** Most repos' trackers already hold ordinary
bugs and feature requests — the board reads only labelled issues, so the two can share one tracker
without the backlog appearing on the roadmap. `roadmap-new` applies it at creation; `/roadmap-edit`
is how an existing bug report gets promoted into an item, or demoted back out.

Ids are **per project**, not global — two projects can each carry an `RM-25`, and they're
unrelated items — so the project is always resolved from the repo you're in. `intent` is
hand-owned in both flows: no skill here infers it, and a PR body says `Refs #N`, never `Closes`.
That's why the issue survives the merge, and why closing it is a separate, owner-triggered step:
`/roadmap-done` is the one skill that closes an item as completed, and it refuses until GitHub
says the PR merged.

### MoveIt feedback loop

The three `move-*-feedback` skills automate the cross-repo feedback dance between the
`MoveIt-API` backend and its two clients (iOS `MoveIt`, standalone `web-desk`). They
assume the clean **3-repo layout** (web already split out of the backend). Round trip:

```
client:  /move-raise-feedback   → draft PR delivers feedback to MoveIt-API inbox
backend: /move-answer-feedback  → makes changes, writes backend-response-<client>.md
client:  /move-apply-feedback   → consumes the reply, updates scoreboard, drafts reply-back
```

Each skill does the docs/correspondence movement; code changes still ship via `/ship`. The
backend checkout is resolved via `$MOVEIT_API_DIR`, a sibling checkout, or by remote.

## Install

There are two places these skills need to be installed, because local Claude Code and
cloud sessions load skills from different sources.

| Where you work | Install route | Picks up `git pull` automatically |
| --- | --- | --- |
| Local Claude Code (terminal, desktop) | `./install.sh` — symlinks into `~/.claude/skills/` | Yes |
| Cloud sessions (Claude Code on the web, Claude mobile app, `claude --cloud`) | `./package.sh`, then upload the ZIPs to claude.ai | No — re-upload after edits |

### Local machines

```sh
git clone https://github.com/saintsim/scarps-skills.git
cd scarps-skills
./install.sh
```

After that, just run **`/setup`** from any project to (re)install everything — handy
after pulling new skills. Or re-run `./install.sh` directly.

Both symlink every skill directory in this repo into `~/.claude/skills/`, refreshing
existing symlinks and leaving any real (non-symlink) entries untouched — they warn
instead of clobbering them. Because they're symlinks, a `git pull` updates every
installed skill with no reinstall.

### Cloud sessions

Cloud sessions run on a fresh VM that clones only the repo you're working in, so
`~/.claude/skills/` from your laptop never reaches them. What *does* reach them is
[skills you upload and enable on claude.ai](https://code.claude.com/docs/en/cloud-environments#what-carries-over-from-your-setup)
— those load automatically in every cloud session, in every repo, on every surface
(web, the Claude mobile app, the desktop app, `claude --cloud`).

Build one ZIP per skill:

```sh
./package.sh
```

This writes `dist/<skill>.zip` for each skill, each containing a single top-level
directory with its `SKILL.md` — the layout claude.ai expects. Then upload each ZIP at
**claude.ai → Settings → Features → Skills** and toggle it on. Requires code execution
enabled; custom skills are per-user and can't be managed org-wide.

`dist/` is gitignored — the ZIPs are build output, not source.

> **Re-upload after changes.** Unlike the local symlinks, an uploaded ZIP is a snapshot.
> Edit a `SKILL.md` and push, and cloud sessions keep running the old copy until you
> re-run `./package.sh` and upload again.

Two routes that look like alternatives but aren't worth using here:

- **Cloud environment setup scripts** run once and are then filesystem-cached for
  roughly seven days, so a `git clone` in one serves a stale copy of these skills long
  after you've pushed changes.
- **Committing `.claude/skills/` into a project** works and stays fresh, but only for
  that one repo — which defeats the purpose for the `move-*-feedback` skills, since
  they're meant to run from `shipworthy-api`, `MoveIt`, and `web-desk` alike.

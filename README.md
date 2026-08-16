# scarps-skills

Claude Code skills to use across my projects.

Each skill lives in its own directory with a `SKILL.md`. Install by symlinking each
skill directory into `~/.claude/skills/`, so this repo stays the source of truth and
every project picks the skills up automatically.

## Skills

| Skill | Invoke | What it does |
| --- | --- | --- |
| [`roadmap-item`](roadmap-item/SKILL.md) | `work on RM-25` / `/roadmap-item RM-25` | Picks up an **Open-Road** roadmap item by bare id and builds it in whichever code repo you're standing in — resolving the project from that repo's `.roadmap` pointer, because ids are per project and the same `RM-25` can exist in more than one. Reads the item and its authorities, asks up front only if the item is too thin to build from, branches `rm-<id>-<slug>` off the freshly fetched default branch, implements, then **builds and runs the unit tests** before stopping for you to test (UI tests are compiled but not run — too slow — unless your diff touched one). On your go-ahead: `/review-loop` → `/ship` → a paired **draft** Open-Road PR marking the item done, with evidence, the README row flipped and one item promoted to `next`. Say "don't wait for me to test" to run straight through. |
| [`review-loop`](review-loop/SKILL.md) | `/review-loop [scope]` | Loops an **independent Fable sub-agent** code review + fix cycle until Fable judges the changes clean and good to ship. Fable reviews only; you fix every finding; the same Fable sub-agent re-reviews; repeat until clean. Findings too big to fix now are recorded in `docs/deferred-review-items.md` — never silently ignored. Runs unattended. |
| [`plan-review`](plan-review/SKILL.md) | `/plan-review [scope]` | The plans counterpart of `review-loop`, for **intent-only repos** (e.g. Open-Road). Same independent Fable loop, but reviewing markdown plans against the repo's schema and conventions: frontmatter validity, repo invariants, dangling references, spec/item consistency, ambiguity an implementer would diverge on, sequencing, and evidence discipline. Owner-only fixes (intent, ordering, renumbering) are recorded, never made. Runs unattended. |
| [`ship`](ship/SKILL.md) | `/ship` | Ships the current changes on **GitHub** (assumes review is done). Re-lints if a linter exists, ensures repo docs are up to date, branches off the default branch, commits, pushes, and opens a **draft** PR with a title + description. Never marks ready-for-review and never merges — human stays in the loop. |
| [`move-raise-feedback`](move-raise-feedback/SKILL.md) | `/move-raise-feedback` | **MoveIt** — from a client repo (iOS/web-desk), composes the client's backend feedback and delivers it into the `MoveIt-API` inbox via a **draft PR**. |
| [`move-apply-feedback`](move-apply-feedback/SKILL.md) | `/move-apply-feedback` | **MoveIt** — from a client repo, pulls the backend's latest reply, implements the changes it enables, updates the scoreboard, drafts a reply back. |
| [`move-answer-feedback`](move-answer-feedback/SKILL.md) | `/move-answer-feedback` | **MoveIt** — from `MoveIt-API`, addresses the clients' inbound feedback and writes dated `backend-response-<client>` replies with a status table. |
| [`setup`](setup/SKILL.md) | `/setup` | Installs every skill in this repo onto the current machine by symlinking each skill directory into `~/.claude/skills/`. Idempotent — safe to re-run after pulling new skills. |

### Open-Road roadmap loop

[Open-Road](https://github.com/saintsim/Open-Road) holds **intent, not code** — one folder
per project, with the build spec and the roadmap items. The roadmap always lives there; the
code lives in each project's own repo, which points back with a `.roadmap` file.
`roadmap-item` is the bridge: stand in **any** repo carrying that pointer, name the id, and
it does the rest.

```
<code repo>/  work on RM-25  → resolve project via .roadmap → read item + spec + conventions
                             → branch rm-25-<slug> → implement → build + test → STOP, you test
              (go-ahead)     → /review-loop → /ship (draft code PR)
                             → Open-Road draft PR: intent done, evidence, README row, next item
```

Ids are **per project**, not global — two projects can each carry an `RM-25`, and they're
unrelated items — so the project is always resolved from the repo you're in, never by
searching Open-Road for the filename. The code PR merges first; both are opened as drafts
together so you can merge the pair in one sitting.

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

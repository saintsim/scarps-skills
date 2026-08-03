# scarps-skills

Claude Code skills to use across my projects.

Each skill lives in its own directory with a `SKILL.md`. Install by symlinking each
skill directory into `~/.claude/skills/`, so this repo stays the source of truth and
every project picks the skills up automatically.

## Skills

| Skill | Invoke | What it does |
| --- | --- | --- |
| [`review-loop`](review-loop/SKILL.md) | `/review-loop [scope]` | Loops an **independent Fable sub-agent** code review + fix cycle until Fable judges the changes clean and good to ship. Fable reviews only; you fix every finding; the same Fable sub-agent re-reviews; repeat until clean. Findings too big to fix now are recorded in `docs/deferred-review-items.md` — never silently ignored. Runs unattended. |
| [`ship`](ship/SKILL.md) | `/ship` | Ships the current changes on **GitHub** (assumes review is done). Re-lints if a linter exists, ensures repo docs are up to date, branches off the default branch, commits, pushes, and opens a **draft** PR with a title + description. Never marks ready-for-review and never merges — human stays in the loop. |
| [`move-raise-feedback`](move-raise-feedback/SKILL.md) | `/move-raise-feedback` | **MoveIt** — from a client repo (iOS/web-desk), composes the client's backend feedback and delivers it into the `shipworthy-api` inbox via a **draft PR**. |
| [`move-apply-feedback`](move-apply-feedback/SKILL.md) | `/move-apply-feedback` | **MoveIt** — from a client repo, pulls the backend's latest reply, implements the changes it enables, updates the scoreboard, drafts a reply back. |
| [`move-answer-feedback`](move-answer-feedback/SKILL.md) | `/move-answer-feedback` | **MoveIt** — from `shipworthy-api`, addresses the clients' inbound feedback and writes dated `backend-response-<client>` replies with a status table. |
| [`setup`](setup/SKILL.md) | `/setup` | Installs every skill in this repo onto the current machine by symlinking each skill directory into `~/.claude/skills/`. Idempotent — safe to re-run after pulling new skills. |

### MoveIt feedback loop

The three `move-*-feedback` skills automate the cross-repo feedback dance between the
`shipworthy-api` backend and its two clients (iOS `MoveIt`, standalone `web-desk`). They
assume the clean **3-repo layout** (web already split out of the backend). Round trip:

```
client:  /move-raise-feedback   → draft PR delivers feedback to shipworthy-api inbox
backend: /move-answer-feedback  → makes changes, writes backend-response-<client>.md
client:  /move-apply-feedback   → consumes the reply, updates scoreboard, drafts reply-back
```

Each skill does the docs/correspondence movement; code changes still ship via `/ship`. The
backend checkout is resolved via `$SHIPWORTHY_API_DIR`, a sibling checkout, or by remote.

## Install

### First time on a new machine

```sh
git clone https://github.com/saintsim/scarps-skills.git
cd scarps-skills
./install.sh
```

### After that

Once installed, just run **`/setup`** from any project to (re)install everything —
handy after pulling new skills. Or re-run `./install.sh` directly.

Both symlink every skill directory in this repo into `~/.claude/skills/`, refreshing
existing symlinks and leaving any real (non-symlink) entries untouched — they warn
instead of clobbering them.

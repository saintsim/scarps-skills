# Working on scarps-skills

The skills themselves — one directory per skill, each with a `SKILL.md`, installed by symlinking
into `~/.claude/skills/` (`install.sh`, or `/setup`). The repo is the source of truth; the symlinks
pick up edits automatically. Cloud sessions get per-skill ZIP snapshots instead, so a skill can be
current on a Mac and stale on claude.ai — assume nothing about which sibling skills are installed
beside the one being edited.

## This repo is on the roadmap, and the three marks apply here too

`.roadmap` says `kind: github-issues`, so items are this repo's own issues carrying the `roadmap`
label. That file is new, and the reason it exists is the reason this section does: without it every
roadmap skill stopped on sight, and a session changing the skills was invisible to any board by
construction.

**A session working an item says so on the item, in three marks and nowhere else.** Before it writes
code it posts the `<!-- sidebar:start -->` comment, adds `in-progress`, and sets `intent:now`.
`/roadmap-item` and `/roadmap-checkin` write all three, and `/roadmap-new` writes them too when the
item it is raising is work this session is already doing; a session that picked work up without any
of them still owes them. The machine lives in the comment's `surface` and `host` and nowhere else —
`claude.ai` for a cloud session, `hostname -s` verbatim for a Mac. Never GitHub's Assignee field: it
holds a *user*, and every session posts with the owner's token, so it names the owner whichever
machine did the work.

`intent:now` is the one intent a skill writes, and only at pick-up — it records the instruction
*work on this*. `next`, `later`, `idea` and both closed states are hand-owned, never inferred from a
green build, a merged PR or a passing review.

## The start comment is a contract shared with two other repos

The shape a skill here writes is parsed elsewhere, and a change touches all three:

| Where | Repo | Role |
| --- | --- | --- |
| `sidebar/issues.py` | [saintsim/Sidebar](https://github.com/saintsim/Sidebar) | **the authority** — the reference parser |
| `roadmap-item/issues.md`, `roadmap-checkin/SKILL.md` | here | writes the comment |
| `Parsing/`, `Model/Models.swift` | [saintsim/SidePocket](https://github.com/saintsim/SidePocket) | reads it on the phone |

**Never change the shape in one of them alone.** The marker, the yaml fence and the key names are
verbatim; the heading line and the paragraph under the block are prose and are not parsed.

## Writing a skill

- **A skill is read by a model that has never seen this repo.** Every branch it can land in needs an
  instruction, including the ones that fail: no `gh`, no MCP tools, a label that does not exist, a
  sibling skill not installed. "Print the exact text and ask the user to post it" is the house
  fallback — never skip a write silently.
- **Detect, never assume.** Where a skill must know what machine it is on, it measures and takes
  the first matching rule in a stated order, and stops and asks where nothing matches rather than
  inventing a value. **The test itself lives in `roadmap-item/issues.md` §4 and
  `roadmap-checkin/SKILL.md` §3, and only there** — it changes as the harness does, and a copy here
  would be the one that rots.
- **Examples get copied more reliably than rules get obeyed.** An example that contradicts the rule
  three paragraphs above it is a bug, not a typo. Keep worked examples consistent with the README.
- **Say what was measured, and when.** A claim about an environment variable or a command's
  behaviour belongs beside the date it was observed.

## Conventions

**PRs open as drafts. A human merges.** Never mark ready or merge unasked. A PR body says `Refs #N`,
never `Closes` — a merge closing an issue is automation writing intent.

**British English** in prose. Comment the *intent* — why this shape, not what the line does.

**Reviews run in an independent sub-agent**, which reviews and never edits; the orchestrator applies
every fix and hands them back to the same agent. Ask it to re-measure rather than taking your word.

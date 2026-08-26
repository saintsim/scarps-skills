---
name: plan-review
description: Loop an independent Fable sub-agent review and fix cycle over markdown plans — roadmap items, build specs, project READMEs — until Fable judges them clean. For intent-only repos (e.g. Open-Road) where review-loop's code dimensions don't apply. Findings too big to fix now, and owner-only calls, are recorded in the project's deferred-review log — never silently ignored.
user-invocable: true
allowed-tools: Read, Grep, Glob, Edit, Write, Bash, Agent, SendMessage
---

You are running an **iterative, independent review loop over markdown plans** — roadmap items, build
specs, project READMEs and CLAUDE.md conventions in an intent-only repo. A **Fable sub-agent is the
reviewer/judge**; **you (the orchestrator) do all the fixing**; the loop repeats until the *same*
sub-agent reports the plans clean. It runs **unattended** — do not stop to ask for approval between
rounds.

This is the plans counterpart of `/review-loop`. Code dimensions (bugs, tests, performance) don't
apply to a repo that holds **intent, not code** — but plans fail in their own ways: frontmatter that
breaks the schema, references that dangle, claims that drift from reality, and ambiguity that makes
an implementing agent build the wrong thing. Those are what this loop hunts.

The loop's value is an **independent second model**, so keep the roles separate:
- **Fable = reviewer only.** It returns findings and a verdict. It must **not** edit files, and you
  do not tell it to invoke any skill — give it the self-contained instructions below.
- **You = fixer.** Apply every fix, then hand the fixes back to the *same* sub-agent for an honest
  re-review.

## Scope

From `$ARGUMENTS`:
- No arguments → the working diff: `git diff` plus staged/unstaged changes, falling back to
  `git diff main...HEAD` (or `master`) if the working tree is clean.
- An item id (e.g. `RM-05`), file, directory, or project name → that scope, plus everything that
  references it.
- `"all"` or a project folder → audit that whole plan set against the repo's rules.

**Not for recording an item done.** This loop is for plans that are new or restructured — a newly
written item, a renumbering, a deliberate `depends_on` rework, a spec reconciliation — so that an
implementing agent can build against them. Marking an item `done` is not that, even though it edits
`depends_on` and touches the README: it is bookkeeping, verified by the roadmap repo's validator or
by hand-check. If you were sent here to record a completion, **stop and hand back** — the done-flip
does not gate on this review.

Run `git status` and `git branch --show-current` first. Then **identify the repo's authority
documents** — the schema/contract doc (e.g. `SCHEMA.md`), the repo-root CLAUDE.md, and any
per-project CLAUDE.md/README covering the scope — and name them in the reviewer's prompt. Report the
resolved scope before starting round 1.

## The loop

### Round 1 — spawn the Fable reviewer

Spawn **one** Fable sub-agent with the **Agent** tool (`model: "fable"`,
`subagent_type: "general-purpose"`), and **keep its agent id** — every re-review goes back to this
*same* agent via `SendMessage`, so it remembers its earlier findings and can tell you honestly
whether anything changed.

Write the reviewer a thorough, self-contained prompt: the resolved scope, the authority documents by
path, and any invariants specific to this repo. Instruct it to:

1. **Review only — do not edit any files and do not invoke any skills.** Return findings; the
   orchestrator applies fixes.
2. Read the authority documents first, then every changed file in full, then every file that
   *references* the changed files — plans fail at the seams between documents more than inside any
   one of them.
3. **Verify, don't just read.** Plans make checkable claims — check them:
   - Run the repo's **validator** if one exists; otherwise parse every touched frontmatter block
     itself and check it against the schema.
   - Follow every relative **link** and section citation (`§2.7` style) in the changed text and
     confirm the target exists and says what the citation implies.
   - Confirm every referenced **item id** exists and its frontmatter agrees with what the reference
     claims (a `depends_on` id exists; a "done" claim matches `intent: done`).
   - Where the plan names artefacts in a **code repo** (branches, file paths, commands, measured
     numbers) and that repo is available locally, check them there — a claim about git is one git
     can answer.
   - State **what it verified and what it only read** — read-only areas are lower-confidence.
4. Check, at minimum, every dimension below, and give each finding a severity:
   **critical / major / minor / nit**.
5. Return a structured result: numbered findings (each with `file:line`, severity, category, and a
   concrete description) and an explicit verdict:
   - **`NEEDS_WORK`** — at least one finding of severity minor or above remains.
   - **`CLEAN_AFTER_NITS`** — everything remaining is nit-level (wording, punctuation, trivial
     phrasing). List the nits; the orchestrator fixes them and re-runs the mechanical checks, and
     **no further review round is needed**.
   - **`CLEAN`** — nothing remaining.

   Nits never gate the verdict on their own.

Review dimensions (make these explicit in the reviewer's prompt):
- **Schema adherence** — frontmatter carries exactly the keys the schema allows, with valid values;
  ids well-formed and padded per convention; no key the validator would reject.
- **Repo invariants** — the standing rules in the repo's CLAUDE.md files hold *after* this change.
  In Open-Road that means: exactly one item marked `next` (or the stated exception recorded);
  `intent` hand-owned, never inferred from a merged PR or green build; `blocked` derived, never
  declared — no item is `next` while a `depends_on` id isn't `done`; the README item table and its
  closing prose agree with every item's frontmatter; a roadmap-done PR states its dependency on the
  code PR that merges first.
- **Reference integrity** — no dangling `depends_on`, no dependency cycles, no broken links, no
  stale section citations, no reference to an item saying something the item doesn't say.
- **Internal consistency** — the body agrees with its own frontmatter; two items don't claim the
  same work or contradict each other's constraints; a spec and the items built from it tell the same
  story. Where reality diverged from the spec, the spec was reconciled in the same change — **the
  spec must not lie**.
- **Ambiguity an implementer would diverge on** — the audience for these plans is an implementing
  agent. Flag any instruction two reasonable readers would build differently: undefined terms,
  unstated defaults, "done when" criteria that aren't actually checkable, decisions the plan defers
  without saying who decides.
- **Feasibility and sequencing** — `depends_on` reflects the real prerequisites (nothing depended on
  that isn't needed; nothing needed that isn't depended on); an item's scope is deliverable in one
  branch; overlaps between items are named and assigned an owner rather than left to collide.
- **Evidence discipline** — completed items carry the measured evidence and decisions the convention
  requires, not just a status flip; claims of what shipped match the delivering branch.
- **Prose and convention** — British English; concise; items **obey the authorities rather than
  restating them** (no schema rules copied into items); nothing pushed into a README level that the
  conventions reserve for another.

### Each round — show the user the findings in full

When the reviewer's report arrives — round 1 and every re-review — **relay the findings to the user
in full before you start fixing**. The loop runs unattended, so this text is the user's only window
into what Fable actually said:

- State the verdict, then list **every** finding with its number, `file:line`, severity, category,
  and the reviewer's actual description — quote or faithfully reproduce it. A one-line summary may
  precede the list but **never replaces it**.
- On re-review rounds, also list per prior finding whether the reviewer confirmed it resolved, any
  new findings in full, and the reviewer's answer to "is your feedback the same or has it changed?".

### Each round — fix everything

For **every** finding Fable returns:
1. **Fix it now** if it's reasonable to do so in this session. Apply the fix with Edit.
2. **Fix the class, not the instance.** Grep the scope for sibling occurrences of the same defect —
   the same stale citation in another item, the same schema slip in a neighbouring file — and fix
   them all in the same pass.
   - **When the finding is a false or unverified factual belief, sweep for the *concept*, not the
     phrasing.** A belief gets restated in different words at every copy ("iCloud Drive off" /
     "iCloud Drive was off" / "with iCloud off"), so a grep for the exact phrasings you know about
     reports clean while copies survive — each costing a full extra round when the reviewer finds
     it. Grep the subject keyword alone and intersect with context words instead, e.g.
     `grep -rn "iCloud" --include="*.md" | grep -i "restore\|purchas\|recover"`, and read every hit.
   - **The sweep scope is every repo in the review's remit, untouched files included** — the
     authority documents, the whole roadmap set, and any code-adjacent repo the plans are written
     from. A false belief's copies live precisely in the files the change *didn't* touch.
   - **Hand the reviewer the sweep evidence**: the exact command, its hits, and how each hit was
     dispositioned (fixed / genuine non-instance and why) — so it verifies your sweep instead of
     running its own incrementally wider one each round.
3. **Respect hand-owned fields.** Some findings are not yours to fix: if the correct fix would
   change `intent`, reorder the README table, or renumber an id, that is the owner's call — record
   it as a deferred/decision item and put it to the reviewer as such, don't make the call yourself.
4. If a finding is **genuinely too big to fix now**, record it — **never silently ignore it** (see
   *Deferred findings* below).

**Disagreeing with a finding:** you may push back, but a finding is **never resolved by assertion**.
Put your counter-argument to the reviewer as an explicit question and let its ruling stand. Anything
you decline to fix that the reviewer hasn't ruled on is an open finding.

### Each round — self-review before re-review

Fix-introduced collateral is the number-one cause of extra rounds, so before sending fixes back:
1. **Re-read every hunk you edited, plus the documents that reference it.** Did a fix make a README
   row, a closing-prose paragraph, a citation, or a sibling item stale? Fix those now.
2. **Run `git status` and `git diff`** and check nothing unintended is in the change. Stage
   explicitly by path — never `git add -A`.
3. **Re-run the mechanical checks** — the validator if one exists, otherwise your own frontmatter
   parse and link sweep over every touched file.

### Each round — same Fable sub-agent re-reviews

Use **`SendMessage`** to the **same** Fable agent id (never a fresh Agent call — that loses its
memory of the prior round). Tell it what you fixed per prior finding — reminding it to **verify each
claimed fix against the actual diff, not your description** — what you deferred or flagged as
owner-only and why, and any finding you're contesting. Ask it to confirm each prior finding
resolved, raise any new issues the fixes introduced, and return an updated verdict.

Explicitly ask: **"Is your feedback the same as the last review, or has it changed?"** Report the
answer each round.

### Stop conditions

- **`CLEAN`** → done. Deferred and owner-decision items don't block a clean verdict, but they must
  already be recorded **before** you accept it.
- **`CLEAN_AFTER_NITS`** → fix the listed nits, re-run the mechanical checks, and finish **without
  another review round**. If a nit turns out to need a real change, it wasn't a nit — send it back.
- **Do not edit the reviewed files after the final verdict.** Anything that must change post-verdict
  goes back to the reviewer.

**Safety cap:** if you reach **6 rounds** without converging, or findings start oscillating, **stop**
and report the state to the user rather than looping forever.

## Deferred findings and owner decisions — the tracked file

Findings too big to fix now, and fixes that belong to the owner (intent changes, reordering,
renumbering), go into **the project's deferred-review log** — at the location this repo's own
conventions name (`SCHEMA.md`'s layout, `CLAUDE.md`), never a path this skill picks. Look for the
project's existing `deferred-review-items.md` first: an existing file **is** the answer, and there is
**one per project** — record each finding in the log of the project whose plans it came from, not in
a single shared file. Only where the repo's conventions name none does it fall back to
`docs/deferred-review-items.md` at the repo root (create it and `docs/` if missing). Append — never
overwrite:

```markdown
## <YYYY-MM-DD> — <branch> — round <N>
- **[<CATEGORY>] <file>:<line>** — <finding as Fable described it>
  - **Why deferred / whose call:** <concrete reason, or the owner decision required>
  - **Suggested follow-up:** <what resolving it would involve>
```

Use today's date. Unlike `/review-loop`, the log is in the repo you are reviewing, so the append
rides the same branch and PR as the plan fixes — it needs no separate change. Mention the log (and
how many items you added) in the final report.

## Final report

When the loop converges (or hits the safety cap), report:
1. **Verdict** — Fable's final verdict, quoted.
2. **Rounds** — how many, and whether the feedback converged or oscillated.
3. **Fixed** — the findings fixed, grouped by category, including any nits fixed under
   `CLEAN_AFTER_NITS`.
4. **Contested** — any findings you pushed back on and how the reviewer ruled.
5. **Owner decisions & deferred** — items written to the deferred-review log, naming the path they
   landed in, with the count, separating "too big for now" from "the owner must decide".
6. **Verification** — what was mechanically checked (validator, links, cross-repo claims) and
   anything that could not be verified from here.

Do not claim "clean" unless Fable actually said so — report faithfully.

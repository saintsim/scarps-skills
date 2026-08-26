---
name: review-loop
description: Loop an independent Fable sub-agent code review and fix cycle until Fable judges the changes clean and good to ship. Fable reviews only; you fix every finding; the same sub-agent re-reviews; repeat until clean. Findings too big to fix now are recorded in the project's deferred-review log — never silently ignored.
user-invocable: true
allowed-tools: Read, Grep, Glob, Edit, Write, Bash, Agent, SendMessage
---

You are running an **iterative, independent code-review loop**: a **Fable sub-agent is the
reviewer/judge**; **you (the orchestrator) do all the fixing**; the loop repeats until the *same*
Fable sub-agent reports the changes clean and good to ship. It runs **unattended** — do not stop to
ask for approval between rounds.

The loop's value is an **independent second model** checking the work, so keep the roles separate:
- **Fable = reviewer only.** It returns findings and a verdict. It must **not** edit code — that
  would collapse the independence of the re-review — and you do not tell it to invoke any skill
  (skills like `code-review` are fix-oriented); give it the self-contained instructions below.
- **You = fixer.** Apply every fix, then hand the fixes back to the *same* sub-agent for an honest
  re-review.

## Scope

From `$ARGUMENTS`:
- No arguments → the working diff: `git diff` plus staged/unstaged changes, falling back to
  `git diff main...HEAD` (or `master`) if the working tree is clean.
- `"last N commits"` → `git diff HEAD~N...HEAD`.
- A file, directory, or feature name → review that scope.

Run `git status` and `git branch --show-current` first so you know the branch and exactly what
changed. Report the resolved scope before starting round 1.

## The loop

### Round 1 — spawn the Fable reviewer

Spawn **one** Fable sub-agent with the **Agent** tool (`model: "fable"`,
`subagent_type: "general-purpose"`), and **keep its agent id** — every re-review goes back to this
*same* agent via `SendMessage`, so it remembers its earlier findings and can tell you honestly
whether anything changed.

Write the reviewer a thorough, self-contained prompt — the more concrete (exact files, invariants to
protect, specific suspicion targets), the fewer rounds the loop takes. Instruct it to:

1. **Review only — do not edit any files and do not invoke any skills.** Return findings; the
   orchestrator applies fixes.
2. Read every changed file in full, plus enough surrounding code to judge regressions.
3. **Execute, don't just read.** Run the project's test suite, linter, and typecheck/build where a
   toolchain exists. For non-trivial pure logic (parsers, converters, calculations), compile and run
   a small throwaway harness rather than desk-checking — execution catches bugs read-only reviews
   miss. Where something cannot be executed, **say what was executed and what was only read**, and
   treat read-only areas as lower-confidence.
4. Check, at minimum, every dimension below, and give each finding a severity:
   **critical / major / minor / nit**.
5. Return a structured result: numbered findings (each with `file:line`, severity, category, and a
   concrete description), any optional UI-polish suggestions, and an explicit verdict:
   - **`NEEDS_WORK`** — at least one finding of severity minor or above remains.
   - **`CLEAN_AFTER_NITS`** — everything remaining is nit-level (stale comment, wording, trivial
     polish). List the nits; the orchestrator fixes them and verifies mechanically, and **no further
     review round is needed**.
   - **`CLEAN`** — good to ship, nothing remaining.

   Nits never gate the verdict on their own — a round whose only findings are nits is
   `CLEAN_AFTER_NITS`, not `NEEDS_WORK`.

Review dimensions (make these explicit in the reviewer's prompt):
- **Bugs** — logic errors, off-by-one, nil/crash paths, race conditions, incorrect state mutations.
- **Regressions** — anything that breaks previously working behaviour.
- **Specification adherence** — does it actually do what the task/spec/client-feedback asked?
- **Design adherence** — does it match the intended design; and are there **hardcoded reusable design
  elements** (colours, spacing, fonts, sizes, copy) that should be shared design tokens/constants?
  Flag these specifically.
- **Code quality** — duplication, methods over ~200 lines, hardcoded magic values, inefficient code,
  main-thread/blocking work.
- **Stale comments and docs** — comments, doc sentences, README/CLAUDE.md claims made false by the
  change; cheap to miss and the most common cause of extra rounds.
- **CLAUDE.md deviations** — violations of the project's CLAUDE.md and the user's global CLAUDE.md
  (British English spellings, SwiftUI-not-UIKit, short methods, commented intent, senior-IC quality,
  etc.).
- **Missing tests** — new public methods, ViewModels, models, or bug fixes with no test coverage.
  Where tests were added, spot-check they can actually fail (would a plausible mutation of the code
  under test break them?).
- **UI polish (optional)** — if the change is UI, Fable may suggest polish; apply it if it's clearly
  an improvement and in scope.

### Each round — show the user the findings in full

When the reviewer's report arrives — round 1 and every re-review — **relay the findings to the user
in full before you start fixing**. The loop runs unattended, so this text is the user's only window
into what Fable actually said:

- State the verdict, then list **every** finding with its number, `file:line`, severity, category,
  and the reviewer's actual description — quote or faithfully reproduce it. A one-line summary may
  precede the list but **never replaces it**.
- On re-review rounds, also list per prior finding whether the reviewer confirmed it resolved, any
  new findings in full, and the reviewer's answer to "is your feedback the same or has it changed?".
- Include the reviewer's optional/polish suggestions and note which you're applying.

### Each round — fix everything

For **every** finding Fable returns:
1. **Fix it now** if it's reasonable to do so in this session. Apply the fix with Edit.
2. **Fix the class, not the instance.** Grep the scope for sibling occurrences of the same pattern —
   the same unguarded call in a neighbouring function, the same logic mirrored in another language or
   port — and fix them all in the same pass; half-fixed patterns become next-round findings.
3. If a finding is **genuinely too big to fix now**, record it — **never silently ignore it** (see
   *Deferred findings* below) — and note in your round summary that it was deferred and why.

**Disagreeing with a finding:** you may push back, but a finding is **never resolved by assertion**.
Put your counter-argument to the reviewer as an explicit question ("I deliberately did X because Y —
tell me if you disagree and I'll change it") and let the reviewer's ruling stand. If it agrees no
change is needed, the finding is closed; if not, fix it. Anything you decline to fix that the
reviewer hasn't ruled on is an open finding.

### Each round — self-review before re-review

Fix-introduced collateral is the number-one cause of extra rounds, so before sending fixes back:

1. **Re-read every hunk you edited, plus the comments and doc sentences around it.** Did a fix make a
   nearby comment, module doc, README or CLAUDE.md claim stale or inverted? Fix those now.
2. **Run `git status` and `git diff`** and check nothing unintended is in the change. Stage files
   explicitly by path — **never `git add -A`** (it sweeps scaffolding and strays into reviewed
   commits).
3. **Verify with the strongest toolchain available**: build and/or run the project's tests, linter,
   and typecheck. If the build or tests fail, fix them before continuing. If part of the change
   cannot be compiled or run in this environment, say so explicitly to the reviewer and flag those
   areas for its hardest scrutiny. Do not create git hooks.

### Each round — same Fable sub-agent re-reviews

Use **`SendMessage`** to the **same** Fable agent id (never a fresh Agent call — that loses its
memory of the prior round). Tell it:
- What you fixed, per prior finding — and remind it to **verify each claimed fix against the actual
  diff, not your description of it**.
- What you deferred and why (with the tracked-file reference), and any finding you're contesting
  (phrased as a question for its ruling).
- To re-review the fixes, confirm whether each prior finding is resolved, raise any new issues the
  fixes introduced, and return an updated verdict.

Explicitly ask: **"Is your feedback the same as the last review, or has it changed?"** Report the
answer each round — the user cares whether the review is converging.

### Stop conditions

- **`CLEAN`** → done. Deferred items the reviewer agrees can wait don't block a clean verdict, but
  every deferral must already be in the tracked file **before** you accept CLEAN.
- **`CLEAN_AFTER_NITS`** → fix the listed nits, re-run the mechanical checks
  (lint/typecheck/build/tests), and finish **without another review round**; report the nits and
  fixes in the final report. If fixing a nit needs a non-trivial change, that's not a nit — send it
  back for a real re-review.
- **Do not edit the reviewed code after the final verdict.** If something must change post-verdict,
  either keep it out of this ship or send it back to the reviewer — never ship unreviewed changes
  under a CLEAN flag.

**Fresh eyes (optional):** the same-agent loop is deliberate — its memory is what makes
"resolved / changed / same" honest — but a reviewer can carry a round-1 blind spot forward. If the
diff is large (roughly 1,000+ lines) or the loop passes round 3, spawn **one** additional fresh Fable
reviewer for a single independent pass, and feed anything it finds back into the main loop as
ordinary findings.

**Safety cap:** if you reach **6 rounds** without converging, or findings start oscillating (fixing A
reopens B), **stop** and report the state to the user rather than looping forever.

## Deferred findings — the tracked file

Findings too big to fix now go into **the project's deferred-review log** — at the location the
project's own conventions name, never a path this skill picks. Resolve it in this order:

1. **The repo has a `.roadmap` pointer** → the log lives in the **roadmap repo**, alongside that
   project's items — not in the code repo. Read that repo's conventions (`SCHEMA.md`, `CLAUDE.md`)
   for the layout, and look for the project's existing `deferred-review-items.md` there. An existing
   file **is** the answer; never create a second one, and never add one to the code repo.
2. **No pointer, but the repo's `CLAUDE.md` names a deferred log** → use that.
3. **Neither** → `docs/deferred-review-items.md` at the repo root (create it and `docs/` if missing).

**The log is often not in the repo you are reviewing.** When it isn't, the append is a separate
change in that repo, and `/ship` will **not** carry it with the code branch: commit and push it there
on its own branch, from a worktree cut off a fresh fetch of that repo's default branch — never by
`switch`ing a shared checkout, which would move another session's HEAD mid-edit. **One exception:**
if this session is already going to open a PR against that repo — `/roadmap-item` opens one for the
item being built — don't open a second. Report the entries and let that branch carry them.

Append an entry — never overwrite existing ones, and follow the shape of the entries already in the
file where it has one:

```markdown
## <YYYY-MM-DD> — <branch> — round <N>
- **[<CATEGORY>] <file>:<line>** — <finding as Fable described it>
  - **Why deferred:** <concrete reason it's too big for now>
  - **Suggested follow-up:** <what a future fix would involve>
```

Use today's date, and keep `file:line` references **relative to the code repo** — that is where the
code is, whichever repo the log sits in. Mention the log (and how many items you added) in the final
report so nothing is lost.

## Final report

When the loop converges (or hits the safety cap), report:
1. **Verdict** — Fable's final verdict, quoted.
2. **Rounds** — how many, and whether the feedback converged or oscillated.
3. **Fixed** — the findings fixed, grouped by category, including any nits fixed under
   `CLEAN_AFTER_NITS`.
4. **Contested** — any findings you pushed back on and how the reviewer ruled.
5. **Deferred** — items written to the deferred-review log, with the count, the repo and path they
   landed in, and whether that write still needs its own PR.
6. **UI polish** — any polish Fable suggested and whether you applied it.
7. **Build/tests** — final status, and anything that could not be executed in this environment.

Do not claim "clean" unless Fable actually said so — report faithfully, including any deferrals or a
hit safety cap.

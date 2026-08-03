---
name: review-loop
description: Loop an independent Fable sub-agent code review and fix cycle until Fable judges the changes clean and good to ship. Fable reviews only (bugs, regressions, spec/design adherence, hardcoded reusable design elements, code quality, missing tests); you fix every finding; the same Fable sub-agent then re-reviews the fixes; repeat until Fable reports no remaining issues. Findings too big to fix now are recorded in a tracked repo file — never silently ignored.
user-invocable: true
allowed-tools: Read, Grep, Glob, Edit, Write, Bash, Agent, SendMessage
---

You are running an **iterative, independent code-review loop**. A **Fable sub-agent acts as the reviewer/judge**; **you (the orchestrator) do all the fixing**. The loop keeps going until the *same* Fable sub-agent reports the changes are clean and good to ship.

This mirrors how the user always asks for reviews: *"Ask model Fable in a sub-agent to `/code-review` the changes… then fix up all findings, then repeat until Fable thinks it's clean and good to ship."* The user trusts Fable's opinion and is happy for this to run **unattended** — do not stop to ask for approval between rounds; apply every fix and keep going until the loop converges.

## Why Fable reviews and you fix

The value of this loop is an **independent second model** checking the work. So keep the roles separate:
- **Fable = reviewer only.** It identifies findings and gives a verdict. It must **not** edit code — that would collapse the independence of the re-review.
- **You = fixer.** You apply every fix, then hand the fixes back to the *same* Fable sub-agent for an honest re-review.

## Scope

Determine what to review from `$ARGUMENTS`:
- No arguments → the working diff: `git diff` plus staged/unstaged changes, falling back to `git diff main...HEAD` (or `git diff master...HEAD`) if the working tree is clean.
- `"last N commits"` → `git diff HEAD~N...HEAD`.
- A file, directory, or feature name → review that scope.

Run `git status` and `git branch --show-current` first so you know the branch and exactly what changed. Report the resolved scope before starting round 1.

## The loop

### Round 1 — spawn the Fable reviewer

Spawn **one** Fable sub-agent with the **Agent** tool (`model: "fable"`, `subagent_type: "general-purpose"`), and **keep its agent id** — every re-review goes back to this *same* agent via `SendMessage`, so it remembers its earlier findings and can tell you honestly whether anything changed.

Instruct the Fable reviewer to:
1. Run a thorough `/code-review` (invoke the `code-review` skill) over the resolved scope.
2. **Review only — do not edit any files.** Return findings; the orchestrator applies fixes.
3. Check, at minimum, every dimension below.
4. Return a structured result: the numbered findings (each with `file:line`, severity, category, and a concrete description) **and** an explicit verdict — `CLEAN` (good to ship, no remaining issues) or `NEEDS_WORK` — plus any optional UI-polish suggestions.

Review dimensions (make these explicit in the reviewer's prompt):
- **Bugs** — logic errors, off-by-one, nil/crash paths, race conditions, incorrect state mutations.
- **Regressions** — anything that breaks previously working behaviour.
- **Specification adherence** — does it actually do what the task/spec/client-feedback asked?
- **Design adherence** — does it match the intended design; and are there **hardcoded reusable design elements** (colours, spacing, fonts, sizes, copy) that should be shared design tokens/constants? Flag these specifically.
- **Code quality** — duplication, methods over ~200 lines, hardcoded magic values, inefficient code, main-thread/blocking work.
- **CLAUDE.md deviations** — violations of the project's CLAUDE.md and the user's global CLAUDE.md (British English spellings, SwiftUI-not-UIKit, short methods, commented intent, senior-IC quality, etc.).
- **Missing tests** — new public methods, ViewModels, models, or bug fixes with no test coverage.
- **UI polish (optional)** — if the change is UI, Fable may suggest polish to make it look more professional; apply it if it's clearly an improvement and in scope.

### Each round — fix everything

For **every** finding Fable returns:
1. **Fix it now** if it's reasonable to do so in this session. Apply the fix with Edit.
2. If a finding is **genuinely too big to fix now**, record it — **never silently ignore it** (see *Deferred findings* below) — and note in your round summary that it was deferred and why.

After applying fixes, **verify you didn't break anything before re-review**: build and/or run the project's tests (this is exactly the "it built and tests passed, now ask Fable to re-review" flow the user follows, and it stops buggy first-pass fixes reaching the re-review). If the build or tests fail, fix them before continuing. Do not create git hooks.

### Each round — same Fable sub-agent re-reviews

Use **`SendMessage`** to the **same** Fable agent id (never a fresh Agent call — that loses its memory of the prior round). Tell it:
- What you fixed, per prior finding.
- What you deferred and why (with the tracked-file reference).
- Ask it to **re-review the fixes**, confirm whether each prior finding is resolved, raise any new issues the fixes introduced, and return an updated verdict.

Explicitly ask: **"Is your feedback the same as the last review, or has it changed?"** Report the answer each round — the user cares whether the review is converging or the feedback doc shifted.

### Stop condition

Repeat fix → re-review until Fable returns **`CLEAN` / "good to ship"** with no remaining actionable findings (deferred items that Fable agrees can wait don't block a clean verdict).

**Safety cap:** if you reach **6 rounds** without converging, or Fable's findings start oscillating (fixing A reopens B), **stop** and report the state to the user rather than looping forever.

## Deferred findings — the tracked file

Findings too big to fix now go into **`docs/deferred-review-items.md`** at the repo root (create it and the `docs/` dir if missing). Append an entry — never overwrite existing ones:

```markdown
## <YYYY-MM-DD> — <branch> — round <N>
- **[<CATEGORY>] <file>:<line>** — <finding as Fable described it>
  - **Why deferred:** <concrete reason it's too big for now>
  - **Suggested follow-up:** <what a future fix would involve>
```

Use today's date. Mention this file (and how many items you added) in the final report so nothing is lost.

## Final report

When the loop converges (or hits the safety cap), report:
1. **Verdict** — Fable's final verdict, quoted.
2. **Rounds** — how many, and a one-line note on how the feedback changed each round (converging / oscillating).
3. **Fixed** — the findings fixed, grouped by category.
4. **Deferred** — items written to `docs/deferred-review-items.md`, with the count.
5. **UI polish** — any polish Fable suggested and whether you applied it.
6. **Build/tests** — final build/test status.

Do not claim "clean" unless Fable actually said so — report faithfully, including any deferrals or a hit safety cap.

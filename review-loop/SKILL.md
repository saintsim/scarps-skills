---
name: review-loop
description: Loop an independent Fable sub-agent code review and fix cycle until Fable judges the changes clean and good to ship. Fable reviews only; you fix every finding; the same sub-agent re-reviews; repeat until clean. Each round first merges in the latest default branch if the branch is behind. Then the reviewed code goes on a draft PR without asking — pushed to the PR it was reviewed on, or shipped with /ship when there was none — and, only in a repo whose `.roadmap` opts in with a `verify` line set to `ready-for-review`, the PR is marked ready so its check runs, and a red check gets one bounded fix. Never merges. Findings too big to fix now are recorded — as a `deferred`-labelled issue where the project's roadmap is issues, else in its deferred-review log — never silently ignored.
user-invocable: true
allowed-tools: Read, Grep, Glob, Edit, Write, Bash, Agent, SendMessage, Skill, mcp__github__update_pull_request, mcp__github__pull_request_read, mcp__github__actions_list, mcp__github__get_job_logs, mcp__claude-code-remote__subscribe_pr_activity, mcp__claude-code-remote__unsubscribe_pr_activity, mcp__claude-code-remote__send_later
---

You are running an **iterative, independent code-review loop**: a **Fable sub-agent is the
reviewer/judge**; **you (the orchestrator) do all the fixing**; the loop repeats until the *same*
Fable sub-agent reports the changes clean and good to ship. It runs **unattended** — do not stop to
ask for approval between rounds. The one stop it makes is a merge conflict that changes logic
(*Before every review*): that is a decision about the code, not an approval.

The loop's value is an **independent second model** checking the work, so keep the roles separate:
- **Fable = reviewer only.** It returns findings and a verdict. It must **not** edit code — that
  would collapse the independence of the re-review — and you do not tell it to invoke any skill
  (skills like `code-review` are fix-oriented); give it the self-contained instructions below.
- **You = fixer.** Apply every fix, then hand the fixes back to the *same* sub-agent for an honest
  re-review.

## Scope

From `$ARGUMENTS`:
- No arguments → the working diff: `git diff` plus staged/unstaged changes, falling back to
  `git diff "origin/$base...HEAD"` (`$base` as in *Before every review*) if the working tree is
  clean — never a local `main`, whose merge-base goes stale once the branch has merged the
  remote's in. With no `$base` to fall back on, ask what to review.
- `"last N commits"` → `git diff HEAD~N...HEAD`.
- A file, directory, or feature name → review that scope.

Run `git status` and `git branch --show-current` first so you know the branch and exactly what
changed. Report the resolved scope before starting round 1.

**When the work is already on a pull request** — the roadmap loop ships before it reviews, so this
is the common case — review the **PR's own diff**, `git diff origin/<default-branch>...HEAD`, and
say which PR you are reviewing. Two rules follow from the code being pushed:

- **Every fix has to reach the PR, at the end of every round** — not once the loop goes clean.
  Commit on the same branch and push; a plain `git push` updates the PR. **Never run `/ship` to do
  it** — a PR already exists and a second run would try to open another. A fix that only ever
  existed in a working tree is a fix nobody reviewed and nobody merged, and a session that dies
  mid-loop takes every unpushed round with it.
- **Leave the PR a draft while the loop runs, and never merge it.** A clean verdict from the
  reviewer is not a human's approval. **The one exception is a repo that opts in to a
  ready-for-review check** (*Ready for review*, below): there the session's last act, after the
  clean verdict and the final push, is marking the PR ready so the check runs once, on reviewed
  code. Everywhere else the PR stays a draft. No repo's opt-in ever permits a merge.
- **If a push needs approval, the loop is not unattended any more.** Say so at the first round it
  happens, keep going, and never report a round as pushed when it was not — the final report names
  every commit still sitting unpushed. Worth telling the user once: one entry,
  `"permissions": {"allow": ["Bash(git push:*)", "Bash(git commit:*)"]}` in `~/.claude/settings.json`,
  and the rounds stop stopping.

### Before every review — bring the branch up to the latest default branch

**The reviewer reads the diff that would merge, never one against a stale base.** A branch cut days
ago is reviewed against code that has since moved, so a conflict, a duplicated fix or a rule that
changed under it is invisible until the merge. So **before round 1, and again before each
re-review**, fetch and check:

```sh
base=$(git remote show origin | sed -n 's/.*HEAD branch: //p')
git fetch origin "$base" --quiet
git merge-base --is-ancestor "origin/$base" HEAD && echo up-to-date || echo behind
```

**No `origin`, or `$base` comes back empty** (a remote with no HEAD branch set, a local-only
repo) → there is no default branch to measure against: say so, skip the update, and review as-is.
Never guess `main`.

**Behind → merge `origin/$base` in before anything goes to the reviewer:**

- **Merge, never rebase**, on any feature branch, pushed or not — one rule, and on a pushed one a
  rebase rewrites what the PR and the reviewer are both reading, and needs the force-push this
  skill never does. `git merge --no-edit "origin/$base"`, then re-run the round's checks (step 3 of the self-review) and, on a PR, push
  the merge with a plain `git push` before sending.
- **On the default branch itself, with nothing committed** — the work is only in the working
  tree — `git merge --ff-only "origin/$base"` instead. If git refuses because a file it would
  update has uncommitted edits or is in the way untracked, `git stash -u`, fast-forward,
  `git stash pop`, and treat any conflict the pop reports like a merge conflict below. If the
  stash route itself fails, pop back anything that was stashed (`git stash pop`), say so, and
  review as-is.
  Never commit the user's work just to make the update go through.
- **On the default branch with local commits that have diverged from `origin`** — never merge
  into or rebase the default branch itself: that writes history onto the user's `main`. Say it
  is behind and review as-is; `/ship` cuts a feature branch at the end (*When the loop ends*),
  and the next check, on that branch, merges `origin/$base` in under the first rule.
- **A conflict** — resolve it when it is mechanical (both sides added neighbouring lines, a moved
  import); regenerate lockfiles and generated files with the repo's own tooling, never by hand.
  **When both sides changed the same logic and either resolution loses behaviour, stop and ask** —
  that is a decision about the code, not a step in the loop. Abort the merge (`git merge --abort`)
  rather than leaving the tree half-merged while you ask.
- **Tell the reviewer** that the base moved, which commit it was merged up to, and anything the
  merge resolved — on a re-review, so it can tell the merge's hunks from your fixes.

Up to date → say so in the round's report and carry on. A scope that is not a branch's change — a
directory of code already on the default branch — still fetches first, so the reviewer reads the
code as it stands now.

## The loop

### Round 1 — spawn the Fable reviewer

Bring the branch up to date first (*Before every review*).

Spawn **one** Fable sub-agent with the **Agent** tool (`model: "fable"`,
`subagent_type: "general-purpose"`), and **keep its agent id** — every re-review goes back to this
*same* agent via `SendMessage`, so it remembers its earlier findings and can tell you honestly
whether anything changed.

**Reasoning effort:** when the Fable model is **5.1 or newer**, run the reviewer at **medium**
effort, not high — medium is enough for this loop and high burns far more tokens for no gain in
review quality. On older Fable, keep the default effort.

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
4. **Commit the round and push it**, where the change is on a PR — **every round, before the
   re-review**, so nothing is lost if the session dies and the PR shows the loop converging round by
   round rather than arriving as one opaque commit. The checks in step 3 come first: a round that
   does not build does not get pushed, it gets fixed. One commit per round, its subject naming the
   round and what it fixed — `Second review round: fix a blocking fault the first round introduced`
   is the shape — staged by path, never `git add -A`. A plain `git push`, always: **never amend,
   rebase or force-push**, since the reviewer and the PR both read the history you are rewriting.
   Note the pushed head, and tell the reviewer in the next step that its re-review is against a
   pushed commit rather than a working tree.

### Each round — same Fable sub-agent re-reviews

Bring the branch up to date first (*Before every review*) — the base may have moved during the
round. Then use **`SendMessage`** to the **same** Fable agent id (never a fresh Agent call — that
loses its memory of the prior round). Tell it:
- What you fixed, per prior finding — and remind it to **verify each claimed fix against the actual
  diff, not your description of it**.
- The commit you just pushed for this round and the head sha, where the change is on a PR, so it
  re-reviews what the PR actually carries.
- Whether the base moved and was merged in since its last review, and up to which commit.
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
- **Nothing is left unpushed**, where the change is on a PR: the last round's fixes — nits fixed
  under `CLEAN_AFTER_NITS` included — are committed and pushed like every other round's, so the PR
  and the clean verdict describe the same code. Report the final pushed head.
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

## When the loop ends — put the reviewed code on a draft PR, without asking

**Never end by asking whether to ship or whether the review's fixes have been pushed.** The owner
reads reviewed work on its GitHub PR, so that is where a finished loop leaves it, on every surface;
the answer to both questions is always yes, and asking only stops the session until somebody
types it. Take the first rule that matches, once the verdict is `CLEAN` or `CLEAN_AFTER_NITS` and
its nits are fixed:

1. **The change is on a PR** — the roadmap loop's case. Every round is already pushed (*Scope*);
   check it is so, because there are two ways it may not be:
   ```sh
   git status --short                         # uncommitted edits — the last round's nits, say
   git log "origin/$(git branch --show-current)..HEAD" --oneline   # commits not on the PR
   ```
   **Uncommitted edits** to reviewed files → commit them first, in the round-commit shape (step 4
   of the self-review), staged by path. **Unpushed commits** → a plain `git push`. Say which you
   did. Never `/ship` here — it would try to open a second PR.
2. **It is not on a PR yet** — `/review-loop` run by hand over a working tree or local commits —
   **snapshot the reviewed state first**, so you can tell afterwards what `/ship` itself changed:
   ```sh
   git rev-parse HEAD > <scratch>/pre-ship.head
   git diff HEAD > <scratch>/pre-ship.patch   # the reviewed change to tracked files
   git ls-files --others --exclude-standard > <scratch>/pre-ship.untracked   # and its new files
   ```
   Then invoke **`/ship`** with the **Skill** tool. It branches if needed, commits, pushes and
   opens the **draft** PR, and it sees this loop's verdict and does not start another review.
   Afterwards compare `git diff "$(cat <scratch>/pre-ship.head)" HEAD` with the snapshot — a
   new file listed in `pre-ship.untracked` is reviewed code, not an addition — and **any hunk not
   in the snapshot** is a lint or docs edit `/ship` made, which the reviewer has not
   read. Send exactly those hunks to the same reviewer as one more round, and commit and push its
   fixes like any round's, before you report — never a clean verdict over unreviewed changes. No
   difference → say so; that is a measurement, not an assumption.
3. **Nothing was changed and nothing is unshipped** — a review of code already on the default
   branch that found nothing, say — there is nothing to ship; say so.

**The safety cap is not a verdict**, so a loop that hit it does not ship anything new: push the
rounds already committed, if the change is on a PR, and report the state. Nor does it mark
anything ready (*Ready for review*).

Then, once the reviewed code is on the PR, **check for the opt-in below**. In a repo that has not
opted in, the loop is over and the PR stays a draft.

## Ready for review — only where the repo opts in to a check

Some repos run a workflow — on a self-hosted runner, since there is no paid GitHub CI — that builds
and tests a PR **when it is marked ready for review**, and never on opening or on a push, so it
fires once, when the work is done. saintsim/jlpt-jiten-swift was the first (its #206). A session
that leaves its PR a draft never triggers that check and never sees it go red, which defeats the
point: verifying a cloud session's work without the owner having to be there.

**The opt-in is one line in the repo's `.roadmap`**, read from the checkout:

```sh
grep -E '^verify: *ready-for-review *$' "$(git rev-parse --show-toplevel)/.roadmap" 2>/dev/null
```

No `.roadmap`, or no such line → **not opted in**: leave the PR a draft and stop here, exactly as
before. A line, not detection of the workflow, because whether a session should mark its own PRs
ready is the owner's decision about the repo, like intent; a workflow that happens to listen for
`ready_for_review` (a labeller, a notifier) is not that decision. The line works in either kind of
`.roadmap`.

**Opted in — then confirm the check exists before relying on it.** Measure, never assume:

```sh
base=$(git remote show origin | sed -n 's/.*HEAD branch: //p')
git grep -l 'ready_for_review' "origin/$base" -- .github/workflows/ 2>/dev/null
```

(`actions_list` with `list_workflows` is the web equivalent; read a candidate's file to see its
trigger.) **No workflow on the default branch mentions `ready_for_review`** → the opt-in names a
check that does not exist: say so in the report, leave the PR a draft, and stop. Marking it ready
would hand the owner an unchecked PR that looks checked.

Mark the PR ready **only when all of these hold**: the verdict was `CLEAN` or `CLEAN_AFTER_NITS`
(never the safety cap), its nits are fixed, the change is on a PR, and nothing is uncommitted or
unpushed (*When the loop ends*, rule 1). Then:

1. **Mark it ready — the session's last change to the PR.**
   On a Mac, `gh pr ready <n>`. On a cloud session, `update_pull_request` with `draft: false`, or
   else `gh api -X POST repos/<owner>/<repo>/pulls/<n>/ccr/ready_for_review` — **not**
   `gh pr ready`, which goes through GraphQL and was refused there with HTTP 403 (measured
   2026-11-14; the refusal itself names the `ccr/ready_for_review` and `ccr/convert_to_draft`
   routes). **Then read it back** —
   `gh pr view <n> --json isDraft`, or `pull_request_read` with `get` — and go on only when it is no
   longer a draft. **If it cannot be marked ready** (no `gh`, no MCP tool, a permission error, or
   the read-back still says draft), say so and ask the owner to tap *Ready for review* on the PR,
   naming its URL. Never skip it silently, and never report a check as running when nothing marked
   the PR ready.
2. **Wait for the check, within a bound.** This is the one place these skills watch a check, and
   only because the owner built one to be read. `/ship` still watches nothing: the check runs on
   *ready for review*, never on the opening or the push `/ship` makes.
   - **Find the run**: `gh run list --branch <branch> --event pull_request --limit 5 --json
     databaseId,name,status,conclusion,createdAt`, or `actions_list` with `list_workflow_runs`
     filtered to the branch, and take the newest run created after you marked the PR ready. **None
     within about five minutes** → report it and stop: the workflow's own filters (a branch-name
     pattern, say) may exclude this PR. Never re-toggle the PR to coax a run.
   - **Wait for its conclusion**: on a Mac, `gh run watch <run-id> --exit-status`, as a background
     command where the harness offers one. On a cloud session, `subscribe_pr_activity` on the PR and
     end the turn — the check's result arrives as an event and wakes the session; schedule one
     fallback check-in (`send_later`) at the bound, in case it never does.
   - **The bound is 60 minutes from marking the PR ready.** A self-hosted runner can be asleep or
     busy, and a run queued that long is the owner's to look at, not the session's to wait out.
     Past it, report the run as still queued or in progress, with its URL, and stop. The PR stays
     ready.
3. **Green** → report it, with the run's URL. Done.
4. **Red** → read the failure before touching anything: `gh run view <run-id> --log-failed`, or
   `get_job_logs` with `run_id` and `failed_only: true`.
   - **Not the code** — the runner was offline, a toolchain or signing step failed, the workflow
     itself errored — fix nothing: report what failed, in the log's own words, and stop. A code
     change cannot fix a runner.
   - **The code** — **one fix attempt, no more.** Fix exactly what the log names; reproduce it
     locally first where the toolchain exists. Run the repo's lint and tests, and **send the fix to
     the same reviewer as one more round** (*Do not edit the reviewed code after the final verdict*
     still holds) — or, if that agent can no longer be reached after the wait, one fresh Fable
     reviewer for that single round, told what the loop already passed. Commit it in the round-commit shape and push with a plain `git push`. Then
     re-trigger the check: put the PR back to draft (`gh pr ready <n> --undo` on a Mac;
     `update_pull_request` with `draft: true`, or `gh api -X POST
     repos/<owner>/<repo>/pulls/<n>/ccr/convert_to_draft`, on a cloud session), mark it ready
     again as in step 1, read it back, and wait once
     more under step 2, with a fresh 60-minute bound.
   - **The attempt is spent** — the reviewer would not pass the fix, or the re-run is red again →
     **put the PR back to draft**, so *ready* still means reviewed and checked, push anything
     committed, and report: both runs' URLs, the failure in the log's own words, and what the fix
     tried. Never a second attempt.
5. **Unsubscribe** (`unsubscribe_pr_activity`) once the check has reported or the bound has passed,
   on a cloud session, so the owner's later comments on the PR do not wake a finished session.

**Never merge, whatever the check says.** A green check on a ready PR is still the owner's to merge.

**If `/ship` cannot run** — it is not installed here, the Skill tool is unavailable, or it stopped on
one of its own hard rules (detached HEAD, a remote that is not GitHub, unrelated dirty changes, no
GitHub access) — relay its reason in its own words, name the branch and every unpushed commit, and
say what the user has to clear before running `/ship` over that branch. That is the report, not a
question — never ask whether to ship.

## Deferred findings — an issue, labelled `deferred`

A finding too big to fix now is **recorded, never silently ignored**. Where it is recorded depends on
how the project keeps its roadmap, and there is one question to ask: does the repo's `.roadmap` say
`kind: github-issues`?

**Yes — file an issue on that repo, labelled `deferred` and nothing else.** Not a markdown log: the
finding is about that repo's code, it belongs beside it, and promotion is then one label edit rather
than a retype. Create the label if it is missing (no-op when it is not):

```sh
gh label create deferred --color c5def5 \
  --description 'a deferred review finding — not roadmap work until promoted' 2>/dev/null || true
gh issue create --repo <owner>/<repo> --label deferred --title '<title>' --body-file <file>
```

- **Title:** `[<category>] <subject> — <the finding, trimmed>`, about 90 characters. The category is
  the one you gave the finding (`correctness`, `test-coverage`, `cleanup`, …), lower-cased.
- **Body:** the finding as the reviewer described it, then **Why deferred** and **Suggested
  follow-up**, then a line saying it is not roadmap work. `file:line` references stay relative to the
  code repo, which is now the same repo.
- **Never add an `intent:` label and never add `roadmap`.** A deferred finding is not work anyone has
  decided to do, and `intent` is hand-owned. A `deferred` issue carrying no `roadmap` label is
  invisible to the board by design, which is the whole point of the split.
- **Promotion is the owner's**, and it is one `/roadmap-edit` away: add `roadmap` plus an intent and
  the finding becomes an item, carrying its issue number and history with it. Say in your final
  report that this is how it would be picked up; do not do it yourself.

**No — the project keeps a markdown roadmap, or none at all.** Then use the markdown log, at the
location the project's own conventions name, never a path this skill picks:

1. **A `.roadmap` pointer at a markdown roadmap** → the log lives in the **roadmap repo**, alongside
   that project's items. Read that repo's conventions (`SCHEMA.md`, `CLAUDE.md`) for the layout and
   look for an existing `deferred-review-items.md`. An existing file **is** the answer; never create a
   second one, and never add one to the code repo.
2. **No pointer, but the repo's `CLAUDE.md` names a deferred log** → use that.
3. **Neither** → `docs/deferred-review-items.md` at the repo root (create it and `docs/` if missing).

**That log is often not in the repo you are reviewing.** When it isn't, the append is a separate
change in that repo, and `/ship` will **not** carry it with the code branch: commit and push it there
on its own branch, from a worktree cut off a fresh fetch of that repo's default branch — never by
`switch`ing a shared checkout, which would move another session's HEAD mid-edit. **One exception:** if
this session is already going to open a PR against that repo, don't open a second; report the entries
and let that branch carry them.

Append an entry — never overwrite existing ones, and follow the shape of the entries already there:

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
5. **Deferred** — items recorded, with the count and where they landed: the issue numbers and repo
   where the roadmap is issues, else the log's repo and path they
   landed in, and whether that write still needs its own PR.
6. **UI polish** — any polish Fable suggested and whether you applied it.
7. **Build/tests** — final status, and anything that could not be executed in this environment.
8. **Pushed** — the commit per round, the final head, and the **PR URL**, saying whether the
   PR already existed or `/ship` opened it at the end (*When the loop ends*).
9. **Ready for review** — one of: not opted in, so the PR stays a draft; opted in but no
   `ready_for_review` workflow found, so it stays a draft; marked ready, with the check's run URL and
   its result (green, red and fixed, red and back to draft, not the code, or still running past the
   bound); or could not be marked ready, and the owner was asked to tap it.

Do not claim "clean" unless Fable actually said so — report faithfully, including any deferrals or a
hit safety cap.

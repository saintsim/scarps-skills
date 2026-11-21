---
name: review-loop
description: Loop an independent Fable sub-agent code review and fix cycle until Fable judges the changes clean and good to ship. Fable reviews only; you fix every finding; the same sub-agent re-reviews; repeat until clean. Each round first merges in the latest default branch if the branch is behind. Then the reviewed code goes on a draft PR without asking — pushed to the PR it was reviewed on, or shipped with /ship when there was none — and, only on a cloud session in a repo whose `.roadmap` opts in with a `verify` line set to `ready-for-review`, the PR is marked ready so its check runs, and a red check gets one bounded fix. Where the PR's item is a roadmap issue, posts a `reviewed` stage comment on it at the pushed head. Never merges. Findings too big to fix now are recorded — as a `deferred`-labelled issue where the project's roadmap is issues, else in its deferred-review log — never silently ignored.
user-invocable: true
allowed-tools: Read, Grep, Glob, Edit, Write, Bash, Agent, SendMessage, Skill, mcp__github__add_issue_comment, mcp__github__issue_read, mcp__github__list_pull_requests, mcp__github__update_pull_request, mcp__github__pull_request_read, mcp__github__actions_list, mcp__github__get_job_logs, mcp__claude-code-remote__subscribe_pr_activity, mcp__claude-code-remote__unsubscribe_pr_activity, mcp__claude-code-remote__send_later, mcp__claude-code-remote__delete_trigger
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
say which PR you are reviewing. Three rules follow from the code being pushed:

- **Every fix has to reach the PR, at the end of every round** — not once the loop goes clean.
  Commit on the same branch and push; a plain `git push` updates the PR. **Never run `/ship` to do
  it** — a PR already exists and a second run would try to open another. A fix that only ever
  existed in a working tree is a fix nobody reviewed and nobody merged, and a session that dies
  mid-loop takes every unpushed round with it.
- **Leave the PR a draft while the loop runs, and never merge it.** A clean verdict from the
  reviewer is not a human's approval. **The one exception is a cloud session in a repo that opts in
  to a ready-for-review check** (*Ready for review*, below): there, after the clean verdict and the
  final push, the session marks the PR ready so the check runs on reviewed code, and reads the
  result. Everywhere else the PR stays a draft. No repo's opt-in ever permits a merge.
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

**If `/ship` cannot run** — it is not installed here, the Skill tool is unavailable, or it stopped on
one of its own hard rules (detached HEAD, a remote that is not GitHub, unrelated dirty changes, no
GitHub access) — relay its reason in its own words, name the branch and every unpushed commit, and
say what the user has to clear before running `/ship` over that branch. That is the report, not a
question — never ask whether to ship.

**The safety cap is not a verdict**, so a loop that hit it does not ship anything new: push the
rounds already committed, if the change is on a PR, and report the state. Nor does it mark
anything ready (*Ready for review*).

Then, once the reviewed code is on the PR, **post the stage comment** (next section) and **check
for the opt-in below**. In a repo that has not opted in, the loop is over and the PR stays a draft.

## The stage comment — once per verdict on a pushed head

Where the PR belongs to an item on a **repo whose roadmap is its own issues**, the loop's outcome
goes on the item as a `<!-- sidebar:stage -->` comment, so a board such as Sidebar or SidePocket
can tell *reviewed clean, awaiting your verification* from *still being built*. This holds whether
`/roadmap-item` called you or the owner ran you by hand — the board cannot tell the difference,
and should not have to.

**First, the reviewed code must be a commit on an open PR.** All three of these, or post nothing:

- an **open PR** has this branch as its head (`pull_request_read` / `list_pull_requests` with
  `head`, or REST: `gh api 'repos/<owner>/<repo>/pulls?state=open&head=<owner>:<branch>'` —
  `gh pr list` goes through GraphQL, refused like `gh issue view` in step 4 below);
- `git status --porcelain` is **empty** — reviewed edits left uncommitted mean what was reviewed
  is *HEAD plus edits*, which no SHA names;
- `git rev-parse HEAD` equals `git rev-parse @{u}` — and an `@{u}` that errors (no upstream)
  counts as unpushed.

Any of them failing → say which in the final report, post nothing, and print the comment you would
have posted so the owner can post it once the code is on the PR.

**Then resolve the item, in this order, and post nothing where it does not resolve:**

1. **The PR body's `Refs`.** `Refs <owner>/<repo>#N` names that repo's issue, whatever this repo's
   `.roadmap` says — an item can live in another repo. A bare `Refs #N` names this repo's issue,
   and only where this repo's `.roadmap` says `kind: github-issues`. Two or more different items
   named → say so and post nothing; never pick one.
2. **No `Refs` in the body → the branch**, and only where `.roadmap` says `kind: github-issues`:
   `41-issues-roadmap` → #41; `rm-NN-*` → the issue whose title starts `RM-NN —`.
3. **The branch's number and a bare `Refs #N` disagree** (a `41-…` branch whose PR says
   `Refs #58`) → the branch and the work have come apart; say so and post nothing.
4. **The issue carries the `roadmap` label.** Read it with `issue_read` (`get_labels`), else
   `gh api repos/<owner>/<repo>/issues/<N> --jq '.labels[].name'` — the REST form, since
   `gh issue view` goes through GraphQL and is refused on some cloud sessions (403, measured
   2026-11-21). An unlabelled issue is not an item → post nothing. Labels that cannot be read →
   post nothing and print the comment for the owner.

No `.roadmap` with `kind: github-issues` and no long-form `Refs` → there is no issue roadmap; say so
in the final report and post nothing.

Then post one comment. Keep the marker, the yaml fence and the key names **verbatim** — the shape
is saintsim/Sidebar's `docs/item-flow.md`, parsed by its `sidebar/issues.py`, and copied by the
phone; a key spelt differently here is a stage that silently never shows:

````markdown
<!-- sidebar:stage -->
**Reviewed** · round 3 · clean

```yaml
stage: reviewed
verdict: clean
round: 3
sha: 4f2a9c1
branch: 41-issues-roadmap
session: https://claude.ai/code/session_017wSwKg7FYMenuCMUTo5Grw
```

Fable returned CLEAN after three rounds; one finding deferred as #57.
````

- **`verdict`** — `clean` for `CLEAN` or `CLEAN_AFTER_NITS` (the parser drops
  `CLEAN_AFTER_NITS` itself); `findings` when the loop stopped at the safety cap or on oscillation
  with findings still open, once the committed rounds are pushed. This skill never writes
  `failed`: a round whose checks fail is never committed, so no pushed head carries it — the gate
  above posts nothing and the report says why.
- **`round`** — the number of review rounds run, the nit-fixing finish not counted as one.
- **`sha`** — `git rev-parse --short HEAD`, the pushed head the verdict describes. Required: it is
  what lets the next push retire the stage as *changed since review*.
- **`branch`** — the PR's head branch. **`session`** — the `session:` of a start comment this
  session posted on the item, if there is one; else the claude.ai session URL your system prompt
  names; else leave the key out. Not `CLAUDE_CODE_SESSION_ID`: it is set on cloud sessions too and
  identifies nothing on its own. The key is optional, and a wrong value is worse than none.
- **The paragraph** is prose and is not parsed: the verdict in words and anything deferred.
- **Once per verdict on a pushed head, never per round, and never edited.** The comment is
  append-only and the latest wins. **A red check's fix (*A red check*) is a second verdict**: once
  the reviewer has ruled on it and it is pushed, post another `reviewed` stage at the new head, its `round` counting the fix's round (N+1) —
  `clean` when it passed, `findings` when the reviewer returned `NEEDS_WORK` and the unreviewed fix
  stays pushed — so the board does not read *changed since review* over code that was re-reviewed.

**A clean review is not a verification, and neither is a green check** — the check is the repo's,
the verification the owner's. They open *awaiting your verification* on the board, and only the
owner closes it: say in the final report that the item is waiting for the owner to test the PR's
head. **If the owner then says, in their own words, that they tested this head and it is good**,
post the owner's stage on the same item — and only then; never on your own reading of a review,
a check or a silence:

````markdown
<!-- sidebar:stage -->
**Verified** · by the owner · clean

```yaml
stage: verified
verdict: clean
by: owner
sha: 4f2a9c1
branch: 41-issues-roadmap
```

The owner tested the PR's head and said it is good.
````

`sha` is the head they tested — ask if it has moved since your `reviewed` stage. A reported problem
is the same shape with `verdict: failed` and **Verified** · by the owner · failed.

**Access**, for every comment here: the `mcp__github__*` tools if you have them
(`add_issue_comment`), else `gh api repos/<owner>/<repo>/issues/<N>/comments -F body=@<file>` (REST,
for the reason in step 4). If neither works, **print the exact comment and ask the user to post
it** — never skip it silently.

## Ready for review — only where the repo opts in to a check

Some repos run a workflow — on a self-hosted runner, since there is no paid GitHub CI — that builds
and tests a PR **when it is marked ready for review**, and never on opening or on a push, so it
fires once, when the work is done. saintsim/jlpt-jiten-swift was the first (its #206). A session
that leaves its PR a draft never triggers that check and never sees it go red, which defeats the
point: verifying a cloud session's work without the owner having to be there.

**A cloud session only. On a Mac, leave the PR a draft and skip this section.** The runner stands in
for the machine a cloud session lacks; a session on the owner's own Mac verifies there, with
`/swift-verify` or the repo's own build and tests, as it always has (the owner's decision,
2026-11-14, while saintsim/scarps-skills#29 was built). **Go on only when the surface measurement in
`roadmap-item/issues.md` §2 answers `surface: web`.** Anything else skips this section without a
question, and report item 9 says why: `surface: local` is a Mac, and §2's *stop and ask* — an
environment nothing has measured, such as CI or a devcontainer — is not a cloud session either. That
file is a sibling skill's (`../roadmap-item/issues.md` beside this skill's directory) and may not be
installed: then `uname -s` reading `Darwin` — §2's first rule, which nothing overrides — still
skips, and anything else skips too, saying the surface could not be measured.

**One rule holds the section together: a PR this skill leaves ready is reviewed, and its check
has passed or is still running.** Every outcome below that would leave a ready PR unchecked or red
puts it back to draft instead, so *ready* never looks checked when it is not.

### The opt-in — a `.roadmap` line, confirmed against a workflow

**The opt-in is a `verify: ready-for-review` line in the repo's `.roadmap`.** A line, not detection
of the workflow, because whether a session marks its own PRs ready is the owner's decision about
the repo, like intent; a workflow that happens to listen for `ready_for_review` (a labeller, a
notifier) is not that decision, and the line is what lets the owner roll it out one repo at a
time. It works in either kind of `.roadmap`. Run the script in this skill's own directory with
`bash` — not `sh`, and not relying on its exec bit surviving an unzip — from anywhere in the
checkout:

```sh
bash <this skill's directory>/ready-check-opt-in.sh
```

It reads both answers from the **freshly fetched default branch**, never the working tree, so a
session's own branch cannot opt itself in, and it reads the value as YAML would (quotes, a trailing
comment, CRLF). Its first line decides:

- **`NOT_OPTED_IN`** → leave the PR a draft and stop here, exactly as before.
- **`UNRECOGNISED <value>`** → a `verify:` value this skill does not know, or the key spelt another
  way (`Verify:`): leave the PR a draft and say so in the report, naming what it found, so a typo
  does not read as a silent opt-out.
- **`NO_BASE`** → no default branch could be resolved or fetched: leave the PR a draft and say why.
- **`NO_WORKFLOW`** → the opt-in names a check that does not exist on the default branch: leave the
  PR a draft and say so. Marking it ready would hand the owner an unchecked PR that looks checked.
- **`OPTED_IN`** → it lists the workflow files that mention `ready_for_review`. **Read each one**
  and confirm it triggers on `pull_request` (or `pull_request_target`) with `ready_for_review` in
  its `types:` — a mention in a comment is not a trigger. None does → treat it as `NO_WORKFLOW`.

**The script is missing** (an older snapshot of this skill) or cannot run → do the same by hand:
`git fetch` the default branch, read `.roadmap` from it with `git show origin/<base>:.roadmap`, and
list `.github/workflows/` from it (`actions_list` with `list_workflows` is the web equivalent).

### Marking it ready

Mark the PR ready **only when all of these hold**: the verdict was `CLEAN` or `CLEAN_AFTER_NITS`
(never the safety cap), its nits are fixed, the change is on a PR, and nothing is uncommitted or
unpushed (*When the loop ends*, rule 1).

**The routes, tried in order until one succeeds.** `gh pr …` goes through GraphQL, which was
refused from a cloud session with HTTP 403 (measured 2026-11-14 — the refusal itself names the
`ccr/ready_for_review` and `ccr/convert_to_draft` routes), while `gh api` on REST paths answered:

- **To ready:** `update_pull_request` with `draft: false`, where the GitHub MCP tools are loaded;
  else `gh api -X POST repos/<owner>/<repo>/pulls/<n>/ccr/ready_for_review`; else `gh pr ready <n>`.
- **Back to draft:** `update_pull_request` with `draft: true`; else
  `gh api -X POST repos/<owner>/<repo>/pulls/<n>/ccr/convert_to_draft`; else
  `gh pr ready <n> --undo`.
- **To read it:** `gh api repos/<owner>/<repo>/pulls/<n> --jq .draft` (REST — `gh pr view` was
  refused like `gh pr ready`), or `pull_request_read` with `get`.

Only the refusal and the REST read were measured on 2026-11-14; the MCP call and the `ccr` routes
actually changing a PR's state were **not**, so the read after every change is what proves it.
**A change back to draft that fails** leaves a ready PR this section meant to withdraw: say so
plainly in the report, with the PR's URL and why it should be a draft, and ask the owner to convert
it — never report it as a draft when the read says otherwise.

The steps:

1. **On the MCP-only path** (no `gh`; see *Waiting*), `subscribe_pr_activity` on the PR **now**,
   before anything changes, so a fast check cannot finish unseen.
2. **Read the PR.** Already not a draft — the owner tapped *Ready* mid-loop, or an earlier run left
   it ready — means marking it ready fires no event: put it back to draft first, so the check runs
   on the reviewed head.
3. **Note the time and the head**: `date -u +%Y-%m-%dT%H:%M:%SZ` and `git rev-parse HEAD`.
4. **Mark it ready, then read it back.** Go on only when it reads `false`.
5. **If it cannot be marked ready** — every route refused, or the read-back still says draft — say
   so and ask the owner to tap *Ready for review* on the PR, naming its URL. Never skip it silently,
   and never report a check as running when nothing marked the PR ready.

### Waiting for the check — within a bound

This is the one place these skills watch a check, and only because the owner built one to be read.
`/ship` still watches nothing: the check runs on *ready for review*, never on the opening or the
push `/ship` makes.

**With `gh`**, start the watcher in this skill's directory, with `bash`, **as a background command
whose timeout is above the bound** — 70 minutes (`4200000` ms) where the harness takes one, since
its default for a background command was 30 minutes when read on 2026-11-14:

```sh
bash <this skill's directory>/watch-check.sh <owner>/<repo> <head-sha> <time-noted-in-step-3>
```

It polls GitHub's REST API once a minute for the runs a PR event started on that commit after that
time — every one of them, if two workflows listen — needs nothing beyond `gh` and awk, and exits by
itself, so there is nothing to cancel. End the turn after starting it; its exit wakes the session.
**The bound is 60 minutes from marking ready**, and a run must have **started within 5 minutes**.
Its last line is the outcome:

- **`SUCCESS`** → green. Report it, with the run URLs it printed. The PR stays ready. Done.
- **`FAILURE`** → a run went red — reported as soon as one does, even with another still running.
  The failed run ids follow. Go to *A red check*.
- **`NO_RUN`** → no run started: the workflow's own filters (a branch-name pattern, say) may
  exclude this PR. **Put the PR back to draft** and report it; never re-toggle to coax a run.
- **`TIMEOUT`** → runs started, none has failed, but some are still queued or running. A self-hosted
  runner can be asleep or busy, and a run queued that long is the owner's to look at, not the
  session's to wait out. Report the run URLs; **the PR stays ready**, because the run is attached to
  it and will report there by itself.
- **`ERROR`** → `gh api` failed; the cause follows. Report it and put the PR back to draft —
  nothing is watching.
- **No outcome line** — the harness stopped the command, or it was killed — or **the script is
  missing** (an older snapshot of this skill), or **the harness runs nothing in the background** →
  wait the MCP-only way below if its tools are there; else treat it as `ERROR`.

**Without `gh`** (MCP tools only) → the subscription is already on (step 1 of *Marking it ready*);
now `send_later` two check-ins, 6 and 60 minutes out — the first is what notices `NO_RUN`, since
nothing else wakes the session when no run starts. On **every** wake — a check result, a comment, a
push, or a check-in — read the runs with `pull_request_read` `get_check_runs` (or `actions_list`
`list_workflow_runs`) and apply the outcomes above. Not yet concluded and inside the bound → end the
turn again. Once an outcome is acted on,
`unsubscribe_pr_activity` and cancel the check-in (`delete_trigger` on the id `send_later`
returned) that is still pending, so nothing wakes a finished session; a check-in that fires anyway
finds the outcome already reported and does nothing. **No `gh`, no subscription and no
`send_later`** → there is no way to wait: leave the PR ready — the check was triggered and reports
on the PR by itself, like `TIMEOUT` — say it could not be read here, and ask the owner to look.

### A red check — one fix, no more

Read the failure before touching anything: `get_job_logs` with `run_id` and `failed_only: true`,
or `gh api repos/<owner>/<repo>/actions/runs/<run-id>/jobs` for the failed step and then
`gh api repos/<owner>/<repo>/actions/jobs/<job-id>/logs` for its log.

- **Not the code** — the runner was offline, a toolchain, signing step or simulator runtime failed,
  the workflow itself errored → fix nothing, since a code change cannot fix a runner. **Put the PR
  back to draft**, report what failed in the log's own words, and stop.
- **The code** → **one fix attempt.** Fix exactly what the log names — the minimal change, from the
  log's own words, never a guess at an error it does not show. Reproduce it locally first where the
  toolchain exists; a cloud container usually has none for what the runner builds (no Xcode, no
  simulator on Linux), and then **claim no pass**: say the fix is unverified until the re-run, which
  is the only verification there is. Run whatever lint and tests do run here, then commit in the
  round-commit shape and push with a plain `git push`, as every round does — so the fix is on the
  PR, reviewed or not.
  **Send it to the same reviewer as one more round** (*Do not edit the reviewed code after the final
  verdict* still holds) — or, if that agent cannot be reached after the wait, one fresh Fable
  reviewer for that single round, told what the loop already passed.
  - **`CLEAN`, or `CLEAN_AFTER_NITS` with its nits fixed, committed and pushed** → re-trigger: back
    to draft, then mark ready again and wait once more, both exactly as above, with a fresh note of
    the time and head and a fresh 60-minute bound.
  - **`NEEDS_WORK`** → the attempt is spent.

  Either way, post the second `reviewed` stage at the fix's head (*The stage comment*).
- **The attempt is spent** — the reviewer would not pass the fix, or the re-run comes back
  `FAILURE`, `NO_RUN` or `ERROR` → **put the PR back to draft** and report: every run's URL, the
  failure in the log's own words, what the fix tried, and, if the reviewer did not pass it, that the
  pushed fix is unreviewed. **Never a second attempt**, whatever the re-run's cause. A re-run that
  ends `TIMEOUT` is handled as above — reported, the PR left ready — and the report says the fix is
  still unverified.

**Never merge, whatever the check says.** A green check on a ready PR is still the owner's to merge.

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
9. **Ready for review** — skipped, saying why: a Mac, an environment §2 could not place, or the
   surface could not be measured; else the opt-in script's answer, and then one of: left a draft
   (not opted in, an unrecognised `verify:` value, no default branch, or no `ready_for_review`
   workflow); marked ready, with every run URL and the outcome — green; red and fixed, green on the
   re-run; red and back to draft (not the code, or the one attempt spent); no run started, back to
   draft; still running past the bound, left ready; or triggered but unreadable — and the PR's final
   state; or could not be marked ready, and the owner was asked to tap it.
10. **Stage** — each `reviewed` stage comment's URL and verdict, or why none was posted (not on an
    open PR, uncommitted or unpushed, no issue roadmap, no item or several resolved, a branch and
    `Refs` that disagree, an unlabelled issue, or labels that could not be read).

Do not claim "clean" unless Fable actually said so — report faithfully, including any deferrals or a
hit safety cap.

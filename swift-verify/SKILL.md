---
name: swift-verify
description: Verify a Swift/Xcode project locally — SwiftLint, build, build-for-testing, then the unit (non-UI) tests, fixing failures and re-running until they pass. Use after /teleport from a web session, or any time the ask is "lint, build and get the tests green" on a Swift app. Needs Xcode and a simulator, so it runs on a Mac. Discovers the scheme, test targets and simulator at run time — nothing project-specific is hardcoded. Does not run the UI tests (that is /swift-verify-ui) and does not commit, push or launch the app. On a repo whose roadmap is its own GitHub issues, posts a `verified` stage comment on the branch's item at the end of the run.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit, AskUserQuestion
---

You are verifying the Swift/Xcode project you are standing in, locally, and leaving it green. The ladder is fixed:

**lint → build → build-for-testing → unit tests → fix → re-run until green.**

The usual entry is straight after a `/teleport` from a web session: code arrived that no one has
compiled on real hardware. Nothing below is project-specific — the scheme, test targets, simulator
and conventions are all discovered at run time. Where a repo's documents disagree with what actually
runs on disk, **the disk wins** — and say so.

## Rules that hold for the whole run

- **Never get green by weakening the check.** No skipping, disabling, deleting, `XCTSkip`-ing or
  commenting out a test, no loosening an assertion to fit the wrong answer, no lint rule disabled to
  silence a violation. If a test is genuinely wrong, fix the test *as a test* and say plainly that
  you changed the test rather than the code, and why.
- **Do not commit, push, or open a PR.** Verification is not shipping — `/ship` does that, when the
  user asks for it. Respect the repo's own git conventions (many say a local run leaves committing
  to the developer). The one thing this skill writes to GitHub is the **stage comment** in step 6
  — a record of the run on the item, never a change to the code.
- **Do not launch the app**, and do not run the UI tests. `build`, `build-for-testing` and the unit
  suites only.
- **Fix forward, minimally.** Repair what the failure needs. Don't refactor, don't tidy, don't widen
  scope because you were in the file anyway.
- **Read the repo's own conventions first** — `CLAUDE.md`, `README.md`, any `TESTING*.md`. They
  routinely name the required simulator, a known-bad runtime, or a gotcha that looks exactly like an
  app defect. Consult them **before** diagnosing a whole-suite failure as a code bug.
- **Run unattended.** Don't ask permission to lint, build, run tests, or fix your own breakage. Stop
  only where a step below says stop.

## 0. Preflight — is this even the right machine?

```sh
xcodebuild -version
git rev-parse --show-toplevel
```

No `xcodebuild`, no run: stop and say so rather than reaching for a substitute toolchain, because a
green from something that isn't Xcode is a false green.

Then discover the project:

```sh
xcodebuild -list -json                       # schemes and targets; add -project/-workspace if ambiguous
ls *.xcworkspace *.xcodeproj 2>/dev/null
ls *.xctestplan 2>/dev/null
```

- **Scheme:** the shared scheme matching the app. One scheme → use it, no question. Several → prefer
  the one named for the app/product; if still ambiguous, ask with `AskUserQuestion` once and remember
  the answer for the rest of the run.
- **Test targets:** from the target list (and the test plan, if there is one). Treat targets whose
  name ends in `UITests` — or that build as a UI testing bundle — as **UI targets**, and everything
  else with `Tests` in the name as **unit targets**. This skill runs the unit targets only.
- **A workspace beats a project.** If a `.xcworkspace` exists, pass `-workspace`; otherwise `-project`.

If the user passed arguments (a scheme name, a device such as `iPhone 17 Pro`, an OS such as `26.2`,
or a `-only-testing`-style filter), they override the discovery below.

### Picking the destination

Prefer, in order: a simulator the **repo's own documents require** (a CLAUDE.md gotcha pinning a
runtime is not optional — honour it); then a **booted** simulator; then the newest available iPhone.

```sh
xcrun simctl list devices available | sed -n '/^-- iOS/,$p'
xcrun simctl list devices booted
```

Use a stable destination string, e.g.
`-destination 'platform=iOS Simulator,name=iPhone 17 Pro'`, adding `,OS=26.2` when a specific
runtime is required. If the required runtime has no device, create one rather than silently falling
back:

```sh
xcrun simctl create "swift-verify-<os>" <device-type-id> <runtime-id>
```

State the destination you settled on, and why, in your first message of the run.

### Long commands

`xcodebuild` runs routinely outrun a foreground command timeout. Run each one **in the background**,
tee'd to a log, and poll it:

```sh
xcodebuild ... 2>&1 | tee /tmp/swift-verify-<stage>.log
```

Never conclude anything from a truncated log. Read the tail for the verdict banner
(`** BUILD SUCCEEDED **`, `** TEST BUILD SUCCEEDED **`, `** TEST SUCCEEDED/FAILED **`) and grep the
body for `error:` and failure lines.

## 1. Lint

Only if the repo has a linter (`.swiftlint.yml`, or `swiftlint` referenced in its docs). If it has
none, say "no linter configured — skipping" and move on; don't invent one.

```sh
swiftlint --fix        # auto-corrections first
swiftlint              # then see what is left
```

- **Fix every error.** Errors gate the run.
- **Do not go on a warning hunt.** Warnings are the project's backlog. But *your* changes must not
  add new ones — if a warning sits in a line this session touched, fix that one. Report the warning
  count so drift is visible.
- If `swiftlint` is not installed, say so (`brew install swiftlint`) and continue to the build rather
  than stopping — an uninstalled linter is a machine gap, not a code failure. Note it in the report.

## 2. Build the app

```sh
xcodebuild build -scheme <scheme> -destination '<destination>'
```

Fix every compile error and re-run until `** BUILD SUCCEEDED **`. Compiler warnings introduced by
recent changes are worth fixing; the pre-existing pile is not this run's job.

## 3. Build for testing — this is not optional

```sh
xcodebuild build-for-testing -scheme <scheme> -destination '<destination>'
```

`xcodebuild build` compiles the **app target only**. A test file that does not compile still reports
`** BUILD SUCCEEDED **`, so a run that skips this step can declare success over tests that cannot
even build. Look for `** TEST BUILD SUCCEEDED **`.

Fix test-target compile errors here — they are frequently *not* the same class of error as app
errors (ambiguous type lookups from modules XCTest pulls in, a helper that drifted from the API it
tests, a renamed symbol). Check the repo's known-gotchas section before inventing a theory.

## 4. Run the unit tests

Reuse the build from step 3 — do not rebuild:

```sh
xcodebuild test-without-building -scheme <scheme> -destination '<destination>' \
  -only-testing:<UnitTarget> [-only-testing:<OtherUnitTarget> ...]
```

Naming the unit targets explicitly is what keeps the UI suites out. (`-skip-testing:<UITarget>` is
the equivalent when there are many unit targets and few UI ones — either is fine, but be sure no UI
target runs.)

### The fix loop

For each failure, in this order:

1. **Read the actual assertion**, not just the test name — the message, expected vs actual, and the
   file and line it points at.
2. **Decide who is wrong: the code or the test.** Both happen. A test encoding an outdated
   expectation is a real finding; so is a test that is right and a change that broke it. Say which
   you concluded and why.
3. **Fix it**, minimally.
4. **Re-run the narrowest thing that proves it** —
   `-only-testing:<Target>/<TestClass>/<testMethod>` — then widen back to the full unit run before
   declaring green.
5. **Any fix touching app or test source means step 3 again** (`build-for-testing`) before the next
   test run. `test-without-building` will happily re-run a stale bundle.

**A whole suite failing identically smells environmental.** Before treating it as an app defect,
check the repo's known gotchas and try the runtime the docs require. Simulator/runtime regressions
that make a healthy app look broken are common and documented per project; chasing one as a code bug
costs a session.

**Stop rather than churn.** If the same test fails three times running and your understanding has not
advanced, stop and report: what fails, the assertion, what you tried, and your best reading. A
truthful "one test still red, here is why" beats a green achieved by bending the test — and beats
another six rounds of guessing.

**Flakes get named, never absorbed.** If a test passes on a re-run with nothing changed, say so
explicitly in the report — name the test and that it was non-deterministic. Never let a re-run pass
quietly stand in for a fix.

## 5. Record the run

So `/swift-verify-ui` can pick up where this left off instead of repeating the whole ladder, write a
state file inside `.git` (never in the working tree — it must not be committable):

```sh
cat > "$(git rev-parse --git-dir)/swift-verify-state.json" <<EOF
{
  "finished_at": "$(date -u +%FT%TZ)",
  "head": "$(git rev-parse HEAD)",
  "tree_fingerprint": "$( { git status --porcelain; git diff HEAD; } | shasum | cut -d' ' -f1 )",
  "scheme": "<scheme>",
  "destination": "<destination>",
  "unit_targets": ["<UnitTarget>"],
  "ui_targets": ["<UITarget>"],
  "lint": "clean|skipped|<n> warnings",
  "build": "passed",
  "build_for_testing": "passed",
  "unit_tests": "passed|<n> failing"
}
EOF
```

Write it **only when the ladder actually got that far**, and record honestly what each stage did —
a state file claiming a pass that did not happen is worse than none, because the UI skill will trust
it and skip the work.

## 6. Post the stage on the item

Where the repo's roadmap is its own GitHub issues, the run's outcome goes on the item as a
`<!-- sidebar:stage -->` comment, so a board such as Sidebar or SidePocket can show the item as
verified on the Mac — or as needing work — rather than still awaiting verification.

**Resolve the item first, and post nothing where it does not resolve:**

1. `.roadmap` at the repo root says `kind: github-issues`. No such line, or no `.roadmap` → say
   "no issue roadmap — no stage posted" in the report and move on.
2. The issue is the branch's leading number (`41-issues-roadmap` → #41); failing that, an
   `rm-NN-*` branch's alias, the issue whose title starts `RM-NN —`; failing that, the first
   `Refs #N` in the body of the open PR whose head is this branch
   (`gh pr list --head <branch> --json body`). None, or several → say so and post nothing; never
   guess.
3. The issue carries the **`roadmap`** label; an unlabelled issue is not an item. Say so and post
   nothing.
4. **The tree this run verified is a commit.** `git status --porcelain` must be empty. A fix this
   run made — or anything else uncommitted — means what went green is *HEAD plus edits*, which no
   SHA names, and a `verified` claim at HEAD would vouch for code that was never built. Post
   nothing, and say in the report that the stage waits for the owner to commit and re-run.
5. **The run got far enough to judge.** A stop at preflight (no Xcode, a scheme nobody chose) has
   verified nothing either way — post nothing.

Then post one comment. Keep the marker, the yaml fence and the key names **verbatim** — the shape
is saintsim/Sidebar's `docs/item-flow.md`, parsed by its `sidebar/issues.py`, and read on the
phone; a key spelt differently is a stage that silently never shows:

````markdown
<!-- sidebar:stage -->
**Verified** · swift-verify · clean

```yaml
stage: verified
verdict: clean
by: swift-verify
sha: 4f2a9c1
branch: 41-issues-roadmap
session: 9f2c1e04-7a3b-4d51-8c6e-2b0f4a7d9e13
```

Lint clean; build, build-for-testing and 214 unit tests passed on iPhone 17 Pro (iOS 26.2).
````

- **`verdict`** — `clean` when every stage of the ladder passed; `failed` when anything is still
  red at the end (a lint error, a build, or a unit test you stopped on). No other word: the parser
  drops a `verified` stage with any other verdict, or none — and `findings` is a review's word.
- **`by: swift-verify`**, always. **Never `by: owner`** — that is the owner's own verdict, written
  only on their words, and a green ladder is not them saying they tried it.
- **`sha`** — `git rev-parse --short HEAD`. Required: it is what lets a later push retire the stage
  as *changed since verification*. It may be a commit not yet pushed; the board copes with that.
- **`branch`** — `git branch --show-current`. **`session`** — `CLAUDE_CODE_SESSION_ID` if it is
  set, else leave the key out. Both are optional, and a wrong value is worse than none.
- **The paragraph** is prose and not parsed: what passed, the destination, anything still red.
- One per run, append-only, never edited — the latest wins.

**Access:** `gh issue comment <N> --body-file <file>` (or the `mcp__github__*` tools, where a session
has them). If neither works, **print the exact comment and ask the user to post it** — never skip it
silently.

## 7. Report

Tell the user, briefly:

- **Destination** used, and if it wasn't the obvious default, why.
- **Lint** — clean, fixed *n* errors, *n* warnings outstanding, or not installed.
- **Build** and **build-for-testing** — passed, or what had to be fixed.
- **Unit tests** — count passed, and every failure that had to be fixed, with the one-line diagnosis
  (code was wrong / test was wrong).
- **Anything still red**, plainly, up front.
- **What changed on disk**, since the user will review and commit it themselves.
- **Stage** — the stage comment's URL and verdict, or why none was posted.

Then offer `/swift-verify-ui` if the project has UI targets — noting it will run only the UI suites,
because this run is already recorded.

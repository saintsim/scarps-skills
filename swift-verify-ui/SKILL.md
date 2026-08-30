---
name: swift-verify-ui
description: Verify a Swift/Xcode project locally including its UI tests — SwiftLint, build, build-for-testing, unit tests, then the UI suites, fixing failures and re-running until green. The UI counterpart of /swift-verify, and it deliberately does not repeat work: run straight after /swift-verify and it runs only the UI tests. Use after /teleport from a web session when the UI flows need proving too, or when the ask is "run the UI tests and get them passing". Needs Xcode and a simulator, so it runs on a Mac.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit, AskUserQuestion, Skill
---

You are verifying the Swift/Xcode project you are standing in, locally, all the way through its
**UI tests**. This is `/swift-verify` plus the UI suites, with one rule that shapes the
whole run:

> **Never repeat work `/swift-verify` just did.** If it ran on this exact tree, the only thing left
> is the UI tests.

Everything in `/swift-verify`'s **"Rules that hold for the whole run"** applies here unchanged — no
green by weakening the check, no commits, fix forward minimally, read the repo's own conventions
first, run unattended. Read that skill's file if it is installed alongside this one
(`~/.claude/skills/swift-verify/SKILL.md`); the rules below are additions, not replacements.

## 0. Preflight and resume

Same preflight as `/swift-verify` — `xcodebuild -version` must answer, or stop and say so.

Then decide whether the earlier ladder still counts:

```sh
STATE="$(git rev-parse --git-dir)/swift-verify-state.json"
cat "$STATE" 2>/dev/null
git rev-parse HEAD
{ git status --porcelain; git diff HEAD; } | shasum | cut -d' ' -f1
```

**The state is usable when the file exists, every stage in it passed, and both the `head` and the
`tree_fingerprint` still match.** The fingerprint is what makes this safe: a single edit since
`/swift-verify` finished changes it, and stale state is exactly how a run declares green over code
nobody compiled.

- **Usable →** say so ("`/swift-verify` covered lint, build and the unit tests on this tree — running
  the UI suites only"), reuse its scheme and destination, and go to step 2. The test bundles are
  already built, so `test-without-building` is valid.
- **Missing, stale, or incomplete →** run the full ladder first: invoke the **`/swift-verify`** skill
  and let it finish, then continue here from step 2. If that skill is not installed, follow its
  ladder yourself — lint, `build`, `build-for-testing`, unit tests — before touching the UI suites.
  Say which of the two happened; never imply a stage ran that didn't.

Whichever path you took, you now need the **UI targets** and the destination in hand (from the state
file, or discovered as `/swift-verify` describes: targets whose name ends in `UITests`, or that build
as UI testing bundles).

If the project has **no UI targets**, say so and stop — there is nothing this skill adds over
`/swift-verify`.

## 1. Prepare the simulator

UI tests drive real UI, so the machine's state is part of the test.

- **Run them serially.** Parallel UI testing multiplies flake for no gain at this scale:
  `-parallel-testing-enabled NO`.
- **Nothing else should be driving the simulator.** If Xcode is mid-run on the same device, or the
  app is open on it, results are unreliable — mention it if you spot it.
- **Fresh state:** many suites simulate a first install via a launch argument (`--uitesting` and the
  like) rather than by wiping the device. Check how *this* project does it before reaching for
  `xcrun simctl erase`. **Never erase a simulator without telling the user first** — it destroys
  whatever else lives on that device.

## 2. Run the UI tests

```sh
xcodebuild test-without-building -scheme <scheme> -destination '<destination>' \
  -only-testing:<UITarget> \
  -parallel-testing-enabled NO \
  -resultBundlePath /tmp/swift-verify-ui.xcresult
```

Delete a previous result bundle at that path first — `xcodebuild` refuses to overwrite one. Run it in
the background, tee'd to a log, and poll: UI suites take minutes, and a foreground timeout that kills
the run mid-flight tells you nothing.

`test-without-building` reuses the bundles from `build-for-testing`. **The moment you change app or
test source, that build is stale** — re-run `build-for-testing` before the next UI run, or you are
testing the previous version of the code and will chase a ghost.

## 3. The UI fix loop

A UI failure names an element that wasn't there, a tap that did nothing, or a wait that expired. It
rarely says why. Get the evidence before theorising:

```sh
xcrun xcresulttool get test-results tests --path /tmp/swift-verify-ui.xcresult          # failures, per test
xcrun xcresulttool export attachments --path /tmp/swift-verify-ui.xcresult --output-path /tmp/swift-verify-ui-attachments
```

(Flags move between Xcode versions — if one is rejected, ask the tool: `xcrun xcresulttool help`.)
The exported attachments include **failure screenshots**: read them. Seeing the screen at the moment
of failure settles in one look what a stack trace argues about for an hour. The automatic UI
hierarchy dump in the failure output is the other half — it tells you what the runner *could* see.

Then work the failure in this order:

1. **Is the app actually broken, or is the test looking in the wrong place?** Both are real
   outcomes. A test hunting a renamed button is a test fix; a button that no longer responds is a
   code fix. Say which you concluded.
2. **Prefer accessibility identifiers over label text.** When a test breaks because a caption
   changed, the durable fix is an identifier on the control and a query against it — not a new
   hardcoded string that will break at the next copy edit. Follow whatever convention the repo
   already uses.
3. **Prefer waiting for a condition over sleeping.** `waitForExistence(timeout:)` on the thing you
   need beats a fixed sleep, which is either too short on a cold simulator or wasted everywhere else.
4. **Check the project's known gotchas before blaming your own change.** UI-layer platform behaviour
   — a control that silently won't attach in a particular presentation context, a view raised too
   early in a presentation animation, a toolbar the OS re-lays-out — is exactly the class of thing a
   repo writes down after losing a day to it. Read those notes before inventing a theory.
5. **Re-run the single test** (`-only-testing:<UITarget>/<Class>/<method>`) to confirm the fix, then
   the whole UI target before declaring green.

**Flake is diagnosed, never absorbed.** A UI test that fails then passes untouched is
non-deterministic, and that is a finding: name it in the report, and where the cause is clear and the
fix is small and in scope (a wait that should be a condition, a query that should be an identifier),
fix it. What you must never do is re-run until it happens to pass and call that green. Equally,
never skip, disable or `XCTSkip` a UI test to finish — if one cannot be made to pass, stop and report
it as still red.

**A fix in app code re-opens the earlier rungs.** UI tests exercise the shipping app, so a change you
made to satisfy one can break a unit test or a lint rule:

- Touched **app source** → re-run lint on it, `build-for-testing`, **and the unit suites** before
  finishing. This is the one case where repeating `/swift-verify`'s work is required, not wasteful.
- Touched **only UI test files** → `build-for-testing` and the UI suites are enough.

**Stop rather than churn**, exactly as in `/swift-verify`: three rounds on one test with no advance in
understanding, and you stop and report what you know.

## 4. Update the run record

Refresh `.git/swift-verify-state.json` so the tree's status stays truthful — same fields as
`/swift-verify` writes, plus what this run did:

```json
"ui_tests": "passed|<n> failing",
"ui_finished_at": "<UTC timestamp>"
```

Recompute `head` and `tree_fingerprint` **after** your last edit, and re-record `unit_tests` honestly:
if you changed app code and re-ran them, say passed; if you changed app code and did *not* re-run
them, say so rather than carrying the old pass forward. The next run trusts this file.

## 5. Report

- **What you skipped and why** — "lint/build/unit tests were already green on this tree from
  `/swift-verify`" — or that you ran the full ladder because the state was missing or stale.
- **UI tests** — count passed, each failure fixed with its one-line diagnosis (app was broken / test
  was looking in the wrong place), and any test that was flaky, named as such.
- **Anything still red**, plainly and first.
- **Whether the unit suites were re-run**, if app code changed.
- **What changed on disk** — the user reviews and commits it themselves.

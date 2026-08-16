---
name: roadmap-item
description: Pick up a roadmap item by id and build it in the current code repo. Use whenever the user names a bare roadmap id from the current repo's checkout — "work on RM-25", "lets work on RM-18 next", "do RM-07", "start the next item" — without explaining what the id is. The id belongs to the Open-Road roadmap repo (intent only); the work belongs to the repo you are standing in, which the item's project is resolved from via that repo's `.roadmap` pointer. Reads the item and its authorities first, asks up front if the item is too thin to build from, branches off fresh main, implements, builds and runs the tests, then stops for the user to test. On their go-ahead it runs /review-loop, /ship, and prepares the paired Open-Road draft PR marking the item done.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, AskUserQuestion, Skill, Agent, SendMessage
---

You are picking up a **roadmap item** and building it. The user will say no more than `work on RM-25`,
because everything below is what the skill is for — they should not have to re-explain the setup each
time.

## The setup you are standing in

Two repos, and confusing them is the failure this skill exists to prevent:

- **[Open-Road](https://github.com/saintsim/Open-Road)** holds **intent, not code** — build specs and
  roadmap items, one folder per project. `RM-25` is a file there: `<Project>/roadmap/RM-25.md`.
- **The repo the user is in right now** holds the code. That is where the work happens. Sidebar and
  PackRight items are built in `Sidebar/` and `PackRight/` respectively, never in Open-Road.

**Ids are per project, not global.** `Sidebar/roadmap/RM-25.md` and `PackRight/roadmap/RM-25.md` are
both real and unrelated. Never resolve an id by searching Open-Road for `RM-25.md` and taking the
first hit — resolve the project first, from the repo you are standing in.

**Branch is the spine.** A branch named `rm-25-*` resolves back to `RM-25`, which is how observed work
links to intent with nobody maintaining a mapping. That is why the branch name is not cosmetic.

## Two touch points, and only two

This skill runs on its own except at these points:

1. **Before building** — only if the item is too thin to build from without guessing (see *Gate 1*).
2. **After building** — you stop so the user can test it themselves (see *Gate 2*).

Everything else is unattended: don't ask permission to read, branch, implement, or fix your own build
breaks.

If the user's opening message waives the second gate — "don't wait for me to test", "go all the way
through", "don't stop", or anything equivalent — **skip Gate 2** and run straight on to review, ship
and the roadmap change. Say at the start that you're doing so.

---

## 1. Resolve the item — never guess the project

```sh
git rev-parse --show-toplevel        # the code repo you are in
cat "$(git rev-parse --show-toplevel)/.roadmap"
```

The `.roadmap` file names the roadmap repo and the item directory, e.g.:

```yaml
repo: saintsim/Open-Road
path: Sidebar/roadmap/
```

That `path` **is** the project resolution. Locate the Open-Road checkout, in this order:

1. `$OPEN_ROAD_DIR` if set.
2. A sibling checkout of the current repo's parent directory whose name matches the `repo` field
   (typically `../Open-Road`).
3. Anything else on disk you can find with a bounded search.

Then bring it up to date and check its state — you are about to read intent from it and later write to
it, and a stale or dirty checkout poisons both:

```sh
git -C <open-road> fetch --quiet origin
git -C <open-road> status --short --branch
```

If the checkout is dirty or behind `origin/main`, say so plainly before continuing, and say which
state you read the item from. Do not stash, reset or discard the user's work there.

**Stop and ask** if: there is no `.roadmap` in this repo, no Open-Road checkout can be found, or the
named item file does not exist. For a missing item, list the ids that do exist in that project's
roadmap directory rather than picking the closest one.

## 2. Read before you build

In this order, and actually read them — this repo pays for skimming:

1. **The item** — `<open-road>/<path>/RM-NN.md`. Several items record a decision already taken and the
   evidence for it, so it does not have to be re-derived; some also ask for a **measurement to be
   re-run before building** (Sidebar's RM-18 is the pattern). Do that measurement first and keep the
   result — it goes back into the item at the end.
2. **Its `depends_on` items** — confirm each is `done`. If one is not, the item is blocked; say so,
   name the blocker, and ask whether to proceed anyway rather than quietly building on sand.
3. **The project's spec** — `<open-road>/<Project>/specs/*.md`, at least the sections the item cites.
   Keep `§` citations exact if you quote or move them.
4. **The project README** — `<open-road>/<Project>/README.md`, for where the item sits in the order.
5. **The conventions** — `<open-road>/CLAUDE.md`, `<open-road>/<Project>/CLAUDE.md`, and the **code
   repo's own `CLAUDE.md`**, which carries its build, test and review discipline. These are the
   authorities; obey them rather than restating them.

## 3. Gate 1 — ask if the item is too thin

The item is the requirement. If it does not determine what to build, **ask before writing code** — a
wrong build is far more expensive than a question. Ask when:

- The item states a goal but not the behaviour: what the thing does at the edges, what happens on
  failure, what the user actually sees.
- Two reasonable readings would produce materially different implementations.
- It names a decision as deferred without saying who decides or what to assume meanwhile.
- Its "done when" is not something you could check.
- It conflicts with the spec, with a `depends_on` item, or with what the code repo already does.

Do **not** ask about routine judgement a careful engineer would just make: naming, file layout, which
helper to reuse, test structure. Make those calls and note them.

When you do ask, use **AskUserQuestion** and put **every** question in a single call with concrete
options — don't drip-feed. Then continue without further checkpoints.

## 4. Branch off fresh main — never work on main

```sh
git -C <code-repo> fetch --quiet origin
git -C <code-repo> status --short --branch
```

- If the working tree has unrelated changes, stop and report rather than sweeping them into the item.
- Determine the default branch (`git remote show origin | sed -n 's/.*HEAD branch: //p'`).
- Create the branch **from the freshly fetched default branch**, not from whatever `main` happens to
  be locally:

  ```sh
  git -C <code-repo> switch -c rm-<id>-<slug> origin/<default-branch>
  ```

- **Name it `rm-<id>-<slug>`** — `rm-25-roadmap-refresh`. The digits are matched numerically, so
  `rm-25-*` and `rm-025-*` both resolve; never reconstruct the id by string concatenation. The slug is
  a few kebab-case words from the item's title.
- If a branch for this item already exists, don't make a second one — see *Resuming*.

## 5. Implement

Build what the item specifies, in the code repo, following that repo's `CLAUDE.md`.

- **Hold the item's scope.** Things the item didn't foresee get noted in your report, not silently
  built. If you find work that belongs in a different item, say which.
- Where the item records a decision and its reasoning, implement that decision — it was taken
  deliberately, and re-deriving it is how it gets quietly reversed.
- Update the code repo's own docs (`README`, `docs/`, `CLAUDE.md`) where this change makes them stale.
- **British English** in prose, comments and commit text.
- If reality contradicts the item mid-build — the measurement comes out differently, the approach
  doesn't survive contact — **stop and say so**. Don't reshape the requirement silently to fit what
  you built; that lands a false item at the end.

## 6. Verify — prove it builds, and run the tests

Never hand back work you have not compiled. The point is that build breaks are caught here rather
than by the user, so run the real commands and report the real output. **Never claim a check passed
that you did not run.**

Take the commands from the code repo's `CLAUDE.md` first; these are fallbacks when it is silent:

- **Python (e.g. Sidebar)** — `.venv/bin/python -m pytest -q`, and `.venv/bin/ruff check .` plus
  `.venv/bin/ruff format --check .`. Use the venv binaries, not the system ones.
- **Node / web** — `npm run lint`, `npm test`, `npm run build` in the web directory.
- **Xcode / iOS (e.g. PackRight)** — `swiftlint --fix` then `swiftlint`; `xcodebuild build`; and if
  you touched test files, `xcodebuild build-for-testing` too (plain `build` never compiles the test
  targets, so a broken test file still reports `BUILD SUCCEEDED`). Then run the test plan on a
  simulator. Use the destination the repo's `CLAUDE.md` names.

**iOS builds are non-blocking.** If the simulator or toolchain misbehaves — no matching destination,
a stuck simulator, a derived-data problem — make one honest attempt to clear it, then report exactly
what failed and hand back anyway. Do not burn the session on the harness. Say plainly which of
compile / test-compile / tests actually ran and which did not.

> `PackRight/CLAUDE.md` currently says "do not launch the app or tests in the simulator — the
> developer runs those in Xcode". That line is stale: the owner reversed it on 2026-08-16 because
> build breaks kept coming back to them. Run the tests, and mention the stale line so it can be fixed.

Fix what you break. Pre-existing failures on the base branch are not yours to fix — confirm they fail
on `origin/<default-branch>` too, and report them as pre-existing.

## 7. Gate 2 — hand back for the user to test

Commit your work on the branch so nothing is lost, then **stop** and report:

- **Item** — id, title, project, and the one-line summary of what it asked for.
- **Branch** — its name, and that it was cut from fresh `origin/<default-branch>`.
- **What changed** — the key changes, by file or area.
- **Verification** — every command you ran and its actual result. Anything you couldn't run, named.
- **How to try it** — the concrete command or steps to exercise the change: the run command, the
  screen to open, the thing to look at.
- **Decisions and open points** — judgement calls you made, anything the item didn't cover, anything
  you deliberately left out of scope.
- **What happens next** — say explicitly that on their go-ahead you'll run `/review-loop`, then
  `/ship`, then prepare the Open-Road draft PR. And that they can say "don't wait for me to test"
  next time to run straight through.

Do **not** run `/review-loop`, `/ship`, or touch Open-Road yet. The evidence written into the roadmap
item has to describe the code that actually ships, and it hasn't been tested or reviewed yet.

---

## 8. On the go-ahead — review, ship, then the roadmap

When the user comes back happy (or the second gate was waived up front), run the rest unattended:

1. **`/review-loop`** — invoke the skill with the **Skill** tool and let it run to a clean verdict.
   Fix what it finds; don't shortcut the loop.
2. **`/ship`** — invoke the skill. It re-lints, updates docs, commits, pushes and opens the **draft**
   code PR. Keep the PR title prefixed with the project name and the item id, e.g.
   `Sidebar: RM-25 — roadmap tab refresh`. **Capture the code PR URL** — the roadmap PR has to link it.
3. **The Open-Road change** — section 9. It is not optional and it is not a separate errand: an item
   finished with its roadmap PR unwritten is an unfinished job.

If the user reports a problem instead of a go-ahead, fix it on the same branch, re-verify, and hand
back again. The gate repeats; the skill does not restart.

## 9. The Open-Road change

The **code PR merges first** — the roadmap must never claim work that isn't shipped — but both PRs are
**opened together as drafts in this session**, so the owner can merge the pair in sequence without
being prompted for the second half.

In the Open-Road checkout, on a **new branch off fresh `origin/main`**:

```sh
git -C <open-road> switch -c rm-<id>-<project>-roadmap origin/main
```

Put the project in the slug — two projects share every id, so a bare `rm-25-roadmap` is ambiguous in
this repo in a way it never is in a code repo.

Make these edits **together**:

- **`intent: done`** on the item. Nothing else in the run touches `intent` — it is hand-owned, and
  this flip is the owner's completion instruction, not an inference from a green build.
- **`branches: [rm-<id>-<slug>]`** — the delivering **code** branch, not this roadmap branch.
- **Measured evidence in the item body** — the decisions taken and the numbers actually measured,
  which are deliberately not duplicated in the code. Sidebar's RM-04 and RM-18 are the shape. This is
  the part that gets read months later as settled fact, so:
  - **Cite the file and the thing, never a line number** — "the app target's `productName` in
    `project.pbxproj`", not `project.pbxproj:487`.
  - **Produce the citation in the same turn as the sentence citing it.** Run the command, then write
    the sentence — not from memory of a read earlier in the session.
  - **Record what you observed and its ordering; never name a cause you didn't observe.** "The remote
    was reset at some point after the push" is a fact; "X reset the remote" is a claim about a tool's
    behaviour that a future session will rely on.
  - Do not write "validated" or "schema-checked" — `sidebar validate` does not exist yet.
- **The project README** — flip that item's row and its intent, and move it if the ordering says so.
  The table is hand-owned, not generated. Check the closing prose too: it names the current `next`,
  and it must not disagree with the table.
- **Promote exactly one item to `intent: next`**, choosing only from items whose `depends_on` are all
  `done`, and say in one line why that one. `blocked` is derived, never declared — never mark an item
  `next` while a dependency isn't `done`; edit the `depends_on` instead. The two exceptions —
  everything is `done`, or nothing is unblocked — must be **stated in the PR**, never left as silence.

Then hand-check, because there is no validator: exactly six frontmatter keys per touched item; exactly
one item `next` with all its `depends_on` done; every `depends_on` id exists with no cycles; the README
table matches the frontmatter; any count stated in prose still matches the files.

**Run `/plan-review` when the change is non-trivial** — when it adds or renumbers items, edits
`depends_on`, reorders the README, or reconciles the spec with what actually got built. A plain
done-flip plus a README row does not need it; say which you judged it to be.

Commit and open the PR:

- Commit subject in the house style: `Sidebar: RM-25 done — <what shipped>, and RM-26 next`. End the
  message with the same `Co-Authored-By:` trailer `/ship` uses.
- `gh pr create --draft`, title prefixed with the project name, e.g.
  `Sidebar: RM-25 done — roadmap tab refresh`.
- The body must **say plainly that it depends on the code PR and must be merged after it**, and link
  it. Also state the promoted `next` item and why, and any evidence that could not be measured.
- **Draft only.** Never `gh pr ready`, never `gh pr merge`. A human merges both, in order.

If the code PR changes materially in later review, come back and revisit the roadmap PR before it
merges — that is the cost of preparing early, and it is far cheaper than the round trip.

## Resuming a part-finished item

If a branch named `rm-<id>-*` already exists in the code repo, or one already exists in Open-Road,
don't start again. Work out where it got to — `git log`, `git status`, `gh pr list --head <branch>` —
say so, and rejoin at the right step: still implementing, waiting at Gate 2, reviewed but unshipped,
or shipped with the roadmap half outstanding.

## Final report

When the whole thing is done, report: the item and what shipped; the code branch and **draft PR URL**;
the verification actually run, with results; the review-loop verdict; the Open-Road branch and **draft
PR URL**; the item promoted to `next` and why; anything deferred or left out of scope; and an explicit
reminder that **both PRs are drafts, and the code PR merges first**.

Report faithfully. If something didn't run, say it didn't run.

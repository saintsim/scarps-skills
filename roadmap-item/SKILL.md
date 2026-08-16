---
name: roadmap-item
description: Pick up a roadmap item by id and build it in the current code repo. Use whenever the user names a bare roadmap id from the current repo's checkout — "work on RM-25", "lets work on RM-18 next", "do RM-07" — without explaining what the id is. The id belongs to the Open-Road roadmap repo, which holds intent only; the work belongs to the repo you are standing in, whose project is resolved from its own `.roadmap` pointer. Reads the item and its authorities first, asks up front if the item is too thin to build from, branches off the freshly fetched default branch, implements, builds and runs the tests, then stops for the user to test. On their go-ahead it runs /review-loop, /ship, and prepares the paired Open-Road draft PR marking the item done.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, AskUserQuestion, Skill, Agent, SendMessage
---

You are picking up a **roadmap item** and building it. The user will say no more than `work on RM-25`,
because everything below is what the skill is for — they should not have to re-explain the setup each
time.

## The setup you are standing in

Two repos, and confusing them is the failure this skill exists to prevent:

- **[Open-Road](https://github.com/saintsim/Open-Road)** holds **intent, not code** — build specs and
  roadmap items, one folder per project. `RM-25` is a file there: `<Project>/roadmap/RM-25.md`. The
  roadmap always lives in Open-Road, whatever the project.
- **The repo you are standing in** holds the code. That is where the work happens. It can be **any**
  repo carrying a `.roadmap` pointer — never assume a particular one, and never build in Open-Road.

**Ids are per project, not global.** Two projects can each carry an `RM-25`, and they are unrelated
items. Never resolve an id by searching Open-Road for `RM-25.md` and taking the first hit — resolve
the project first, from the repo you are standing in.

**Nothing in this skill is specific to one project.** Every path, command and convention below is
discovered from the repos at run time. Where a repo's own documents disagree with what you find on
disk, the disk wins and you say so.

## Touch points

Two **planned** stops:

1. **Before building** — only if the item is too thin to build from without guessing (*Gate 1*).
2. **After building** — so the user can test it themselves (*Gate 2*).

Beyond those, stop only when the run **cannot safely continue** — an unresolvable item, a code repo
the item doesn't name, a dirty working tree, a dependency that isn't done, or reality contradicting
the item mid-build. Each is called out where it arises. Otherwise run unattended: don't ask permission to read, branch, implement,
or fix your own build breaks.

If the user's opening message waives the second gate — "don't wait for me to test", "go all the way
through", "don't stop", or anything equivalent — **skip Gate 2** and run straight on to review, ship
and the roadmap change. Say at the start that you're doing so.

---

## 1. Resolve the item — never guess the project

```sh
git rev-parse --show-toplevel        # the code repo you are in
cat "$(git rev-parse --show-toplevel)/.roadmap"
```

`.roadmap` is YAML naming the roadmap repo and the item directory. Expect comment lines; read the
keys, not the first two lines:

```yaml
repo: saintsim/Open-Road
path: <Project>/roadmap/
```

It may also carry optional `field_map`, `value_map` or `branch_pattern` keys for repos whose
conventions differ from the canonical schema. If they are present, respect them — the field names and
branch shape they define override the defaults described here.

That `path` **is** the project resolution. Locate the Open-Road checkout, in this order:

1. `$OPEN_ROAD_DIR` if set.
2. A sibling checkout of the current repo's parent directory whose name matches the `repo` field.
3. Anything else on disk you can find with a bounded search.

Then bring it up to date and check its state — you are about to read intent from it and later write to
it, and a stale or dirty checkout poisons both:

```sh
git -C <open-road> fetch --quiet origin
git -C <open-road> status --short --branch
```

If the checkout is dirty or behind its upstream, say so plainly before continuing, and say which state
you read the item from. Do not stash, reset or discard the user's work there.

**Stop and ask** if any of these hold — do not guess your way past them:

- there is no `.roadmap` in this repo;
- `.roadmap` is missing its `repo:` or `path:` key, or `path` names a directory that does not exist in
  the roadmap checkout;
- no Open-Road checkout can be found;
- the named item file does not exist — in that case list the ids that *do* exist in that project's
  roadmap directory, rather than picking the closest one.

**If the user names no id at all** ("start the next item"), resolve the item whose `intent` is `next`,
say which one you resolved and carry on. If none or more than one is `next`, ask which they mean.

## 2. Read before you build

In this order, and actually read them — this setup punishes skimming:

1. **The item** — `<open-road>/<path>/RM-NN.md`. Items record decisions already taken and the evidence
   for them, so they don't have to be re-derived. Some ask for a **measurement to be re-run before
   building**. Do that first and keep the result — it goes back into the item at the end.
2. **`repos:` in the item's frontmatter** — the code repos the work lands in. Compare it with the repo
   you are standing in (`git remote get-url origin`). **If this repo is not among them, stop and ask**
   — the user may be in the wrong checkout, or the item may belong elsewhere. If the item spans more
   than one code repo, say so up front and agree what lands where before writing anything; some
   projects deliberately split work across an app repo and a companion repo.
3. **Its `depends_on` items** — confirm each is `done`. If one is not, the item is blocked; say so,
   name the blocker, and ask whether to proceed rather than quietly building on sand.
4. **The project's spec** — `<open-road>/<Project>/specs/`, at least the sections the item cites. Keep
   `§` citations exact if you quote or move them.
5. **The project README** — `<open-road>/<Project>/README.md`, for where the item sits in the order.
6. **The conventions** — `<open-road>/CLAUDE.md`, `<open-road>/SCHEMA.md` (the frontmatter contract
   you will edit against later), `<open-road>/<Project>/CLAUDE.md`, and the **code repo's own
   `CLAUDE.md`**, which carries its build, test and review discipline. These are the authorities;
   obey them rather than restating them.

## 3. Gate 1 — ask if the item is too thin

The item is the requirement. If it does not determine what to build, **ask before writing code** — a
wrong build is far more expensive than a question. Ask when:

- The item states a goal but not the behaviour: what the thing does at the edges, what happens on
  failure, what the user actually sees.
- Two reasonable readings would produce materially different implementations.
- It names a decision as deferred without saying who decides or what to assume meanwhile.
- Its "done when" is not something you could check.
- It conflicts with the spec, with a `depends_on` item, or with what the code already does.

Do **not** ask about routine judgement a careful engineer would just make: naming, file layout, which
helper to reuse, test structure. Make those calls and note them.

When you do ask, use **AskUserQuestion** and put **every** question in a single call with concrete
options — don't drip-feed. Then continue without further checkpoints.

## 4. Branch off the fresh default branch — never commit to it directly

```sh
git -C <code-repo> fetch --quiet origin
git -C <code-repo> status --short --branch
git -C <code-repo> remote show origin | sed -n 's/.*HEAD branch: //p'   # the default branch
```

- If the working tree has unrelated changes, stop and report rather than sweeping them into the item.
- Create the branch **from the freshly fetched default branch**, not from whatever it happens to be
  locally:

  ```sh
  git -C <code-repo> switch -c rm-<id>-<slug> origin/<default-branch>
  ```

- **Name it `rm-<id>-<slug>`** — `rm-25-roadmap-refresh`. Branch is the spine: `rm-25-*` resolves back
  to `RM-25`, which is how observed work links to intent with nobody maintaining a mapping. The digits
  are matched numerically, so `rm-25-*` and `rm-025-*` both resolve; never reconstruct the id by
  string concatenation. The slug is a few kebab-case words from the item's title. If `.roadmap`
  defines a `branch_pattern`, follow that instead.
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

Never hand back work you have not compiled. The point is that build breaks are caught here rather than
by the user, so run the real commands and report the real output. **Never claim a check passed that
you did not run.**

**The code repo's own `CLAUDE.md` is the authority on how to build and test it** — read it and use its
commands. The following are fallbacks for when it is silent, and illustrations of the shape rather
than a closed list. A repo in any other language still gets built and tested, using whatever its
README, `CLAUDE.md` or build manifest specifies.

- **Python** — the project's own virtualenv binaries rather than the system ones, e.g.
  `.venv/bin/python -m pytest -q`, plus its linter and formatter check.
- **Node / web** — `npm run lint`, `npm test`, `npm run build` in the relevant directory.
- **Xcode / iOS** — `swiftlint --fix` then `swiftlint`; `xcodebuild build`; and if you touched test
  files, `xcodebuild build-for-testing` too, because plain `build` compiles the app target only, so a
  test file that does not compile still reports `BUILD SUCCEEDED`. Use the scheme and destination the
  repo names.

### Which tests to run

Run the **unit tests**. They are fast, and they are what catches the breakage.

**Do not run UI tests** — they are slow, and the owner runs them himself. **The one exception: if your
diff touched a UI test, run that suite**, because a UI test you edited and never executed is exactly
the thing that comes back broken. **Compile them either way**: `build-for-testing` builds every test
target without running anything, which catches a compile break at a fraction of the cost.

Identify the UI test target by the project's own layout — conventionally a target and folder suffixed
`UITests`, listed alongside the unit test target in the scheme or test plan. "Your diff touched a UI
test" means `git diff --name-only origin/<default-branch>...HEAD` includes a file under that target.
On an Xcode project the exclusion looks like:

```sh
xcodebuild test -scheme <Scheme> -destination <Destination> -skip-testing:<UITestTarget>
xcodebuild test -scheme <Scheme> -destination <Destination> -only-testing:<UITestTarget>  # you edited one
```

Run the equivalent wherever the project keeps slow end-to-end suites behind a separate target, marker
or tag. If the repo has no UI tests, this carve-out simply doesn't apply — run the tests it has.

**Builds and tests are non-blocking.** If the simulator or toolchain misbehaves — no matching
destination, a stuck simulator, a derived-data problem — make one honest attempt to clear it, then
report exactly what failed and hand back anyway. Do not burn the session on the harness. Say plainly
which of compile / test-compile / unit tests / UI tests actually ran, and which did not and why.

Fix what you break. Pre-existing failures on the base branch are not yours to fix — confirm they fail
on `origin/<default-branch>` too, and report them as pre-existing.

> **A code repo's `CLAUDE.md` may predate this and tell you not to build or run tests at all.** That
> instruction has been superseded: the owner reversed it because build breaks kept coming back to
> them, and reporting each one wasted their time. Follow this section instead, and **tell the user
> which repo's `CLAUDE.md` is stale** so it can be corrected at the source rather than overridden
> again every session.

## 7. Gate 2 — hand back for the user to test

Commit your work on the branch so nothing is lost, then **stop** and report:

- **Item** — id, title, project, and the one-line summary of what it asked for.
- **Branch** — its name, and that it was cut from the freshly fetched default branch.
- **What changed** — the key changes, by file or area.
- **Verification** — every command you ran and its actual result. Anything you couldn't run, named.
- **How to try it** — the concrete command or steps to exercise the change: what to run, what to open,
  what to look at.
- **Decisions and open points** — judgement calls you made, anything the item didn't cover, anything
  you deliberately left out of scope.
- **What happens next** — say explicitly that on their go-ahead you'll run `/review-loop`, then
  `/ship`, then prepare the Open-Road draft PR. And that they can say "don't wait for me to test" next
  time to run straight through.

Do **not** run `/review-loop`, `/ship`, or touch Open-Road yet. The evidence written into the roadmap
item has to describe the code that actually ships, and it hasn't been tested or reviewed yet.

---

## 8. On the go-ahead — review, ship, then the roadmap

When the user comes back happy (or the second gate was waived up front), run the rest unattended:

1. **`/review-loop`** — invoke the skill with the **Skill** tool and let it run to a clean verdict.
   Fix what it finds; don't shortcut the loop.
2. **`/ship`** — invoke the skill. It re-lints, updates docs, commits, pushes and opens the **draft**
   code PR. Keep the PR title prefixed with the project name and the item id, e.g.
   `<Project>: RM-25 — <what it does>`. **Capture the code PR URL** — the roadmap PR must link it.
3. **The Open-Road change** — section 9. It is not optional and it is not a separate errand: an item
   finished with its roadmap PR unwritten is an unfinished job.

If the user reports a problem instead of a go-ahead, fix it on the same branch, re-verify, and hand
back again. The gate repeats; the skill does not restart.

## 9. The Open-Road change

The **code PR merges first** — the roadmap must never claim work that isn't shipped — but both PRs are
**opened together as drafts in this session**, so the owner can merge the pair in sequence without
being prompted for the second half.

In the Open-Road checkout, on a **new branch off its freshly fetched default branch**:

```sh
git -C <open-road> switch -c rm-<id>-<project>-roadmap origin/<default-branch>
```

Putting the project in the slug is for human readability: numeric matching ignores the slug, so a bare
`rm-25-roadmap` still resolves, but a reader scanning branches in a repo holding several projects
cannot tell which `RM-25` it means.

Make these edits **together**:

- **`intent: done`** on the item.
- **`branches: [rm-<id>-<slug>]`** — the delivering **code** branch, not this roadmap branch. Note
  that `SCHEMA.md` describes `branches:` as being for assertions the naming convention missed, while
  the root `CLAUDE.md` requires recording the delivering branch on completion. Follow `CLAUDE.md`:
  completed items record their branch either way.
- **Measured evidence in the item body** — the decisions taken and the numbers actually measured,
  which are deliberately not duplicated in the code. The project's already-completed items are the
  shape to follow. This is the part read months later as settled fact, so:
  - **Cite the file and the thing, never a line number** — name the setting, symbol or group, because
    a line number rots the moment anyone edits above it and then points confidently at the wrong
    thing.
  - **Produce the citation in the same turn as the sentence citing it.** Run the command, then write
    the sentence — not from memory of a read earlier in the session.
  - **Record what you observed and its ordering; never name a cause you didn't observe.** "The remote
    was reset at some point after the push" is a fact; "X reset the remote" is a claim about a tool's
    behaviour that a future session will rely on.
- **The project README** — flip that item's row and its intent, and move it if the ordering says so.
  The table is hand-owned, not generated. Check the closing prose too: it names the current `next`,
  and it must not disagree with the table.
- **Promote exactly one item to `intent: next`**, choosing only from items whose `depends_on` are all
  `done`, and say in one line why that one. `blocked` is derived, never declared — never mark an item
  `next` while a dependency isn't `done`; edit the `depends_on` instead. The two exceptions —
  everything is `done`, or nothing is unblocked — must be **stated in the PR**, never left as silence.

**Those two are the only `intent` edits in the whole run**: the done-flip on this item and the
promotion of its successor, both at the end. Never flip an item to `now` when you pick it up. `intent`
is hand-owned — never inferred from a green build, a merged PR or a passing review — and the
promotion is a standing instruction from the owner, written down where a one-word reply overrules it.

### Check it mechanically

**Run the roadmap repo's validator if one is available.** Check the roadmap repo's conventions for
what it is called and how to invoke it; some validators accept a pointer to a code repo and check the
directory its `.roadmap` names, applying any `field_map`, `value_map` and `branch_pattern`. Run it
from the code repo in that case. **Only write "validated" or "schema-checked" if you actually ran it
and it passed** — and if the roadmap repo's own documents say no validator exists while one plainly
runs, trust what runs and tell the user those documents are stale.

If none is available, hand-check: exactly the frontmatter keys the schema allows per touched item;
exactly one item `next` with all its `depends_on` done; every `depends_on` id exists with no cycles;
the README table matches the frontmatter; any count stated in prose still matches the files.

**Run `/plan-review` when the change is non-trivial** — when it adds or renumbers items, edits
`depends_on`, reorders the README, or reconciles the spec with what actually got built. A plain
done-flip plus a README row does not need it; say which you judged it to be.

### Commit and open the PR

- Commit subject: the project, the item, and what shipped — `<Project>: RM-25 done — <what shipped>,
  and RM-26 next`. End the message with the same `Co-Authored-By:` trailer `/ship` uses.
- `gh pr create --draft`, title prefixed with the project name, because several projects raise roadmap
  and code PRs in parallel and an unprefixed title gives no clue which one it belongs to.
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

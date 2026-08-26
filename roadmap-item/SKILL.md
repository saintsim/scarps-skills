---
name: roadmap-item
description: Pick up an Open-Road roadmap item by bare id and build it in the current code repo. Use whenever the user names a bare roadmap id from the current repo's checkout — "work on RM-25", "lets work on RM-18 next", "do RM-07" — without explaining what the id is. The id lives in the Open-Road roadmap repo (intent only); the work happens in the repo you are standing in, whose project is resolved from its own `.roadmap` pointer.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, AskUserQuestion, Skill, Agent, SendMessage
---

The user says no more than `work on RM-25` — everything below is what they should not have to
re-explain each time.

- **[Open-Road](https://github.com/saintsim/Open-Road)** holds **intent, not code** — specs and
  roadmap items, one folder per project. `RM-25` is `<Project>/roadmap/RM-25.md` there, whatever the
  project.
- **The repo you are standing in** holds the code and the work. It can be **any** repo with a
  `.roadmap` pointer — never assume a particular one, and never build in Open-Road.
- **Ids are per project.** Two projects can each carry an unrelated `RM-25`. Never resolve an id by
  searching Open-Road for the filename — resolve the project first, from the repo you are in.
- **Nothing here is project-specific.** Paths, commands and conventions are discovered at run time.
  Where a repo's documents disagree with what runs on disk, the disk wins — say so.

## Touch points

Two **planned** stops: **Gate 1** before building, only if the item is too thin to build from; and
**Gate 2** after building, so the user can test. Beyond those, stop only where a step below says stop
— otherwise run unattended: don't ask permission to read, branch, implement, or fix your own build
breaks.

If the user's opening message waives the second gate — "don't wait for me to test", "go all the way
through", "don't stop", or anything equivalent — **skip Gate 2** and run straight on: say at the
start that you're doing so, and when you reach the end of §7 read `after-go-ahead.md` from this
skill's own directory and continue there.

---

## 1. Resolve the item — never guess the project

```sh
git rev-parse --show-toplevel                                          # the code repo you are in
cat "$(git rev-parse --show-toplevel)/.roadmap"
git -C <open-road> fetch --quiet origin
git -C <open-road> remote show origin | sed -n 's/.*HEAD branch: //p'  # <default-branch>
git -C <open-road> show origin/<default-branch>:<path>/RM-NN.md
```

`.roadmap` is YAML (comment lines are normal), naming the roadmap repo and the item directory:

```yaml
repo: saintsim/Open-Road
path: <Project>/roadmap/
```

Optional `field_map`, `value_map` or `branch_pattern` keys override the defaults below. That `path`
**is** the project resolution. Locate the Open-Road checkout: `$OPEN_ROAD_DIR`, else a sibling
directory named for the `repo` field, else a bounded search.

**Read everything in the roadmap repo from `origin/<default-branch>`** — items, specs, READMEs,
conventions, and the search below — never from its working tree, which another session may have
mid-edit on another branch.

### When the repo has no `.roadmap`

A companion repo — a website, a service, a second client — often delivers items from a project whose
*other* repo carries the pointer. Every item names the repos it lands in, so match this repo's remote
against the remote ref:

```sh
git remote get-url origin                                        # …/<owner>/<repo>.git
git -C <open-road> grep -l "^repos:.*<owner>/<repo>" \
    origin/<default-branch> -- '*/roadmap/*.md'                  # items whose repos: names this repo
```

**Anchor the match to the `repos:` line** — an unanchored search hits the slug in other items' prose
and resolves to the wrong project. Confirm the hit is a whole element of the list, not the prefix of
a longer name.

One project matches → that is the answer; say you resolved it this way, and suggest adding a
`.roadmap` here. Several, or none → ask.

### The shared checkout is not yours to disturb

**Never `switch`, `checkout`, `stash`, `pull`, `reset` or discard anything in it** — another session's
uncommitted work is unrecoverable once you move its HEAD. Everything you write goes in your own
worktree (§9, in `after-go-ahead.md`). Inspect it only to report: if it is dirty, on another branch,
or carries worktrees, say so and say you read the item from `origin/<default-branch>` instead. If its
uncommitted changes touch this item or its README, that is in-flight intent — surface it and ask
before building.

**Stop and ask** if: there is no `.roadmap` **and** the match above resolves to no project or several;
`.roadmap` lacks `repo:`/`path:`, or `path` names a directory that doesn't exist; no Open-Road
checkout can be found; or the item file doesn't exist — then list the ids that *do* exist rather than
picking the closest.

**If the user names no id** ("start the next item"), resolve the item whose `intent` is `next`, say
which, and carry on. If none or several are `next`, ask.

**Still unclear after all that? Ask** — say what you tried, what you found, and your best guess. A
wrong resolution is silent: nothing downstream catches it.

## 2. Read before you build

**Every roadmap-repo read here comes from `origin/<default-branch>`**, per §1. Where a path is written
`<open-road>/…` it means `git show origin/<default-branch>:…`, not the file on disk. Only the code
repo you are standing in is read from its working tree, because that one is yours.

1. **The item** — `<path>/RM-NN.md`. Items record decisions already taken, so they aren't re-derived.
   Some ask for a **measurement to be re-run before building** — do that first and keep the result; it
   goes back into the item at the end.
2. **`repos:` in its frontmatter** — the code repos the work lands in. Compare with
   `git remote get-url origin`. **If this repo is not among them, stop and ask.** If the item spans
   more than one repo, say so and agree what lands where before writing anything.
3. **Its `depends_on` items** — confirm each is `done`. If not, the item is blocked: name the blocker
   and ask whether to proceed.
4. **The project's spec** — at least the sections the item cites; keep `§` citations exact.
5. **The project README** — where the item sits in the order.
6. **The conventions** — `<open-road>/CLAUDE.md`, `<open-road>/SCHEMA.md` (the frontmatter contract
   for the roadmap edits), the project's `CLAUDE.md`, and the **code repo's own `CLAUDE.md`** for its
   build, test and review discipline. These are the authorities; obey them rather than restating them.

## 3. Gate 1 — ask if the item is too thin

The item is the requirement. If it does not determine what to build, **ask before writing code**. Ask
when: behaviour at the edges, on failure, or as the user sees it is unstated; two readings diverge
materially; a decision is deferred with no default and no decider; the "done when" isn't checkable; or
it conflicts with the spec, a dependency, or the existing code.

Do **not** ask about routine judgement — naming, file layout, which helper to reuse, test structure.
Make those calls and note them. When you do ask, put **every** question in a single
**AskUserQuestion** call with concrete options, then continue without further checkpoints.

## 4. Branch off the fresh default branch — never commit to it directly

```sh
git -C <code-repo> fetch --quiet origin
git -C <code-repo> status --short --branch
git -C <code-repo> remote show origin | sed -n 's/.*HEAD branch: //p'   # <default-branch>
git -C <code-repo> switch -c rm-<id>-<slug> origin/<default-branch>
```

- If the working tree has unrelated changes, stop and report rather than sweeping them into the item.
- Cut the branch from the **freshly fetched** default branch, not from whatever it is locally.
- **Name it `rm-<id>-<slug>`** — `rm-25-roadmap-refresh`. Branch is the spine. The digits are matched
  **numerically**, so `rm-25-*` and `rm-025-*` both resolve to RM-25 — never reconstruct the id by
  string concatenation. Slug from the item's title; a `branch_pattern` in `.roadmap` overrides.
- If a branch for this item exists already, don't make a second one — see *Resuming*.

## 5. Implement

Build what the item specifies, following the code repo's `CLAUDE.md`.

- **Hold the item's scope.** Work the item didn't foresee goes in your report, not silently into the
  branch — and say which item it belongs to.
- Where the item records a decision and its reasoning, implement that decision; re-deriving it is how
  it gets quietly reversed.
- **British English** in prose, comments and commit text.
- If reality contradicts the item mid-build, **stop and say so**. Don't reshape the requirement to fit
  what you built — that lands a false item at the end.

## 6. Verify — prove it builds, and run the tests

Build breaks are caught here rather than by the user, so run the real commands and report the real
output. **Never claim a check you did not run.**

**The code repo's own `CLAUDE.md` is the authority on how to build and test it.** A repo in any
language gets built and tested using whatever it, the README or the build manifest specifies. One
fallback worth stating because it hides a trap:

- **Xcode / iOS** — `swiftlint --fix` then `swiftlint`; `xcodebuild build`; and if you touched test
  files, `xcodebuild build-for-testing` too, because plain `build` compiles the app target **only**,
  so a test file that does not compile still reports `BUILD SUCCEEDED`.

### Which tests to run

Run the **unit tests**. **Do not run UI tests** — they are slow and the owner runs them himself. **The
one exception: if your diff touched a UI test, run that suite.** **Compile them either way** —
`build-for-testing` builds every test target without running anything.

Identify the UI target by the project's layout — conventionally a target and folder suffixed
`UITests`. "Your diff touched a UI test" means `git diff --name-only origin/<default-branch>...HEAD`
includes a file under it.

```sh
xcodebuild test -scheme <Scheme> -destination <Destination> -skip-testing:<UITestTarget>
xcodebuild test -scheme <Scheme> -destination <Destination> -only-testing:<UITestTarget>  # you edited one
```

Do the equivalent wherever slow end-to-end suites sit behind a separate target, marker or tag. No UI
tests in the repo → the carve-out doesn't apply; run what it has.

**Builds and tests are non-blocking.** If the simulator or toolchain misbehaves, make one honest
attempt to clear it, then report exactly what failed and hand back. Say which of compile /
test-compile / unit tests / UI tests actually ran, and which did not and why.

Fix what you break. Pre-existing failures aren't yours to fix — confirm they also fail on
`origin/<default-branch>` and report them as pre-existing.

> **A code repo's `CLAUDE.md` may predate this and tell you not to build or run tests at all.** The
> owner reversed that. Follow this section, and **tell the user which repo's `CLAUDE.md` is stale** so
> it is fixed at the source rather than overridden every session.

## 7. Gate 2 — hand back for the user to test

Commit your work on the branch, then **stop** and report: the **item** (id, title, project, what it
asked for) and **branch**; **what changed**, by file or area; **verification** — every command run and
its actual result, and anything you couldn't run; **how to try it** — what to run, open, look at;
**decisions and open points**, including anything left out of scope; and **what happens next** — that
on their go-ahead you'll run `/review-loop`, then `/ship`, then prepare the Open-Road draft PR, and
that "don't wait for me to test" runs straight through next time.

Do **not** run `/review-loop`, `/ship`, or touch Open-Road yet — the evidence must describe the code
that actually ships.

**On the go-ahead, read `after-go-ahead.md` from this skill's own directory and follow it** — it
carries §8 (review and ship), §9 (the Open-Road change) and the final report. If the user reports a
problem instead, fix it on the same branch, re-verify, and hand back again — the gate repeats; the
skill does not restart.

## Resuming a part-finished item

If a branch named `rm-<id>-*` already exists in either repo, don't start again. Work out where it got
to — `git log`, `git status`, `git worktree list`, `gh pr list --head <branch>` — say so, and rejoin:
still implementing, waiting at Gate 2, reviewed but unshipped, or shipped with the roadmap half
outstanding. Rejoining past Gate 2 means reading `after-go-ahead.md` and picking up at the matching
step.

A leftover worktree from an earlier run of *this* item is yours to reuse or remove. One belonging to
another item or session is not — leave it, and pick a branch name that doesn't collide.

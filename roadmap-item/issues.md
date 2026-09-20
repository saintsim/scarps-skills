# roadmap-item — a roadmap kept as GitHub Issues

Read from `SKILL.md` when the code repo's `.roadmap` says `kind: github-issues`. Section numbers are this file's own.

The user says no more than `work on #41` — everything below is what they should not have to
re-explain each time.

- **The item is a GitHub Issue on the repo you are standing in.** The issue number is the id; a
  migrated issue also carries its old id as a title alias, `RM-27 — <title>`. New items have none.
- **The project is the repo** — `git remote get-url origin`. Never resolve an item anywhere else.
- **Intent is hand-owned.** It is a label (`intent:now|next|later|idea`) or the closed state (done =
  closed as completed, dropped = closed as not planned). **This skill never writes an `intent:`
  label and never closes an issue.** The only label it touches is `in-progress`, on and off.
- **GitHub access:** the `mcp__github__*` tools if available (the web), else `gh` on a Mac
  (`gh issue view/list/comment/edit`, `gh api` for the rest). If neither works, **print the exact
  comment text and ask the user to post it** — never skip a comment silently.

## Touch points

Two **planned** stops: **Gate 1** before building, only if the item is too thin to build from; and
**Gate 2** after building, so the user can test. Neither comes before §2: the pick-up is announced
on the issue first, so even a run that stops at Gate 1 is visible on the board. Beyond those two,
stop only where a step says stop — otherwise run unattended: don't ask permission to read,
comment, branch, implement, or fix your own build breaks. If the opening message waives the second
gate — "don't wait for me to test", "go all the way through", or equivalent — **skip Gate 2**: say
so at the start and run §8 straight into §9.

---

## 1. Resolve the item — never guess

```sh
git remote get-url origin                                       # …/<owner>/<repo>.git — the project
grep -E '^kind:' "$(git rev-parse --show-toplevel)/.roadmap"
```

**If `.roadmap` has no `kind: github-issues` line, this repo is not on issues yet** — say so and
stop; do not fall back to guessing a markdown file.

- `#41` → read issue 41 (`issue_read`, or `gh issue view 41`).
- `RM-27` → the alias. Search open **and closed** issue titles for the prefix `RM-27 —`, matching the
  **start of the title** (`search_issues` with `repo:<owner>/<repo> in:title "RM-27 —"`, or
  `gh issue list --state all --search 'in:title "RM-27 —"'`). One hit is the item; none → list the
  aliases that do exist rather than picking the closest; several → ask.
- **No id given** ("start the next item") → the one open issue labelled `intent:next`; none or
  several → ask.

**An issue without the `roadmap` label is not a roadmap item.** Most repos' trackers hold ordinary
bugs and feature requests that predate the roadmap — PackRight had 66 — and the board reads only
labelled issues. If the id you are given resolves to an unlabelled issue, say so and stop rather
than picking it up: either it is not roadmap work, or it needs promoting first (`/roadmap-edit`,
which adds the label).

**Blocked check.** The first body line matching `Depends on: #12, #15` is the dependency list. Read
**each** dependency's state: any still open means the item is blocked — name the blocker and ask
whether to proceed. One closed as *not planned* was dropped, not done; ask about that too. This is
the **one** question that comes before §2, because a blocked item may not be picked up at all:
if the answer is no, nothing is posted and nothing is labelled.

**Still unclear? Ask** — say what you tried, what you found, and your best guess. A wrong resolution
is silent: nothing downstream catches it.

**Read the issue's existing comments while you are here** — an earlier start comment means this is a
**resume** (see *Resuming*). That changes the paragraph §2 writes, never whether §2 runs.

## 2. Announce the pick-up — start comment and `in-progress`, before anything else

**Do this the moment §1 has resolved the issue — before reading the body in depth, before Gate 1,
before branching, before a line of code.** It is the same comment `/roadmap-checkin` posts on its
own, and it is what tells the board, and anyone on another machine, that the item is in hand. A
pick-up that stalls at Gate 1, runs long, or is abandoned half-read still has to be visible, so
nothing else comes first: not the dependencies' bodies, not the spec, not Gate 1's questions. The
only thing ahead of it is §1's blocked check, which decides whether there is a pick-up at all.

The durable "started" mark, readable from any machine and from the web.

- **Web** — `CLAUDE_CODE_ENTRYPOINT=remote` and `CLAUDE_CODE_REMOTE_SESSION_ID=cse_<id>`; the
  session's URL is `https://claude.ai/code/session_<id>` with the same `<id>`. **Prefer the URL the
  harness supplied** in your system prompt (an attribution line naming
  `https://claude.ai/code/session_…`). Only if absent, derive it by replacing `cse_` with
  `session_`, and say in the paragraph that the link was derived. `host: claude.ai`.
- **Local (Mac)** — `CLAUDE_CODE_ENTRYPOINT` is `cli` or unset. `CLAUDE_CODE_SESSION_ID` is expected
  to hold the transcript uuid — **not yet measured on a Mac**. If it is empty, take the newest
  `*.jsonl` under `~/.claude/projects/` modified in the last minute, and say in the paragraph that
  the uuid was inferred. `host` is `hostname -s`; `link` is `http://<host>.local:8787/session/<uuid>`.

**Remote Control does not change either of those.** A local session with `/rc` on keeps running on
the Mac — Claude Code's own documentation is explicit that "Claude keeps running locally the entire
time, so your code execution and filesystem access stay on your machine" — and claude.ai is a second
keyboard on it, not a second machine. So `surface` stays `local` and `host` stays the hostname. It
adds one thing: a way to reach that session from a phone, which `remote_control:` records.

```sh
env | grep -i 'remote.control' || true          # a URL or id here, or nothing
```

Write `remote_control:` only when Remote Control is actually on for this session. Prefer a URL the
environment or your system prompt names; if Remote Control is on but nothing carries the URL, write
`remote_control: enabled` — that alone tells a reader the session is reachable from the Claude app,
where it is named for this machine's hostname by default. **Never ask the user to paste the URL**,
and never write the key at all when `/rc` is off: a reader must be able to trust that its absence
means "not reachable". `enabled` rather than `on` or `yes` deliberately — those two are booleans in
YAML 1.1, so a stricter parser than Sidebar's would read the field as `true` and choke where it
expected the URL.

Timestamp UTC ISO 8601 to the minute (`date -u +%Y-%m-%dT%H:%MZ`). Keep the marker, the yaml fence
and the keys **verbatim** — Sidebar parses them. `branch:` is omitted before the branch exists, and
`remote_control:` is omitted whenever Remote Control is off.

````markdown
<!-- sidebar:start -->
**Started** on **web** · 2026-09-09T12:04Z

```yaml
surface: web            # web | local
session: session_017wSwKg7FYMenuCMUTo5Grw
link: https://claude.ai/code/session_017wSwKg7FYMenuCMUTo5Grw
host: claude.ai
```

Starting from the item as written.
````

A local pick-up on a Mac with Remote Control on, which is the same shape plus one key:

````markdown
<!-- sidebar:start -->
**Started** on **mac-mini** · 2026-09-13T19:20Z

```yaml
surface: local
session: 9f2c1e04-7a3b-4d51-8c6e-2b0f4a7d9e13
link: http://mac-mini.local:8787/session/9f2c1e04-7a3b-4d51-8c6e-2b0f4a7d9e13
host: mac-mini
remote_control: enabled
```

Starting from the item as written.
````

For local: `surface: local`, `session: <uuid>`, `link: http://<host>.local:8787/session/<uuid>`,
`host: <hostname>`. The paragraph states the work's state — a fresh pick-up is "starting from the
item as written"; a resume says what is built, what is uncommitted or unpushed, and the PR URL if one
exists. **One start comment per pick-up; never edit an earlier one** — history is the point.

**Arriving by teleport is a new pick-up, and it needs its own comment.** Work often starts on the
web and is pulled down with `claude --teleport`; the terminal then gets *its own copy* of the
session, and new work there never appears in the cloud session again. So the web start comment
already on the issue is now describing a **dead copy** — it names claude.ai as the machine and
offers a link to a session that has stopped moving. Left alone, every reader is pointed at the wrong
place.

If this session arrived by teleport — its history begins on the web, or the user says they
teleported it — **post a fresh start comment before continuing**, with `surface: local`, this Mac's
`host`, the local `session` uuid, and a paragraph saying it was teleported from the web session and
where that one stopped. Do not edit the web comment: both pick-ups are true, in that order, and the
latest is the one that says where the work is now.

Then add the label (`issue_write` with `labels` = the existing labels plus `in-progress`, or
`gh issue edit <N> --add-label in-progress`) and capture the comment URL for the report.

## 3. Read before you build

1. **The issue body** — the requirement. Items record decisions already taken, so they aren't
   re-derived. Some ask for a **measurement to be re-run before building** — do that first and keep
   the result for the Delivered comment.
2. **Its dependencies** — each `Depends on:` issue, for what they settled.
3. **The code repo's own `CLAUDE.md`** — build, test, lint and review discipline. It is the
   authority; obey it rather than restating it.
4. **The build spec**, when the item cites a `§`: `Open-Road/Sidebar/specs/` in a sibling checkout
   (`$OPEN_ROAD_DIR`, else `../Open-Road`), read with `git show origin/<default-branch>:…`, never
   from its working tree. Keep `§` citations exact.

## 4. Gate 1 — ask if the item is too thin

The issue is the requirement. If it does not determine what to build, **ask before writing code**:
behaviour at the edges, on failure, or as the user sees it is unstated; two readings diverge
materially; a decision is deferred with no default and no decider; *Done when* isn't checkable; or
it conflicts with the spec, a dependency, or the existing code. Do **not** ask about routine
judgement — naming, file layout, which helper to reuse, test structure; make those calls and note
them. When you do ask, put **every** question in one **AskUserQuestion** call with concrete options,
then continue without further checkpoints.

## 5. Branch off the fresh default branch — never commit to it directly

```sh
git fetch --quiet origin && git status --short --branch
git remote show origin | sed -n 's/.*HEAD branch: //p'           # <default-branch>
git switch -c <N>-<slug> origin/<default-branch>                  # e.g. 41-issues-roadmap
```

If the working tree has unrelated changes, stop and report rather than sweeping them in. Cut from
the **freshly fetched** default branch. **Name it `<issue-number>-<slug>`**, slug from the title with
the alias stripped — what GitHub's own *Create a branch* button produces. An item picked up earlier
on an `rm-NN-*` branch **keeps that branch**; never make a second one — see *Resuming*.

## 6. Implement

Build what the item specifies, following the code repo's `CLAUDE.md`. **Hold the item's scope** —
work it didn't foresee goes in your report, naming the issue it belongs to or that it needs one
(`/roadmap-new`). Where the item records a decision and its reasoning, implement that decision;
re-deriving it is how it gets quietly reversed. **British English** in prose, comments and commit
text. If reality contradicts the item mid-build, **stop and say so** — don't reshape the requirement
to fit what you built; that lands a false Delivered comment.

## 7. Verify — prove it builds, and run the tests

Run the real commands and report the real output. **Never claim a check you did not run.** The code
repo's `CLAUDE.md` is the authority on how to build, lint and test — the venv's Python and `ruff`,
the `web/` build, lint and vitest, whatever it names. One fallback worth stating because it hides a
trap: **Xcode** — `swiftlint --fix` then `swiftlint`; `xcodebuild build`; and `build-for-testing`
if you touched tests, because plain `build` compiles the app target only.

Run the **unit tests**. **Do not run UI tests** — the owner runs them — unless your diff
(`git diff --name-only origin/<default-branch>...HEAD`) touched one; compile them either way. Do the
equivalent wherever slow suites sit behind a separate target, marker or tag.

**Builds and tests are non-blocking.** If the toolchain misbehaves, make one honest attempt, then
report exactly what failed and hand back, saying which of compile / test-compile / unit / UI ran.
Fix what you break; pre-existing failures are confirmed on `origin/<default-branch>` and reported as
such. **After fixing a bug, revert the fix and re-run** — if the suite still passes, nothing pins it.

## 8. Gate 2 — hand back for the user to test

Commit on the branch, then **stop** and report: the **item** (number, alias, title, what it asked
for) and **branch**; **what changed**, by file or area; **verification** — every command and its
actual result, and anything you couldn't run; **how to try it**; **decisions and open points**; and
**what happens next** — on their go-ahead `/review-loop`, `/ship`, then the Delivered comment, and
that "don't wait for me to test" runs straight through next time.

Do **not** run `/review-loop` or `/ship` yet — the evidence must describe the code that ships. If
the user reports a problem, fix it on the same branch, re-verify, and hand back again — the gate
repeats; the skill does not restart.

## 9. On the go-ahead — review, ship, deliver

1. **`/review-loop`** — invoke it with the **Skill** tool and let it run to a clean verdict; don't
   shortcut the loop. Anything it defers goes into the Delivered comment, not silently away.
2. **`/ship`** — re-lints, updates docs, commits, pushes and opens the **draft** PR, titled
   `Sidebar: #41 — <what it does>`. The body carries **`Refs #41`** — **never `Closes`, `Fixes` or
   `Resolves`**: a merge must not close an issue; that is automation writing intent. Capture the URL.
3. **The Delivered comment** — what the roadmap PR used to carry. The body is not rewritten.

   ```markdown
   <!-- sidebar:delivered -->
   **Delivered** · branch `41-issues-roadmap` · PR <url>

   <the measured evidence and decisions; anything the review deferred>
   ```

   It is read months later as settled fact: **cite the file and the thing, never a line number**;
   **produce each citation in the same turn as the sentence citing it**; **record what you observed
   and its ordering, never a cause you didn't observe**.
4. **Remove `in-progress`** (`issue_write` with the label omitted, or `gh issue edit <N>
   --remove-label in-progress`) — **only if the latest start comment on the issue is yours.** If
   another session has started since, it holds the item now; leave the label and say so. **Do not
   close the issue and do not touch any `intent:` label.** The owner reads the comment, merges the
   PR, and then runs **`/roadmap-done`**, which closes the issue only once the PR is actually
   merged — one actor, one decision.

## Final report

The item and what shipped; the branch and **draft PR URL**; the verification actually run, with
results; the review-loop verdict; the start and Delivered comment URLs; anything deferred or out of
scope; and that **the PR is a draft and the issue stays open until the owner merges it and runs
`/roadmap-done`**. Then
**name the item you would pick up next and why** — one line, from open issues whose dependencies
are all closed as completed — and say plainly that **the owner applies `intent:next` themselves**
(one word to `/roadmap-edit`); this skill does not.

## Resuming a part-finished item

If a branch `<N>-*` or `rm-NN-*` for this item exists, locally or on the remote, don't start again.
Work out where it got to — `git log`, `git status`, `gh pr list --head <branch>` or
`list_pull_requests`, the issue's comments — say so, and rejoin: still implementing, waiting at
Gate 2, reviewed but unshipped, or shipped with the Delivered comment outstanding. **A resume is a
pick-up: post a new start comment (§2) with `branch:` set and the paragraph stating the real state**,
and make sure `in-progress` is on. Never edit the earlier comment. Past Gate 2, pick up at the
matching step of §9.

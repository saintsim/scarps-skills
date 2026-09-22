# roadmap-item — a roadmap kept as GitHub Issues

Read from `SKILL.md` when the code repo's `.roadmap` says `kind: github-issues`. Section numbers are this file's own.

The user says no more than `work on #41` — everything below is what they should not have to
re-explain each time.

- **The item is a GitHub Issue on the repo you are standing in.** The issue number is the id; a
  migrated issue also carries its old id as a title alias, `RM-27 — <title>`. New items have none.
- **The project is the repo** — `git remote get-url origin`. Never resolve an item anywhere else.
- **Intent is hand-owned, and `now` is the one word this skill says.** Intent is a label
  (`intent:now|next|later|idea`) or the closed state (done = closed as completed, dropped = closed
  as not planned). At pick-up this skill writes **`intent:now`** alongside `in-progress` (§2),
  because being told *work on #41* is the owner saying the item is current — not something read off
  a branch, a build or a merge. **It never writes `next`, `later` or `idea`, and never closes an
  issue.**
- **GitHub access:** the `mcp__github__*` tools if available (the web), else `gh` on a Mac
  (`gh issue view/list/comment/edit`, `gh api` for the rest). If neither works, **print the exact
  comment text and ask the user to post it** — never skip a comment silently.

## Touch points

Two **planned** stops: **Gate 1** before building, only if the item is too thin to build from; and
**Gate 2** after building, so the user can test. Neither comes before §2: the pick-up is marked on
the issue first, so even a run that stops at Gate 1 is already visible on the board. Beyond those
two, stop only where a step says stop — otherwise run unattended: don't ask permission to read,
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
the **one** question that comes before §2, because a blocked item may not be picked up at all: if
the answer is no, nothing is posted and nothing is labelled.

**Still unclear? Ask** — say what you tried, what you found, and your best guess. A wrong resolution
is silent: nothing downstream catches it.

**Read the issue's existing comments while you are here** — an earlier start comment means this is a
**resume** (see *Resuming*). That changes the paragraph §2 writes, never whether §2 runs.

## 2. Mark the pick-up — start comment, `in-progress`, `intent:now` — before anything else

**Do this the moment §1 has resolved the issue — before reading the item in depth, before Gate 1,
before branching, before a line of code.** These are the same three marks `/roadmap-checkin` writes
on its own, and they are what tell a board the item is in hand. A pick-up that stalls at Gate 1,
runs long, or is abandoned half-read still has to be visible, so nothing else comes first: not the
dependencies' bodies, not the spec, not Gate 1's questions. The only thing ahead of them is §1's
blocked check, which decides whether there is a pick-up at all.

The durable "started" mark, readable from any machine and from the web, and always ahead of the
branch — so the pick-up is visible even if nothing is ever pushed.

Three marks doing three jobs, and a board needs all three: the comment says **where** the session is
and how to reach it, `in-progress` says **somebody has it**, and `intent:now` says **this is the
current work**. Leave the comment out and the machine is unrecoverable — GitHub attributes the issue
and every comment on it to whoever's token posted, which is the owner's, on a Mac and on the web
alike. **The start comment is the only place a surface or a host is ever recorded.** Nothing else on
the issue can tell a phone that claude.ai has this one.

**Work out the surface first, and measure it — never assume.** Run this before writing anything:

```sh
uname -s                                    # Darwin = a Mac. First test, and it wins.
echo "${CLAUDE_CODE_REMOTE:-}"              # true on a cloud (CCR) session
echo "${CLAUDE_CODE_ENTRYPOINT:-}"          # remote, remote_mobile, cli, local-agent, or unset
```

Take the **first** of these that matches. The order is load-bearing:

1. **`uname -s` is `Darwin` → `surface: local`.** Darwin decides, and nothing overrides it. A Mac is
   a Mac whether the keyboard is in front of it, on a phone through Remote Control, or running a
   self-hosted runner on that same machine — all three keep the work on the Mac, which is exactly
   what the `/rc` rule below says. Testing the remote variables first would label the Mac mini
   `claude.ai` on any of them.
   `host` is `hostname -s`; `link` is `http://<host>.local:8787/session/<uuid>`. The uuid is
   `CLAUDE_CODE_SESSION_ID`, or — when that is empty — the newest `*.jsonl` under
   `~/.claude/projects/` modified in the last minute, saying in the paragraph that it was inferred.
2. **`CLAUDE_CODE_REMOTE` is `true`, or `CLAUDE_CODE_ENTRYPOINT` *starts with* `remote` →
   `surface: web`, `host: claude.ai`.** *Starts with*, not equals: the entrypoint names the client,
   and measured 2026-09-16 from the iPhone app it is `remote_mobile`. `remote_desktop` and
   `remote_trigger` are others. The session id is `CLAUDE_CODE_REMOTE_SESSION_ID=cse_<id>` and the
   URL is `https://claude.ai/code/session_<id>` with the same `<id>` — verified against a live
   session. **Prefer the URL the harness supplied** in your system prompt (an attribution line
   naming `https://claude.ai/code/session_…`); only if absent, derive it by replacing `cse_` with
   `session_`, and say in the paragraph that the link was derived.
3. **Neither → stop and ask**, naming what a good answer is: which machine this is, spelled as its
   own `hostname -s` gives it, or that it is a cloud session. There are **exactly three** shapes —
   `claude.ai`, and one per Mac — so a Linux container, a devcontainer or CI is an environment
   nothing here has measured, and guessing mints a fourth the owner never had and cannot remove.
   Put the answer in the paragraph so the next session does not have to ask again.

**`CLAUDE_CODE_SESSION_ID` identifies nothing on its own.** It is populated on cloud sessions as
well as local ones (measured 2026-09-16), so a model reading it as the local branch's signature
writes `surface: local` with `host: vm` and a link to a machine that does not exist.

**If the uuid cannot be found on a Mac, do not post the comment at all.** The phone drops a start
whose `session` is missing or empty: SidePocket's `IssueParsing.swift` guards `surface` and
`session` strictly and every other key leniently, because half a start is a row claiming a session
that may not exist. A comment written without it is not a weaker mark — it is **no mark, reported as
posted**. Add `in-progress` and `intent:now`, then say plainly that the session could not be
identified, so the item shows in hand with the machine unknown and the owner knows why.

**`host` is `hostname -s` verbatim** — never a friendly name, never with `.local` appended, never
invented. A board keys the machine on that exact string, so one session writing `Simons-Mac-mini`
and another writing `mac-mini` puts the same Mac on the phone twice, under two names. The web's
`host` is always the literal `claude.ai`.

**Never mark the pick-up anywhere else** — not GitHub's Assignee field, which holds a GitHub *user*
and so can only ever name the owner's login whichever machine is working; not a plain comment, not
the title. `surface` and `host` in the block below are the only place a machine is ever recorded.

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

**A start with no `session:` value is never posted, on either surface.** The phone drops it whole
(`IssueParsing.swift` guards `surface` and a non-empty `session` strictly), so it would be no mark
wearing the appearance of one. If the id cannot be established — the Mac uuid is not discoverable,
or a cloud session carries no `CLAUDE_CODE_REMOTE_SESSION_ID` and the harness supplied no URL —
post nothing, add the two labels, and say so. That applies to every comment written from this file,
including a teleport's second one and any printed for the user to post by hand.

**The heading names the machine, not the author.** `claude.ai` for a web session, the hostname for
a local one — the same words the board uses, so the comment reads the same on a phone and on the
issue page. GitHub itself cannot help here: it attributes every issue and comment to whoever's token
posted, which is the owner's on both surfaces, so the issue page will say *saintsim* whatever
machine did the work. This line and the `yaml` block below it are the only places the real answer
is ever written down.

````markdown
<!-- sidebar:start -->
**Started** on **claude.ai** · 2026-09-09T12:04Z

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
**Started** on **Simons-Mac-mini** · 2026-09-13T19:20Z

```yaml
surface: local
session: 9f2c1e04-7a3b-4d51-8c6e-2b0f4a7d9e13
link: http://Simons-Mac-mini.local:8787/session/9f2c1e04-7a3b-4d51-8c6e-2b0f4a7d9e13
host: Simons-Mac-mini
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

Then the labels, in **one** edit. **Compose the target set from the labels you actually read** —
everything the issue carries, minus any `intent:` label it carries, plus `in-progress` and
`intent:now` — rather than sending a blind delta:

On a Mac, substitute the issue's own `intent:` labels into the remove list — and when it carries
none, **drop the `--remove-label` flag entirely** rather than passing it an empty argument:

```
gh issue edit <N> --add-label in-progress,intent:now --remove-label intent:later
gh issue edit <N> --add-label in-progress,intent:now            # carried no intent label
```

**Never name a label the issue does not carry.** `gh` resolves label names against the repo's own
list, so naming one the repo never created is expected to fail the whole command — and then **both
marks are lost together**: the comment posted, the labels not, which is the original complaint with
extra steps. (Expected, not measured — treat it as the reason for the shape rather than as an
observation.) Composing from what you read is correct either way. On the web it is safe by
construction: `issue_write` takes the whole label list, so build it from the labels read and send
that.

**A label that does not exist cannot be added either**, so create the two first on a Mac — both are
no-ops when they are already there:

```sh
gh label create intent:now --color d93f0b --description 'intent: now — in hand, hand-owned' 2>/dev/null || true
gh label create in-progress --color 0e8a16 --description 'a session has this item in hand' 2>/dev/null || true
```

The web MCP server has no label-create call: if the edit then fails for a missing label, **say which
one and ask the user to add it** rather than dropping it and leaving a start comment nothing
corroborates. An item already carrying `intent:now` needs no change to it; say so rather than
claiming an edit.

**Why `now`, when intent is hand-owned:** the hand is the one that just typed *work on #41*. The
rule being kept is that intent is never read off the code — not from a green build, a merged PR, a
passing review, or a branch that exists — and it is what leaves the rest to the owner. `next`
especially: it sequences what has **not** started, so it is never this skill's to write.

Capture the comment URL for the report.

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

**On a Mac this happens inside a worktree** — `SKILL.md`'s rule, which comes first: the main
checkout is never switched out from under a parallel session.

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
**what happens next** — on their go-ahead `/ship` opens the draft PR, `/review-loop` then reviews
what is on it, and the Delivered comment lands last; and that "don't wait for me to test" runs
straight through next time.

Do **not** run `/ship` or `/review-loop` yet — the evidence must describe the code that ships. If
the user reports a problem, fix it on the same branch, re-verify, and hand back again — the gate
repeats; the skill does not restart.

## 9. On the go-ahead — ship, review, deliver

**`/ship` runs first, then `/review-loop`.** The order is deliberate: shipping first puts the work
on a **draft** PR, so the reviewer reads the same diff a human would, the evidence and the review
both hang off something with a URL, and a session that dies mid-review leaves the code pushed rather
than stranded in a working tree. The draft PR is the point — nothing is ready for review until the
loop is clean, and nobody merges a draft.

1. **`/ship`** — re-lints, updates docs, commits, pushes and opens the **draft** PR. `/ship` §8
   owns the title (it mirrors the commit subject); do not impose one here, and never a hardcoded
   project prefix — `Sidebar:` is that repo's convention, not every repo's. The body carries **`Refs #41`** — **never `Closes`, `Fixes` or
   `Resolves`**: a merge must not close an issue; that is automation writing intent. Capture the URL.
2. **`/review-loop`** — invoke it with the **Skill** tool and let it run to a clean verdict; don't
   shortcut the loop. Scope it at the PR's own diff (`git diff origin/<default-branch>...HEAD`), and
   tell it the PR URL so its findings and the PR agree. **Each round's fixes are committed and
   pushed as that round ends**, once the repo's lint and tests pass — not saved up for the end — so
   nothing is lost if the session dies and the PR shows the loop converging. Do not run `/ship` a
   second time to do it: the PR exists, and a plain `git push` updates it. Anything the loop defers
   goes into the Delivered comment, not silently away. **Leave the PR a draft** — a clean verdict is
   not a human's approval.
3. **The Delivered comment** — what the roadmap PR used to carry, posted **after** the review's
   fixes are pushed so the evidence describes the PR's final head. The body is not rewritten.

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
   another session has started since, it holds the item now; leave the label and say so. **If there
   is no start comment at all** — the uuid could not be found at pick-up, or the item was marked by
   `/roadmap-new` with the comment left to the owner — the label is yours by elimination: this
   session did the work, so take it off and say that no comment was ever posted. Leaving it on
   strands a label nobody will ever clear. **Do not
   close the issue, and leave `intent:now` on.** Nobody has it in hand any more, but it is the work
   most recently done and the one thing waiting on the owner; the close is what settles it, and
   putting it back to `later` here would file delivered work behind work nobody has started. The
   owner reads the comment, merges the PR, and then runs **`/roadmap-done`**, which closes the issue
   once — and only once — the PR has actually merged, and clears `intent:now` on the way: the
   **closed state is what says done**, so a finished item needs no intent label and keeps none.

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

# roadmap-item — after the go-ahead

Part of the `roadmap-item` skill, read on the user's go-ahead at Gate 2 (or straight away when the
opening message waived the gate). Section numbers and `§` references continue from `SKILL.md`; the
resolution, conventions and shared-checkout rules there still apply.

## 8. On the go-ahead — review, ship, then the roadmap

1. **`/review-loop`** — invoke it with the **Skill** tool and let it run to a clean verdict; don't
   shortcut the loop. Anything it defers belongs in this project's deferred log in Open-Road, not in
   the code repo — but **don't let it open a second roadmap PR**: have it report the entries rather
   than pushing them itself, and write them onto the roadmap branch in §9, which is already opening a
   PR against Open-Road for this item.
2. **`/ship`** — it re-lints, updates docs, commits, pushes and opens the **draft** code PR. Title
   prefixed with project and item, e.g. `<Project>: RM-25 — <what it does>`. **Capture the PR URL** —
   the roadmap PR must link it.
3. **The Open-Road change** — §9. Not optional: an item without its roadmap PR is unfinished.

## 9. The Open-Road change

The **code PR merges first** — the roadmap must never claim work that isn't shipped — but both PRs are
**opened together as drafts in this session**, so the owner can merge the pair in sequence.

### Work in your own worktree, never in the shared checkout

The checkout may be occupied; `switch`ing it would move another session's HEAD mid-edit and can lose
its uncommitted work.

```sh
git -C <open-road> fetch --quiet origin
git -C <open-road> worktree add <scratch-dir>/rm-<id>-roadmap \
    -b rm-<id>-<project>-roadmap origin/<default-branch>
```

Put `<scratch-dir>` outside the repository. **Make every edit, commit and push from the worktree
path.** When the PR is open and the branch pushed:

```sh
git -C <open-road> worktree remove <scratch-dir>/rm-<id>-roadmap
```

Leave it — and say where it is — if anything is uncommitted or the push failed. **Never remove a
worktree you did not create.** If `worktree add` fails, do **not** fall back to `switch` in the shared
checkout: pick a fresh branch name and retry once; if that also fails, stop and tell the user.

**Re-read the item and project README as they stand in the worktree before editing.** It is cut from a
fetch made now, possibly hours after §2 — another session's roadmap PR may have merged in between.

Make these edits **together**:

- **`intent: done`** on the item.
- **`branches: [rm-<id>-<slug>]`** — the delivering **code** branch, not this roadmap branch.
  `SCHEMA.md` calls `branches:` assertions-only while the root `CLAUDE.md` requires recording the
  delivering branch on completion; follow `CLAUDE.md` — completed items record their branch either way.
- **Measured evidence in the item body** — the decisions taken and numbers actually measured, not
  duplicated in the code. The project's completed items are the shape. It is read months later as
  settled fact, so:
  - **Cite the file and the thing, never a line number** — a line number rots and then points
    confidently at the wrong thing.
  - **Produce the citation in the same turn as the sentence citing it** — run the command, then write
    the sentence.
  - **Record what you observed and its ordering; never name a cause you didn't observe.** "The remote
    was reset at some point after the push" is a fact; "X reset the remote" is a claim about a tool's
    behaviour a future session will rely on.
- **The project README** — flip that item's row and intent, and move it if the ordering says so. The
  table is hand-owned. Its closing prose names the current `next` and must not disagree with it.
- **Promote exactly one item to `intent: next`**, only from items whose `depends_on` are all `done`,
  and say in one line why. `blocked` is derived, never declared — never mark an item `next` while a
  dependency isn't `done`; edit the `depends_on` instead. The two exceptions — everything is `done`,
  or nothing is unblocked — must be **stated in the PR, never left as silence**.
- **Any items `/review-loop` deferred**, appended to this project's deferred log at the path
  `SCHEMA.md`'s layout names — never overwriting existing entries, and with `file:line` references
  left relative to the **code** repo, which is where that code lives. Nothing deferred, nothing to add.

Those are the **only** `intent` edits in the run — never flip an item to `now` at pick-up. `intent` is
hand-owned, never inferred from a green build, a merged PR or a passing review.

### Check it mechanically

**Run the roadmap repo's validator if one is available** — its conventions name it; some accept a
pointer to a code repo and apply `field_map`, `value_map` and `branch_pattern`.

**Point it at the roadmap directory inside your worktree.** A pointer-based invocation resolves to
whichever checkout the pointer leads to — the shared one — so it would validate the files you did
*not* edit and pass while your change is broken.

**Only write "validated" if you ran it and it passed.** If the roadmap repo's documents say no
validator exists while one plainly runs, trust what runs and tell the user those documents are stale.

Otherwise hand-check: only the frontmatter keys the schema allows; exactly one item `next` with all
its `depends_on` done; every `depends_on` id exists, no cycles; the README table matches the
frontmatter; any count stated in prose still matches the files.

**Run `/plan-review` only when the change authors or restructures the plan** — a newly written item,
a renumbering, a deliberate rework of a `depends_on` graph, or a reconciliation of the spec with what
was built. Its job is to make sure an implementing agent can build against the plan.

**Recording an item done is none of those, and never invokes it.** A done-flip clears the finished
item from its dependents' `depends_on` and reconciles the README's row, counts and prose as a matter
of course — that is bookkeeping, not restructuring, and the validator or hand-check above is its
verification. Say which of the two you judged the change to be.

### Commit and open the PR

All of this **from the worktree path**.

- Subject: `<Project>: RM-25 done — <what shipped>, and RM-26 next`. End with the same
  `Co-Authored-By:` trailer `/ship` uses.
- Stage explicitly by path — never `git add -A`.
- **Push with the branch named: `git push -u origin rm-<id>-<project>-roadmap`.** A worktree branch
  created off `origin/<default-branch>` inherits it as upstream, so a bare `git push` fails — and the
  failure *suggests* `git push origin HEAD:<default-branch>`. **Do not follow that suggestion**: it
  would push the roadmap edits onto the default branch, skipping the draft PR and landing a "done"
  claim before the code merged.
- `gh pr create --draft`, title prefixed with the project name — several projects raise PRs in
  parallel.
- The body must **say plainly that it depends on the code PR and merges after it**, and link it; state
  the promoted `next` and why, any items the review deferred, and any evidence that could not be
  measured.
- **Draft only.** Never `gh pr ready`, never `gh pr merge`. A human merges both, in order.

If the code PR changes materially in review, revisit the roadmap PR before it merges.

## Final report

Report the item and what shipped; the code branch and **draft PR URL**; the verification actually run,
with results; the review-loop verdict; the Open-Road branch and **draft PR URL**; the item promoted to
`next` and why; anything deferred or out of scope; and that **both PRs are drafts, and the code PR
merges first**. If something didn't run, say it didn't run.

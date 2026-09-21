---
name: roadmap-edit
description: Change one roadmap item — a GitHub Issue on the current code repo — exactly as the user instructs. Use when the user asks to retitle an item, rewrite a section of its body, change what it depends on, set its intent (now / next / later / idea), or close it as done or not planned — "make #41 next", "RM-27 is done", "drop #52", "#41 also depends on #39". Every change is one named edit, echoed back; intent is never inferred.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion, mcp__github__issue_read, mcp__github__issue_write, mcp__github__list_issues, mcp__github__search_issues
---

Items are GitHub Issues on the repo you are standing in (`git remote get-url origin`); `.roadmap`
must carry `kind: github-issues`, else say the repo is not on issues yet and stop. Resolve `#N`
directly; resolve `RM-NN` by searching open and closed titles for the prefix `RM-NN —` and matching
the start of the title. **Read the issue first** (`issue_read` / `gh issue view N`) and show its
number and title before changing it.

**GitHub access:** the `mcp__github__*` tools if available (the web), else `gh` on a Mac. If neither
works, **print the exact edit — field, old value, new value — and ask the user to apply it.**

## The rule

**Change only what the user asked for, in this message.** Intent is hand-owned: an `intent:` label
or a close is written only on the user's explicit instruction here. **Refuse to infer it** from a
merged PR, a green build, a passing review, a Delivered comment, or a branch that exists — if the
message does not say the state, ask, or leave it. This skill never adds or removes `in-progress`;
that is the start and ship steps' mark.

## The edits

Each is **one** `issue_write` (method `update`) or one `gh issue edit`, with the fields named, so the
conversation shows exactly what moved. Do not bundle an unrequested change into a requested one.

- **Retitle** — `title` only. Keep a migrated issue's `RM-NN — ` alias prefix unless the user asks to
  drop it; never add one to an issue that has none.
- **Rewrite a body section** — read the body, replace the one section (*Why*, *Scope*, *Done when*,
  or another the body carries) and write the whole `body` back with everything else byte-for-byte as
  it was, including the `Depends on:` line.
- **Change `Depends on:`** — the first body line, `Depends on: #12, #15`; add, remove or replace
  numbers, each confirmed to exist. Remove the line entirely when no dependency is left. Warn if the
  edit makes a cycle. `blocked` is derived from this line — never asked for as a label.
- **Set intent** — add the requested `intent:<value>` and **remove the other `intent:` labels** so
  exactly one remains; keep every non-intent label. On the web, `issue_write` takes the full label
  list, so compose it from the labels read; on a Mac:

  ```sh
  gh issue edit N --add-label intent:next --remove-label intent:now        # the ones it HAS
  gh issue edit N --add-label intent:next                                  # it had none
  ```

  **Name only the `intent:` labels the issue actually carries**, and drop `--remove-label` when it
  carries none. `gh` resolves label names against the repo's own list, so naming one the repo never
  created is expected to fail the whole command — and *nothing* changes, silently, on the skill that
  is also the documented way to repair a pick-up whose labels went wrong.

  For `next`, say if another open issue already carries `intent:next` or if a dependency is still
  open — then apply what the user said anyway; the owner's sequencing is not relitigated.
- **Close** — `state: closed` with `state_reason: completed` (done) or `not_planned` (dropped), as
  the user said; `gh issue close N --reason completed|"not planned"`. Ask if the message does not
  say which. **Reopen** only on instruction, likewise. Finishing a **delivered** item is normally
  `/roadmap-done` instead — it proves the PR merged, records the evidence and clears the working
  labels (`in-progress` and the `intent:` one); this skill's close is the blunt one, for an item
  dropped as *not planned* or done outside a PR, and it checks nothing. It also **leaves the labels
  where they are**, as every edit here does: ask for the intent label to come off too and that is
  one more named edit, echoed like the rest.
- **Milestone** — set or move to the named phase.
- **Promote an ordinary issue to a roadmap item** — add the `roadmap` label, and an `intent:` one
  in the same edit, since an item with no intent is a validation finding. This is the supported way
  a bug report already in the tracker becomes roadmap work; dropping the `roadmap` label again
  demotes it without losing the issue or its history.
- **Promote a deferred finding** — the same edit, on an issue labelled `deferred`: add `roadmap` and
  an intent, and **remove `deferred`**, since it is no longer deferred. This is what the review loop
  means when it says a finding is one edit from becoming an item — the issue number, the reviewer's
  words and the why-deferred reasoning all come with it, rather than being retyped. Only on the
  user's instruction: a deferred finding is precisely work nobody has yet decided to do.

## Report

Echo exactly what changed: issue number and title, each field, its old and new value, and the URL.
If nothing changed — the label was already there, the title already matched — say so rather than
claiming an edit.

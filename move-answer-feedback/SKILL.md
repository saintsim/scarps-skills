---
name: move-answer-feedback
description: MoveIt ecosystem — from the MoveIt-API backend, address the clients' inbound feedback and prepare replies. Run from the MoveIt-API repo. Reads the newest un-answered client feedback (iOS and/or web-desk), implements the backend changes to address the asks, and writes a dated backend-response file per client with a delivered/answered/deferred/declined status table mirroring the client's ask numbers. Leaves shipping to /ship.
user-invocable: true
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

You are the **backend** (`MoveIt-API`) responding to the clients' feedback: make the backend changes and prepare the replies. This is operation #3 of the MoveIt cross-repo feedback flow. Run this **from the `MoveIt-API` repo**.

## Conventions

- Inbound client feedback lands in **`docs/client-feedback/`** as `<YYYY-MM-DD>-<client>-<slug>.md` (client = `ios` | `web-desk`), delivered by clients via `/move-raise-feedback`.
- Backend replies you write go in the **same dir** as `<YYYY-MM-DD>-backend-response-<client>.md`. Clients read these via `/move-apply-feedback`.
- Confirm you're actually in the backend: origin `saintsim/MoveIt-API` (or the redirected old `saintsim/shipworthy-api`), Supabase migrations, `docs/client-feedback/` present. If this looks like a client repo, stop and point the user at the right skill.

## Steps

### 1. Find what's unanswered
List `docs/client-feedback/`. For each client, an inbound `…-<client>-<slug>.md` is **unanswered** if there's no later `…-backend-response-<client>.md` addressing it. Pick the newest unanswered feedback per client. If `$ARGUMENTS` names a client (`ios`/`web-desk`) or a specific file, scope to that. If nothing is unanswered, say so and stop.

Read the relevant inbound file(s) in full, plus the migration/contract docs they reference, so you understand each ask and its current state.

### 2. Address the asks in the backend
For each ask, decide and act:
- **Deliver** — implement it: a migration (follow the repo's migration numbering/conventions), a contract/`api-contract.md` update, a new field/route/limit. Keep changes scoped to the asks; don't reshape unrelated schema.
- **Answer** — where no code is owed, prepare the reasoned explanation / documentation pointer.
- **Defer** — accept but not now, by agreement; record why and what would trigger it.
- **Decline by design** — with a concrete reason.

Keep derived types, `api-contract.md`, and any docs **in sync** with schema changes (stale migration docs are a known trap). After changes, run the backend's local checks/tests so nothing is left broken. Never create git hooks.

### 3. Write the reply per client
For each client answered, write `docs/client-feedback/<YYYY-MM-DD>-backend-response-<client>.md`:
- A short dated header (who it's to, what it responds to).
- A **status table mirroring the client's ask numbers**, using the established legend: ✅ delivered · 📘 answered · ⏸️ deferred · ❌ declined by design · 🔲 open — each row's "resolved by" naming the migration/contract section or the reason.
- Any heads-up on changes you're **offering** that the client didn't ask for (logged separately, owed nothing), matching how migrations 25–27 were recorded.
- British English, house style.

### 4. Report
- Which clients you answered and the inbound files addressed.
- Backend changes made (migrations/contract/docs), grouped, with local check/test status.
- The `backend-response-<client>.md` file(s) written, with a one-line tally (delivered/answered/deferred/declined).
- **Next step for the human:** run `/ship` to open a draft PR for the backend changes + replies. The clients then pull the replies via `/move-apply-feedback`. Do not ship or merge from here.

---
name: move-apply-feedback
description: MoveIt ecosystem — pull the backend's latest reply to this client and act on it. Run from a client repo (iOS MoveIt, or the standalone web-desk app). Finds the newest backend-response file for this client in the MoveIt-API checkout, copies it into the client repo as a record, reads it, implements the code changes it now enables/requests, updates the client's scoreboard, and drafts a reply back to the backend. Leaves shipping the code changes to /ship.
user-invocable: true
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

You pull the **backend's reply to this client** and act on it. This is operation #2 of the MoveIt cross-repo feedback flow. Run this **from a client repo** (iOS `MoveIt`, or the standalone `web-desk` app).

## Repo map & conventions

Same as `move-raise-feedback`:
- **Client id** (`ios` | `web-desk`) detected from the current repo; ask if ambiguous. Stop if this is the backend repo.
- **Client feedback dir**: iOS `docs/backend-feedback/` (+ README scoreboard); web an existing feedback dir else `docs/backend-feedback/`.
- **Backend repo (`MoveIt-API`)**: `$MOVEIT_API_DIR` → sibling/`~/Documents/Programming/MoveIt-API` → search for origin `saintsim/MoveIt-API` (or the redirected old `saintsim/shipworthy-api`) → ask.
- **Backend replies** to read: `<backend>/docs/client-feedback/<YYYY-MM-DD>-backend-response-<client>.md`.

## Steps

### 1. Find the reply
In the backend checkout, list `docs/client-feedback/<date>-backend-response-<client>.md` and pick the **most recent by date**. If `$ARGUMENTS` names a specific file or date, use that. If there's no backend-response for this client, say so and stop — nothing to apply.

Confirm the chosen file to the user before acting on it.

### 2. Bring it into the client repo
Copy the reply into the client's feedback dir as a local record (e.g. `<clientDir>/<same-date>-backend-response.md`), fixing relative links so they resolve from the client repo. This keeps the correspondence with the client, mirroring the existing dated files. **Read it in full.**

### 3. Act on it
Work through the reply against the client's earlier asks:
- For each item the backend now **delivered** (a migration, a contract change, a new field/route), implement the client-side change to consume it — the code, not just the doc. Keep changes scoped to what the reply enables/requests; don't refactor beyond it.
- For items the backend **answered by documentation / deferred / declined**, make any small client adjustment implied (e.g. adopt the documented behaviour) and note it.
- Follow the project's `CLAUDE.md`/coding guidelines (British English, SwiftUI not UIKit for iOS, short methods, view previews for iOS views, etc.).
- After changes, build/test locally so nothing is left broken.

### 4. Update the scoreboard & draft the reply back
- Update the client's `README.md` scoreboard: flip each addressed ask to its new status (✅ delivered / 📘 answered / ⏸️ deferred / ❌ declined) with a one-line "resolved by" note, following the existing legend.
- Draft the client's reply back to the backend at `<clientDir>/<YYYY-MM-DD>-reply.md`: acknowledge what shipped, confirm what the client adopted, and settle or re-raise any remaining threads. Keep it in the house style and British English.

### 5. Report
- The reply file applied, and where its local copy landed.
- The client-side changes made (grouped), and build/test status.
- Scoreboard rows updated.
- The drafted reply-back file.
- **Next steps for the human:** run `/ship` to open a draft PR for the code changes; and when ready, `/move-raise-feedback` to deliver the reply-back to the backend. Do not ship or PR from here — that stays the user's call via `/ship`.

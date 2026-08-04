---
name: move-raise-feedback
description: MoveIt ecosystem — raise the current client's backend feedback and deliver it to the MoveIt-API backend. Run from a client repo (iOS MoveIt, or the standalone web-desk app). Reviews the client's integration with the backend, writes a dated feedback doc in the client's own feedback dir (updating its scoreboard), copies it into the backend's inbox on a new branch in the MoveIt-API checkout, and opens a DRAFT PR there. Never merges — human stays in the loop.
user-invocable: true
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

You raise the **current client's feedback about the backend** and deliver it to the `MoveIt-API` backend, following the established "scoreboard + dated correspondence" convention. This is operation #1 of the MoveIt cross-repo feedback flow.

Assumes the **clean 3-repo layout**: backend `MoveIt-API`, iOS client `MoveIt`, and the **standalone web-desk** client repo. Run this **from a client repo**.

## Repo map & conventions (shared across the move-*-feedback skills)

**Which client am I in?** Detect from the current git repo:
- **`ios`** — origin remote is `saintsim/MoveIt`, or an `*.xcodeproj`/`Package.swift` is present, or `docs/backend-feedback/` exists.
- **`web-desk`** — the standalone web app (Next.js / `package.json`), origin remote is the web repo, or a `client-feedback/`/`docs/backend-feedback/` dir exists.
- If it looks like the **backend** (`saintsim/MoveIt-API`, Supabase migrations, `docs/client-feedback/`), stop — this skill runs from a client, not the backend.
- If ambiguous, ask the user which client this is.

**Client's own outgoing feedback dir** (its record + scoreboard):
- iOS: `docs/backend-feedback/` (with a `README.md` scoreboard).
- web-desk: an existing feedback dir if present, else `docs/backend-feedback/` (mirror iOS, incl. a README scoreboard).

**Backend repo (`MoveIt-API`) resolution**, in order:
1. `$MOVEIT_API_DIR` if set.
2. A sibling checkout: `../MoveIt-API`, else `~/Documents/Programming/MoveIt-API`.
3. Search `~/Documents/Programming` for a git repo whose `origin` is `saintsim/MoveIt-API` (or `saintsim/shipworthy-api`, the pre-2026-08-04 name GitHub still redirects).
4. If not found, **ask the user** for the path — don't guess.

**Backend inbox** (where client feedback lands): `<backend>/docs/client-feedback/`.
- Inbound file naming: `<YYYY-MM-DD>-<client>-<slug>.md` (client = `ios` | `web-desk`).
- Backend replies (read by op #2): `<YYYY-MM-DD>-backend-response-<client>.md`.

Match the existing prose style: a short dated header banner, then asks **ranked by what they cost**, each naming the file/migration it comes from, with a one-line severity. See `docs/backend-feedback/*` (iOS) and the web-desk files for the register.

## Steps

### 1. Identify context
Resolve the client id and the client's outgoing feedback dir, and the backend repo path (per the map above). Report all three before proceeding. Confirm the backend checkout is clean-ish (`git -C <backend> status`); if it has unrelated uncommitted changes, warn the user before branching there.

### 2. Compose the feedback
Review how this client integrates with the backend — the sync/contract code it touches, recent work, and any friction or missing affordances — and write the asks. For each ask: what it is, the file/migration it comes from, a one-line **severity**, and (where relevant) how the client is working around it today. Keep it in **British English** and in the house style. Don't invent asks — ground every one in real client code.

Write it to the client's own dir: `<clientDir>/<YYYY-MM-DD>-<slug>.md` (slug e.g. `review`, `followup`, or a topic). If the client has a scoreboard `README.md`, add a row for this file and update the standings.

### 3. Deliver into the backend inbox (draft PR)
In the **backend repo** (use `git -C <backend>`):
1. Create a branch off its default branch: `feedback/<client>-<slug>-<YYYY-MM-DD>`.
2. Copy the feedback file to `<backend>/docs/client-feedback/<YYYY-MM-DD>-<client>-<slug>.md` (fix any relative links so they resolve from the backend repo).
3. Commit — subject e.g. `docs(client-feedback): <client> feedback — <topic>`; British-English body; end with:
   ```
   Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
   ```
4. Push `-u`, then open a **draft** PR in `MoveIt-API`:
   ```sh
   gh pr create --draft --base <default> --title "<title>" --body "<body>" --repo saintsim/MoveIt-API
   ```
   Body (British English): **Summary** (which client, what it needs), **Asks** (the ranked list), **Source** (link to the client's copy). End the body with:
   ```
   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   ```
   Never `gh pr ready`, never `gh pr merge`. If `gh` is missing/unauthenticated, stop and tell the user to run `! gh auth login`.

**Never create git hooks.** Never operate in a detached HEAD in either repo.

### 4. Report
- Client id + the client-side feedback file written (note it's **uncommitted** — ship it with the client's own work via `/ship`).
- The backend branch + **draft PR URL**, flagged as **awaiting the backend author's review** (they merge it in, then answer via `/move-answer-feedback`).
- Scoreboard rows added/updated.

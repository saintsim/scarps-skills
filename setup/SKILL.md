---
name: setup
description: Install every skill in the scarps-skills repo onto this machine by symlinking each skill directory into ~/.claude/skills, so all skills become available in every project. Idempotent — safe to re-run after pulling new skills; refreshes existing symlinks and never clobbers real files. Use when setting up a new machine or after adding/updating skills.
user-invocable: true
allowed-tools: Bash, Read
---

You are installing the **scarps-skills** repo onto this machine so every skill in it is available in every project. Installation = symlinking each skill directory into `~/.claude/skills/`. The repo stays the source of truth; the symlinks pick up any future edits automatically.

The repo's `install.sh` already contains the canonical symlink logic — **run it rather than re-implementing the symlinking**, so there's a single source of truth.

This skill assumes it is **run from within the checked-out repo**. The repo root is the directory containing `install.sh` and the skill directories (each with a `SKILL.md`).

## Steps

### 1. Find the repo root from the working directory

Start at the current working directory and walk up until you find the directory that contains `install.sh` next to `*/SKILL.md` — that's the repo root. Usually it's just the cwd:
```sh
dir="$PWD"
while [ "$dir" != "/" ]; do
  if [ -f "$dir/install.sh" ] && ls "$dir"/*/SKILL.md >/dev/null 2>&1; then
    echo "repo root: $dir"; break
  fi
  dir="$(dirname "$dir")"
done
```
If no repo root is found, tell the user to run `/setup` from inside their `scarps-skills` checkout — don't guess a path.

### 2. Run the installer

From the repo root:
```sh
./install.sh   # or: bash install.sh  if it isn't executable
```
This symlinks every `*/SKILL.md` skill directory into `~/.claude/skills/`, refreshing existing symlinks and skipping (with a warning) any path that already exists as a real file/directory.

### 3. Report

From the installer's output, tell the user:
- Skills **linked** (new) and **updated** (refreshed symlinks).
- Anything **skipped** because a non-symlink already occupied the target — so they can resolve the conflict manually.
- The final `~/.claude/skills/` contents, so they can see everything that's now available.

#!/usr/bin/env bash
# Does this repo opt in to having a session mark its reviewed PR ready for review?
#
#   bash ready-check-opt-in.sh        (run anywhere inside the checkout)
#
# Read by review-loop/SKILL.md (*Ready for review*). Both answers come from the freshly fetched
# default branch, never the working tree: the opt-in is the owner's decision about the repo, and a
# session's own branch adding the line must not opt itself in. `.roadmap` is YAML with comments, so
# the value is read the way YAML would read it — quotes, a trailing comment, tabs, CRLF and leading
# space all allowed — rather than by an exact-line match that fails silently.
#
# Prints one first line and exits with its code; anything after it is detail for the report:
#   OPTED_IN       0  `verify: ready-for-review`, and a workflow mentions ready_for_review;
#                     the candidate workflow files follow, to be read for their trigger
#   NOT_OPTED_IN   1  no .roadmap on the default branch, or no `verify:` line in it
#   UNRECOGNISED   2  a `verify:` line with another value, or a `Verify:`-style key; it follows
#   NO_WORKFLOW    3  opted in, but no workflow on the default branch mentions ready_for_review
#   NO_BASE        4  no origin, no default branch resolved, or the fetch failed
set -uo pipefail

top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "NO_BASE not inside a git checkout"; exit 4; }
cd "$top" || exit 4

base=$(git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p')
[ -n "$base" ] && [ "$base" != "(unknown)" ] || { echo "NO_BASE no default branch on origin"; exit 4; }
git fetch origin "$base" --quiet 2>/dev/null || { echo "NO_BASE fetch of origin/$base failed"; exit 4; }

# Found case-insensitively so `Verify:` is reported rather than silently ignored; YAML keys are
# case-sensitive, so only `verify` itself opts in.
line=$(git show "origin/$base:.roadmap" 2>/dev/null | tr -d '\r' |
  grep -iE '^[[:space:]]*verify[[:space:]]*:' | head -n 1)
[ -n "$line" ] || { echo "NOT_OPTED_IN"; exit 1; }
grep -qE '^[[:space:]]*verify[[:space:]]*:' <<<"$line" || { echo "UNRECOGNISED"; echo "$line"; exit 2; }
value=$(sed -E "s/^[^:]*:[[:space:]]*//; s/(^|[[:space:]]+)#.*\$//; s/^[\"']//; s/[\"'][[:space:]]*\$//; s/[[:space:]]+\$//" <<<"$line")
[ -n "$value" ] || { echo "NOT_OPTED_IN"; exit 1; }
[ "$value" = "ready-for-review" ] || { echo "UNRECOGNISED"; echo "$value"; exit 2; }

# `:/` anchors the pathspec at the top, whatever directory the caller is in.
files=$(git grep -l 'ready_for_review' "origin/$base" -- ':/.github/workflows/' 2>/dev/null |
  sed "s|^origin/$base:||")
[ -n "$files" ] || { echo "NO_WORKFLOW"; exit 3; }
echo "OPTED_IN"; echo "$files"; exit 0

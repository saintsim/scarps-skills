#!/usr/bin/env bash
# Wait for the workflow runs a "ready for review" event started on one commit, within a bound.
#
#   watch-check.sh <owner>/<repo> <head-sha> <since: UTC ISO 8601, when the PR was marked ready>
#
# Read by review-loop/SKILL.md (*Ready for review*). It polls GitHub's REST API through `gh api`,
# which answered from a cloud session on 2026-11-14 where `gh pr ready` and `gh pr view` were
# refused (HTTP 403, GraphQL) — so one script waits on a Mac and in the cloud, without depending on
# which of gh's own commands use GraphQL. Run it as a background command: it exits by itself, at
# the latest when the bound passes.
#
# Prints one final line and exits with its code:
#   SUCCESS  0  every run concluded success (or neutral/skipped)
#   FAILURE  1  at least one run concluded otherwise; the failed run ids follow
#   NO_RUN   2  no run started on this commit within the start window
#   TIMEOUT  3  runs started but had not all concluded when the bound passed
#   ERROR    4  bad arguments, or `gh api` kept failing
set -uo pipefail

repo=${1:-} sha=${2:-} since=${3:-}
[ -n "$repo" ] && [ -n "$sha" ] && [ -n "$since" ] || { echo "ERROR usage: $0 owner/repo sha since"; exit 4; }

interval=${WATCH_INTERVAL:-60}        # seconds between polls
start_window=${WATCH_START_WINDOW:-300}   # a run must have appeared by then
bound=${WATCH_BOUND:-3600}            # 60 minutes from marking ready

# Only runs a PR event started, after the mark: an earlier push run on the same sha is not the check.
filter='[.workflow_runs[]
         | select(.event == "pull_request" or .event == "pull_request_target")
         | select(.created_at >= $since)]'

elapsed=0 failures=0 read_once=0
while :; do
  if raw=$(gh api "repos/$repo/actions/runs?head_sha=$sha&per_page=50" 2>/dev/null) &&
     runs=$(jq -c --arg since "$since" "$filter" <<<"$raw"); then
    failures=0 read_once=1
    count=$(jq 'length' <<<"$runs")
    if [ "$count" -gt 0 ] && [ "$(jq '[.[] | select(.status != "completed")] | length' <<<"$runs")" -eq 0 ]; then
      bad=$(jq -r '[.[] | select(.conclusion != "success" and .conclusion != "neutral"
                                and .conclusion != "skipped")] | map("\(.id) \(.html_url)") | .[]' <<<"$runs")
      jq -r '.[] | "run \(.id) \(.name): \(.conclusion) \(.html_url)"' <<<"$runs"
      if [ -z "$bad" ]; then echo "SUCCESS"; exit 0; fi
      echo "FAILURE"; echo "$bad"; exit 1
    fi
    if [ "$count" -eq 0 ] && [ "$elapsed" -ge "$start_window" ]; then echo "NO_RUN"; exit 2; fi
  else
    failures=$((failures + 1))
    [ "$failures" -ge 5 ] && { echo "ERROR gh api failed five times running"; exit 4; }
  fi
  if [ "$elapsed" -ge "$bound" ]; then
    [ "$read_once" -eq 1 ] || { echo "ERROR gh api never answered"; exit 4; }
    jq -r '.[] | "run \(.id) \(.name): \(.status) \(.html_url)"' <<<"${runs:-[]}" 2>/dev/null
    echo "TIMEOUT"; exit 3
  fi
  sleep "$interval"; elapsed=$((elapsed + interval))
done

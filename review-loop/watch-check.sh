#!/usr/bin/env bash
# Wait for the workflow runs a "ready for review" event started on one commit, within a bound.
#
#   bash watch-check.sh <owner>/<repo> <head-sha> <since: UTC, YYYY-MM-DDTHH:MM:SSZ, when marked ready>
#
# Read by review-loop/SKILL.md (*Ready for review*). It polls GitHub's REST API through `gh api`,
# which answered from a cloud session on 2026-11-14 where `gh pr ready` and `gh pr view` were
# refused (HTTP 403, GraphQL). It needs only `gh` and awk: the filtering runs in gh's own `--jq`,
# so no standalone jq is assumed. Run it as a background command with a timeout above the bound.
#
# Prints the runs, then one final line, and exits with its code:
#   SUCCESS  0  every run concluded success (or neutral/skipped)
#   FAILURE  1  a run concluded otherwise — reported as soon as one does, even with others pending
#   NO_RUN   2  no run started on this commit within the start window
#   TIMEOUT  3  runs started, none has failed, but not all had concluded when the bound passed
#   ERROR    4  bad arguments, no gh, or `gh api` kept failing; the cause follows
set -uo pipefail

repo=${1:-} sha=${2:-} since=${3:-}
[[ $repo == */* && $sha =~ ^[0-9a-f]{40}$ && $since =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] ||
  { echo "ERROR usage: watch-check.sh owner/repo <full 40-character sha> <YYYY-MM-DDTHH:MM:SSZ>"; exit 4; }
command -v gh >/dev/null 2>&1 || { echo "ERROR gh is not installed"; exit 4; }

interval=${WATCH_INTERVAL:-60}            # seconds between polls
start_window=${WATCH_START_WINDOW:-300}   # a run must have appeared by then
bound=${WATCH_BOUND:-3600}                # 60 minutes from marking ready

# Only runs a PR event started after the mark — an earlier push run on the same sha is not the
# check — with two minutes' margin, in case this machine's clock runs ahead of GitHub's. `since`
# is validated above, so splicing it into the filter is safe.
filter='.workflow_runs[]
  | select(.event == "pull_request" or .event == "pull_request_target")
  | select((.created_at | fromdate) >= ("'"$since"'" | fromdate) - 120)
  | [.id, .name, .status, (.conclusion // "-"), .html_url] | @tsv'

elapsed=0 failures=0 read_once=0 runs='' last_err=''
# stderr kept apart: a notice from gh on a successful call must not read as a run.
errfile=$(mktemp) || { echo "ERROR mktemp failed"; exit 4; }
trap 'rm -f "$errfile"' EXIT
while :; do
  if runs=$(gh api "repos/$repo/actions/runs?head_sha=$sha&per_page=50" --jq "$filter" 2>"$errfile"); then
    failures=0 read_once=1
    # A run is bad once completed with anything but success, neutral or skipped.
    bad=$(awk -F'\t' '$3 == "completed" && $4 != "success" && $4 != "neutral" && $4 != "skipped"' <<<"$runs")
    pending=$(awk -F'\t' 'NF && $3 != "completed"' <<<"$runs")
    if [ -n "$bad" ]; then
      awk -F'\t' 'NF {print "run " $1 " " $2 ": " $3 "/" $4 " " $5}' <<<"$runs"
      echo "FAILURE"; awk -F'\t' '{print $1 " " $5}' <<<"$bad"; exit 1
    fi
    if [ -n "$runs" ] && [ -z "$pending" ]; then
      awk -F'\t' 'NF {print "run " $1 " " $2 ": " $4 " " $5}' <<<"$runs"
      echo "SUCCESS"; exit 0
    fi
    if [ -z "$runs" ] && [ "$elapsed" -ge "$start_window" ]; then echo "NO_RUN"; exit 2; fi
  else
    failures=$((failures + 1))
    # The last line: gh prints its own notices before the error, not after.
    last_err=$(tail -n 1 "$errfile") runs=''
    [ "$failures" -ge 5 ] && { echo "ERROR gh api failed five times running: $last_err"; exit 4; }
  fi
  if [ "$elapsed" -ge "$bound" ]; then
    [ "$read_once" -eq 1 ] || { echo "ERROR gh api never answered: $last_err"; exit 4; }
    awk -F'\t' 'NF {print "run " $1 " " $2 ": " $3 " " $5}' <<<"$runs"
    echo "TIMEOUT"; exit 3
  fi
  sleep "$interval"; elapsed=$((elapsed + interval))
done

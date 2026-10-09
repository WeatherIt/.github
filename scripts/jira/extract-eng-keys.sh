#!/usr/bin/env bash
# Print the ENG ticket keys a merged PR delivers, one per line, sorted and unique.
#
# Usage: extract-eng-keys.sh "<pr title>" "<head branch>" < commit-subjects.txt
#
# A key counts only where our convention puts it on purpose:
#   - the PR title starts with it              "ENG-123: ..."  or "ENG-123 ..."
#   - the head branch starts with it            "ENG-123-short-name"
#   - a commit subject starts with it           "ENG-123: ..."
#   - a merge-commit subject names such a branch "Merge pull request #82 from WeatherIt/ENG-123-..."
# A key mentioned in passing ("relates to ENG-229", "see ENG-229") is NOT delivered and is
# ignored, so a release PR never closes a ticket it merely references.
set -euo pipefail

title="${1:-}"
branch="${2:-}"

{
  printf '%s\n' "$title"  | grep -oE '^[[:space:]]*ENG-[0-9]+'                     || true
  printf '%s\n' "$branch" | grep -oE '^ENG-[0-9]+'                                 || true
  while IFS= read -r subject || [ -n "$subject" ]; do
    printf '%s\n' "$subject" | grep -oE '^[[:space:]]*ENG-[0-9]+[: ]'             || true
    printf '%s\n' "$subject" | grep -oE '^Merge pull request #[0-9]+ from [^/[:space:]]+/ENG-[0-9]+' || true
  done
} | grep -oE 'ENG-[0-9]+' | sort -t- -k2,2n -u

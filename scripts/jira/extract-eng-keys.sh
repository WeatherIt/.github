#!/usr/bin/env bash
# Print the ENG ticket keys a merged PR delivers, one per line, sorted and unique.
#
# Usage: extract-eng-keys.sh "<pr title>" "<head branch>" ["<pr body>"] < commit-subjects.txt
#
# A key counts only where our convention puts it on purpose:
#   - the PR title starts with it              "ENG-123: ..."  or "ENG-123 ..."
#   - the PR title's Conventional Commits scope "feat(ENG-123): ..." / "fix(ENG-1, ENG-2)!: ..."
#   - the head branch starts with it            "ENG-123-short-name"
#   - a commit subject starts with it           "ENG-123: ..."
#   - a commit subject's Conventional scope     "feat(ENG-123): ..." (ENG-543)
#   - a merge-commit subject names such a branch "Merge pull request #82 from WeatherIt/ENG-123-..."
# A key mentioned in passing ("relates to ENG-229", "see ENG-229", "release: x (ENG-229)",
# "docs(api): ENG-229 ...") is NOT delivered and is ignored, so a release PR never closes a
# ticket it merely references.
#
# Opt-out for tickets that ship in stages: a PR body line starting "Jira-Keep-Open:" lists keys
# to leave open even though the PR delivers them, e.g. "Jira-Keep-Open: ENG-486, ENG-525".
set -euo pipefail

title="${1:-}"
branch="${2:-}"
body="${3:-}"

# Scope holding only ENG keys: "(ENG-1)", "(ENG-1, ENG-2)", then an optional "!" and the colon.
scope='^[a-z]+\(ENG-[0-9]+(,[[:space:]]*ENG-[0-9]+)*\)!?:'

delivered() {
  printf '%s\n' "$title"  | grep -oE '^[[:space:]]*ENG-[0-9]+'                     || true
  printf '%s\n' "$title"  | grep -oE "$scope"                                      || true
  printf '%s\n' "$branch" | grep -oE '^ENG-[0-9]+'                                 || true
  while IFS= read -r subject || [ -n "$subject" ]; do
    printf '%s\n' "$subject" | grep -oE '^[[:space:]]*ENG-[0-9]+[: ]'             || true
    printf '%s\n' "$subject" | grep -oE "$scope"                                   || true
    printf '%s\n' "$subject" | grep -oE '^Merge pull request #[0-9]+ from [^/[:space:]]+/ENG-[0-9]+' || true
  done
}

keep_open() {
  printf '%s\n' "$body" | tr -d '\r' | grep -iE '^[[:space:]]*jira-keep-open:' \
    | grep -oE 'ENG-[0-9]+' || true
}

keep="$(keep_open)"
# "|| true": under pipefail a PR with no keys would otherwise exit 1 and fail the caller's step.
{ delivered | grep -oE 'ENG-[0-9]+' || true; } | sort -t- -k2,2n -u | while IFS= read -r key; do
  # Whole-line match, so keeping ENG-1 open never holds back ENG-12.
  if [ -n "$keep" ] && printf '%s\n' "$keep" | grep -qxF "$key"; then continue; fi
  printf '%s\n' "$key"
done

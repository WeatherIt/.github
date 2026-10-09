#!/usr/bin/env bash
# Move each ENG key given on stdin to Done, with a comment linking the merged PR.
#
# Env: JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN, PR_URL, PR_NUMBER, REPO, MERGE_SHA
#      DRY_RUN=1 to report what would happen without writing to Jira.
# Fail-soft by design: the PR is already merged, so a Jira problem is reported (job summary
# + ::warning::) and never fails the job. Exit code is always 0.
set -uo pipefail

: "${JIRA_BASE_URL:=https://weatherit.atlassian.net}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

if [ -z "${JIRA_EMAIL:-}" ] || [ -z "${JIRA_API_TOKEN:-}" ]; then
  echo "::warning::JIRA_EMAIL / JIRA_API_TOKEN not set for ${REPO:-this repo}; no tickets moved. Add them as repo or org secrets."
  echo "Jira: secrets missing, no tickets moved." >> "$SUMMARY"
  exit 0
fi

jira() { curl -sS --fail-with-body -u "$JIRA_EMAIL:$JIRA_API_TOKEN" -H 'Content-Type: application/json' -H 'Accept: application/json' "$@"; }

comment_body() { # ADF: "Delivered to production by <PR link> (<repo>@<sha7>)."
  jq -n --arg url "$PR_URL" --arg n "#$PR_NUMBER" --arg ref "$REPO@${MERGE_SHA:0:7}" '{
    body: {type:"doc", version:1, content:[{type:"paragraph", content:[
      {type:"text", text:"Delivered to production: "},
      {type:"text", text:$n, marks:[{type:"link", attrs:{href:$url}}]},
      {type:"text", text:(" merged to main (" + $ref + "). Moved to Done automatically by the Jira-done-on-main workflow.")}
    ]}]}}'
}

echo "### Jira: tickets delivered by ${REPO} #${PR_NUMBER}" >> "$SUMMARY"
found=0
while IFS= read -r key; do
  [ -z "$key" ] && continue
  found=1
  if ! issue="$(jira "$JIRA_BASE_URL/rest/api/3/issue/$key?fields=status" 2>&1)"; then
    echo "::warning::$key: could not read issue ($issue)"; echo "- $key: could not read (skipped)" >> "$SUMMARY"; continue
  fi
  status="$(jq -r '.fields.status.name' <<<"$issue")"
  category="$(jq -r '.fields.status.statusCategory.key' <<<"$issue")"
  if [ "$category" = "done" ]; then
    echo "- $key: already $status (no change)" >> "$SUMMARY"; continue
  fi
  transitions="$(jira "$JIRA_BASE_URL/rest/api/3/issue/$key/transitions" 2>&1)" || {
    echo "::warning::$key: could not list transitions"; echo "- $key: could not list transitions (skipped)" >> "$SUMMARY"; continue; }
  tid="$(jq -r '[.transitions[] | select(.to.name=="Done")][0].id // empty' <<<"$transitions")"
  if [ -z "$tid" ]; then
    echo "::warning::$key: no transition to Done available from $status"; echo "- $key: no Done transition from $status (skipped)" >> "$SUMMARY"; continue
  fi
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "- $key: would move $status → Done (dry run)" >> "$SUMMARY"; continue
  fi
  if jira -X POST "$JIRA_BASE_URL/rest/api/3/issue/$key/transitions" -d "{\"transition\":{\"id\":\"$tid\"}}" >/dev/null 2>&1; then
    jira -X POST "$JIRA_BASE_URL/rest/api/3/issue/$key/comment" -d "$(comment_body)" >/dev/null 2>&1 \
      || echo "::warning::$key: moved to Done but the comment failed"
    echo "- $key: $status → **Done**" >> "$SUMMARY"
  else
    echo "::warning::$key: transition to Done failed"; echo "- $key: transition failed" >> "$SUMMARY"
  fi
done
[ "$found" = 0 ] && echo "- no ENG keys delivered by this PR" >> "$SUMMARY"
exit 0

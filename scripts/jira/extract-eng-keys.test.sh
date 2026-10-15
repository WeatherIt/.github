#!/usr/bin/env bash
# Tests for extract-eng-keys.sh. Run: bash scripts/jira/extract-eng-keys.test.sh
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
x="$here/extract-eng-keys.sh"
fail=0

check() { # name, expected (space-separated), title, branch, subjects (newline-separated), [pr body]
  local name="$1" expected="$2" got
  got="$(printf '%s' "$5" | bash "$x" "$3" "$4" "${6:-}" | tr '\n' ' ' | sed 's/ $//')"
  if [ "$got" = "$expected" ]; then echo "ok   $name"; else echo "FAIL $name: expected [$expected] got [$got]"; fail=1; fi
}

check "feature PR: title + branch"          "ENG-365" \
  "ENG-365: fetch stamp_duty_amount" "ENG-365-quote-premiums-stamp-duty" "ENG-365: fetch stamp_duty_amount"

check "release PR: keys from commit subjects" "ENG-120 ENG-365 ENG-376" \
  "Release sandbox -> main" "sandbox" $'ENG-365: fetch stamp_duty_amount\nENG-376: promotion gate\nchore: bump deps\nENG-120 seed fix'

check "release PR: keys from merge-commit branch names" "ENG-333 ENG-376" \
  "Release" "sandbox" $'Merge pull request #615 from WeatherIt/ENG-376-promotion-gate\nMerge pull request #99 from WeatherIt/ENG-333-era5\nMerge pull request #80 from WeatherIt/dependabot/npm'

check "passing mention is ignored"           "" \
  "Release" "sandbox" $'fix: tidy footer (relates to ENG-229)\ndocs: see ENG-364 for context\nfeat: ENG-999 in the middle'

check "lower-case and other projects ignored" "" \
  "eng-12: lower" "feature/ENG-12-not-a-prefix" $'OPS-5: other project\neng-7: lower'

check "dedupe and numeric sort"              "ENG-9 ENG-80 ENG-365" \
  "ENG-365: x" "ENG-80-y" $'ENG-9: a\nENG-365: b\nENG-80: c'

check "no trailing newline on last subject"  "ENG-1" \
  "chore" "main" "ENG-1: last line without newline"

check "empty everything"                     "" "" "" ""

# --- Conventional Commits scopes (ENG-543) ---

check "conventional title scope"             "ENG-486" \
  "feat(ENG-486): partner-collected weather" "feature/partner-collected" ""

check "conventional subject scopes, all types" "ENG-493 ENG-523 ENG-533" \
  "release: x" "Sandbox" $'fix(ENG-493): voucher defaults (#1176)\nfeat(ENG-523): optional last name\ntest(ENG-533): pin fixture'

check "multi-key scope"                       "ENG-406 ENG-432" \
  "feat(ENG-432, ENG-406): two tickets" "main" ""

check "multi-key scope without space"         "ENG-1 ENG-2" \
  "chore" "main" "fix(ENG-1,ENG-2): tight"

check "breaking-change marker"                "ENG-1" \
  "chore" "main" "feat(ENG-1)!: drop v1 route"

check "key in parentheses later in a title is ignored" "" \
  "release: RoomStay + Daydream (ENG-486), AU state (ENG-472)" "Sandbox" ""

check "non-ENG scope with a key in the subject is ignored" "" \
  "chore" "main" $'docs(api): ENG-482 type TemplateMessage\nchore(sdk): ENG-472 regenerate types\nfeat(sdk): bump'

check "scope must be keys only"               "" \
  "chore" "main" $'fix(ENG-472, sdk): mixed scope\nfix(xENG-1): prefix\nfix(ENG-1 foo): trailing'

# The 18 commit subjects of Supabase-Production release #1174 (2026-10-15), which the old
# extractor reduced to ENG-472 ENG-481.
release_1174=$'ENG-481: regenerate seed.sql for the Learn more template fixes (#1171)
docs(api): ENG-482 type TemplateMessage.content as the real plainLanguage object (#1172)
chore(sdk): ENG-482 prepare @weatherit/node 1.1.0 (#1173)
feat(ENG-486): partner-collected weather is a receivable until banked (#1175)
fix(ENG-486): payable read keys on the per-leg payout item, not policy status (#1177)
fix(ENG-472): require a valid state for AUS quotes so stamp duty is charged
chore(sdk): ENG-472 regenerate types \u2014 location.state optional in requests
Merge pull request #1179 from WeatherIt/ENG-472-au-state-required
feat(ENG-486): partner remittance invoice claim, premium_collected_by, credit leg (#1180)
fix(ENG-486): payable read recovers partner-funded credits on all sales (#1181)
fix(ENG-493): partners voucher columns no longer default to a live 15% Gift Card (#1176)
fix(ENG-523): make customer last name optional at purchase (#1182)
fix(ENG-525): API responses agree with stored quote/policy data (#1183)
test(ENG-533): pin KPI fixture quotes to noon Sydney (#1184)
fix(ENG-532): GET /policies rounds daily_premium to the cent (#1185)
Merge pull request #1170 from WeatherIt/fix/au-portal-partners
chore: bump deps
Merge branch \'Sandbox\' into main'

check "release #1174 replay"                  "ENG-472 ENG-481 ENG-486 ENG-493 ENG-523 ENG-525 ENG-532 ENG-533" \
  "release: RoomStay + Daydream partner-collected (ENG-486), AU state required (ENG-472)" "Sandbox" "$release_1174"

# --- Jira-Keep-Open opt-out in the PR body (ENG-543) ---

check "keep-open drops a key"                 "ENG-472 ENG-481 ENG-493 ENG-523 ENG-525 ENG-532 ENG-533" \
  "release: x" "Sandbox" "$release_1174" $'## Why\nShips the DB side.\n\nJira-Keep-Open: ENG-486\n'

check "keep-open: several keys, commas, spaces, any case" "ENG-481 ENG-493 ENG-523 ENG-532 ENG-533" \
  "release: x" "Sandbox" "$release_1174" $'jira-keep-open: ENG-486, ENG-525 ENG-472'

check "keep-open: several lines, CRLF body"   "ENG-2" \
  "chore" "main" $'ENG-1: a\nENG-2: b\nENG-3: c' $'Jira-Keep-Open: ENG-1\r\nJira-Keep-Open: ENG-3\r\n'

check "keep-open must start the line"         "ENG-1" \
  "chore" "main" "ENG-1: a" "Do not add Jira-Keep-Open: ENG-1 unless staged"

check "keep-open does not match a longer key" "ENG-12" \
  "chore" "main" "ENG-12: a" "Jira-Keep-Open: ENG-1"

check "keep-open for a key not delivered is harmless" "ENG-1" \
  "chore" "main" "ENG-1: a" "Jira-Keep-Open: ENG-99"

check "body mentions do not add keys"         "" \
  "chore" "main" "" $'ENG-471, ENG-472, ENG-481\nfeat(ENG-9): in the body'

# A PR with no keys must exit 0: the workflow step runs under `bash -e`, so exit 1 failed the
# job on every keyless merge to main (pipefail + grep finding nothing).
if printf 'chore: bump deps' | bash "$x" "chore: deps" "dependabot/npm" "" >/dev/null; then
  echo "ok   no keys exits 0"; else echo "FAIL no keys exits 0: exit $?"; fail=1; fi

exit $fail

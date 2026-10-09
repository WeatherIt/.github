#!/usr/bin/env bash
# Tests for extract-eng-keys.sh. Run: bash scripts/jira/extract-eng-keys.test.sh
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
x="$here/extract-eng-keys.sh"
fail=0

check() { # name, expected (space-separated), title, branch, subjects (newline-separated)
  local name="$1" expected="$2" got
  got="$(printf '%s' "$5" | bash "$x" "$3" "$4" | tr '\n' ' ' | sed 's/ $//')"
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

exit $fail

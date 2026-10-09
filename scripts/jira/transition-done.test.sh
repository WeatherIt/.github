#!/usr/bin/env bash
# Tests for transition-done.sh against a fake `curl` on PATH. No network, no real Jira.
# Run: bash scripts/jira/transition-done.test.sh
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail=0

# Fake Jira: ENG-1 In Review (Done transition 61), ENG-2 already Done, ENG-3 has no Done transition,
# ENG-4 does not exist. Every POST is appended to $tmp/posts.
cat > "$tmp/curl" <<'EOF'
#!/usr/bin/env bash
url=""; method=GET; for a in "$@"; do case "$a" in http*) url="$a";; POST) method=POST;; esac; done
if [ "$method" = POST ]; then echo "$url" >> "$FAKE_DIR/posts"; echo '{}'; exit 0; fi
case "$url" in
  */ENG-1\?fields=status) echo '{"fields":{"status":{"name":"In Review","statusCategory":{"key":"indeterminate"}}}}';;
  */ENG-2\?fields=status) echo '{"fields":{"status":{"name":"Done","statusCategory":{"key":"done"}}}}';;
  */ENG-3\?fields=status) echo '{"fields":{"status":{"name":"Triage","statusCategory":{"key":"new"}}}}';;
  */ENG-1/transitions)    echo '{"transitions":[{"id":"31","to":{"name":"Ready"}},{"id":"61","to":{"name":"Done"}}]}';;
  */ENG-3/transitions)    echo '{"transitions":[{"id":"31","to":{"name":"Ready"}}]}';;
  *) echo '{"errorMessages":["Issue does not exist"]}'; exit 22;;
esac
EOF
chmod +x "$tmp/curl"

run() { # DRY_RUN, keys...
  local dry="$1"; shift; : > "$tmp/posts"; : > "$tmp/summary"
  printf '%s\n' "$@" | env PATH="$tmp:$PATH" FAKE_DIR="$tmp" GITHUB_STEP_SUMMARY="$tmp/summary" \
    JIRA_EMAIL=x JIRA_API_TOKEN=y PR_URL=https://example/pr/1 PR_NUMBER=1 REPO=WeatherIt/demo MERGE_SHA=abcdef1234 \
    DRY_RUN="$dry" bash "$here/transition-done.sh" > "$tmp/stdout" 2>&1
  echo $?
}
assert() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

rc="$(run 0 ENG-1 ENG-2 ENG-3 ENG-4)"
assert "always exits 0"                       '[ "$rc" = 0 ]'
assert "ENG-1 transitioned with id 61"         'grep -q "ENG-1/transitions" "$tmp/posts"'
assert "ENG-1 commented"                       'grep -q "ENG-1/comment" "$tmp/posts"'
assert "ENG-2 already Done: untouched"         '! grep -q "ENG-2/" "$tmp/posts" && grep -q "ENG-2: already Done" "$tmp/summary"'
assert "ENG-3 no Done transition: skipped"     '! grep -q "ENG-3/" "$tmp/posts" && grep -q "ENG-3: no Done transition" "$tmp/summary"'
assert "ENG-4 missing: warned, skipped"        '! grep -q "ENG-4/" "$tmp/posts" && grep -q "ENG-4: could not read" "$tmp/summary"'
assert "exactly two writes (ENG-1 only)"       '[ "$(wc -l < "$tmp/posts" | tr -d " ")" = 2 ]'

rc="$(run 1 ENG-1)"
assert "dry run writes nothing"                '[ ! -s "$tmp/posts" ] && grep -q "would move In Review" "$tmp/summary"'

: > "$tmp/summary"
printf 'ENG-1\n' | env PATH="$tmp:$PATH" FAKE_DIR="$tmp" GITHUB_STEP_SUMMARY="$tmp/summary" JIRA_EMAIL= JIRA_API_TOKEN= REPO=r \
  bash "$here/transition-done.sh" > "$tmp/stdout" 2>&1; rc=$?
assert "missing secrets: warns, exits 0"       '[ "$rc" = 0 ] && grep -q "secrets missing" "$tmp/summary"'

rc="$(run 0)"
assert "no keys: says so"                      'grep -q "no ENG keys" "$tmp/summary"'

exit $fail

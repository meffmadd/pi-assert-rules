#!/bin/sh
# ↔ rules/general.json
# Covers:
#   - write-only-md      (tool_call, grep on MINIFIED PI_TOOL_INPUT)
#   - edit-only-md       (tool_call, grep on MINIFIED PI_TOOL_INPUT, filter toolName=edit)
#   - no-env-access      (tool_call, `when` guards on PI_TOOL_NAME → skip path)
#   - read-max-*-chars   (tool_result, ${#PI_TOOL_RESULT} boundary off-by-one)
#
# PI_TOOL_INPUT is minified JSON in production (JSON.stringify). The grep
# asserts match `"path":"…"` literally, so inputs here are minified to mirror
# reality — a spaced variant would be a different (invalid) test.

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$TEST_DIR
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/rules" ]; do
  REPO_ROOT=$(CDPATH= cd -- "$REPO_ROOT/.." && pwd)
done
TARGET=rules/general.json
. "$REPO_ROOT/tests/helpers/harness.sh"

printf -- '--- write-only-md (tool_call, filter toolName=write)\n'
tc write-only-md 0 write '{"path":"README.md"}'
tc write-only-md 0 write '{"path":"docs/sub/a.md"}'
tc write-only-md 1 write '{"path":"notes.txt"}'
tc write-only-md 1 write '{"path":"image.png"}'

printf -- '--- edit-only-md (tool_call, filter toolName=edit)
'
tc edit-only-md 0 edit '{"path":"README.md"}'
tc edit-only-md 0 edit '{"path":"docs/sub/a.md"}'
tc edit-only-md 1 edit '{"path":"notes.txt"}'
tc edit-only-md 1 edit '{"path":"image.png"}'

printf -- '--- no-env-access (`when` fires only for read/write → test the skip path too)\n'
tc no-env-access 1 read  '{"path":".env"}'
tc no-env-access 0 read  '{"path":"README.md"}'
tc no-env-access 1 write '{"path":"config/.env"}'
# .env must be a path segment, not a substring — env.ts has no ".env"
tc no-env-access 0 read  '{"path":"env.ts"}'
# non read/write tool → `when` fails → assert SKIPPED (counts as skip, not fail)
tc no-env-access 0 bash  '{"command":"cat .env"}'

# Boundary matrix: at-limit must PASS (exit 0); limit+1 must BLOCK (exit 1).
_boundary() {
  # $1 assert name, $2 limit
  r=$(printf '%*s' "$2" '');      tr "$1" 0 read '{"path":"x"}' "$r"   # exact limit → 0
  r=$(printf '%*s' "$(($2 + 1))" ''); tr "$1" 1 read '{"path":"x"}' "$r"   # limit+1 → 1
}

printf -- '--- read-max-*-chars (tool_result boundaries, ${#PI_TOOL_RESULT})\n'
_boundary read-max-500-chars      500
_boundary read-max-10000-chars   10000
_boundary read-max-20000-chars   20000
_boundary read-max-50000-chars   50000
_boundary read-max-100000-chars  100000
_boundary read-max-200000-chars  200000
_boundary read-max-500000-chars  500000

printf -- '--- no-env-secrets-in-output (tool_result, parse .env → grep -F -f on PI_TOOL_RESULT)
'
# This assert reads .env relative to PI_CWD. Each case runs in a throwaway dir
# with a known .env; the trailing cwd arg points the harness at it (it cd-s there
# for BOTH `when` and `shell`, mirroring pi-assert's real runtime). The helper
# `setenv` rewrites $ENVFIX/.env between groups so each case is self-contained.
ENVFIX=$(mktemp -d "${TMPDIR:-/tmp}/par-env.XXXXXX")
NOENVFIX=$(mktemp -d "${TMPDIR:-/tmp}/par-noenv.XXXXXX")
trap 'rm -rf "$ENVFIX" "$NOENVFIX"' EXIT INT TERM
setenv() { printf '%s\n' "$1" > "$ENVFIX/.env"; }

# --- core: unquoted value, name contains 'key' → block when leaked ---
setenv 'API_KEY=sk-live-1234567890abcdef'
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'resp: sk-live-1234567890abcdef here' "$ENVFIX"
tr no-env-secrets-in-output 0 read  '{"path":"x"}' 'nothing sensitive here' "$ENVFIX"
# substring within a larger word still matches (grep -F, no word boundaries)
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'xxsk-live-1234567890abcdefyy' "$ENVFIX"
# secret at start and at end of result
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'sk-live-1234567890abcdef is first' "$ENVFIX"
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'last is sk-live-1234567890abcdef' "$ENVFIX"

# --- double-quoted value, `export` prefix, name has 'secret' ---
setenv 'export SECRET_TOKEN="supersecret-value-99"'
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'leaked supersecret-value-99 !!' "$ENVFIX"

# --- single-quoted value ---
setenv "client_secret='opaque-client-secret-xx'"
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'opaque-client-secret-xx in output' "$ENVFIX"

# --- var name without key/secret → value NOT collected → allow ---
setenv 'DATABASE_URL=postgres://should-not-match-1234'
tr no-env-secrets-in-output 0 read  '{"path":"x"}' 'postgres://should-not-match-1234' "$ENVFIX"

# --- short value (len < 8) skipped → no false positive on common words ---
setenv 'DEBUG_KEY=true'
tr no-env-secrets-in-output 0 read  '{"path":"x"}' 'the flag returned true' "$ENVFIX"
setenv 'KEY=1234567'           # 7 chars → below floor
tr no-env-secrets-in-output 0 read  '{"path":"x"}' 'value 1234567 shown' "$ENVFIX"

# --- length-floor boundary: exactly 8 → matched (block); 7 → not (allow) ---
setenv 'KEY=12345678'          # 8 chars → matched
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'id=12345678' "$ENVFIX"

# --- comments and blank lines ignored ---
setenv '# API_KEY=secretvalue1234
API_KEY=realvalue1234'
tr no-env-secrets-in-output 0 read  '{"path":"x"}' 'commented secretvalue1234 leaked' "$ENVFIX"
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'realvalue1234 leaked' "$ENVFIX"

# --- empty .env → when passes, no patterns → allow ---
setenv ''
tr no-env-secrets-in-output 0 read  '{"path":"x"}' 'anything at all' "$ENVFIX"

# --- .env with only comments → allow ---
setenv '# just a comment
# SECRET_KEY=topsecret1234'
tr no-env-secrets-in-output 0 read  '{"path":"x"}' 'topsecret1234 appeared' "$ENVFIX"

# --- trailing whitespace after unquoted value is stripped ---
setenv 'API_KEY=trailval1234   '
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'found trailval1234 here' "$ENVFIX"

# --- trailing whitespace after closing quote is stripped ---
setenv 'API_KEY="quotetrail12"  '
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'quotetrail12 here' "$ENVFIX"

# --- spaces around `=` are tolerated ---
setenv 'API_KEY = spacedval123'
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'spacedval123 here' "$ENVFIX"

# --- leading whitespace before an unquoted value is stripped ---
setenv 'API_KEY=   leadval12345'
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'leadval12345 here' "$ENVFIX"

# --- value with internal `=` (split on first `=`) ---
setenv 'API_KEY=abc=def12345'
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'val abc=def12345 here' "$ENVFIX"

# --- value with internal spaces (quoted) ---
setenv 'API_KEY="a secret with spaces12"'
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'got a secret with spaces12 ok' "$ENVFIX"

# --- regex metacharacters matched literally (grep -F) ---
setenv 'API_KEY=sk-.*+?()special'
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'token sk-.*+?()special here' "$ENVFIX"

# --- case-insensitive name match ---
setenv 'api_key=lowercasekey1
Api-Key=mixedcasekey1'
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'lowercasekey1 here' "$ENVFIX"
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'mixedcasekey1 here' "$ENVFIX"

# --- substring name match (per spec): NOT_A_SECRET contains 'secret' ---
setenv 'NOT_A_SECRET=ignoredvalue12'
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'ignoredvalue12 appears' "$ENVFIX"

# --- multiple secrets, any one leaked → block ---
setenv 'API_KEY=aaa-secret-111
OTHER_SECRET=bbb-secret-222'
tr no-env-secrets-in-output 1 read  '{"path":"x"}' 'bbb-secret-222 found' "$ENVFIX"

# --- leaks via bash tool too: no filter → any tool's result is checked ---
setenv 'API_KEY=bashleak123456'
tr no-env-secrets-in-output 1 bash '{"command":"env"}' 'API_KEY=bashleak123456' "$ENVFIX"

# --- `when` guard: no .env in cwd → assert SKIPPED (counts as skip ⊘) ---
tr no-env-secrets-in-output 0 read  '{"path":"x"}' 'sk-live-1234567890abcdef' "$NOENVFIX"

summary
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

summary
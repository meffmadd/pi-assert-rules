#!/bin/sh
# tests/helpers/run.sh — discover and run every *.test.sh under tests/, plus the
# optional ajv schema validation. Exits non-zero on any failure.
#
# Each test file computes its own REPO_ROOT from $0, so it can also be run
# standalone:
#   sh tests/bash-deny/git.test.sh

# This script lives in tests/helpers/. The tests/ directory is its parent, and
# the repo root is one level above that.
HELPERS_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TESTS_DIR=$(CDPATH= cd -- "$HELPERS_DIR/.." && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TESTS_DIR/.." && pwd)
export REPO_ROOT

status=0
printf '== pi-assert-rules test suite ==\n'

# Optional schema validation (node + ajv). Skipped silently if either is absent.
if command -v node >/dev/null 2>&1 && [ -f "$TESTS_DIR/schema.test.mjs" ]; then
  printf '\n[ schema.test.mjs ]\n'
  node "$TESTS_DIR/schema.test.mjs" "$REPO_ROOT" || status=1
else
  printf '\n[ schema.test.mjs ]  skipped (node not found)\n'
fi

# Run every *.test.sh (deterministic order).
for t in $(find "$TESTS_DIR" -name '*.test.sh' -type f | sort); do
  name=${t#"$TESTS_DIR/"}
  printf '\n[ %s ]\n' "$name"
  /bin/sh "$t" || status=1
done

printf '\n== done ==\n'
exit "$status"
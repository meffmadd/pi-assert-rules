#!/bin/sh
# ↔ rules/bash-deny/gh.json

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$TEST_DIR
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/rules" ]; do
  REPO_ROOT=$(CDPATH= cd -- "$REPO_ROOT/.." && pwd)
done
TARGET=rules/bash-deny/gh.json
. "$REPO_ROOT/tests/helpers/harness.sh"

command -v bash-deny >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || {
  printf '  %b✗%b FAIL: bash-deny and jq must be on PATH to run these tests\n' "$C_BAD" "$C_N"
  exit 1
}

printf -- '--- destructive gh subcommands\n'
tc deny-gh-repo-delete 1 bash '{"command":"gh repo delete owner/repo --yes","timeout":30}'
tc deny-gh-pr-merge 1 bash '{"command":"gh pr merge 42 --merge","timeout":30}'
tc deny-gh-release-delete 1 bash '{"command":"gh release delete v1.0.0 --yes","timeout":30}'
tc deny-gh-repo-delete 1 bash '{"command":"sudo gh repo delete owner/repo --yes","timeout":30}'
tc deny-gh-repo-delete 0 bash '{"command":"gh repo view owner/repo","timeout":30}'
tc deny-gh-pr-merge 0 bash '{"command":"gh pr view 42","timeout":30}'

printf -- '--- destructive gh api requests\n'
tc deny-gh-api-delete 1 bash '{"command":"gh api --method DELETE repos/owner/repo","timeout":30}'
tc deny-gh-api-delete-long-equals 1 bash '{"command":"gh api repos/owner/repo --method=DELETE","timeout":30}'
tc deny-gh-api-delete-short 1 bash '{"command":"gh api -X DELETE repos/owner/repo","timeout":30}'
tc deny-gh-api-delete-short-equals 1 bash '{"command":"gh api repos/owner/repo -X=DELETE","timeout":30}'
tc deny-gh-api-delete 0 bash '{"command":"gh api --method GET repos/owner/repo","timeout":30}'
tc deny-gh-api-delete-long-equals 0 bash '{"command":"gh api --method=GET repos/owner/repo","timeout":30}'
tc deny-gh-api-delete-short 0 bash '{"command":"gh api -X GET repos/owner/repo","timeout":30}'
tc deny-gh-api-delete-short-equals 0 bash '{"command":"gh api -X=GET repos/owner/repo","timeout":30}'

printf -- '--- deny-gh-destructive preset\n'
if jq -e '
  .["deny-gh-destructive"].preset == [
    "meffmadd/pi-assert-rules/deny-gh-repo-delete",
    "meffmadd/pi-assert-rules/deny-gh-pr-merge",
    "meffmadd/pi-assert-rules/deny-gh-release-delete",
    "meffmadd/pi-assert-rules/deny-gh-api-delete",
    "meffmadd/pi-assert-rules/deny-gh-api-delete-long-equals",
    "meffmadd/pi-assert-rules/deny-gh-api-delete-short",
    "meffmadd/pi-assert-rules/deny-gh-api-delete-short-equals"
  ]
' "$TARGET" >/dev/null 2>&1; then
  PASSED=$((PASSED+1)); printf '  %b✓%b deny-gh-destructive (preset)\n' "$C_OK" "$C_N"
else
  FAILED=$((FAILED+1)); printf '  %b✗%b deny-gh-destructive (preset)\n' "$C_BAD" "$C_N"
fi

summary

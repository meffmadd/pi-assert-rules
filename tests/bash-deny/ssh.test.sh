#!/bin/sh
# ↔ rules/bash-deny/ssh.json

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$TEST_DIR
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/rules" ]; do
  REPO_ROOT=$(CDPATH= cd -- "$REPO_ROOT/.." && pwd)
done
TARGET=rules/bash-deny/ssh.json
. "$REPO_ROOT/tests/helpers/harness.sh"

command -v bash-deny >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || {
  printf '  %b✗%b FAIL: bash-deny and jq must be on PATH to run these tests\n' "$C_BAD" "$C_N"
  exit 1
}

printf -- '--- deny-ssh (bare command and remote connections)\n'
tc deny-ssh 1 bash '{"command":"ssh","timeout":30}'
tc deny-ssh 1 bash '{"command":"ssh user@example.com","timeout":30}'
tc deny-ssh 1 bash '{"command":"ssh -i ~/.ssh/id_ed25519 user@example.com uname -a","timeout":30}'
tc deny-ssh 1 bash '{"command":"sudo ssh user@example.com","timeout":30}'
tc deny-ssh 0 bash '{"command":"ssh-keygen -t ed25519","timeout":30}'
tc deny-ssh 0 bash '{"command":"git status","timeout":30}'

summary

#!/bin/sh
# ↔ rules/typescript/knip.json   (hook=agent_end)
#
# These asserts shell out to `knip` (an external binary) at agent_end. Without a
# fixture project there's nothing to analyse → knip (if installed) reports an
# error; if absent, /bin/sh exits 127. Either way the assert FAILS CLOSED (any
# non-zero) — a non-zero exit blocks the agent from going idle and triggers a
# new turn, the desired behaviour. We assert "NZ" (any non-zero) for that
# contract.
#
# A full behaviour test (assert success when knip finds zero issues on a real
# fixture project) is TODO pending a fixtures/typescript/ project.

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$TEST_DIR
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/rules" ]; do
  REPO_ROOT=$(CDPATH= cd -- "$REPO_ROOT/.." && pwd)
done
TARGET=rules/typescript/knip.json
. "$REPO_ROOT/tests/helpers/harness.sh"

# Run from an empty cwd so there's no package.json/tsconfig → knip (if
# installed) reports a config error; if absent, /bin/sh exits 127.
FIX=$(mktemp -d "${TMPDIR:-/tmp}/par-knip.XXXXXX")
trap 'rm -rf "$FIX"' EXIT INT TERM

printf -- '--- knip-run (fails closed without a fixture project)\n'
ae knip-run NZ "$FIX"

summary
#!/bin/sh
# ↔ rules/python/pre-commit.json   (hook=agent_end)
#
# These asserts shell out to `pre-commit` (an external binary) at agent_end.
# Without a fixture project (.pre-commit-config.yaml) they must FAIL CLOSED:
# a non-zero exit blocks the agent from going idle and triggers a new turn —
# the desired behaviour. We assert "NZ" (any non-zero) for that contract.
#
# A full behaviour test (assert success when pre-commit passes on a real
# fixture project) is TODO pending a fixtures/python/ project.

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$TEST_DIR
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/rules" ]; do
  REPO_ROOT=$(CDPATH= cd -- "$REPO_ROOT/.." && pwd)
done
TARGET=rules/python/pre-commit.json
. "$REPO_ROOT/tests/helpers/harness.sh"

# Run from an empty cwd so there's no .pre-commit-config.yaml → pre-commit
# (if installed) reports "no hooks"/config error; if absent, /bin/sh exits 127.
FIX=$(mktemp -d "${TMPDIR:-/tmp}/par-pc.XXXXXX")
trap 'rm -rf "$FIX"' EXIT INT TERM

printf -- '--- pre-commit-run-all-files (fails closed without a fixture project)\n'
ae pre-commit-run-all-files NZ "$FIX"

printf -- '--- pre-commit-run (fails closed without a fixture project)\n'
ae pre-commit-run NZ "$FIX"

summary
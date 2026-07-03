#!/bin/sh
# ↔ rules/typescript/npm.json   (hook=agent_end)
#
# These asserts shell out to `npm` (an external binary) at agent_end. Without a
# passing npm script they must FAIL CLOSED: a non-zero exit blocks the agent from
# going idle and triggers a new turn — the desired behaviour. We assert "NZ" (any
# non-zero) for that contract.
#
# Unlike knip/pre-commit, npm walks UP the directory tree for a package.json, so
# an empty cwd could resolve a parent project's package.json and accidentally
# pass. We therefore pin npm to a fixture package.json with an empty `scripts`
# map: every call reports a missing script and exits 1 (deterministic, no
# walk-up). If npm itself is absent, /bin/sh exits 127 — still NZ.
#
# A full behaviour test (assert success when npm scripts pass on a real fixture
# project) is TODO pending a fixtures/typescript/ project.

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$TEST_DIR
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/rules" ]; do
  REPO_ROOT=$(CDPATH= cd -- "$REPO_ROOT/.." && pwd)
done
TARGET=rules/typescript/npm.json
. "$REPO_ROOT/tests/helpers/harness.sh"

# Fixture project: a package.json with no scripts, so every npm call fails
# closed with a clean "missing script" / "no test specified" exit 1.
FIX=$(mktemp -d "${TMPDIR:-/tmp}/par-npm.XXXXXX")
trap 'rm -rf "$FIX"' EXIT INT TERM
printf '{"name":"par-npm-fixture","version":"0.0.0","scripts":{}}' > "$FIX/package.json"

printf -- '--- npm-test (fails closed with no test script)\n'
ae npm-test NZ "$FIX"

printf -- '--- npm-lint (fails closed with no lint script)\n'
ae npm-lint NZ "$FIX"

printf -- '--- npm-build (fails closed with no build script)\n'
ae npm-build NZ "$FIX"

printf -- '--- npm-typecheck (fails closed with no typecheck script)\n'
ae npm-typecheck NZ "$FIX"

summary

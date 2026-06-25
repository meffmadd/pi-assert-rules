#!/bin/sh
# ↔ rules/python/django/general.json   (hook=agent_end)
#
# Asserts shell out to `python manage.py test`. Without a fixture project
# (no manage.py) the shell exits non-zero → fails closed (blocks idle,
# triggers a new turn). We assert "NZ" for that contract. Full behaviour
# test against a real Django app is TODO pending fixtures/python/django/.

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$TEST_DIR
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/rules" ]; do
  REPO_ROOT=$(CDPATH= cd -- "$REPO_ROOT/.." && pwd)
done
TARGET=rules/python/django/general.json
. "$REPO_ROOT/tests/helpers/harness.sh"

FIX=$(mktemp -d "${TMPDIR:-/tmp}/par-dj.XXXXXX")
trap 'rm -rf "$FIX"' EXIT INT TERM

printf -- '--- django-tests (fails closed without manage.py)\n'
ae django-tests NZ "$FIX"

summary
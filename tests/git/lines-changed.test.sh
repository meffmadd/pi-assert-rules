#!/bin/sh
# ↔ rules/git/lines-changed.json   (hook=agent_end)
#
# These asserts inspect the working tree via `git diff HEAD --numstat` plus
# untracked-file line counts, so each case drives a throwaway fixture repo to
# a known diff state and runs the assert with PI_CWD pointed at it.
#
# Exit semantics for agent_end: 0 = accept (agent may go idle), non-zero =
# block → triggers a new turn. So "block" cases expect exit 1 (assert detected
# a violation); "accept" cases expect 0.

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$TEST_DIR
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/rules" ]; do
  REPO_ROOT=$(CDPATH= cd -- "$REPO_ROOT/.." && pwd)
done
TARGET=rules/git/lines-changed.json
. "$REPO_ROOT/tests/helpers/harness.sh"
. "$REPO_ROOT/tests/helpers/fixture-repo.sh"

FIX=$(mktemp -d "${TMPDIR:-/tmp}/par-lc.XXXXXX")
trap 'rm -rf "$FIX"' EXIT INT TERM

BASELINE=100   # base.txt has 100 lines committed

# --- require-no-change -------------------------------------------------------
mkrepo "$FIX/r0" "$BASELINE"
ae require-no-change 0 "$FIX/r0"          # clean tree → accept
add_lines "$FIX/r0" base.txt 5 "$((BASELINE+1))"
ae require-no-change 1 "$FIX/r0"          # dirty → block

# --- diff-max-10-lines (clean boundary at 10) -------------------------------
mkrepo "$FIX/r10" "$BASELINE"
add_lines "$FIX/r10" base.txt 10 "$((BASELINE+1))"
ae diff-max-10-lines 0 "$FIX/r10"         # exactly 10 → accept
add_lines "$FIX/r10" base.txt 1 "$((BASELINE+11))"
ae diff-max-10-lines 1 "$FIX/r10"         # 11 → block

# --- diff-max-50-lines -------------------------------------------------------
mkrepo "$FIX/r50" "$BASELINE"
add_lines "$FIX/r50" base.txt 50 "$((BASELINE+1))"
ae diff-max-50-lines 0 "$FIX/r50"
add_lines "$FIX/r50" base.txt 1 "$((BASELINE+51))"
ae diff-max-50-lines 1 "$FIX/r50"

# --- diff-max-100 / 250 / 500 / 1000 / 2000 / 5000 (single accept + block) ---
# For each, exactly N added → accept; N+1 added → block.
_for_each_max() {
  n=$1
  mkrepo "$FIX/m$n" "$BASELINE"
  add_lines "$FIX/m$n" base.txt "$n" "$((BASELINE+1))"
  ae "diff-max-$n-lines" 0 "$FIX/m$n"
  add_lines "$FIX/m$n" base.txt 1 "$((BASELINE+n+1))"
  ae "diff-max-$n-lines" 1 "$FIX/m$n"
}
_for_each_max 100
_for_each_max 250
_for_each_max 500
_for_each_max 1000
_for_each_max 2000
_for_each_max 5000

# --- require-more-deletions -------------------------------------------------
# deletions > additions → accept; additions >= deletions → block.
mkrepo "$FIX/del" "$BASELINE"
del_lines "$FIX/del" base.txt 5              # 0 added, 5 deleted → 0<5 → accept
ae require-more-deletions 0 "$FIX/del"

mkrepo "$FIX/del2" "$BASELINE"
del_lines "$FIX/del2" base.txt 3
add_lines "$FIX/del2" base.txt 5 "$((BASELINE-3+1))"   # 5 added, 3 deleted → 5<3 false → block
ae require-more-deletions 1 "$FIX/del2"

mkrepo "$FIX/del3" "$BASELINE"
del_lines "$FIX/del3" base.txt 5
add_lines "$FIX/del3" base.txt 5 "$((BASELINE-5+1))"   # equal → 5<5 false → block
ae require-more-deletions 1 "$FIX/del3"

summary
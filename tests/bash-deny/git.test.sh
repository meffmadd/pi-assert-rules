#!/bin/sh
# ↔ rules/bash-deny/git.json
# Covers: block + allow, wrapper-awareness (sudo/env unwrapping), compound
# commands (&& ;), and the intent splits (git reset --soft vs --hard;
# git branch -d vs -D). Cases match the hand-verified matrix.
#
# Skips the whole file when bash-deny or jq aren't on PATH (the rules need
# the deps to run their checks).

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$TEST_DIR
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/rules" ]; do
  REPO_ROOT=$(CDPATH= cd -- "$REPO_ROOT/.." && pwd)
done
TARGET=rules/bash-deny/git.json
. "$REPO_ROOT/tests/helpers/harness.sh"

# Skip the whole file when bash-deny or jq aren't on PATH (the rules need
# the deps to run their checks).
command -v bash-deny >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || {
  printf '  %b⊘%b skipped (bash-deny/jq not on PATH)\n\n' "$C_SK" "$C_N"
  exit 0
}

printf -- '--- deny-git-external\n'
tc deny-git-external 1 bash '{"command":"git -C ../repo log","timeout":30}'
tc deny-git-external 1 bash '{"command":"git -C","timeout":30}'
tc deny-git-external 1 bash '{"command":"git -C /repo","timeout":30}'
tc deny-git-external 1 bash '{"command":"sudo git -C /repo log","timeout":30}'
tc deny-git-external 0 bash '{"command":"git status","timeout":30}'

printf -- '--- deny-git-commit\n'
tc deny-git-commit 1 bash '{"command":"git commit -m wip","timeout":30}'
tc deny-git-commit 1 bash '{"command":"git commit --amend","timeout":30}'
tc deny-git-commit 1 bash '{"command":"sudo git commit -m x","timeout":30}'
tc deny-git-commit 0 bash '{"command":"git status","timeout":30}'

printf -- '--- deny-git-push\n'
tc deny-git-push 1 bash '{"command":"git push origin main","timeout":30}'
tc deny-git-push 1 bash '{"command":"sudo git push origin main","timeout":30}'
tc deny-git-push 1 bash '{"command":"env git push origin main","timeout":30}'
tc deny-git-push 1 bash '{"command":"echo safe && git push origin main","timeout":30}'
tc deny-git-push 1 bash '{"command":"git status; git push origin main","timeout":30}'
tc deny-git-push 0 bash '{"command":"git status","timeout":30}'
tc deny-git-push 0 bash '{"command":"sudo git status","timeout":30}'
tc deny-git-push 0 bash '{"command":"echo safe && git status","timeout":30}'

printf -- '--- deny-git-history-rewrite\n'
tc deny-git-history-rewrite 1 bash '{"command":"git reset --hard HEAD~3","timeout":30}'
tc deny-git-history-rewrite 1 bash '{"command":"git rebase main","timeout":30}'
tc deny-git-history-rewrite 1 bash '{"command":"git reset --hard","timeout":30}'
tc deny-git-history-rewrite 0 bash '{"command":"git reset --soft HEAD~3","timeout":30}'
tc deny-git-history-rewrite 0 bash '{"command":"git reset HEAD~3","timeout":30}'
tc deny-git-history-rewrite 0 bash '{"command":"git status","timeout":30}'

printf -- '--- deny-git-destructive\n'
tc deny-git-destructive 1 bash '{"command":"git clean -fd","timeout":30}'
tc deny-git-destructive 1 bash '{"command":"git branch -D feature","timeout":30}'
tc deny-git-destructive 1 bash '{"command":"git stash drop","timeout":30}'
tc deny-git-destructive 1 bash '{"command":"git stash clear","timeout":30}'
tc deny-git-destructive 1 bash '{"command":"git checkout -- file","timeout":30}'
tc deny-git-destructive 1 bash '{"command":"sudo git clean -fd","timeout":30}'
tc deny-git-destructive 0 bash '{"command":"git branch -d feature","timeout":30}'
tc deny-git-destructive 0 bash '{"command":"git stash list","timeout":30}'
tc deny-git-destructive 0 bash '{"command":"git status","timeout":30}'

summary
#!/bin/sh
# ↔ skills/bash-deny-subcommands/
# Tests discovery plus generation from both discovered subcommands and curated
# manifests. Curated manifests are the committed-rule workflow: they support
# nested commands, flag-specific patterns, mixed command families, explicit
# names/descriptions, and direct-member pi-assert presets.

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$TEST_DIR
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/rules" ]; do
  REPO_ROOT=$(CDPATH= cd -- "$REPO_ROOT/.." && pwd)
done
SKILL="$REPO_ROOT/skills/bash-deny-subcommands"
SUBS="$SKILL/scripts/subcommands.sh"
GEN="$SKILL/scripts/gen-rules.sh"

PASSED=0; FAILED=0
if [ -t 1 ]; then C_OK='\033[32m'; C_BAD='\033[31m'; C_N='\033[0m'; else C_OK=''; C_BAD=''; C_N=''; fi
ok()  { PASSED=$((PASSED+1)); printf '  %b✓%b %s\n' "$C_OK"  "$C_N" "$1"; }
bad() { FAILED=$((FAILED+1)); printf '  %b✗%b %s\n' "$C_BAD" "$C_N" "$1"; }
command -v bash-deny >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || {
  printf '  %b✗%b FAIL: bash-deny and jq must be on PATH to run these tests\n' "$C_BAD" "$C_N"
  exit 1
}
command -v git >/dev/null 2>&1 || {
  printf '  %b✗%b FAIL: git must be on PATH\n' "$C_BAD" "$C_N"
  exit 1
}

TMP=$(mktemp -d "${TMPDIR:-/tmp}/bash-deny-skill.XXXXXX")
trap 'rm -rf "$TMP"' EXIT INT TERM HUP

# --- discovery and original output modes ---
out=$("$SUBS" git)
EXPECT_LABEL="subcommands.sh git: sorted, unique, includes commit and push"
if [ -n "$out" ] && printf '%s\n' "$out" | grep -qx commit &&
   printf '%s\n' "$out" | grep -qx push &&
   [ "$out" = "$(printf '%s\n' "$out" | sort -u)" ]; then ok "$EXPECT_LABEL"; else bad "$EXPECT_LABEL"; fi

out=$("$GEN" git --bashdeny)
EXPECT_LABEL="discovery --bashdeny emits git commit and git push"
if printf '%s\n' "$out" | grep -qx 'git commit' && printf '%s\n' "$out" | grep -qx 'git push'; then ok "$EXPECT_LABEL"; else bad "$EXPECT_LABEL"; fi

out=$("$GEN" git --inline)
EXPECT_LABEL="discovery --inline blocks git commit and allows echo"
if ! bash-deny -r "$out" -i 'git commit -m x' -q && bash-deny -r "$out" -i 'echo hello' -q; then ok "$EXPECT_LABEL"; else bad "$EXPECT_LABEL"; fi

# --- curated, command-relative manifest ---
# Fields are selector<TAB>optional-name<TAB>optional-description.
printf '%s\n' \
  '# narrow Git policy' \
  'commit' \
  'reset --hard	deny-git-reset-hard	Blocks hard resets while allowing soft resets.' \
  'git stash drop' \
  > "$TMP/git-dangerous.txt"

out=$("$GEN" git --input "$TMP/git-dangerous.txt" --bashdeny)
EXPECT_LABEL="relative manifest prefixes selectors but preserves full git patterns"
if [ "$out" = "git commit
git reset --hard
git stash drop" ]; then ok "$EXPECT_LABEL"; else bad "$EXPECT_LABEL"; fi

out=$("$GEN" git --input "$TMP/git-dangerous.txt" --asserts \
  --preset deny-git-dangerous --source meffmadd/pi-assert-rules \
  --preset-description 'Blocks selected destructive Git operations.')
printf '%s\n' "$out" > "$TMP/git.json"
EXPECT_LABEL="--asserts emits three atomic guards and one direct-member preset"
if jq -e '
  (keys | sort) == ["deny-git-commit", "deny-git-dangerous", "deny-git-reset-hard", "deny-git-stash-drop"]
  and .["deny-git-dangerous"] == {
    description: "Blocks selected destructive Git operations.",
    preset: [
      "meffmadd/pi-assert-rules/deny-git-commit",
      "meffmadd/pi-assert-rules/deny-git-reset-hard",
      "meffmadd/pi-assert-rules/deny-git-stash-drop"
    ]
  }
  and ([.[] | select(has("shell"))] | length) == 3
  and ([.[] | select(has("shell"))] | all(.[]; .hook == "tool_call" and .filter.toolName == "bash"))
' "$TMP/git.json" >/dev/null 2>&1; then ok "$EXPECT_LABEL"; else bad "$EXPECT_LABEL"; fi

shell=$(jq -r '."deny-git-reset-hard".shell' "$TMP/git.json")
EXPECT_LABEL="explicitly named atomic guard blocks hard reset but permits soft reset"
if ! PI_TOOL_INPUT='{"command":"git reset --hard HEAD~1"}' /bin/sh -c "$shell" >/dev/null 2>&1 &&
   PI_TOOL_INPUT='{"command":"git reset --soft HEAD~1"}' /bin/sh -c "$shell" >/dev/null 2>&1; then ok "$EXPECT_LABEL"; else bad "$EXPECT_LABEL"; fi

# --- full-pattern, mixed-command manifest ---
printf '%s\n' \
  'curl' \
  'wget' \
  'helm plugin install	deny-helm-plugin-install	Blocks Helm plugin installation.' \
  > "$TMP/mixed.txt"
out=$("$GEN" --input "$TMP/mixed.txt" --asserts --preset deny-network-and-plugin --source local)
printf '%s\n' "$out" > "$TMP/mixed.json"
EXPECT_LABEL="mixed manifest preserves bare, nested, and explicitly named patterns"
if jq -e '
  .["deny-network-and-plugin"].preset == [
    "local/deny-curl",
    "local/deny-wget",
    "local/deny-helm-plugin-install"
  ]
  and (."deny-curl".shell | contains("bash-deny -r '\''curl'\''"))
  and (."deny-helm-plugin-install".description == "Blocks Helm plugin installation.")
' "$TMP/mixed.json" >/dev/null 2>&1; then ok "$EXPECT_LABEL"; else bad "$EXPECT_LABEL"; fi

shell=$(jq -r '."deny-helm-plugin-install".shell' "$TMP/mixed.json")
EXPECT_LABEL="mixed nested-command guard blocks install but allows plugin list"
if ! PI_TOOL_INPUT='{"command":"helm plugin install x"}' /bin/sh -c "$shell" >/dev/null 2>&1 &&
   PI_TOOL_INPUT='{"command":"helm plugin list"}' /bin/sh -c "$shell" >/dev/null 2>&1; then ok "$EXPECT_LABEL"; else bad "$EXPECT_LABEL"; fi

# stdin is useful for one-off, diverse command sets.
out=$(printf '%s\n' 'docker run' 'kubectl exec' | "$GEN" --input - --inline)
EXPECT_LABEL="stdin full-pattern input supports diverse commands"
if [ "$out" = 'docker run;kubectl exec' ]; then ok "$EXPECT_LABEL"; else bad "$EXPECT_LABEL"; fi

# Fail closed on ambiguous/invalid generator requests instead of silently
# overwriting a JSON object or accepting a misspelled output mode.
printf '%s\n' 'one	duplicate' 'two	duplicate' > "$TMP/duplicate.txt"
EXPECT_LABEL="duplicate explicit assertion names fail generation"
if "$GEN" --input "$TMP/duplicate.txt" --asserts >/dev/null 2>&1; then bad "$EXPECT_LABEL"; else ok "$EXPECT_LABEL"; fi
EXPECT_LABEL="preset requires a source"
if "$GEN" git --input "$TMP/git-dangerous.txt" --asserts --preset bundle >/dev/null 2>&1; then bad "$EXPECT_LABEL"; else ok "$EXPECT_LABEL"; fi
EXPECT_LABEL="unknown options fail generation"
if "$GEN" git --not-a-mode >/dev/null 2>&1; then bad "$EXPECT_LABEL"; else ok "$EXPECT_LABEL"; fi

printf '\n  %b%d passed%b, %b%d failed%b\n' "$C_OK" "$PASSED" "$C_N" "$C_BAD" "$FAILED" "$C_N"
[ "$FAILED" -eq 0 ]

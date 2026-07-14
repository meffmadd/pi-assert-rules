#!/bin/sh
# ↔ rules/pi-tools.json
# Covers the seven built-in pi tools (read, bash, edit, write, grep, find, ls).
# Each block-<tool> assert unconditionally runs `false` (exit 1) under a
# tool_call filter, so it blocks regardless of input. One case per assert is
# sufficient — `false` ignores PI_TOOL_INPUT — but inputs mirror each tool's
# expected shape for documentation honesty.
#
# Note: the harness runs the assert's `shell` with PI_TOOL_NAME from the tc
# args; it does NOT evaluate the `filter` field (filtering is pi-assert's job
# at runtime). These cases therefore verify the shell exits 1, not filter
# matching.

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$TEST_DIR
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/rules" ]; do
  REPO_ROOT=$(CDPATH= cd -- "$REPO_ROOT/.." && pwd)
done
TARGET=rules/pi-tools.json
. "$REPO_ROOT/tests/helpers/harness.sh"

printf -- '--- block-read (unconditional, toolName=read)\n'
tc block-read 1 read '{"path":"README.md"}'

printf -- '--- block-bash (unconditional, toolName=bash)\n'
tc block-bash 1 bash '{"command":"echo hi"}'

printf -- '--- block-edit (unconditional, toolName=edit)\n'
tc block-edit 1 edit '{"path":"README.md","edits":[{"oldText":"a","newText":"b"}]}'

printf -- '--- block-write (unconditional, toolName=write)\n'
tc block-write 1 write '{"path":"README.md","content":"x"}'

printf -- '--- block-grep (unconditional, toolName=grep)\n'
tc block-grep 1 grep '{"pattern":"foo","path":"."}'

printf -- '--- block-find (unconditional, toolName=find)\n'
tc block-find 1 find '{"path":"."}'

printf -- '--- block-ls (unconditional, toolName=ls)\n'
tc block-ls 1 ls '{"path":"."}'

# read-only is a preset (no shell/hook), so the harness can't execute it —
# pi-assert expands it to its member asserts at runtime via activeList().
# Verify its contract instead: it bundles exactly block-bash + block-write +
# block-edit (all defined in this file, so it installs non-dangling, no § badge)
# and carries no shell/hook.
printf -- '--- read-only (preset: block-bash + block-write + block-edit)\n'
if jq -e '
  .["read-only"].preset
    == ["meffmadd/pi-assert-rules/block-bash",
        "meffmadd/pi-assert-rules/block-write",
        "meffmadd/pi-assert-rules/block-edit"]
  and (.["read-only"].shell // null | not)
  and (.["read-only"].hook // null | not)
' "$TARGET" >/dev/null 2>&1; then
  PASSED=$((PASSED+1)); printf '  %b✓%b read-only (preset)\n' "$C_OK" "$C_N"
else
  FAILED=$((FAILED+1)); printf '  %b✗%b read-only (preset)\n' "$C_BAD" "$C_N"
fi

summary

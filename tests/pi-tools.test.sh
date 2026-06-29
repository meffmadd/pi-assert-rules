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

summary

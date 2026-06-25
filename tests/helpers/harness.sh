#!/bin/sh
# tests/helpers/harness.sh — shared utilities for the pi-assert-rules test suite.
#
# POSIX /bin/sh only (no bashisms). Mirrors pi-assert's runtime EXACTLY,
# verified against ../pi-assert/pi-assert/engine.ts:
#
#   - the assert's `shell` (and `when`) run via `/bin/sh -c` (child_process.exec
#     with the default shell = /bin/sh on Unix).
#   - PI_* env vars are merged ON TOP OF the inherited parent env (PATH etc.),
#     not a clean env:  const merged = { ...process.env, ...PI_env }.
#   - PI_TOOL_INPUT is JSON.stringify(input) → MINIFIED JSON (no spaces). The
#     grep-based asserts (write-only-md, no-env-access) match `"path":"…"`
#     literally, so test inputs must be minified to mirror reality.
#   - exit 0      = pass / allow.
#   - non-zero    = block / fail  (or, for agent_end, trigger a new turn).
#   - if `when` is present and exits non-zero, the assert is SKIPPED (not run,
#     not failed) — exactly pi-assert's behaviour; lets bash-deny tests skip
#     cleanly when bash-deny/jq aren't installed.
#
# Env produced by pi-assert, per hook:
#   tool_call   : PI_TOOL_NAME, PI_TOOL_CALL_ID, PI_TOOL_INPUT, PI_CWD
#   tool_result : PI_TOOL_NAME, PI_TOOL_CALL_ID, PI_TOOL_INPUT, PI_TOOL_RESULT,
#                 PI_TOOL_IS_ERROR ("true" | "false"), PI_CWD
#   agent_end   : PI_EVENT="agent_end", PI_CWD
#
# Usage (from a test file that has set REPO_ROOT and TARGET):
#   . "$REPO_ROOT/tests/helpers/harness.sh"
#   tc <assert> <expected> <tool_name> <tool_input> [cwd]      # hook=tool_call
#   tr <assert> <expected> <tool_name> <tool_input> <result> [cwd]  # hook=tool_result
#   ae <assert> <expected> [cwd]                                # hook=agent_end
#
# <expected> is the expected exit code: 0 (pass/allow), 1 (block), or the
# special token "NZ" meaning "any non-zero exit".

: "${REPO_ROOT:?set REPO_ROOT before sourcing harness.sh}"
: "${TARGET:?set TARGET (a rules/... path) before sourcing harness.sh}"

# Resolve TARGET to an absolute path.
case "$TARGET" in
  /*) ;;
  *)  TARGET="$REPO_ROOT/$TARGET" ;;
esac

# Default PI_CWD = repo root; per-case cwd overrides via tc/tr/ae last arg.
PI_CWD="$REPO_ROOT"
CALL_ID="test-call-1"

PASSED=0; FAILED=0; SKIPPED=0

# Colours only when stdout is a tty.
if [ -t 1 ]; then
  C_OK='\033[32m'; C_BAD='\033[31m'; C_SK='\033[33m'; C_N='\033[0m'
else
  C_OK=''; C_BAD=''; C_SK=''; C_N=''
fi

# _load <assert_name> -> sets HOOK, SHELL_STR, WHEN. Returns 1 if missing.
_load() {
  HOOK=$(jq -r --arg n "$1" '.[$n].hook // empty' "$TARGET")
  SHELL_STR=$(jq -r --arg n "$1" '.[$n].shell // empty' "$TARGET")
  WHEN=$(jq -r --arg n "$1" '.[$n].when // empty' "$TARGET")
  [ -n "$HOOK" ] && [ -n "$SHELL_STR" ]
}

_ok()  { PASSED=$((PASSED+1));   printf '  %b✓%b %s (exit %s)\n'    "$C_OK"  "$C_N" "$1" "$2"; }
_bad() { FAILED=$((FAILED+1));   printf '  %b✗%b %s (exit %s, expected %s)\n' "$C_BAD" "$C_N" "$1" "$3" "$2"; }
_sk()  { SKIPPED=$((SKIPPED+1)); printf '  %b⊘%b %s (skipped: when)\n' "$C_SK" "$C_N" "$1"; }

# _compare <assert> <expected> <got>
_compare() {
  if [ "$2" = "NZ" ]; then
    if [ "$3" -ne 0 ]; then _ok "$1" "$3"; else _bad "$1" "NZ" "$3"; fi
  else
    if [ "$3" = "$2" ]; then _ok "$1" "$3"; else _bad "$1" "$2" "$3"; fi
  fi
}

# Build the PI_* env for the current HOOK inside a subshell and run the given
# string via /bin/sh -c. $1 = string to run, $2.. = hook-specific values.
# Uses variables from the enclosing scope (POSIX sh has no local arrays).
_run() {
  _str=$1; _tn=$2; _ti=$3; _tr=$4; _rcwd=$5
  _wd=${_rcwd:-$REPO_ROOT}
  (
    export PI_CWD="$_wd" PI_TOOL_CALL_ID="$CALL_ID"
    case "$HOOK" in
      tool_call)
        export PI_TOOL_NAME="$_tn" PI_TOOL_INPUT="$_ti" ;;
      tool_result)
        export PI_TOOL_NAME="$_tn" PI_TOOL_INPUT="$_ti" \
               PI_TOOL_RESULT="$_tr" PI_TOOL_IS_ERROR=false ;;
      agent_end)
        export PI_EVENT=agent_end ;;
      *)
        printf 'unknown hook: %s\n' "$HOOK" >&2; exit 2 ;;
    esac
    # pi-assert's exec() does NOT chdir — asserts that run `git diff` etc. rely
    # on the pi process cwd already being the project dir (= PI_CWD). Mirror
    # that by cd'ing into PI_CWD before running the shell string.
    cd "$_wd" || exit 2
    # Inherit the rest of the parent env (PATH, …) — just like pi-assert.
    /bin/sh -c "$_str"
  )
}

# _wts <assert> <expected> <tool_name> <tool_input> <tool_result> <cwd>
_wts() {
  assert=$1; exp=$2; tn=$3; ti=$4; tr=$5; cwd=$6
  if [ -n "$WHEN" ]; then
    _run "$WHEN" "$tn" "$ti" "$tr" "$cwd" >/dev/null 2>&1 || { _sk "$assert"; return; }
  fi
  _run "$SHELL_STR" "$tn" "$ti" "$tr" "$cwd" >/dev/null 2>&1
  _compare "$assert" "$exp" "$?"
}

# Public case helpers.
tc() { _load "$1" || { _bad "$1 (load)" "?" "$?"; return; }; _wts "$1" "$2" "$3" "$4" "" "${5-}"; }
tr() { _load "$1" || { _bad "$1 (load)" "?" "$?"; return; }; _wts "$1" "$2" "$3" "$4" "$5" "${6-}"; }
ae() { _load "$1" || { _bad "$1 (load)" "?" "$?"; return; }; _wts "$1" "$2" "" "" "" "${3-}"; }

summary() {
  printf '\n  %b%d passed%b, %b%d failed%b, %b%d skipped%b\n' \
    "$C_OK" "$PASSED" "$C_N" \
    "$C_BAD" "$FAILED" "$C_N" \
    "$C_SK" "$SKIPPED" "$C_N"
  [ "$FAILED" -eq 0 ]
}
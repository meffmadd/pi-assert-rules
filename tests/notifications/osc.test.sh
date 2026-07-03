#!/bin/sh
# ↔ rules/notifications/osc.json   (hook=agent_end)
#
# Two contracts for every notify-osc-* assert:
#   (A) exit 0 always — so it never blocks the agent and never triggers a
#       spurious follow-up turn — across terminal env (none / Kitty /
#       iTerm2-via-TERM_PROGRAM / iTerm2-via-ITERM_SESSION_ID) and tmux
#       state, and even when the output target is unwritable.
#   (B) byte-exact OSC sequence written to PI_NOTIFY_OUT, matching an
#       INDEPENDENT printf-octal oracle (hardcoded octal literals, not the
#       assert's own sed/printf construction), for plain and tmux-passthrough
#       modes. notify-osc-auto is exercised across all three terminal
#       branches and must match the corresponding fixed-protocol bytes.
#
# pi-assert captures and discards assert stdout, so the asserts write to
# /dev/tty by default; tests redirect the bytes to a file via PI_NOTIFY_OUT.
# The developer's real terminal env (TMUX/KITTY_WINDOW_ID/...) is scrubbed at
# the top so it can't leak into cases — and VAR=val func PERSISTS in this
# shell, so every case resets env explicitly via setup_env.

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$TEST_DIR
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/rules" ]; do
  REPO_ROOT=$(CDPATH= cd -- "$REPO_ROOT/.." && pwd)
done
TARGET=rules/notifications/osc.json
. "$REPO_ROOT/tests/helpers/harness.sh"

# Scrub the developer's real terminal env so it can't contaminate cases.
unset KITTY_WINDOW_ID TERM_PROGRAM ITERM_SESSION_ID TMUX

WORK=$(mktemp -d "${TMPDIR:-/tmp}/par-osc.XXXXXX")
trap 'rm -rf "$WORK"' EXIT INT TERM
OUT="$WORK/out"
EXP="$WORK/exp"

# setup_env <profile> <tmux:0|1> — set a known terminal profile, unsetting the
# rest. Profiles: none | kitty | iterm-prog | iterm-sess.
setup_env() {
  unset KITTY_WINDOW_ID TERM_PROGRAM ITERM_SESSION_ID TMUX
  case "$1" in
    kitty)      export KITTY_WINDOW_ID=1 ;;
    iterm-prog) export TERM_PROGRAM=iTerm.app ;;
    iterm-sess) export ITERM_SESSION_ID=x ;;
  esac
  [ "$2" = 1 ] && export TMUX=1
}

# expect <protocol:777|9|99> <tmux:0|1> — write the oracle bytes to $EXP via
# printf octal literals. Fully independent of the assert's runtime construction.
expect() {
  case "$1:$2" in
    777:0) printf '\033]777;notify;Pi;Ready for input\007' ;;
    777:1) printf '\033Ptmux;\033\033]777;notify;Pi;Ready for input\007\033\\' ;;
    9:0)   printf '\033]9;Pi: Ready for input\007' ;;
    9:1)   printf '\033Ptmux;\033\033]9;Pi: Ready for input\007\033\\' ;;
    99:0)  printf '\033]99;i=1:d=0;Pi\033\\\033]99;i=1:p=body;Ready for input\033\\' ;;
    99:1)  printf '\033Ptmux;\033\033]99;i=1:d=0;Pi\033\033\\\033\033]99;i=1:p=body;Ready for input\033\033\\\033\\' ;;
  esac > "$EXP"
}

# run <assert> — load + exec with PI_NOTIFY_OUT=$OUT; sets RC (127 = load fail).
run() {
  _load "$1" || { RC=127; return; }
  : > "$OUT"
  PI_NOTIFY_OUT="$OUT" /bin/sh -c "$SHELL_STR" >/dev/null 2>&1
  RC=$?
}

# exit0 <label> <assert> — run and assert exit code 0.
exit0() {
  run "$2"
  if [ "$RC" = 127 ]; then _bad "$1 (load)" "?" 127; return; fi
  _compare "$1" 0 "$RC"
}

# bytes <label> <assert> — run and compare $OUT to $EXP (caller pre-built $EXP).
bytes() {
  run "$2"
  if [ "$RC" = 127 ]; then _bad "$1 (load)" "?" 127; return; fi
  if cmp -s "$OUT" "$EXP"; then _ok "$1" "ok"; else _bad "$1" "match" "diff"; fi
}

# Combined case helpers (profile + tmux set up first).
# exit_case <label> <assert> <profile> <tmux>
exit_case() { setup_env "$3" "$4"; exit0 "$1" "$2"; }
# byte_case <label> <assert> <profile> <tmux> <protocol>
byte_case() { setup_env "$3" "$4"; expect "$5" "$4"; bytes "$1" "$2"; }

printf -- '--- exit 0 across env (never blocks / never triggers a turn) ---\n'
exit_case 'auto none'         notify-osc-auto none        0
exit_case 'auto kitty'        notify-osc-auto kitty       0
exit_case 'auto iterm-prog'   notify-osc-auto iterm-prog 0
exit_case 'auto iterm-sess'   notify-osc-auto iterm-sess 0
exit_case 'auto tmux'         notify-osc-auto none        1
exit_case '777 plain'         notify-osc-777  none        0
exit_case '777 tmux'          notify-osc-777  none        1
exit_case '9 plain'           notify-osc-9    none        0
exit_case '9 tmux'            notify-osc-9    none        1
exit_case '99 plain'          notify-osc-99   none        0
exit_case '99 tmux'           notify-osc-99   none        1

# Robustness: exit 0 even when the output target cannot be written.
if _load notify-osc-auto; then
  PI_NOTIFY_OUT=/no/such/dir/x /bin/sh -c "$SHELL_STR" >/dev/null 2>&1
  _compare 'auto unwritable out' 0 "$?"
else
  _bad 'auto (load)' "?" "$?"
fi

printf -- '--- byte-exact OSC sequences (vs independent printf oracle) ---\n'
byte_case '777 plain'   notify-osc-777  none 0 777
byte_case '777 tmux'    notify-osc-777  none 1 777
byte_case '9 plain'     notify-osc-9    none 0 9
byte_case '9 tmux'      notify-osc-9    none 1 9
byte_case '99 plain'    notify-osc-99   none 0 99
byte_case '99 tmux'     notify-osc-99   none 1 99

printf -- '--- auto dispatches to the matching fixed-protocol bytes ---\n'
byte_case 'auto none ->777 plain'  notify-osc-auto none        0 777
byte_case 'auto none ->777 tmux'   notify-osc-auto none        1 777
byte_case 'auto kitty ->99 plain' notify-osc-auto kitty       0 99
byte_case 'auto kitty ->99 tmux'  notify-osc-auto kitty       1 99
byte_case 'auto iprog ->9 plain'  notify-osc-auto iterm-prog  0 9
byte_case 'auto iprog ->9 tmux'   notify-osc-auto iterm-prog  1 9
byte_case 'auto isess ->9 plain'  notify-osc-auto iterm-sess 0 9

summary

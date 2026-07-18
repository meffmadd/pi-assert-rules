#!/usr/bin/env bash
# subcommands.sh — enumerate subcommands of a CLI command.
# Usage: subcommands.sh <command>
# Prints one subcommand name per line (sorted, unique). Best-effort: the agent
# should eyeball the list and drop noise (plugin aliases, non-commands) before
# generating rules.
set -euo pipefail

cmd="${1:?usage: subcommands.sh <command>}"

# git: 'git help -a' is the authoritative, complete subcommand list.
if [ "$cmd" = git ]; then
  git help -a 2>/dev/null | awk '
    /^[[:space:]]+[a-z][a-z0-9_-]*[[:space:]]+[^[:space:]]/ {
      line=$0; sub(/^[[:space:]]+/,"",line); n=split(line,a," ");
      name=a[1]; sub(/\*$/,"",name);
      if (line !~ /:$/) print name
    }' | sort -u | grep -vx "^git$" || true
  exit 0
fi

# npm: 'npm --help' prints an "All commands:" comma-separated block.
if [ "$cmd" = npm ]; then
  npm --help 2>/dev/null | awk '
    /^All commands:/{f=1; next}
    f && /^[^[:space:]]/{f=0; next}
    f && /^[[:space:]]/{print}
  ' | tr ',' '\n' | awk '{print $1}' | tr -cd 'a-z0-9_-\n' | grep -v '^$' \
    | sort -u | grep -vx "^npm$" || true
  exit 0
fi

# Generic: parse '<cmd> --help' for indented "word  description" lines.
# Covers cobra-style tools (helm, kubectl, docker, …): real subcommands are
# indented; section headers sit at column 0 or end with ':'.
"$cmd" --help 2>&1 | awk '
  /^[[:space:]]+[a-z][a-z0-9_-]*[[:space:]]+[^[:space:]]/ {
    line=$0; sub(/^[[:space:]]+/,"",line); n=split(line,a," ");
    name=a[1]; sub(/\*$/,"",name);
    if (line !~ /:$/) print name
  }' | sort -u | grep -vx "^$cmd$" || true

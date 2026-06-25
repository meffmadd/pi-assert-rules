#!/bin/sh
# tests/helpers/fixture-repo.sh — build throwaway git repos for agent_end
# asserts (git/lines-changed.json) that need a known working-tree diff.
#
# POSIX /bin/sh has no `local`, so every internal variable here is prefixed
# `_fr_` to avoid clobbering variables in the sourcing test file (that bug
# previously ate the caller's loop counter).

# mkrepo <dir> <baseline_lines>
mkrepo() {
  _fr_dir=$1; _fr_base=${2:-100}
  rm -rf "$_fr_dir"; mkdir -p "$_fr_dir"
  ( cd "$_fr_dir" || exit 1
    git init -q
    git config user.email t@t; git config user.name t
    _fr_i=1
    while [ "$_fr_i" -le "$_fr_base" ]; do
      printf 'line %s\n' "$_fr_i"
      _fr_i=$((_fr_i+1))
    done > base.txt
    git add base.txt
    git commit -q -m base )
}

# add_lines <dir> <file> <n> <from>   — append <n> lines numbered from <from>
add_lines() {
  _fr_ad=$1; _fr_af=$2; _fr_an=$3; _fr_ar=$4
  _fr_i=0
  while [ "$_fr_i" -lt "$_fr_an" ]; do
    printf '+line %s\n' "$((_fr_ar+_fr_i))"
    _fr_i=$((_fr_i+1))
  done >> "$_fr_ad/$_fr_af"
}

# del_lines <dir> <file> <n>   — remove the first <n> lines
del_lines() {
  _fr_dd=$1; _fr_df=$2; _fr_dn=$3
  tail -n "+$((_fr_dn+1))" "$_fr_dd/$_fr_df" > "$_fr_dd/$_fr_df.tmp" \
    && mv "$_fr_dd/$_fr_df.tmp" "$_fr_dd/$_fr_df"
}

# add_untracked <dir> <file> <n>   — new untracked file with <n> lines
add_untracked() {
  _fr_ud=$1; _fr_uf=$2; _fr_un=$3
  _fr_i=1
  while [ "$_fr_i" -le "$_fr_un" ]; do
    printf 'untracked %s\n' "$_fr_i"
    _fr_i=$((_fr_i+1))
  done > "$_fr_ud/$_fr_uf"
}
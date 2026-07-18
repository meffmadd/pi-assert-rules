#!/usr/bin/env bash
# Generate bash-deny patterns or pi-assert entries from discovered subcommands
# or a curated pattern manifest.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  gen-rules.sh <command> [options]
  gen-rules.sh --input <file|-> [options]

Input:
  Without --input, subcommands are discovered and prefixed with <command>.
  With --input, each non-empty, non-comment line is one selector/pattern:

    commit
    reset --hard<TAB>deny-git-reset-hard<TAB>Blocks hard resets.
    git stash drop

  When <command> is present, selectors are prefixed with it unless they already
  start with that command. Without <command>, lines are treated as complete
  patterns, allowing one manifest to mix commands such as curl, wget, and
  "helm plugin install". Optional tab-separated fields override the generated
  assert name and description.

Output modes (choose one; default --bashdeny):
  --bashdeny              One bash-deny pattern per line.
  --inline                One semicolon-joined bash-deny rule string.
  --asserts               A JSON object containing one pi-assert per pattern.

Options:
  --input, --from FILE    Read curated selectors/patterns from FILE; - = stdin.
  --full-patterns         Never prefix input lines with <command>.
  --preset NAME           With --asserts, append a preset containing every
                          generated assertion in manifest order.
  --source SOURCE         Preset member source: local or owner/repo. Required
                          with --preset.
  --preset-description D  Override the generated preset description.
  -h, --help              Show this help.
EOF
}

fail() {
  printf 'gen-rules.sh: %s\n' "$*" >&2
  exit 2
}

need_value() {
  [[ $# -ge 2 && -n ${2-} ]] || fail "$1 requires a value"
}

valid_name() {
  [[ $1 =~ ^[A-Za-z0-9._-]+$ ]]
}

valid_source() {
  [[ $1 == local || $1 =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]
}

trim() {
  local value=$1
  value="${value#"${value%%[!$' \t\r\n']*}"}"
  value="${value%"${value##*[!$' \t\r\n']}"}"
  printf '%s' "$value"
}

slug_name() {
  local slug
  slug=$(printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')
  [[ -n $slug ]] || fail "cannot derive an assertion name from pattern: $1"
  printf 'deny-%s' "$slug"
}

# Quote one value as a POSIX-shell single-quoted word.
shell_quote() {
  printf "'"
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
  printf "'"
}

command_name=""
mode="--bashdeny"
input=""
full_patterns=false
preset_name=""
preset_source=""
preset_description=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --bashdeny|--inline|--asserts)
      mode=$1
      shift
      ;;
    --input|--from)
      need_value "$@"
      input=$2
      shift 2
      ;;
    --input=*|--from=*)
      input=${1#*=}
      [[ -n $input ]] || fail "${1%%=*} requires a value"
      shift
      ;;
    --full-patterns)
      full_patterns=true
      shift
      ;;
    --preset)
      need_value "$@"
      preset_name=$2
      shift 2
      ;;
    --preset=*)
      preset_name=${1#*=}
      [[ -n $preset_name ]] || fail "--preset requires a value"
      shift
      ;;
    --source)
      need_value "$@"
      preset_source=$2
      shift 2
      ;;
    --source=*)
      preset_source=${1#*=}
      [[ -n $preset_source ]] || fail "--source requires a value"
      shift
      ;;
    --preset-description)
      need_value "$@"
      preset_description=$2
      shift 2
      ;;
    --preset-description=*)
      preset_description=${1#*=}
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      fail "unknown option: $1"
      ;;
    *)
      [[ -z $command_name ]] || fail "unexpected argument: $1"
      command_name=$1
      shift
      ;;
  esac
done

[[ -n $command_name || -n $input ]] || { usage >&2; exit 2; }
if [[ -n $preset_name ]]; then
  [[ $mode == --asserts ]] || fail "--preset is only valid with --asserts"
  valid_name "$preset_name" || fail "invalid preset name: $preset_name"
  [[ -n $preset_source ]] || fail "--source is required with --preset"
  valid_source "$preset_source" || fail "invalid preset source: $preset_source"
elif [[ -n $preset_source || -n $preset_description ]]; then
  fail "--source and --preset-description require --preset"
fi
if [[ $mode == --asserts ]]; then
  command -v jq >/dev/null 2>&1 || fail "jq is required for --asserts"
fi

script_dir=$(cd "$(dirname "$0")" && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/bash-deny-gen.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT INT TERM HUP
raw_file="$tmp_dir/raw"
patterns_file="$tmp_dir/patterns"
names_file="$tmp_dir/names"
entries_file="$tmp_dir/entries.jsonl"
: > "$patterns_file"
: > "$names_file"
: > "$entries_file"

if [[ -n $input ]]; then
  if [[ $input == - ]]; then
    cat > "$raw_file"
  else
    [[ -r $input ]] || fail "input is not readable: $input"
    cat "$input" > "$raw_file"
  fi
else
  "$script_dir/subcommands.sh" "$command_name" > "$raw_file"
fi

count=0
while IFS= read -r line || [[ -n $line ]]; do
  line=${line%$'\r'}
  stripped=$(trim "$line")
  [[ -n $stripped || $line == *$'\t'* ]] || continue
  [[ $stripped != \#* ]] || continue

  selector=$line
  explicit_name=""
  explicit_description=""
  if [[ $line == *$'\t'* ]]; then
    IFS=$'\t' read -r selector explicit_name explicit_description extra <<< "$line"
    [[ -z ${extra-} ]] || fail "too many tab-separated fields: $line"
  fi
  selector=$(trim "$selector")
  explicit_name=$(trim "$explicit_name")
  explicit_description=$(trim "$explicit_description")
  [[ -n $selector ]] || fail "empty pattern in input line: $line"

  pattern=$selector
  if [[ -n $command_name && $full_patterns == false ]]; then
    case $selector in
      "$command_name"|"$command_name "*) ;;
      *) pattern="$command_name $selector" ;;
    esac
  fi

  name=${explicit_name:-$(slug_name "$pattern")}
  valid_name "$name" || fail "invalid assertion name '$name' for pattern: $pattern"
  if grep -Fqx -- "$name" "$names_file"; then
    fail "duplicate assertion name '$name'; add an explicit tab-separated name"
  fi
  printf '%s\n' "$name" >> "$names_file"
  printf '%s\n' "$pattern" >> "$patterns_file"
  count=$((count + 1))

  if [[ $mode == --asserts ]]; then
    description=${explicit_description:-"Blocks ${pattern}."}
    quoted_pattern=$(shell_quote "$pattern")
    shell="CMD=\$(printf '%s' \"\$PI_TOOL_INPUT\" | jq -r '.command // empty'); [ -z \"\$CMD\" ] || bash-deny -r ${quoted_pattern} -i \"\$CMD\" -q"
    jq -cn \
      --arg name "$name" \
      --arg description "$description" \
      --arg shell "$shell" \
      '{name: $name, value: {description: $description, hook: "tool_call", filter: {toolName: "bash"}, shell: $shell}}' \
      >> "$entries_file"
  fi
done < "$raw_file"

[[ $count -gt 0 ]] || fail "no patterns generated"

case $mode in
  --bashdeny)
    cat "$patterns_file"
    ;;
  --inline)
    paste -sd ';' "$patterns_file"
    ;;
  --asserts)
    if [[ -n $preset_name ]]; then
      if grep -Fqx -- "$preset_name" "$names_file"; then
        fail "preset name '$preset_name' collides with a generated assertion"
      fi
      if [[ -z $preset_description ]]; then
        preset_description="Bundles all ${count} generated command guards."
      fi
      # Build refs without interpolating source/name into JSON source text.
      refs_file="$tmp_dir/refs.jsonl"
      : > "$refs_file"
      while IFS= read -r name; do
        jq -cn --arg ref "$preset_source/$name" '$ref' >> "$refs_file"
      done < "$names_file"
      jq -cs '.' "$refs_file" > "$tmp_dir/refs.json"
      jq -cn \
        --arg name "$preset_name" \
        --arg description "$preset_description" \
        --slurpfile refs "$tmp_dir/refs.json" \
        '{name: $name, value: {description: $description, preset: $refs[0]}}' \
        >> "$entries_file"
    fi
    jq -s '
      reduce .[] as $entry ({};
        if has($entry.name) then error("duplicate entry: " + $entry.name)
        else .[$entry.name] = $entry.value
        end
      )
    ' "$entries_file"
    ;;
esac

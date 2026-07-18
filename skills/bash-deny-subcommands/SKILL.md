---
name: bash-deny-subcommands
description: Generate modular bash-deny and pi-assert command guards from discovered CLI subcommands or curated multi-command patterns, and compose atomic assertions with pi-assert presets.
---

# Modular bash-deny command guards

Generate [bash-deny](https://github.com/meffmadd/pi-deny#bash-deny) rules as
small, independently selectable pi-assert assertions. Use a pi-assert preset to
reassemble a useful policy such as “Helm release management”, “destructive Git
operations”, or “all web fetchers”.

The scripts support two complementary workflows:

1. **Discover a CLI's top-level subcommands** as a starting point.
2. **Generate from a curated manifest** containing arbitrary command patterns.

Prefer a curated manifest for committed rules. Discovery output varies by the
installed CLI version and cannot represent nested commands, significant flags,
bare executables, aliases, or a policy spanning several CLIs.

## Prerequisites

- `bash-deny` on `PATH` to enforce and test generated rules.
- `jq` for `--asserts` generation and at runtime for generated pi-assert
  assertions.
- The target CLI on `PATH` only when using automatic discovery.

Install bash-deny from [pi-deny](https://github.com/meffmadd/pi-deny):

```bash
git clone https://github.com/meffmadd/pi-deny
cd pi-deny && npm install -g .
bash-deny --version
```

## Scripts

Run scripts relative to this skill directory.

### Discover subcommands

```bash
./scripts/subcommands.sh <command>
```

The output is sorted and unique, with one subcommand per line. Discovery is
best-effort:

| CLI | Discovery source |
|---|---|
| `git` | `git help -a` |
| `npm` | the `All commands:` block in `npm --help` |
| other CLIs | indented `word  description` rows in `<command> --help` |

The generic parser works for many Cobra-style tools such as Helm, kubectl, and
Docker. Always inspect the output and remove plugin aliases, help noise, and
commands that the policy should allow.

```bash
./scripts/subcommands.sh helm > /tmp/helm-subcommands.txt
```

### Generate rules

```bash
./scripts/gen-rules.sh <command> [options]
./scripts/gen-rules.sh --input <manifest|-> [options]
```

Output modes:

- `--bashdeny` (default): one bash-deny pattern per line.
- `--inline`: one semicolon-joined rule string.
- `--asserts`: a JSON object with one pi-assert assertion per pattern.

Without `--input`, the generator discovers subcommands and prefixes each with
the command:

```bash
./scripts/gen-rules.sh helm --bashdeny
# helm completion
# helm create
# …
```

## Curated manifests

A manifest is a line-oriented list. Blank lines and lines whose first
non-whitespace character is `#` are ignored.

When a command is supplied, each line is a selector relative to that command.
A line already beginning with the command is not prefixed again:

```text
# git-dangerous.txt
commit
push
reset --hard
stash drop
git checkout --
```

```bash
./scripts/gen-rules.sh git --input git-dangerous.txt --bashdeny
```

Without a command argument, every line is a complete pattern. This permits
mixed command families and bare commands:

```text
# web-fetch.txt
curl
wget
aria2c
axel
helm plugin install
```

```bash
./scripts/gen-rules.sh --input web-fetch.txt --bashdeny
```

Use `--full-patterns` when a command argument is present but every manifest
line should still be interpreted literally.

Input can also come from stdin:

```bash
printf '%s\n' 'docker run' 'kubectl exec' \
  | ./scripts/gen-rules.sh --input - --asserts
```

### Optional names and descriptions

By default, a pattern is slugged into an assertion name:

```text
git reset --hard  -> deny-git-reset-hard
curl              -> deny-curl
```

A manifest line may contain up to three tab-separated fields:

```text
PATTERN<TAB>ASSERT_NAME<TAB>DESCRIPTION
```

For example:

```text
create<TAB>deny-kubectl-create-command<TAB>Blocks kubectl create.
reset --hard<TAB>deny-git-reset-hard<TAB>Blocks hard resets while allowing soft resets.
```

Use explicit names to preserve public rule names, avoid a generated-name
collision, or distinguish an atomic assertion from a preset. Names must match
`[A-Za-z0-9._-]+`. Duplicate names fail generation rather than silently
overwriting JSON entries.

## Generate modular pi-assert entries

```bash
./scripts/gen-rules.sh git --input git-dangerous.txt --asserts
```

Each pattern becomes one independently toggleable assertion:

```json
{
  "deny-git-reset-hard": {
    "description": "Blocks git reset --hard.",
    "hook": "tool_call",
    "filter": { "toolName": "bash" },
    "shell": "CMD=$(printf '%s' \"$PI_TOOL_INPUT\" | jq -r '.command // empty'); [ -z \"$CMD\" ] || bash-deny -r 'git reset --hard' -i \"$CMD\" -q"
  }
}
```

Generated shell strings safely quote the complete deny pattern before passing
it to `bash-deny -r`.

## Compose assertions with a preset

With `--asserts`, pass `--preset` and `--source` to include a preset in the
same JSON object:

```bash
./scripts/gen-rules.sh git \
  --input git-dangerous.txt \
  --asserts \
  --preset deny-git-destructive \
  --source meffmadd/pi-assert-rules \
  --preset-description 'Blocks destructive Git operations.'
```

The generated preset directly references every generated assertion in manifest
order:

```json
{
  "deny-git-clean": { "description": "…", "hook": "tool_call", "filter": { "toolName": "bash" }, "shell": "…" },
  "deny-git-destructive": {
    "description": "Blocks destructive Git operations.",
    "preset": [
      "meffmadd/pi-assert-rules/deny-git-clean",
      "meffmadd/pi-assert-rules/deny-git-stash-drop"
    ]
  }
}
```

`--source` must be `local` or `owner/repo`. It is required because a wrong
source creates dangling preset references.

Pi-assert presets expand **one level only**. Do not reference one preset from
another preset. Aggregate presets must list their atomic shell assertions
directly. Installing a repo preset installs its referenced repo members.

A preset name must not collide with a generated assertion. When preserving an
existing bundle name that also resembles an atomic command, give the atom an
explicit name, for example `deny-kubectl-create-command`, and retain
`deny-kubectl-create` for the preset.

## Other output formats

### Bash-deny file

```bash
./scripts/gen-rules.sh git --input git-dangerous.txt --bashdeny \
  > /tmp/git-dangerous.bashdeny
bash-deny -f /tmp/git-dangerous.bashdeny -i 'git reset --hard HEAD~1'
```

Use `!` exceptions in a hand-maintained `.bashdeny` file when appropriate;
last match wins.

### Inline rule

```bash
RULE=$(./scripts/gen-rules.sh --input web-fetch.txt --inline)
bash-deny -r "$RULE" -i 'curl https://example.com' -q
```

Inline rules are useful for ad hoc checks. For a rules repository, prefer
atomic assertions plus presets so users can select individual protections.

## Recommended repository workflow

1. Discover candidates when the target is a conventional CLI:
   ```bash
   ./scripts/subcommands.sh kubectl > /tmp/kubectl.txt
   ```
2. Curate a manifest. Add nested commands and flag-specific patterns manually.
3. Assign explicit names where compatibility or collisions require them.
4. Generate atomic assertions and a direct-member preset:
   ```bash
   ./scripts/gen-rules.sh kubectl \
     --input /tmp/kubectl-mutations.txt \
     --asserts \
     --preset deny-kubectl-mutate \
     --source meffmadd/pi-assert-rules \
     > rules/bash-deny/kubectl.json
   ```
5. Verify every atomic pattern and the preset membership.
6. Validate the complete rules repository for duplicate names and dangling
   preset references.

Do not commit unreviewed live discovery output. Keep the curated manifest or
otherwise make the selected patterns reviewable and reproducible.

## Matching notes

- `bash-deny` scans forward through interspersed flags, so `git commit` also
  catches forms such as `git -C /repo commit`.
- A subcommand pattern does not block the bare command. Add the bare command as
  its own pattern when required.
- Use the narrowest pattern that expresses the policy. `git reset --hard`
  allows `git reset --soft`; `git reset` does not.
- Strict mode (`bash-deny -s`) adds protection against command substitutions,
  backticks, and path-based command names. It is intentionally not enabled by
  the generator because strictness is a policy choice independent of pattern
  modularity.

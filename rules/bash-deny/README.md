# bash-deny rule bundles

Every shell assertion in this directory is atomic. Each single-CLI rule file
also provides a standalone `deny-<command>` assertion for the bare executable;
it is deliberately separate from selective subcommand presets. The multi-CLI
web-fetch rule provides the equivalent bare assertions for each executable.
Existing policy names (`deny-git-destructive`, `deny-helm-release-mgmt`,
`deny-kubectl-create`, and so on) are presets that directly reference their
atomic members from `meffmadd/pi-assert-rules`.

The tab-separated manifests record the curated patterns, names, and
descriptions used to generate the JSON. Regenerate an individual policy with
`skills/bash-deny-subcommands/scripts/gen-rules.sh`; for example:

```sh
skills/bash-deny-subcommands/scripts/gen-rules.sh kubectl \
  --input rules/bash-deny/manifests/kubectl-create.tsv --asserts \
  --preset deny-kubectl-create --source meffmadd/pi-assert-rules \
  --preset-description 'Blocks new resource creation: kubectl create, apply, replace, and run.'
```

Some JSON files combine several manifests so their related atomic assertions
and presets remain installable from one rule file.

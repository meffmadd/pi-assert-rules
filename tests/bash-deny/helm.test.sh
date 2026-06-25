#!/bin/sh
# ↔ rules/bash-deny/helm.json

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$TEST_DIR
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/rules" ]; do
  REPO_ROOT=$(CDPATH= cd -- "$REPO_ROOT/.." && pwd)
done
TARGET=rules/bash-deny/helm.json
. "$REPO_ROOT/tests/helpers/harness.sh"

printf -- '--- deny-helm-release-mgmt\n'
tc deny-helm-release-mgmt 1 bash '{"command":"helm upgrade app ./c","timeout":30}'
tc deny-helm-release-mgmt 1 bash '{"command":"helm install app ./c","timeout":30}'
tc deny-helm-release-mgmt 1 bash '{"command":"helm rollback app","timeout":30}'
tc deny-helm-release-mgmt 1 bash '{"command":"helm uninstall app","timeout":30}'
tc deny-helm-release-mgmt 1 bash '{"command":"sudo helm upgrade app ./c","timeout":30}'
tc deny-helm-release-mgmt 0 bash '{"command":"helm list","timeout":30}'
tc deny-helm-release-mgmt 0 bash '{"command":"helm repo add upstream https://x","timeout":30}'

printf -- '--- deny-helm-plugin\n'
tc deny-helm-plugin 1 bash '{"command":"helm plugin install x","timeout":30}'
tc deny-helm-plugin 1 bash '{"command":"helm plugin install https://github.com/x","timeout":30}'
tc deny-helm-plugin 0 bash '{"command":"helm list","timeout":30}'
tc deny-helm-plugin 0 bash '{"command":"helm plugin list","timeout":30}'

summary
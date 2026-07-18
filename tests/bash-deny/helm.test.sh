#!/bin/sh
# ↔ rules/bash-deny/helm.json

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$TEST_DIR
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/rules" ]; do
  REPO_ROOT=$(CDPATH= cd -- "$REPO_ROOT/.." && pwd)
done
TARGET=rules/bash-deny/helm.json
. "$REPO_ROOT/tests/helpers/harness.sh"

# Hard requirement: bash-deny and jq must be on PATH to run these tests.
command -v bash-deny >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || {
  printf '  %b✗%b FAIL: bash-deny and jq must be on PATH to run these tests\n' "$C_BAD" "$C_N"
  exit 1
}

printf -- '--- deny-helm-release atoms\n'
tc deny-helm-upgrade 1 bash '{"command":"helm upgrade app ./c","timeout":30}'
tc deny-helm-install 1 bash '{"command":"helm install app ./c","timeout":30}'
tc deny-helm-rollback 1 bash '{"command":"helm rollback app","timeout":30}'
tc deny-helm-uninstall 1 bash '{"command":"helm uninstall app","timeout":30}'
tc deny-helm-upgrade 1 bash '{"command":"sudo helm upgrade app ./c","timeout":30}'
tc deny-helm-upgrade 0 bash '{"command":"helm list","timeout":30}'
tc deny-helm-install 0 bash '{"command":"helm repo add upstream https://x","timeout":30}'

printf -- '--- deny-helm-plugin\n'
tc deny-helm-plugin 1 bash '{"command":"helm plugin install x","timeout":30}'
tc deny-helm-plugin 1 bash '{"command":"helm plugin install https://github.com/x","timeout":30}'
tc deny-helm-plugin 0 bash '{"command":"helm list","timeout":30}'
tc deny-helm-plugin 0 bash '{"command":"helm plugin list","timeout":30}'

printf -- '--- deny-helm-release-mgmt preset\n'
if jq -e '
  .["deny-helm-release-mgmt"].preset == [
    "meffmadd/pi-assert-rules/deny-helm-uninstall",
    "meffmadd/pi-assert-rules/deny-helm-install",
    "meffmadd/pi-assert-rules/deny-helm-upgrade",
    "meffmadd/pi-assert-rules/deny-helm-rollback"
  ]
' "$TARGET" >/dev/null 2>&1; then
  PASSED=$((PASSED+1)); printf '  %b✓%b deny-helm-release-mgmt (preset)\n' "$C_OK" "$C_N"
else
  FAILED=$((FAILED+1)); printf '  %b✗%b deny-helm-release-mgmt (preset)\n' "$C_BAD" "$C_N"
fi

summary
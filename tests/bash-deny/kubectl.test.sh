#!/bin/sh
# ↔ rules/bash-deny/kubectl.json
# Notably denies the bare `k` alias separately from kubectl-* so the alias
# stays blocked even when kubectl itself is allowed.

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$TEST_DIR
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/rules" ]; do
  REPO_ROOT=$(CDPATH= cd -- "$REPO_ROOT/.." && pwd)
done
TARGET=rules/bash-deny/kubectl.json
. "$REPO_ROOT/tests/helpers/harness.sh"

# Hard requirement: bash-deny and jq must be on PATH to run these tests.
command -v bash-deny >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || {
  printf '  %b✗%b FAIL: bash-deny and jq must be on PATH to run these tests\n' "$C_BAD" "$C_N"
  exit 1
}

printf -- '--- deny-kubectl (bare command)\n'
tc deny-kubectl 1 bash '{"command":"kubectl","timeout":30}'
tc deny-kubectl 1 bash '{"command":"kubectl get pods","timeout":30}'

printf -- '--- deny-k-alias (catches all `k ...`, spares kubectl)\n'
tc deny-k-alias 1 bash '{"command":"k get pods","timeout":30}'
tc deny-k-alias 1 bash '{"command":"k","timeout":30}'
tc deny-k-alias 1 bash '{"command":"sudo k get pods","timeout":30}'
tc deny-k-alias 0 bash '{"command":"kubectl get pods","timeout":30}'

printf -- '--- deny-kubectl-create atoms\n'
tc deny-kubectl-apply 1 bash '{"command":"kubectl apply -f foo.yaml","timeout":30}'
tc deny-kubectl-create-command 1 bash '{"command":"kubectl create ns x","timeout":30}'
tc deny-kubectl-run 1 bash '{"command":"kubectl run nginx --image=x","timeout":30}'
tc deny-kubectl-replace 1 bash '{"command":"kubectl replace -f foo.yaml","timeout":30}'
tc deny-kubectl-apply 0 bash '{"command":"kubectl get pods","timeout":30}'

printf -- '--- deny-kubectl-delete atoms\n'
tc deny-kubectl-delete-command 1 bash '{"command":"kubectl delete pod f","timeout":30}'
tc deny-kubectl-drain 1 bash '{"command":"kubectl drain node n","timeout":30}'
tc deny-kubectl-taint 1 bash '{"command":"kubectl taint nodes n key=x:NoSchedule","timeout":30}'
tc deny-kubectl-delete-command 0 bash '{"command":"kubectl get pods","timeout":30}'

printf -- '--- deny-kubectl-mutate atoms\n'
tc deny-kubectl-scale 1 bash '{"command":"kubectl scale deploy x --replicas=3","timeout":30}'
tc deny-kubectl-edit 1 bash '{"command":"kubectl edit cm x","timeout":30}'
tc deny-kubectl-patch 1 bash '{"command":"kubectl patch svc x -p {}","timeout":30}'
tc deny-kubectl-rollout 1 bash '{"command":"kubectl rollout status deploy/x","timeout":30}'
tc deny-kubectl-edit 0 bash '{"command":"kubectl get pods","timeout":30}'

printf -- '--- deny-kubectl-exec\n'
tc deny-kubectl-exec 1 bash '{"command":"kubectl exec -it pod -- sh","timeout":30}'
tc deny-kubectl-exec 1 bash '{"command":"sudo kubectl exec -it pod -- sh","timeout":30}'
tc deny-kubectl-exec 0 bash '{"command":"kubectl get pods","timeout":30}'

printf -- '--- kubectl presets\n'
if jq -e '
  .["deny-kubectl-create"].preset == [
    "meffmadd/pi-assert-rules/deny-kubectl-create-command",
    "meffmadd/pi-assert-rules/deny-kubectl-apply",
    "meffmadd/pi-assert-rules/deny-kubectl-replace",
    "meffmadd/pi-assert-rules/deny-kubectl-run"
  ] and .["deny-kubectl-delete"].preset == [
    "meffmadd/pi-assert-rules/deny-kubectl-delete-command",
    "meffmadd/pi-assert-rules/deny-kubectl-drain",
    "meffmadd/pi-assert-rules/deny-kubectl-taint"
  ] and .["deny-kubectl-mutate"].preset == [
    "meffmadd/pi-assert-rules/deny-kubectl-edit",
    "meffmadd/pi-assert-rules/deny-kubectl-scale",
    "meffmadd/pi-assert-rules/deny-kubectl-patch",
    "meffmadd/pi-assert-rules/deny-kubectl-rollout"
  ]
' "$TARGET" >/dev/null 2>&1; then
  PASSED=$((PASSED+1)); printf '  %b✓%b kubectl presets contain their direct atomic members\n' "$C_OK" "$C_N"
else
  FAILED=$((FAILED+1)); printf '  %b✗%b kubectl presets contain their direct atomic members\n' "$C_BAD" "$C_N"
fi

summary
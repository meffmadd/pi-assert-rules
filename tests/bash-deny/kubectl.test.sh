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

printf -- '--- deny-k-alias (catches all `k ...`, spares kubectl)\n'
tc deny-k-alias 1 bash '{"command":"k get pods","timeout":30}'
tc deny-k-alias 1 bash '{"command":"k","timeout":30}'
tc deny-k-alias 1 bash '{"command":"sudo k get pods","timeout":30}'
tc deny-k-alias 0 bash '{"command":"kubectl get pods","timeout":30}'

printf -- '--- deny-kubectl-create\n'
tc deny-kubectl-create 1 bash '{"command":"kubectl apply -f foo.yaml","timeout":30}'
tc deny-kubectl-create 1 bash '{"command":"kubectl create ns x","timeout":30}'
tc deny-kubectl-create 1 bash '{"command":"kubectl run nginx --image=x","timeout":30}'
tc deny-kubectl-create 1 bash '{"command":"kubectl replace -f foo.yaml","timeout":30}'
tc deny-kubectl-create 0 bash '{"command":"kubectl get pods","timeout":30}'

printf -- '--- deny-kubectl-delete\n'
tc deny-kubectl-delete 1 bash '{"command":"kubectl delete pod f","timeout":30}'
tc deny-kubectl-delete 1 bash '{"command":"kubectl drain node n","timeout":30}'
tc deny-kubectl-delete 1 bash '{"command":"kubectl taint nodes n key=x:NoSchedule","timeout":30}'
tc deny-kubectl-delete 0 bash '{"command":"kubectl get pods","timeout":30}'

printf -- '--- deny-kubectl-mutate\n'
tc deny-kubectl-mutate 1 bash '{"command":"kubectl scale deploy x --replicas=3","timeout":30}'
tc deny-kubectl-mutate 1 bash '{"command":"kubectl edit cm x","timeout":30}'
tc deny-kubectl-mutate 1 bash '{"command":"kubectl patch svc x -p {}","timeout":30}'
tc deny-kubectl-mutate 1 bash '{"command":"kubectl rollout status deploy/x","timeout":30}'
tc deny-kubectl-mutate 0 bash '{"command":"kubectl get pods","timeout":30}'

printf -- '--- deny-kubectl-exec\n'
tc deny-kubectl-exec 1 bash '{"command":"kubectl exec -it pod -- sh","timeout":30}'
tc deny-kubectl-exec 1 bash '{"command":"sudo kubectl exec -it pod -- sh","timeout":30}'
tc deny-kubectl-exec 0 bash '{"command":"kubectl get pods","timeout":30}'

summary
#!/bin/sh
# ↔ rules/bash-deny/docker.json

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$TEST_DIR
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/rules" ]; do
  REPO_ROOT=$(CDPATH= cd -- "$REPO_ROOT/.." && pwd)
done
TARGET=rules/bash-deny/docker.json
. "$REPO_ROOT/tests/helpers/harness.sh"

command -v bash-deny >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || {
  printf '  %b✗%b FAIL: bash-deny and jq must be on PATH to run these tests\n' "$C_BAD" "$C_N"
  exit 1
}

printf -- '--- deny-docker (bare command)\n'
tc deny-docker 1 bash '{"command":"docker","timeout":30}'
tc deny-docker 1 bash '{"command":"docker ps","timeout":30}'

printf -- '--- deny-docker-container-management atoms\n'
tc deny-docker-run 1 bash '{"command":"docker run alpine true","timeout":30}'
tc deny-docker-exec 1 bash '{"command":"docker exec app sh","timeout":30}'
tc deny-docker-rm 1 bash '{"command":"docker rm app","timeout":30}'
tc deny-docker-run 1 bash '{"command":"sudo docker run alpine true","timeout":30}'
tc deny-docker-run 0 bash '{"command":"docker ps","timeout":30}'

printf -- '--- deny-docker-cleanup atoms\n'
tc deny-docker-rmi 1 bash '{"command":"docker rmi app:latest","timeout":30}'
tc deny-docker-system-prune 1 bash '{"command":"docker system prune -af","timeout":30}'
tc deny-docker-volume-rm 1 bash '{"command":"docker volume rm cache","timeout":30}'
tc deny-docker-rmi 0 bash '{"command":"docker images","timeout":30}'

printf -- '--- deny-docker-compose-down\n'
tc deny-docker-compose-down 1 bash '{"command":"docker compose down","timeout":30}'
tc deny-docker-compose-down 1 bash '{"command":"docker compose down --volumes","timeout":30}'
tc deny-docker-compose-down 0 bash '{"command":"docker compose ps","timeout":30}'

printf -- '--- presets\n'
if jq -e '
  .["deny-docker-container-management"].preset == [
    "meffmadd/pi-assert-rules/deny-docker-run",
    "meffmadd/pi-assert-rules/deny-docker-exec",
    "meffmadd/pi-assert-rules/deny-docker-rm"
  ] and .["deny-docker-cleanup"].preset == [
    "meffmadd/pi-assert-rules/deny-docker-rmi",
    "meffmadd/pi-assert-rules/deny-docker-system-prune",
    "meffmadd/pi-assert-rules/deny-docker-volume-rm"
  ]
' "$TARGET" >/dev/null 2>&1; then
  PASSED=$((PASSED+1)); printf '  %b✓%b Docker presets contain their direct atomic members\n' "$C_OK" "$C_N"
else
  FAILED=$((FAILED+1)); printf '  %b✗%b Docker presets contain their direct atomic members\n' "$C_BAD" "$C_N"
fi

summary

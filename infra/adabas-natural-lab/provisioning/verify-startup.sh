#!/usr/bin/env bash
set -euo pipefail
check_only=false
case "${1:-}" in
  "") ;;
  --check-only) check_only=true ;;
  *) printf 'ERROR: unsupported validation mode.\n' >&2; exit 2 ;;
esac

if ! $check_only; then systemctl start docker; fi
deadline=$((SECONDS + 480))
containers=(adabas-db natural-ce ttyd-viewer caddy)
if [[ -f /opt/sifap/guest-viewer-enabled ]]; then containers+=(sifap-viewer-access); fi
for container in "${containers[@]}"; do
  if ! state="$(docker inspect --format '{{.State.Running}}' "$container")"; then
    printf 'ERROR: cannot inspect required container %s; verify Docker and the runtime installation.\n' "$container" >&2
    exit 1
  fi
  if [[ "$state" != true ]]; then
    if $check_only; then printf 'ERROR: %s is not running.\n' "$container" >&2; exit 1; fi
    docker start "$container" > /dev/null
  fi
  while :; do
    health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "$container")"
    if [[ "$health" == healthy ]]; then break; fi
    if [[ "$health" == missing ]] || ((SECONDS >= deadline)); then
      printf 'ERROR: %s readiness failed (%s).\n' "$container" "$health" >&2
      exit 1
    fi
    sleep 5
  done
  printf 'Verified healthy: %s\n' "$container"
done
docker exec adabas-db sh /usr/local/bin/healthcheck.sh > /dev/null
printf 'SIFAP_STARTUP_VALIDATION=OK\n'

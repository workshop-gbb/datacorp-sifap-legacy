#!/usr/bin/env bash
# Shared helpers for SIFAP legacy lab provisioning.
# shellcheck disable=SC2034
set -euo pipefail

PROVISIONING_DIR="${PROVISIONING_DIR:-/opt/sifap/provisioning}"
WORK_DIR="${SIFAP_PROVISIONING_WORK_DIR:-${PROVISIONING_DIR}/work}"
CORPUS_DIR="${SIFAP_CORPUS_DIR:-/opt/sifap/corpus}"
HOST_ADABAS_ENV="${HOST_ADABAS_ENV:-/opt/sifap/adabas.env}"
ADABAS_CONTAINER="${ADABAS_CONTAINER:-adabas-db}"
NATURAL_CONTAINER="${NATURAL_CONTAINER:-natural-ce}"
NATURAL_LIBRARY="${NATURAL_LIBRARY:-SIFAPPRD}"
LOG_FILE="${SIFAP_PROVISIONING_LOG:-/var/log/sifap-provisioning.log}"
ADABAS_WORK_DIR="${ADABAS_WORK_DIR:-/data/sifap-provisioning}"
NATURAL_WORK_DIR="${NATURAL_WORK_DIR:-/opt/softwareag/Natural/sifap-provisioning}"
ADABAS_DBID="${ADABAS_DBID:-}"

log() {
  printf '%s [%s] %s\n' "$(date -Is)" "${1:-INFO}" "${*:2}"
}

info() { log INFO "$*"; }
warn() { log WARN "$*"; }
fatal() { log ERROR "$*"; exit 1; }

retry() {
  local attempts="$1" delay="$2" label="$3"
  shift 3
  local n=1
  while true; do
    if "$@"; then
      return 0
    fi
    if [ "$n" -ge "$attempts" ]; then
      fatal "${label} failed after ${attempts} attempts"
    fi
    warn "${label} failed (attempt ${n}/${attempts}); retrying in ${delay}s"
    sleep "$delay"
    n=$((n + 1))
    delay=$((delay * 2))
    if [ "$delay" -gt 60 ]; then delay=60; fi
  done
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fatal "Required command not found on host: $1"
}

container_running() {
  docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null | grep -qx 'true'
}

container_health() {
  docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$1" 2>/dev/null || true
}

container_exec() {
  local container="$1"
  shift
  docker exec "$container" "$@"
}

container_sh() {
  local container="$1" script="$2"
  docker exec "$container" sh -lc "$script"
}

container_sh_root() {
  # natural-ce runs as uid 1724, so a plain `docker exec` cannot chown files that
  # `docker cp` created as root. Ownership fixes must therefore run as root.
  local container="$1" script="$2"
  docker exec -u 0 "$container" sh -lc "$script"
}

container_has_command() {
  local container="$1" cmd="$2"
  docker exec "$container" sh -lc "command -v '$cmd' >/dev/null 2>&1"
}

load_adabas_env() {
  if [ -r "$HOST_ADABAS_ENV" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$HOST_ADABAS_ENV"
    set +a
  fi
  if [ -z "${ADABAS_DBID:-}" ] && [ -r /opt/sifap/dbmapping.txt ]; then
    ADABAS_DBID="$(awk -F= '/^[[:space:]]*[0-9]+[[:space:]]*=/{gsub(/[[:space:]]/,"",$1); print $1; exit}' /opt/sifap/dbmapping.txt)"
  fi
  if [ -z "${ADABAS_DBID:-}" ]; then
    ADABAS_DBID="${adabas_dbid:-12}"
  fi
  export ADABAS_DBID
}

wait_for_container() {
  local container="$1" timeout_seconds="${2:-600}" start now health
  start="$(date +%s)"
  while true; do
    if container_running "$container"; then
      health="$(container_health "$container")"
      if [ "$health" = "healthy" ] || [ "$health" = "none" ]; then
        info "Container ${container} is running (health=${health})"
        return 0
      fi
      info "Container ${container} health=${health}; waiting"
    else
      info "Container ${container} is not running yet; waiting"
    fi
    now="$(date +%s)"
    if [ $((now - start)) -ge "$timeout_seconds" ]; then
      fatal "Timed out waiting for ${container} after ${timeout_seconds}s"
    fi
    sleep 10
  done
}

wait_for_adabas_ready() {
  local timeout_seconds="${1:-900}" start now
  wait_for_container "$ADABAS_CONTAINER" "$timeout_seconds"
  start="$(date +%s)"
  while true; do
    if container_sh "$ADABAS_CONTAINER" "sh /usr/local/bin/healthcheck.sh >/dev/null 2>&1"; then
      info "Adabas healthcheck reports ready"
      return 0
    fi
    now="$(date +%s)"
    if [ $((now - start)) -ge "$timeout_seconds" ]; then
      fatal "Timed out waiting for Adabas readiness after ${timeout_seconds}s"
    fi
    info "Adabas not ready yet; waiting"
    sleep 15
  done
}

prepare_work_dir() {
  mkdir -p "$WORK_DIR"
}

copy_into_container() {
  local source="$1" container="$2" dest="$3"
  docker cp "$source" "${container}:${dest}"
}

natural_batch() {
  local command_file="$1" object_input_file="$2" output_file="$3" label="$4"
  local base
  base="$(basename "$command_file")"
  docker exec "$NATURAL_CONTAINER" sh -lc "mkdir -p '$NATURAL_WORK_DIR'"
  docker cp "$command_file" "${NATURAL_CONTAINER}:${NATURAL_WORK_DIR}/${base}.cmd"
  docker cp "$object_input_file" "${NATURAL_CONTAINER}:${NATURAL_WORK_DIR}/${base}.obj"
  local rc=0
  docker exec "$NATURAL_CONTAINER" sh -lc \
    "natural BATCHMODE CMSYNIN='${NATURAL_WORK_DIR}/${base}.cmd' CMOBJIN='${NATURAL_WORK_DIR}/${base}.obj' CMPRINT='${NATURAL_WORK_DIR}/${base}.out' BMSIM=MF BMCONTROL=OFF ECHO=ON CC=ON >/dev/null 2>&1" || rc=$?
  docker cp "${NATURAL_CONTAINER}:${NATURAL_WORK_DIR}/${base}.out" "$output_file" || fatal "Natural ${label} did not produce CMPRINT output"
  if grep -E 'NAT[0-9]{4}|Natural Startup Error|Natural error|ERROR NO\.|Syntax error|Invalid command' "$output_file" >/dev/null 2>&1; then
    fatal "Natural ${label} reported an error; see ${output_file}"
  fi
  if [ "$rc" -ne 0 ]; then
    warn "Natural ${label} exited with return code ${rc}; CMPRINT was captured at ${output_file}"
  fi
}

extract_nat_error() {
  local file="$1"
  grep -E 'NAT[0-9]{4}|Natural Startup Error|ERROR NO\.|Syntax error|Invalid command' "$file" || true
}

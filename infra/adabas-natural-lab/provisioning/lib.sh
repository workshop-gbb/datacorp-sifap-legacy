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
FTOUCH_BIN="${FTOUCH_BIN:-/opt/softwareag/Natural/bin/ftouch}"
NATURAL_STACK_TIMEOUT="${NATURAL_STACK_TIMEOUT:-600}"
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

ftouch_register() {
  # Natural does not scan the SRC directory: a library is indexed by FILEDIR.SAG
  # and only ftouch can write that index. Without this, every member is invisible
  # and Natural answers NAT0082. ftouch takes exactly one file per call and
  # enforces the 8.3 member-name limit. 'sm' marks the member as structured
  # mode; without it Natural reads the source as reporting mode and answers
  # NAT0610 for any structured statement.
  local container="$1" library="$2" src_dir="$3"
  docker exec "$container" sh -lc "
    cd '${src_dir}' || exit 1
    rc=0
    for f in *.NS*; do
      [ -e \"\$f\" ] || continue
      if ! ${FTOUCH_BIN} lib=${library} sm -s \"\$f\" 2>&1 | grep -q 'executed with success'; then
        echo \"ftouch failed for \$f\" >&2
        rc=1
      fi
    done
    exit \$rc
  " || fatal "ftouch could not register every source in ${library}; member names must fit 8 characters plus a 3-character extension"
}

natural_stack() {
  # Natural Community Edition rejects BATCHMODE outright ("Natural Startup
  # Error 42 - Batch mode not available for Natural Community Edition"), so the
  # documented CMSYNIN/CMOBJIN path cannot be used here. Natural does accept a
  # STACK on an interactive session, which expect drives on a pty. SM=ON must
  # match the mode the sources were registered with, or Natural answers NAT1155.
  local label="$1" library="$2" output_file="$3"
  shift 3
  local members=("$@") stack="LOGON ${library}" member
  for member in "${members[@]}"; do
    stack="${stack};READ ${member};CATALOG ${member}"
  done
  stack="${stack};FIN"

  local exp="${WORK_DIR}/${label}.exp"
  cat > "$exp" <<EOF_EXP
set timeout ${NATURAL_STACK_TIMEOUT}
log_file -a ${NATURAL_WORK_DIR}/${label}.log
spawn natural SM=ON "STACK=(${stack})"
expect {
  -re "MORE|More" { send "\r"; exp_continue }
  eof { }
  timeout { puts "SIFAP-TIMEOUT" }
}
EOF_EXP

  container_sh "$NATURAL_CONTAINER" "mkdir -p '$NATURAL_WORK_DIR' && rm -f '${NATURAL_WORK_DIR}/${label}.log'"
  copy_into_container "$exp" "$NATURAL_CONTAINER" "${NATURAL_WORK_DIR}/${label}.exp"
  container_sh "$NATURAL_CONTAINER" "expect '${NATURAL_WORK_DIR}/${label}.exp' >/dev/null 2>&1 || true"
  # Strip the terminal escape sequences the pty session emits, otherwise the
  # error scan below matches nothing useful.
  container_sh "$NATURAL_CONTAINER" \
    "sed -e 's/\x1b\[[0-9;?]*[a-zA-Z]//g' -e 's/\x1b[()][A-Z0-9]//g' '${NATURAL_WORK_DIR}/${label}.log' | tr -d '\r' > '${NATURAL_WORK_DIR}/${label}.out'"
  docker cp "${NATURAL_CONTAINER}:${NATURAL_WORK_DIR}/${label}.out" "$output_file" \
    || fatal "Natural ${label} produced no session output"

  if grep -q 'SIFAP-TIMEOUT' "$output_file" 2>/dev/null; then
    fatal "Natural ${label} timed out after ${NATURAL_STACK_TIMEOUT}s; see ${output_file}"
  fi
  # NAT0084 only means the source was already saved, which is expected on a rerun.
  if grep -oE 'NAT[0-9]{4}' "$output_file" 2>/dev/null | grep -qvE 'NAT0084'; then
    return 1
  fi
}

assert_cataloged() {
  local library="$1" expected="$2" found
  found="$(container_sh "$NATURAL_CONTAINER" "ls /opt/softwareag/Natural/fuser/${library}/GP 2>/dev/null | wc -l" | tr -d ' \r')"
  [ "${found:-0}" -ge "$expected" ] \
    || fatal "${library} has ${found:-0} cataloged objects, expected at least ${expected}"
  info "${library}: ${found} cataloged objects in GP"
}

extract_nat_error() {
  local file="$1"
  grep -E 'NAT[0-9]{4}|Natural Startup Error|ERROR NO\.|Syntax error|Invalid command' "$file" || true
}

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

BATCH_WORK_DIR="${SIFAP_BATCH_WORK_DIR:-/mnt/sifap-data/work}"
BATCH_TIMEOUT="${SIFAP_BATCH_TIMEOUT:-${NATURAL_STACK_TIMEOUT:-600}}"
SOURCE_DIR="${SOURCE_DIR:-${CORPUS_DIR}/natural-programs}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

usage() {
  cat <<USAGE
Usage:
  $0 job SIFAPJ01 [YYYYMM]
  $0 job SIFAPJ02 [YYYYMM]
  $0 program BATCHPGT [YYYYMM]
  $0 program BATCHREL [YYYYMM]
  $0 program RELPGT [start-YYYYMM] [end-YYYYMM] [program-code|0000]
  $0 program RELAUDIT [start-YYYYMMDD] [end-YYYYMMDD] [action] [user] [table] [T|I]
  $0 program BATCHCON [YYYYMM] [return-file-name]

Batch output and Natural session logs are written under ${BATCH_WORK_DIR}.
USAGE
}

require_period() {
  local period="$1"
  [[ "$period" =~ ^[0-9]{6}$ ]] || fatal "Invalid period '${period}'; expected YYYYMM"
}

require_date8_or_zero() {
  local value="$1" label="$2"
  [[ "$value" =~ ^0$|^[0-9]{8}$ ]] || fatal "Invalid ${label} '${value}'; expected YYYYMMDD or 0"
}

prepare_batch_work_dir() {
  mkdir -p "$BATCH_WORK_DIR" "$BATCH_WORK_DIR/logs"
  chmod 0775 "$BATCH_WORK_DIR" "$BATCH_WORK_DIR/logs" 2>/dev/null || true
}

output_path() {
  local label="$1"
  printf '%s/logs/%s-%s.out' "$BATCH_WORK_DIR" "$label" "$TIMESTAMP"
}

input_path() {
  local label="$1"
  printf '%s/logs/%s-%s.input' "$BATCH_WORK_DIR" "$label" "$TIMESTAMP"
}

copy_expected_artifacts() {
  local label="$1"
  local artifact_dir="$BATCH_WORK_DIR/${label}-${TIMESTAMP}"
  mkdir -p "$artifact_dir"

  # The VM/container contract wires Natural CMWKF*, CMPRINT and CMPRT* to
  # /mnt/sifap-data/work.  Preserve whatever files that contract produced for
  # this run without inventing another work-file location.
  find "$BATCH_WORK_DIR" -maxdepth 1 -type f \( \
    -name 'CMWKF*' -o -name 'CMPRINT*' -o -name 'CMPRT*' -o -name '*.lst' -o -name '*.dat' \
  \) -exec cp -p {} "$artifact_dir/" \; 2>/dev/null || true
}

scan_natural_failure() {
  local output_file="$1" program="$2" rc=0

  if grep -E 'SIFAP-TIMEOUT|Natural Startup Error|Syntax error|Invalid command' "$output_file" >/dev/null 2>&1; then
    warn "Natural session failed for ${program}:"
    extract_nat_error "$output_file"
    return 12
  fi

  if grep -E 'NATURAL ERROR NO\.:|NATURAL ERROR:|LINE\.+:|PROGRAM\.+:' "$output_file" >/dev/null 2>&1; then
    warn "${program} reported its ON ERROR block:"
    grep -E 'NATURAL ERROR|LINE\.+:|PROGRAM\.+:|PGM:|PERIOD\.+:|LAST ' "$output_file" || true
    return 12
  fi

  if grep -oE 'NAT[0-9]{4}' "$output_file" 2>/dev/null | grep -qvE 'NAT0084'; then
    warn "${program} emitted Natural NAT error code(s):"
    extract_nat_error "$output_file"
    return 12
  fi

  case "$program" in
    BATCHPGT)
      if grep -q 'NO PAYMENT GENERATED FOR THE PERIOD' "$output_file"; then
        warn "BATCHPGT generated no payments. This is the legacy rerun-safe duplicate-period outcome (RC=8)."
        rc=8
      elif grep -q 'CMWKF02 HAS REJECTED RECORDS' "$output_file"; then
        warn "BATCHPGT completed with rejected records (legacy RC=4); inspect CMWKF02."
        rc=4
      fi
      ;;
    BATCHREL)
      if grep -q 'NO PAYMENTS IN PERIOD' "$output_file"; then
        warn "BATCHREL completed with no activity (legacy RC=4)."
        rc=4
      fi
      ;;
    BATCHCON)
      if grep -q 'RECONCILIATION HAS PENDING ITEMS' "$output_file"; then
        warn "BATCHCON completed with discrepancies/not-found items (legacy RC=4)."
        rc=4
      fi
      ;;
  esac

  return "$rc"
}

run_program() {
  local program="$1"
  shift
  local label input_file output_file natural_rc scan_rc
  label="$(printf '%s' "$program" | tr '[:upper:]' '[:lower:]')"
  input_file="$(input_path "$label")"
  output_file="$(output_path "$label")"

  case "$program" in
    BATCHPGT|BATCHREL)
      local period="${1:-$(date +%Y%m)}"
      require_period "$period"
      printf '%s\n' "$period" > "$input_file"
      ;;
    RELPGT)
      local start_period="${1:-$(date +%Y%m)}" end_period="${2:-${1:-$(date +%Y%m)}}" filter="${3:-0000}"
      require_period "$start_period"
      require_period "$end_period"
      [[ "$filter" =~ ^[0-9]{1,4}$ ]] || fatal "Invalid RELPGT program-code filter '${filter}'; expected 0-9999"
      printf '%s\n%s\n%04d\n' "$start_period" "$end_period" "$((10#$filter))" > "$input_file"
      ;;
    RELAUDIT)
      local start_date="${1:-0}" end_date="${2:-0}" action="${3:-}" user="${4:-}" table="${5:-}" output="${6:-T}"
      require_date8_or_zero "$start_date" start-date
      require_date8_or_zero "$end_date" end-date
      [[ "$output" =~ ^[TI]$ ]] || fatal "Invalid RELAUDIT output '${output}'; expected T or I"
      printf '%s\n%s\n%s\n%s\n%s\n%s\n' "$start_date" "$end_date" "$action" "$user" "$table" "$output" > "$input_file"
      ;;
    BATCHCON)
      local period="${1:-$(date +%Y%m)}" return_file="${2:-CMWKF01}"
      require_period "$period"
      printf '%s\n%s\n' "$period" "$return_file" > "$input_file"
      ;;
    *)
      fatal "Unsupported batch program '${program}'"
      ;;
  esac

  info "Running Natural program ${program}; input=${input_file}; output=${output_file}; timeout=${BATCH_TIMEOUT}s"
  NATURAL_STACK_TIMEOUT="$BATCH_TIMEOUT" natural_run "$label-${TIMESTAMP}" "$NATURAL_LIBRARY" "$program" "$input_file" "$output_file" || natural_rc=$?
  natural_rc="${natural_rc:-0}"
  if [ "$natural_rc" -ne 0 ]; then
    warn "Natural runner detected a low-level error for ${program}"
  fi

  scan_rc=0
  scan_natural_failure "$output_file" "$program" || scan_rc=$?
  copy_expected_artifacts "$label"

  if [ "$natural_rc" -ne 0 ] && [ "$scan_rc" -eq 0 ]; then
    scan_rc=12
  fi

  if [ "$scan_rc" -eq 0 ]; then
    info "${program} completed successfully; log=${output_file}"
  else
    warn "${program} completed with legacy/error RC=${scan_rc}; log=${output_file}"
  fi
  return "$scan_rc"
}

run_job() {
  local job="$1"
  shift
  case "$job" in
    SIFAPJ01)
      local period="${1:-202601}" rc=0
      require_period "$period"
      info "SIFAPJ01 declares STEP010=BATCHPGT, CMSYNIN period=${period}, CMWKF01 extract, CMWKF02 rejects; STEP020 copy runs only for RC<=4."
      run_program BATCHPGT "$period" || rc=$?
      if [ "$rc" -le 4 ]; then
        info "SIFAPJ01 STEP020 equivalent: preserving generated CMWKF01 under ${BATCH_WORK_DIR}; no mainframe IEBGENER copy is required in the lab."
      else
        warn "SIFAPJ01 STEP020 skipped because STEP010 RC=${rc}; STEP030 failure notice would run on the mainframe."
      fi
      return "$rc"
      ;;
    SIFAPJ02)
      local period="${1:-202601}" rc1=0 rc2=0
      require_period "$period"
      info "SIFAPJ02 declares STEP010=BATCHREL followed by STEP020=RELPGT only when STEP010 RC<=4; both use period ${period}."
      run_program BATCHREL "$period" || rc1=$?
      if [ "$rc1" -le 4 ]; then
        run_program RELPGT "$period" "$period" 0000 || rc2=$?
      else
        warn "SIFAPJ02 STEP020 skipped because STEP010 RC=${rc1}."
      fi
      if [ "$rc1" -ge 12 ]; then return "$rc1"; fi
      if [ "$rc2" -ge 12 ]; then return "$rc2"; fi
      if [ "$rc1" -ne 0 ]; then return "$rc1"; fi
      return "$rc2"
      ;;
    *)
      fatal "Unsupported job '${job}'; expected SIFAPJ01 or SIFAPJ02"
      ;;
  esac
}

main() {
  local mode="${1:-}"
  if [ -z "$mode" ] || [ "$mode" = "-h" ] || [ "$mode" = "--help" ]; then
    usage
    exit 0
  fi
  shift

  require_command docker
  load_adabas_env
  wait_for_adabas_ready "${SIFAP_ADABAS_READY_TIMEOUT:-900}"
  wait_for_container "$NATURAL_CONTAINER" "${SIFAP_NATURAL_READY_TIMEOUT:-300}"
  prepare_work_dir
  prepare_batch_work_dir
  [ -d "$SOURCE_DIR" ] || warn "Natural source directory not present at ${SOURCE_DIR}; proceeding with cataloged library ${NATURAL_LIBRARY}"

  case "$mode" in
    job)
      [ "$#" -ge 1 ] || fatal "Missing job name"
      run_job "$@"
      ;;
    program)
      [ "$#" -ge 1 ] || fatal "Missing program name"
      run_program "$@"
      ;;
    *)
      usage
      fatal "Invalid mode '${mode}'"
      ;;
  esac
}

main "$@"

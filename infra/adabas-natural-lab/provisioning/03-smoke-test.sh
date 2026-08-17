#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

SEED_DIR="${SEED_DIR:-${PROVISIONING_DIR}/seed}"
SMOKE_WORK="${WORK_DIR}/smoke-test"
SMOKE_PERIOD="${SIFAP_SMOKE_PERIOD:-202601}"
SMOKE_CPF="${SIFAP_SMOKE_CPF:-}"

find_seed_cpf() {
  if [ -n "$SMOKE_CPF" ]; then printf '%s\n' "$SMOKE_CPF"; return 0; fi
  [ -r "$SEED_DIR/beneficiary.dat" ] || fatal "Cannot infer smoke CPF because seed file is missing: $SEED_DIR/beneficiary.dat"
  grep -Eo '[0-9]{11}' "$SEED_DIR/beneficiary.dat" | head -1 || true
}

run_natural_program() {
  local label="$1" commands="$2" input="$3" output="$4"
  local cmd_file="$SMOKE_WORK/${label}.cmsynin" obj_file="$SMOKE_WORK/${label}.cmobjin"
  printf '%s\n' "$commands" > "$cmd_file"
  printf '%s\n' "$input" > "$obj_file"
  natural_batch "$cmd_file" "$obj_file" "$output" "$label"
}

assert_contains() {
  local file="$1" pattern="$2" message="$3"
  if grep -E "$pattern" "$file" >/dev/null 2>&1; then
    info "PASS: ${message}"
  else
    warn "FAIL: ${message}"
    warn "Expected pattern: ${pattern}"
    return 1
  fi
}

main() {
  require_command docker
  load_adabas_env
  wait_for_adabas_ready "${SIFAP_ADABAS_READY_TIMEOUT:-900}"
  wait_for_container "$NATURAL_CONTAINER" "${SIFAP_NATURAL_READY_TIMEOUT:-300}"
  prepare_work_dir
  rm -rf "$SMOKE_WORK"
  mkdir -p "$SMOKE_WORK"

  local cpf failures=0 suffix
  cpf="$(find_seed_cpf)"
  [ -n "$cpf" ] || fatal "No 11-digit CPF found in $SEED_DIR/beneficiary.dat; set SIFAP_SMOKE_CPF explicitly"
  suffix="${cpf: -5}"

  info "Running CONSBENF smoke test for seeded CPF ending in ${suffix}"
  run_natural_program consbenf \
"LOGON ${NATURAL_LIBRARY}
CONSBENF
FIN" \
"C
${cpf}
0" \
"$SMOKE_WORK/consbenf.out" || failures=$((failures + 1))
  assert_contains "$SMOKE_WORK/consbenf.out" 'SIFAP - BENEFICIARY INFORMATION|BENEFICIARY QUERY' 'CONSBENF produced beneficiary screen/output' || failures=$((failures + 1))
  assert_contains "$SMOKE_WORK/consbenf.out" "${suffix}" 'CONSBENF output contains the expected seeded CPF suffix' || failures=$((failures + 1))

  info "Running BATCHPGT smoke test for period ${SMOKE_PERIOD}"
  run_natural_program batchpgt \
"LOGON ${NATURAL_LIBRARY}
BATCHPGT
FIN" \
"${SMOKE_PERIOD}" \
"$SMOKE_WORK/batchpgt.out" || failures=$((failures + 1))
  assert_contains "$SMOKE_WORK/batchpgt.out" 'BATCHPGT - MONTHLY PAYMENT GENERATION' 'BATCHPGT banner is present' || failures=$((failures + 1))
  assert_contains "$SMOKE_WORK/batchpgt.out" "PERIOD.*${SMOKE_PERIOD}|${SMOKE_PERIOD}" 'BATCHPGT output includes the seeded period' || failures=$((failures + 1))
  assert_contains "$SMOKE_WORK/batchpgt.out" 'PAYMENTS GENERATED|NO PAYMENT GENERATED|TOTAL PROCESSED' 'BATCHPGT produced a non-empty business summary' || failures=$((failures + 1))

  if [ "$failures" -eq 0 ]; then
    info "SMOKE TEST SUMMARY: PASS"
  else
    warn "SMOKE TEST SUMMARY: FAIL (${failures} assertion(s) failed)"
    warn "Outputs retained under ${SMOKE_WORK}"
    exit 1
  fi
}

main "$@"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

SEED_DIR="${SEED_DIR:-${PROVISIONING_DIR}/seed}"
DDM_REPORT_DIR="${DDM_REPORT_DIR:-${CORPUS_DIR}/adabas-ddms}"
ENCODER="${ENCODER:-${PROVISIONING_DIR}/adacmp_input.py}"
SMOKE_WORK="${WORK_DIR}/smoke-test"
SMOKE_PERIOD="${SIFAP_SMOKE_PERIOD:-202601}"
SMOKE_CPF="${SIFAP_SMOKE_CPF:-}"
# Natural pauses with MORE whenever a page fills. Redirected input answers each
# pause with a blank line, so the run needs more of them than the longest page
# run it can produce; the payment history is capped at 12 rows.
SMOKE_PAGE_KEYS="${SIFAP_SMOKE_PAGE_KEYS:-8}"

find_seed_cpf() {
  if [ -n "$SMOKE_CPF" ]; then printf '%s\n' "$SMOKE_CPF"; return 0; fi
  [ -r "$SEED_DIR/beneficiary.dat" ] || fatal "Cannot infer smoke CPF because seed file is missing: $SEED_DIR/beneficiary.dat"
  [ -r "$DDM_REPORT_DIR/BENEFIC.ddm" ] || fatal "Cannot infer smoke CPF because the DDM is missing: $DDM_REPORT_DIR/BENEFIC.ddm"
  # The seed is fixed-width binary and NUM-REGISTRATION sits immediately before
  # NUM-CPF, so the two run together as 22 digits and no pattern match can tell
  # them apart. Read the CPF at the offset the DDM gives it instead, which is
  # the same derivation that built the file.
  python3 "$ENCODER" \
    --ddm "$DDM_REPORT_DIR/BENEFIC.ddm" \
    --seed "$SEED_DIR/beneficiary.dat" \
    --print-field NUM-CPF
}

run_natural_program() {
  local label="$1" program="$2" input="$3" output="$4"
  local input_file="$SMOKE_WORK/${label}.input"
  { printf '%s\n' "$input"
    for _ in $(seq "$SMOKE_PAGE_KEYS"); do printf '\n'; done
  } > "$input_file"
  natural_run "$label" "$NATURAL_LIBRARY" "$program" "$input_file" "$output"
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
  require_command python3
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
  # The first ENTER submits the screen with only the search type filled, which
  # the program answers with CPF NOT PROVIDED and a REINPUT that marks the CPF
  # field; the CPF then goes into that field. This is the corpus's own screen
  # flow, not a workaround.
  run_natural_program consbenf CONSBENF \
"C
${cpf}" \
"$SMOKE_WORK/consbenf.out" || failures=$((failures + 1))
  assert_contains "$SMOKE_WORK/consbenf.out" 'SIFAP - BENEFICIARY INFORMATION|BENEFICIARY QUERY' 'CONSBENF produced beneficiary screen/output' || failures=$((failures + 1))
  assert_contains "$SMOKE_WORK/consbenf.out" "${suffix}" 'CONSBENF output contains the expected seeded CPF suffix' || failures=$((failures + 1))
  if grep -Ei 'not found|não encontrado|nao encontrado' "$SMOKE_WORK/consbenf.out" >/dev/null 2>&1; then
    warn "FAIL: CONSBENF reported that the seeded beneficiary was not found"
    failures=$((failures + 1))
  else
    info "PASS: CONSBENF did not report the seeded beneficiary as missing"
  fi

  info "Running BATCHPGT smoke test for period ${SMOKE_PERIOD}"
  # BATCHPGT writes work files, and only a DEFINE WORK FILE inside a Natural
  # program allocates one: the CMWKF01 environment variables that stand in for
  # the mainframe DDs are ignored here and the program stops with NAT1500.
  # 04-batch-jobs.sh already generates that driver, maps each program's files
  # and reads the legacy return codes, so the batch path belongs there. This
  # check stays on what it can answer on its own: the program is cataloged, it
  # runs, and it reaches the seeded data.
  run_natural_program batchpgt BATCHPGT \
"${SMOKE_PERIOD}" \
"$SMOKE_WORK/batchpgt.out" || true
  assert_contains "$SMOKE_WORK/batchpgt.out" 'BATCHPGT - MONTHLY PAYMENT GENERATION' 'BATCHPGT banner is present' || failures=$((failures + 1))
  assert_contains "$SMOKE_WORK/batchpgt.out" "PERIOD.*${SMOKE_PERIOD}|${SMOKE_PERIOD}" 'BATCHPGT output includes the seeded period' || failures=$((failures + 1))
  assert_contains "$SMOKE_WORK/batchpgt.out" 'LAST CPF READ|PROCESSED:|PAYMENTS GENERATED|NO PAYMENT GENERATED|TOTAL PROCESSED' 'BATCHPGT reached the seeded beneficiary data' || failures=$((failures + 1))
  # The corpus carries the findings Stage 1 is built around, so a program that
  # stops in its own ON ERROR block is reproducing the legacy, not failing the
  # lab. Surface it without judging it.
  if grep -q 'NATURAL ERROR' "$SMOKE_WORK/batchpgt.out" 2>/dev/null; then
    warn "BATCHPGT stopped in its own ON ERROR block; this is legacy behaviour, see ${SMOKE_WORK}/batchpgt.out"
    grep -E 'NATURAL ERROR|LINE\.+:|PROGRAM\.+:|LAST ' "$SMOKE_WORK/batchpgt.out" || true
  fi

  if [ "$failures" -eq 0 ]; then
    info "SMOKE TEST SUMMARY: PASS"
  else
    warn "SMOKE TEST SUMMARY: FAIL (${failures} assertion(s) failed)"
    warn "Outputs retained under ${SMOKE_WORK}"
    exit 1
  fi
}

main "$@"

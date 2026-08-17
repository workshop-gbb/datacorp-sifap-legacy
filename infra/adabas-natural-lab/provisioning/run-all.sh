#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROVISIONING_DIR="${PROVISIONING_DIR:-$SCRIPT_DIR}"
export SIFAP_PROVISIONING_LOG="${SIFAP_PROVISIONING_LOG:-/var/log/sifap-provisioning.log}"

mkdir -p "$(dirname "$SIFAP_PROVISIONING_LOG")"
touch "$SIFAP_PROVISIONING_LOG"
exec > >(tee -a "$SIFAP_PROVISIONING_LOG") 2>&1

# shellcheck source=lib.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

DDMS=(BENEFIC SOCPROG PAYMENT AUDIT)
PROVISIONED_MARKER="${SIFAP_PROVISIONED_MARKER:-/opt/sifap/PROVISIONED}"
PHASE="${SIFAP_PHASE:-auto}"

run_base() {
  info "Starting SIFAP base phase"
  "$SCRIPT_DIR/01-load-adabas.sh" "$@"
  SIFAP_NATURAL_BUILD_PHASE=base "$SCRIPT_DIR/02-build-natural.sh"
  info "SIFAP base phase completed; DDM-dependent objects are intentionally deferred"
}

run_finalize() {
  info "Starting SIFAP finalize phase"
  require_ddms_cataloged "$NATURAL_LIBRARY" "${DDMS[@]}"
  SIFAP_NATURAL_BUILD_PHASE=finalize "$SCRIPT_DIR/02-build-natural.sh"
  "$SCRIPT_DIR/03-smoke-test.sh"
  mkdir -p "$(dirname "$PROVISIONED_MARKER")"
  touch "$PROVISIONED_MARKER"
  info "SIFAP finalize phase completed; wrote ${PROVISIONED_MARKER}"
}

main() {
  info "SIFAP provisioning started (phase=${PHASE})"
  require_command docker
  load_adabas_env
  wait_for_adabas_ready "${SIFAP_ADABAS_READY_TIMEOUT:-900}"
  wait_for_container "$NATURAL_CONTAINER" "${SIFAP_NATURAL_READY_TIMEOUT:-300}"

  case "$PHASE" in
    base)
      run_base "$@"
      ;;
    finalize)
      run_finalize
      ;;
    auto)
      run_base "$@"
      if ddms_cataloged "$NATURAL_LIBRARY" "${DDMS[@]}"; then
        info "Required DDMs are present; continuing to finalize phase"
        run_finalize
      else
        info "Waiting for DDMs: create BENEFIC, SOCPROG, PAYMENT, and AUDIT in NaturalONE, then rerun with SIFAP_PHASE=finalize"
      fi
      ;;
    *)
      fatal "Invalid SIFAP_PHASE=${PHASE}; expected auto, base, or finalize"
      ;;
  esac

  info "SIFAP provisioning command completed (phase=${PHASE})"
}

main "$@"

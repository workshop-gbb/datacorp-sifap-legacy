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

info "SIFAP provisioning started"
require_command docker
load_adabas_env
wait_for_adabas_ready "${SIFAP_ADABAS_READY_TIMEOUT:-900}"
wait_for_container "$NATURAL_CONTAINER" "${SIFAP_NATURAL_READY_TIMEOUT:-300}"

"$SCRIPT_DIR/01-load-adabas.sh" "$@"
"$SCRIPT_DIR/02-build-natural.sh"
"$SCRIPT_DIR/03-smoke-test.sh"

info "SIFAP provisioning completed successfully"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

SOURCE_DIR="${SOURCE_DIR:-${CORPUS_DIR}/natural-programs}"
BUILD_WORK="${WORK_DIR}/natural-build"
BUILD_PHASE="${SIFAP_NATURAL_BUILD_PHASE:-${1:-auto}}"

# DDMs are a manual NaturalONE step in Natural CE. These short member names
# remain here so provisioning can verify the generated .NGD objects.
DDMS=(BENEFIC SOCPROG PAYMENT AUDIT)
DATA_AREAS=(PDAVALID PDACALC LDASIFAP)
COPYCODES=(CCVALCPF CCAUDIT)
SUBPROGRAMS=(SUBVALCP SUBVALNI VALBENEF VALELEG CALCBENF)
PROGRAMS=(CADBENEF CONSBENF BATCHPGT BATCHREL RELPGT CADPROG CADDEPEN VALDOCS CALCCORR CALCDSCT RELAUDIT BATCHCON)

require_inputs() {
  local member ext
  [ -d "$SOURCE_DIR" ] || fatal "Natural source directory missing: ${SOURCE_DIR}"
  for member in "${DATA_AREAS[@]}"; do
    if [ "$member" = "LDASIFAP" ]; then ext=NSL; else ext=NSA; fi
    [ -r "$SOURCE_DIR/${member}.${ext}" ] || fatal "Missing Natural data area: $SOURCE_DIR/${member}.${ext}"
  done
  for member in "${COPYCODES[@]}"; do [ -r "$SOURCE_DIR/${member}.NSC" ] || fatal "Missing copycode: $SOURCE_DIR/${member}.NSC"; done
  for member in "${SUBPROGRAMS[@]}"; do [ -r "$SOURCE_DIR/${member}.NSN" ] || fatal "Missing subprogram: $SOURCE_DIR/${member}.NSN"; done
  for member in "${PROGRAMS[@]}"; do [ -r "$SOURCE_DIR/${member}.NSP" ] || warn "Program source not found and will be skipped: $SOURCE_DIR/${member}.NSP"; done
}

prepare_sources() {
  local member ext
  rm -rf "$BUILD_WORK"
  mkdir -p "$BUILD_WORK/sifap-src"
  for member in "${DATA_AREAS[@]}"; do
    if [ "$member" = "LDASIFAP" ]; then ext=NSL; else ext=NSA; fi
    cp "$SOURCE_DIR/${member}.${ext}" "$BUILD_WORK/sifap-src/"
  done
  for member in "${COPYCODES[@]}"; do cp "$SOURCE_DIR/${member}.NSC" "$BUILD_WORK/sifap-src/"; done
  case "$BUILD_PHASE" in
    finalize|auto|all)
      for member in "${SUBPROGRAMS[@]}"; do cp "$SOURCE_DIR/${member}.NSN" "$BUILD_WORK/sifap-src/"; done
      for member in "${PROGRAMS[@]}"; do [ -r "$SOURCE_DIR/${member}.NSP" ] && cp "$SOURCE_DIR/${member}.NSP" "$BUILD_WORK/sifap-src/"; done
      ;;
  esac
}

ensure_libraries() {
  container_sh "$NATURAL_CONTAINER" "mkdir -p /opt/softwareag/Natural/fuser/${NATURAL_LIBRARY}/SRC /opt/softwareag/Natural/fuser/${NATURAL_LIBRARY}/GP '$NATURAL_WORK_DIR'"
}

copy_sources_to_fuser() {
  copy_into_container "$BUILD_WORK/sifap-src/." "$NATURAL_CONTAINER" "/opt/softwareag/Natural/fuser/${NATURAL_LIBRARY}/SRC/"
  container_sh_root "$NATURAL_CONTAINER" "chown -R 1724:1724 /opt/softwareag/Natural/fuser/${NATURAL_LIBRARY} '$NATURAL_WORK_DIR'"
}

run_compile_group() {
  local library="$1" label="$2"
  shift 2
  local out="$BUILD_WORK/${label}.out"
  info "Cataloging ${label}: $*"
  if ! natural_stack "$label" "$library" "$out" "$@"; then
    warn "Natural output for ${label}:"
    extract_nat_error "$out"
    return 1
  fi
}

main() {
  require_command docker
  load_adabas_env
  wait_for_container "$NATURAL_CONTAINER" "${SIFAP_NATURAL_READY_TIMEOUT:-300}"
  prepare_work_dir
  require_inputs
  container_has_command "$NATURAL_CONTAINER" natural || fatal "Natural executable not found in ${NATURAL_CONTAINER}"
  prepare_sources
  ensure_libraries
  copy_sources_to_fuser
  ftouch_register "$NATURAL_CONTAINER" "$NATURAL_LIBRARY" "/opt/softwareag/Natural/fuser/${NATURAL_LIBRARY}/SRC"

  case "$BUILD_PHASE" in
    base)
      run_compile_group "$NATURAL_LIBRARY" data-areas "${DATA_AREAS[@]}"
      assert_cataloged "$NATURAL_LIBRARY" "${DATA_AREAS[@]}"
      info "Copycodes installed as source only: ${COPYCODES[*]}"
      info "DDMs are created manually once in NaturalONE; base phase intentionally stops before DDM-dependent objects: ${DDMS[*]}"
      ;;
    finalize)
      require_ddms_cataloged "$NATURAL_LIBRARY" "${DDMS[@]}"
      run_compile_group "$NATURAL_LIBRARY" subprograms "${SUBPROGRAMS[@]}"
      run_compile_group "$NATURAL_LIBRARY" programs "${PROGRAMS[@]}"
      assert_cataloged "$NATURAL_LIBRARY" "${DATA_AREAS[@]}" "${SUBPROGRAMS[@]}" "${PROGRAMS[@]}"
      ;;
    auto|all)
      run_compile_group "$NATURAL_LIBRARY" data-areas "${DATA_AREAS[@]}"
      assert_cataloged "$NATURAL_LIBRARY" "${DATA_AREAS[@]}"
      info "Copycodes installed as source only: ${COPYCODES[*]}"
      if ddms_cataloged "$NATURAL_LIBRARY" "${DDMS[@]}"; then
        run_compile_group "$NATURAL_LIBRARY" subprograms "${SUBPROGRAMS[@]}"
        run_compile_group "$NATURAL_LIBRARY" programs "${PROGRAMS[@]}"
        assert_cataloged "$NATURAL_LIBRARY" "${DATA_AREAS[@]}" "${SUBPROGRAMS[@]}" "${PROGRAMS[@]}"
      else
        info "Skipping subprograms and programs until DDMs are created in NaturalONE: ${DDMS[*]}"
      fi
      ;;
    *)
      fatal "Invalid SIFAP_NATURAL_BUILD_PHASE=${BUILD_PHASE}; expected base, finalize, or auto"
      ;;
  esac

  info "Natural build phase (${BUILD_PHASE}) finished"
}

main "$@"

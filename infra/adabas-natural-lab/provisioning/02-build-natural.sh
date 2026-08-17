#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

DDM_DIR="${DDM_DIR:-${CORPUS_DIR}/adabas-ddms}"
SOURCE_DIR="${SOURCE_DIR:-${CORPUS_DIR}/natural-programs}"
BUILD_WORK="${WORK_DIR}/natural-build"

# Natural member names cannot exceed 8 characters, which is why the DDMs
# carry short names even though the Adabas files are spelled out in full.
DDMS=(BENEFIC SOCPROG PAYMENT AUDIT)
DDM_FILES=(BENEFICIARY.ddm SOCIAL-PROGRAM.ddm PAYMENT.ddm AUDIT.ddm)
DATA_AREAS=(PDAVALID PDACALC LDASIFAP)
COPYCODES=(CCVALCPF CCAUDIT)
SUBPROGRAMS=(SUBVALCP SUBVALNI VALBENEF VALELEG CALCBENF)
PROGRAMS=(CADBENEF CONSBENF BATCHPGT BATCHREL RELPGT CADPROG CADDEPEND VALDOCS CALCCORR CALCDSCT RELAUDIT BATCHCON)

require_inputs() {
  local member ext
  [ -d "$DDM_DIR" ] || fatal "DDM directory missing: ${DDM_DIR}"
  [ -d "$SOURCE_DIR" ] || fatal "Natural source directory missing: ${SOURCE_DIR}"
  for member in "${DDM_FILES[@]}"; do [ -r "$DDM_DIR/$member" ] || fatal "Missing DDM listing: $DDM_DIR/$member"; done
  for member in "${DATA_AREAS[@]}"; do
    if [ "$member" = "LDASIFAP" ]; then ext=NSL; else ext=NSA; fi
    [ -r "$SOURCE_DIR/${member}.${ext}" ] || fatal "Missing Natural data area: $SOURCE_DIR/${member}.${ext}"
  done
  for member in "${COPYCODES[@]}"; do [ -r "$SOURCE_DIR/${member}.NSC" ] || fatal "Missing copycode: $SOURCE_DIR/${member}.NSC"; done
  for member in "${SUBPROGRAMS[@]}"; do [ -r "$SOURCE_DIR/${member}.NSN" ] || fatal "Missing subprogram: $SOURCE_DIR/${member}.NSN"; done
  for member in "${PROGRAMS[@]}"; do [ -r "$SOURCE_DIR/${member}.NSP" ] || warn "Program source not found and will be skipped: $SOURCE_DIR/${member}.NSP"; done
}

generate_nsd() {
  local ddm="$1" out="$2" fnr dbid name
  name="$(awk -F: '/^DDM NAME:/{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); split($2,a," "); print a[1]; exit}' "$ddm")"
  fnr="$(awk '/FNR:[[:space:]]*[0-9]+/{for(i=1;i<=NF;i++) if($i=="FNR:") {print $(i+1); exit}}' "$ddm")"
  dbid="${ADABAS_DBID}"
  {
    printf 'DB: %03d FILE: %03d  - %-32s DEFAULT SEQUENCE: AA\n' "$dbid" "$fnr" "$name"
    printf 'TYPE: ADABAS\n\n'
    printf 'T L DB Name                              F Leng  S D Remark\n'
    printf -- '- - -- --------------------------------  - ----  - - ------------------------\n'
    awk '
      BEGIN { keep=0 }
      /^\* --- IDENTIFICATION ---|^\* --- KEYS ---|^\* --- EVENT IDENTIFICATION ---/ { keep=1 }
      /^\* --- DERIVED DESCRIPTORS ---/ { keep=2; print "* --- DERIVED DESCRIPTORS ---"; next }
      /^\* COLUMN LEGEND/ { exit }
      keep==1 {
        if ($0 ~ /^[[:space:]]*(G|M|P)?[[:space:]]*[12][[:space:]]+[A-Z][A-Z][[:space:]]+/) print $0
      }
      keep==2 {
        if ($0 ~ /^[[:space:]]*S[[:space:]]+[A-Z0-9][A-Z0-9][[:space:]]+/) print "  1" substr($0,3)
        else if ($0 ~ /^[[:space:]]*\/\*/) { sub(/^[[:space:]]*\/\*/, "*      -------- SOURCE FIELD(S) -------\n*     "); print }
      }
    ' "$ddm"
    printf '******DDM OUTPUT TERMINATED******\n'
  } > "$out"
}

prepare_sources() {
  local member ext i
  rm -rf "$BUILD_WORK"
  mkdir -p "$BUILD_WORK/sifap-src" "$BUILD_WORK/sysddm-src"
  for i in "${!DDMS[@]}"; do
    generate_nsd "$DDM_DIR/${DDM_FILES[$i]}" "$BUILD_WORK/sysddm-src/${DDMS[$i]}.NSD"
  done
  for member in "${DATA_AREAS[@]}"; do
    if [ "$member" = "LDASIFAP" ]; then ext=NSL; else ext=NSA; fi
    cp "$SOURCE_DIR/${member}.${ext}" "$BUILD_WORK/sifap-src/"
  done
  for member in "${COPYCODES[@]}"; do cp "$SOURCE_DIR/${member}.NSC" "$BUILD_WORK/sifap-src/"; done
  for member in "${SUBPROGRAMS[@]}"; do cp "$SOURCE_DIR/${member}.NSN" "$BUILD_WORK/sifap-src/"; done
  for member in "${PROGRAMS[@]}"; do [ -r "$SOURCE_DIR/${member}.NSP" ] && cp "$SOURCE_DIR/${member}.NSP" "$BUILD_WORK/sifap-src/"; done
}

ensure_libraries() {
  container_sh "$NATURAL_CONTAINER" "mkdir -p /opt/softwareag/Natural/fuser/${NATURAL_LIBRARY}/SRC /opt/softwareag/Natural/fuser/${NATURAL_LIBRARY}/GP /opt/softwareag/Natural/fuser/SYSDDM/SRC /opt/softwareag/Natural/fuser/SYSDDM/GP '$NATURAL_WORK_DIR'"
}

copy_sources_to_fuser() {
  copy_into_container "$BUILD_WORK/sifap-src/." "$NATURAL_CONTAINER" "/opt/softwareag/Natural/fuser/${NATURAL_LIBRARY}/SRC/"
  copy_into_container "$BUILD_WORK/sysddm-src/." "$NATURAL_CONTAINER" "/opt/softwareag/Natural/fuser/SYSDDM/SRC/"
  container_sh_root "$NATURAL_CONTAINER" "chown -R 1724:1724 /opt/softwareag/Natural/fuser/${NATURAL_LIBRARY} /opt/softwareag/Natural/fuser/SYSDDM '$NATURAL_WORK_DIR'"
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
  ftouch_register "$NATURAL_CONTAINER" SYSDDM /opt/softwareag/Natural/fuser/SYSDDM/SRC
  ftouch_register "$NATURAL_CONTAINER" "$NATURAL_LIBRARY" "/opt/softwareag/Natural/fuser/${NATURAL_LIBRARY}/SRC"

  # Authoritative order from 01-archaeology/HOW-TO-COMPILE-AND-RUN.md section 2.4.
  run_compile_group SYSDDM ddms "${DDMS[@]}"
  run_compile_group "$NATURAL_LIBRARY" data-areas "${DATA_AREAS[@]}"
  info "Copycodes installed as source only: ${COPYCODES[*]}"
  run_compile_group "$NATURAL_LIBRARY" subprograms "${SUBPROGRAMS[@]}"
  run_compile_group "$NATURAL_LIBRARY" programs "${PROGRAMS[@]}"

  assert_cataloged "$NATURAL_LIBRARY" "$(( ${#DATA_AREAS[@]} + ${#SUBPROGRAMS[@]} ))"
  info "Natural build phase finished"
}

main "$@"

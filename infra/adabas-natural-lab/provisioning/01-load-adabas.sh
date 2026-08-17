#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

FORCE=0
if [ "${1:-}" = "--force" ]; then FORCE=1; fi

DDM_DIR="${DDM_DIR:-${CORPUS_DIR}/adabas-ddms}"
SEED_DIR="${SEED_DIR:-${PROVISIONING_DIR}/seed}"
LOAD_WORK="${WORK_DIR}/adabas-load"

FILE_NAMES=(beneficiary social-program payment audit)
FILE_NUMBERS=(150 151 152 153)
DDM_FILES=(BENEFICIARY.ddm SOCIAL-PROGRAM.ddm PAYMENT.ddm AUDIT.ddm)
FDT_150_REPORT="${FDT_150_REPORT:-${DDM_DIR}/FDT-150-BENEFICIARY.txt}"

seed_file() { printf '%s/%s.dat' "$SEED_DIR" "$1"; }
layout_file() { printf '%s/layout-%s.txt' "$SEED_DIR" "$1"; }

require_inputs() {
  local i name ddm fnr declared
  [ -d "$DDM_DIR" ] || fatal "DDM directory missing: ${DDM_DIR}. Copy legacy-sifap/adabas-ddms into /opt/sifap/corpus."
  [ -r "$FDT_150_REPORT" ] || fatal "Required authoritative FDT report missing for file 150: ${FDT_150_REPORT}"
  for i in "${!FILE_NAMES[@]}"; do
    name="${FILE_NAMES[$i]}"
    ddm="${DDM_DIR}/${DDM_FILES[$i]}"
    [ -r "$ddm" ] || fatal "Required DDM missing: ${ddm}"
    [ -r "$(seed_file "$name")" ] || fatal "Required seed data missing: $(seed_file "$name")"
    [ -r "$(layout_file "$name")" ] || fatal "Required ADACMP layout missing: $(layout_file "$name")"
    declared="$(awk '/FNR:[[:space:]]*[0-9]+/{for(i=1;i<=NF;i++) if($i=="FNR:") {print $(i+1); exit}}' "$ddm")"
    fnr="${FILE_NUMBERS[$i]}"
    [ "$declared" = "$fnr" ] || fatal "${ddm} declares FNR ${declared:-unknown}, expected ${fnr}"
  done
}

packed_len() {
  local spec="$1" digits
  digits="${spec%%,*}"
  digits="${digits%%.*}"
  printf '%d' $(((digits + 1) / 2))
}

emit_fdt_from_adarep() {
  local report="$1" out="$2"
  awk '
    BEGIN { in_fdt=0; in_derived=0 }
    /FIELD DEFINITION TABLE/ { in_fdt=1; next }
    /DERIVED DESCRIPTORS/ { in_fdt=0; in_derived=1; next }
    /OPTION CODES/ { exit }
    in_fdt==1 {
      if ($0 ~ /^[[:space:]]*[12][[:space:]]+[A-Z][A-Z]/) {
        level=$1; db=$2; len=$3; fmt=$4; opts=$5
        if (fmt=="GR") { printf "%s, %s ; group\n", level, db; next }
        if (fmt=="PE") { printf "%s, %s, PE ; periodic group\n", level, db; next }
        if (opts=="") printf "%s, %s, %s, %s\n", level, db, len, fmt
        else printf "%s, %s, %s, %s, %s\n", level, db, len, fmt, opts
      }
    }
    in_derived==1 {
      if ($0 ~ /PHONETIC[[:space:]]+PN = AC/) print "PN=AC ; PHON-NAME"
      if ($0 ~ /SUBDESCRIPTOR[[:space:]]+SA = AF/) print "SA=AF(1-4) ; YEAR-BIRTH"
      if ($0 ~ /SUPERDESCRIPTOR S2 =/) print "S2=BG(1-2), CE(1-1) ; SUPER-UF-STAT"
      if ($0 ~ /SUPERDESCRIPTOR S3 =/) print "S3=CA(1-4), CE(1-1) ; SUPER-PROG-STAT"
    }
  ' "$report" > "$out"
}

emit_fdt_from_ddm() {
  local ddm="$1" out="$2"
  awk '
    function trim(s){gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s}
    function plen(s, d){split(s,a,/[,\.]/); d=a[1]+0; return int((d+1)/2)}
    BEGIN { in_fields=0 }
    /--- IDENTIFICATION ---|--- KEYS ---|--- EVENT IDENTIFICATION ---/ { in_fields=1 }
    /--- DERIVED DESCRIPTORS ---/ { in_fields=2; next }
    /^\* COLUMN LEGEND/ { exit }
    in_fields==1 {
      if ($0 ~ /^[[:space:]]*[GMP]?[[:space:]]*[12][[:space:]]+[A-Z][A-Z][[:space:]]+/) {
        typ=""; level=""; db=""; fmt=""; len=""; opts=""; remark=""
        n=split($0,a,/ +/)
        start=1; while (a[start]=="") start++
        if (a[start] ~ /^[GMP]$/) { typ=a[start]; start++ }
        level=a[start]; db=a[start+1]; long=a[start+2]; fmt=a[start+3]; len=a[start+4]
        # S (storage) and D (descriptor) are optional single-character columns and
        # either may be blank, so they must be consumed by value rather than by
        # position: reading a[start+5]/a[start+6] positionally silently drops the
        # descriptor on every field that has no null-suppression flag.
        k=start+5; storage=""; desc=""
        if (a[k]=="N" || a[k]=="F") { storage=a[k]; k++ }
        if (a[k]=="D" || a[k]=="U") { desc=a[k]; k++ }
        if (typ=="G") { printf "%s, %s ; %s\n", level, db, long; next }
        if (typ=="P") { printf "%s, %s, PE ; %s\n", level, db, long; next }
        opts=""
        if (typ=="M") opts=(opts==""?"MU":opts",MU")
        if (fmt=="N") fmt="U"
        if (fmt=="P") len=plen(len)
        if (storage=="N") opts=(opts==""?"NU":opts",NU")
        if (storage=="F") opts=(opts==""?"FI":opts",FI")
        if (desc=="D") opts=(opts==""?"DE":opts",DE")
        if (desc=="U") opts=(opts==""?"DE,UQ":opts",DE,UQ")
        if (opts=="") printf "%s, %s, %s, %s ; %s\n", level, db, len, fmt, long
        else printf "%s, %s, %s, %s, %s ; %s\n", level, db, len, fmt, opts, long
      }
    }
    in_fields==2 {
      if ($0 ~ /^[[:space:]]*S[[:space:]]+[A-Z0-9][A-Z0-9][[:space:]]+/) {
        n=split($0,a,/ +/); start=1; while(a[start]=="") start++
        pending_db=a[start+1]; pending_long=a[start+2]
        k=start+5
        if (a[k]=="N" || a[k]=="F") k++
        pending_type=a[k]
        next
      } else if ($0 ~ /^[[:space:]]*\/\*/ && pending_db != "") {
        s=$0; sub(/^[[:space:]]*\/\*[[:space:]]*/, "", s); s=trim(s)
        gsub(/[[:space:]]+/, "", s)
        # ADAFDU expects FIELD(from,to); the LISTDDM report renders it FIELD(from-to).
        gsub(/-/, ",", s)
        if (pending_type=="P") printf "%s=PHON(%s) ; %s\n", pending_db, s, pending_long
        else if (pending_type=="H") printf "; %s=%s ; %s (hyperdescriptor omitted: ADAFDU needs a compiled hyperexit, which the lab does not ship)\n", pending_db, s, pending_long
        else printf "%s=%s ; %s\n", pending_db, s, pending_long
        pending_db=""; pending_long=""; pending_type=""
      }
    }
  ' "$ddm" > "$out"
}

emit_fdu() {
  local fnr="$1" name="$2" out="$3"
  cat > "$out" <<EOF_FDU
name=${name}
dssize=20m
nisize=2m
uisize=2m
maxisn=100000
reuse=(isn,ds)
EOF_FDU
}

prepare_control_files() {
  local i name fnr ddm lower
  rm -rf "$LOAD_WORK"
  mkdir -p "$LOAD_WORK"
  for i in "${!FILE_NAMES[@]}"; do
    name="${FILE_NAMES[$i]}"; fnr="${FILE_NUMBERS[$i]}"; ddm="${DDM_DIR}/${DDM_FILES[$i]}"; lower="$name"
    if [ "$fnr" = "150" ]; then
      emit_fdt_from_adarep "$FDT_150_REPORT" "$LOAD_WORK/${lower}.fdt"
    else
      emit_fdt_from_ddm "$ddm" "$LOAD_WORK/${lower}.fdt"
    fi
    emit_fdu "$fnr" "$name" "$LOAD_WORK/${lower}.fdu"
    cp "$(layout_file "$name")" "$LOAD_WORK/${lower}.cmp"
    cp "$(seed_file "$name")" "$LOAD_WORK/${lower}.dat"
  done
}

assert_adabas_utilities() {
  container_has_command "$ADABAS_CONTAINER" adafdu || fatal "Adabas utility adafdu is not available in ${ADABAS_CONTAINER}"
  container_has_command "$ADABAS_CONTAINER" adacmp || fatal "Adabas utility adacmp is not available in ${ADABAS_CONTAINER}"
  if container_has_command "$ADABAS_CONTAINER" adalod; then
    warn "adalod is available; this script still uses the CE demo loader path unless SIFAP_USE_ADALOD=1 is set"
  else
    warn "adalod is not present in softwareag/adabas-ce:7.4.0; using adamup after adacmp, matching the image demo loader"
    container_has_command "$ADABAS_CONTAINER" adamup || fatal "Neither adalod nor adamup is available in ${ADABAS_CONTAINER}"
  fi
}

stage_in_adabas_container() {
  container_sh "$ADABAS_CONTAINER" "mkdir -p '$ADABAS_WORK_DIR' '$ADABAS_WORK_DIR/state'"
  copy_into_container "$LOAD_WORK/." "$ADABAS_CONTAINER" "$ADABAS_WORK_DIR/"
}

load_one_file() {
  local name="$1" fnr="$2"
  local marker="${ADABAS_WORK_DIR}/state/file-${fnr}.loaded"
  if [ "$FORCE" -eq 0 ] && container_sh "$ADABAS_CONTAINER" "test -f '$marker'"; then
    info "Adabas file ${fnr} (${name}) already marked loaded; skipping"
    return 0
  fi
  if [ "$FORCE" -eq 1 ]; then
    warn "--force requested for file ${fnr}; existing Adabas file deletion/reload is intentionally not automated to avoid data loss"
    fatal "Manual cleanup is required before force-loading file ${fnr}"
  fi

  local use_adalod="${SIFAP_USE_ADALOD:-0}"
  info "Defining and loading Adabas file ${fnr} (${name})"
  docker exec "$ADABAS_CONTAINER" sh -lc "
    set -eu
    cd '$ADABAS_WORK_DIR'
    export FDUFDT='$ADABAS_WORK_DIR/${name}.fdt'
    export CMPIN='$ADABAS_WORK_DIR/${name}.dat'
    export CMPDTA='$ADABAS_WORK_DIR/${name}.CMPDTA'
    export CMPDVT='$ADABAS_WORK_DIR/${name}.CMPDVT'
    export MUPDTA=\"\$CMPDTA\"
    export MUPDVT=\"\$CMPDVT\"
    rm -f \"\$CMPDTA\" \"\$CMPDVT\"
    { printf 'dbid=%s\n' '$ADABAS_DBID'; printf 'file=%s\n' '$fnr'; cat '$ADABAS_WORK_DIR/${name}.fdu'; } | adafdu
    { printf 'dbid=%s\n' '$ADABAS_DBID'; printf 'file=%s\n' '$fnr'; cat '$ADABAS_WORK_DIR/${name}.cmp'; } | adacmp
    if command -v adalod >/dev/null 2>&1 && [ '$use_adalod' = '1' ]; then
      printf 'dbid=%s\nfile=%s\n' '$ADABAS_DBID' '$fnr' | adalod
    else
      adamup db='$ADABAS_DBID' update='$fnr',add
    fi
    touch '$marker'
  "
}

main() {
  require_command docker
  load_adabas_env
  wait_for_adabas_ready "${SIFAP_ADABAS_READY_TIMEOUT:-900}"
  prepare_work_dir
  require_inputs
  assert_adabas_utilities
  prepare_control_files
  stage_in_adabas_container
  local i
  for i in "${!FILE_NAMES[@]}"; do
    load_one_file "${FILE_NAMES[$i]}" "${FILE_NUMBERS[$i]}"
  done
  info "Adabas load phase finished"
}

main "$@"

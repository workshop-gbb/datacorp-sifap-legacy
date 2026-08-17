#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

SIFAP_DATA_DIR="${SIFAP_DATA_DIR:-/mnt/sifap-data}"
ADABAS_DATA_DIR="${SIFAP_ADABAS_DATA_DIR:-${SIFAP_DATA_DIR}/adabas-data}"
NATURAL_FUSER_DIR="${SIFAP_NATURAL_FUSER_DIR:-${SIFAP_DATA_DIR}/natural-fuser}"
BATCH_WORK_DIR="${SIFAP_BATCH_WORK_DIR:-${SIFAP_DATA_DIR}/work}"
BACKUP_DIR="${SIFAP_BACKUP_DIR:-${SIFAP_DATA_DIR}/backups}"
RETENTION_DAYS="${SIFAP_BACKUP_RETENTION_DAYS:-14}"
EXPECTED_COUNTS="150:500 151:6 152:2000 153:200"

usage() {
  cat <<USAGE
Usage:
  $0 backup
  $0 restore <backup-directory-or-tar.gz>
  $0 verify-round-trip
  $0 counts

Backups are timestamped under ${BACKUP_DIR}. Retention policy: keep backups for ${RETENTION_DAYS} days unless SIFAP_BACKUP_RETENTION_DAYS overrides it.
USAGE
}

safe_mkdirs() {
  mkdir -p "$ADABAS_DATA_DIR" "$NATURAL_FUSER_DIR" "$BATCH_WORK_DIR" "$BACKUP_DIR"
}

is_running() {
  container_running "$1"
}

stop_if_running() {
  local container="$1"
  if is_running "$container"; then
    info "Stopping ${container} for a consistent backup/restore snapshot"
    docker stop "$container" >/dev/null
    return 0
  fi
  return 1
}

start_if_needed() {
  local container="$1" was_running="$2"
  if [ "$was_running" -eq 1 ] && ! is_running "$container"; then
    info "Starting ${container}"
    docker start "$container" >/dev/null
  fi
}

ensure_not_root_path() {
  local dir="$1" label="$2"
  [ -n "$dir" ] || fatal "${label} path is empty"
  [ "$dir" != "/" ] || fatal "Refusing to operate on / for ${label}"
}

clean_dir() {
  local dir="$1" label="$2"
  ensure_not_root_path "$dir" "$label"
  mkdir -p "$dir"
  find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
}

archive_dir() {
  local source_dir="$1" archive_file="$2" label="$3"
  mkdir -p "$source_dir"
  info "Archiving ${label}: ${source_dir} -> ${archive_file}"
  tar -C "$source_dir" -czf "$archive_file" .
}

extract_dir() {
  local archive_file="$1" dest_dir="$2" label="$3"
  [ -r "$archive_file" ] || fatal "Missing ${label} archive: ${archive_file}"
  clean_dir "$dest_dir" "$label"
  info "Restoring ${label}: ${archive_file} -> ${dest_dir}"
  tar -C "$dest_dir" -xzf "$archive_file"
}

adarep_contents() {
  container_sh "$ADABAS_CONTAINER" "adarep db='${ADABAS_DBID}' contents" 2>&1
}

record_count_for_file() {
  local fnr="$1" line count
  line="$(adarep_contents | awk -v fnr="$fnr" '$1 == fnr {print; exit}')"
  [ -n "$line" ] || { printf 'MISSING\n'; return 1; }
  count="$(printf '%s\n' "$line" | awk '{gsub(/,/,"",$4); print $4}')"
  [[ "$count" =~ ^[0-9]+$ ]] || { printf 'UNKNOWN\n'; return 1; }
  printf '%s\n' "$count"
}

write_counts() {
  local out_file="${1:-}" expected fnr expected_count actual failures=0 line
  for expected in $EXPECTED_COUNTS; do
    fnr="${expected%%:*}"
    expected_count="${expected##*:}"
    actual="$(record_count_for_file "$fnr" || true)"
    line="file ${fnr} count=${actual} expected=${expected_count}"
    if [ -n "$out_file" ]; then printf '%s\n' "$line" >> "$out_file"; else printf '%s\n' "$line"; fi
    [ "$actual" = "$expected_count" ] || failures=$((failures + 1))
  done
  return "$failures"
}

assert_counts() {
  local out_file="$1"
  : > "$out_file"
  if write_counts "$out_file"; then
    info "Adabas record counts match expected SIFAP baseline; details=${out_file}"
  else
    warn "Adabas record counts do not match expected SIFAP baseline:"
    cat "$out_file"
    return 1
  fi
}

run_adabck_dump() {
  local dest_dir="$1" output_file
  output_file="$dest_dir/adabck-dump.out"
  if ! container_has_command "$ADABAS_CONTAINER" adabck; then
    warn "adabck is not available in ${ADABAS_CONTAINER}; relying on stopped-container offline data archive"
    printf 'adabck: unavailable\n' > "$output_file"
    return 0
  fi

  info "Running Adabas online backup utility adabck dump=* before offline archive"
  container_sh "$ADABAS_CONTAINER" "cd /opt/softwareag && rm -f BCK001 && adabck db='${ADABAS_DBID}' dump=*" > "$output_file" 2>&1 || true
  if grep -E '%ADABCK-E-|%ADABCK-I-ABORTED' "$output_file" >/dev/null 2>&1; then
    warn "adabck reported an error; backup will still include the stopped-container offline archive"
    cat "$output_file"
  fi
  if container_sh "$ADABAS_CONTAINER" "test -f /opt/softwareag/BCK001"; then
    docker cp "${ADABAS_CONTAINER}:/opt/softwareag/BCK001" "$dest_dir/BCK001" || warn "Could not copy adabck BCK001 file"
  fi
}

write_manifest() {
  local manifest="$1" backup_name="$2" mode="$3"
  {
    printf 'name=%s\n' "$backup_name"
    printf 'mode=%s\n' "$mode"
    printf 'created_at=%s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)"
    printf 'adabas_container=%s\n' "$ADABAS_CONTAINER"
    printf 'natural_container=%s\n' "$NATURAL_CONTAINER"
    printf 'adabas_dbid=%s\n' "$ADABAS_DBID"
    printf 'adabas_data_dir=%s\n' "$ADABAS_DATA_DIR"
    printf 'natural_fuser_dir=%s\n' "$NATURAL_FUSER_DIR"
    printf 'batch_work_dir=%s\n' "$BATCH_WORK_DIR"
    printf 'retention_days=%s\n' "$RETENTION_DAYS"
    printf 'captures=adabas-adabck-dump,adabas-offline-data,natural-fuser,batch-work-files\n'
  } > "$manifest"
}

prune_old_backups() {
  [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || fatal "SIFAP_BACKUP_RETENTION_DAYS must be numeric"
  [ "$RETENTION_DAYS" -gt 0 ] || return 0
  find "$BACKUP_DIR" -maxdepth 1 \( -name 'sifap-backup-*.tar.gz' -o -name 'sifap-backup-*' \) -mtime "+${RETENTION_DAYS}" -exec rm -rf {} + 2>/dev/null || true
}

backup() {
  require_command docker
  load_adabas_env
  safe_mkdirs
  wait_for_adabas_ready "${SIFAP_ADABAS_READY_TIMEOUT:-900}"

  local ts backup_name stage final_archive nat_was_running=0 ada_was_running=0
  ts="$(date +%Y%m%d-%H%M%S)"
  backup_name="sifap-backup-${ts}"
  stage="$BACKUP_DIR/$backup_name"
  final_archive="$BACKUP_DIR/${backup_name}.tar.gz"
  rm -rf "$stage"
  mkdir -p "$stage"

  write_manifest "$stage/manifest.env" "$backup_name" backup
  assert_counts "$stage/counts-before-backup.txt" || fatal "Refusing backup because baseline record counts are not correct"
  run_adabck_dump "$stage"

  if stop_if_running "$NATURAL_CONTAINER"; then nat_was_running=1; fi
  if stop_if_running "$ADABAS_CONTAINER"; then ada_was_running=1; fi

  archive_dir "$ADABAS_DATA_DIR" "$stage/adabas-data.tar.gz" "Adabas database offline data directory"
  archive_dir "$NATURAL_FUSER_DIR" "$stage/natural-fuser.tar.gz" "Natural FUSER"
  archive_dir "$BATCH_WORK_DIR" "$stage/batch-work.tar.gz" "batch work files"

  start_if_needed "$ADABAS_CONTAINER" "$ada_was_running"
  if [ "$ada_was_running" -eq 1 ]; then wait_for_adabas_ready "${SIFAP_ADABAS_READY_TIMEOUT:-900}"; fi
  start_if_needed "$NATURAL_CONTAINER" "$nat_was_running"
  if [ "$nat_was_running" -eq 1 ]; then wait_for_container "$NATURAL_CONTAINER" "${SIFAP_NATURAL_READY_TIMEOUT:-300}"; fi

  tar -C "$BACKUP_DIR" -czf "$final_archive" "$backup_name"
  prune_old_backups
  info "Backup complete: ${final_archive}"
  printf '%s\n' "$final_archive"
}

resolve_backup_dir() {
  local source="$1" restore_root extracted
  [ -e "$source" ] || fatal "Backup not found: ${source}"
  if [ -d "$source" ]; then
    printf '%s\n' "$source"
    return 0
  fi
  restore_root="$BACKUP_DIR/restore-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$restore_root"
  tar -C "$restore_root" -xzf "$source"
  extracted="$(find "$restore_root" -mindepth 1 -maxdepth 1 -type d -name 'sifap-backup-*' | head -1)"
  [ -n "$extracted" ] || fatal "Archive ${source} did not contain a sifap-backup-* directory"
  printf '%s\n' "$extracted"
}

restore_backup() {
  local backup_source="$1" backup_dir nat_was_running=0 ada_was_running=0 verify_file
  require_command docker
  load_adabas_env
  safe_mkdirs
  backup_dir="$(resolve_backup_dir "$backup_source")"
  [ -r "$backup_dir/manifest.env" ] || fatal "Backup manifest missing: ${backup_dir}/manifest.env"

  if stop_if_running "$NATURAL_CONTAINER"; then nat_was_running=1; fi
  if stop_if_running "$ADABAS_CONTAINER"; then ada_was_running=1; fi

  extract_dir "$backup_dir/adabas-data.tar.gz" "$ADABAS_DATA_DIR" "Adabas database offline data directory"
  extract_dir "$backup_dir/natural-fuser.tar.gz" "$NATURAL_FUSER_DIR" "Natural FUSER"
  extract_dir "$backup_dir/batch-work.tar.gz" "$BATCH_WORK_DIR" "batch work files"
  chown -R 1724:1724 "$ADABAS_DATA_DIR" "$NATURAL_FUSER_DIR" 2>/dev/null || warn "Could not chown restored Adabas/FUSER directories; run as root on the VM if containers cannot read them"

  start_if_needed "$ADABAS_CONTAINER" 1
  wait_for_adabas_ready "${SIFAP_ADABAS_READY_TIMEOUT:-900}"
  start_if_needed "$NATURAL_CONTAINER" "$nat_was_running"
  if [ "$nat_was_running" -eq 1 ]; then wait_for_container "$NATURAL_CONTAINER" "${SIFAP_NATURAL_READY_TIMEOUT:-300}"; fi
  if [ "$ada_was_running" -eq 0 ]; then warn "${ADABAS_CONTAINER} was not running before restore; it was started so counts could be verified"; fi

  verify_file="$backup_dir/counts-after-restore.txt"
  assert_counts "$verify_file"
  info "Restore verified: ${verify_file}"
}

counts() {
  require_command docker
  load_adabas_env
  wait_for_adabas_ready "${SIFAP_ADABAS_READY_TIMEOUT:-900}"
  write_counts
}

verify_round_trip() {
  local archive
  archive="$(backup | tail -1)"
  info "Round-trip verification will destroy current Adabas/FUSER/work directories and restore ${archive}"
  restore_backup "$archive"
  info "Backup/restore round trip completed and record counts match"
}

main() {
  local op="${1:-}"
  case "$op" in
    backup)
      backup
      ;;
    restore)
      [ -n "${2:-}" ] || fatal "restore requires a backup directory or .tar.gz archive"
      restore_backup "$2"
      ;;
    verify-round-trip)
      verify_round_trip
      ;;
    counts)
      counts
      ;;
    -h|--help|help|'')
      usage
      ;;
    *)
      usage
      fatal "Invalid operation '${op}'"
      ;;
  esac
}

main "$@"

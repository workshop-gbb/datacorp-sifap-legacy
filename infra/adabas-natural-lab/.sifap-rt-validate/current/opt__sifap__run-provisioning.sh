#!/usr/bin/env bash
set -Eeuo pipefail

LOG=/var/log/sifap-provisioning.log
# Append, never truncate, and never world-readable - same treatment as the
# bootstrap log.
touch "$LOG"
chown root:adm "$LOG" 2>/dev/null || true
chmod 0640 "$LOG"
# fd 3 keeps a handle on the journal BEFORE the tee is installed. run-all.sh
# tees to this same file itself, so it is handed fd 3 instead of the tee -
# otherwise every line it prints would be written to the log twice.
exec 3>&1
exec > >(tee -a "$LOG") 2>&1

ENTRYPOINT=/opt/sifap/provisioning/run-all.sh
STATE_DIR=/opt/sifap/state
FUSER=/mnt/sifap-data/natural-fuser
DDM_BACKUP=/mnt/sifap-data/state/ddm-gp-backup.tgz
STATE_BASE="https://sifappayload.blob.core.windows.net/state"
BLOB_API=2021-08-06
SIFAP_PHASE="${SIFAP_PHASE:-auto}"

rm -f /opt/sifap/PROVISIONING-FAILED

storage_token() {
  curl -s --retry 3 --retry-delay 2 -H "Metadata:true" \
    "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fstorage.azure.com%2F" \
    | jq -r '.access_token // empty'
}

restore_ddm_backup_if_empty() {
  mkdir -p "$FUSER" "$STATE_DIR"
  if find "$FUSER" -path '*/GP/*.NGD' -type f -print -quit 2>/dev/null | grep -q .; then
    echo "Natural DDMs already present in FUSER; restore not needed"
    return 0
  fi
  if [ ! -s "$DDM_BACKUP" ]; then
    token=$(storage_token || true)
    if [ -n "$token" ]; then
      curl -sSf --max-time 60 \
        -H "Authorization: Bearer $token" -H "x-ms-version: $BLOB_API" \
        -o "$DDM_BACKUP" "$STATE_BASE/ddm-gp-backup.tgz" \
        && echo "downloaded DDM backup from lab state storage" || true
    fi
  fi
  if [ -s "$DDM_BACKUP" ]; then
    echo "restoring Natural DDM GP backup into persistent FUSER"
    tar -xzf "$DDM_BACKUP" -C "$FUSER"
    chown -R 1724:1724 "$FUSER"
  else
    echo "no DDM backup available yet; a fresh lab needs the NaturalONE DDM step"
  fi
}

backup_ddms_if_present() {
  mkdir -p "$STATE_DIR"
  if ! find "$FUSER" -path '*/GP/*.NGD' -type f -print -quit 2>/dev/null | grep -q .; then
    echo "no Natural DDM objects found to back up"
    return 0
  fi
  tmp="$STATE_DIR/ddm-gp-backup.new.tgz"
  ( cd "$FUSER" && find . -path './*/GP/*.NGD' -type f -print0 | tar --null -czf "$tmp" --files-from - )
  mv "$tmp" "$DDM_BACKUP"
  chown 1724:1724 "$DDM_BACKUP"
  date -Is > "$STATE_DIR/DDMS-READY"
  token=$(storage_token || true)
  if [ -n "$token" ]; then
    curl -sSf --max-time 120 -X PUT \
      -H "Authorization: Bearer $token" -H "x-ms-version: $BLOB_API" \
      -H "x-ms-blob-type: BlockBlob" --data-binary "@$DDM_BACKUP" \
      "$STATE_BASE/ddm-gp-backup.tgz" \
      && echo "uploaded DDM backup to lab state storage" || echo "WARNING: DDM backup upload failed"
  else
    echo "WARNING: could not get storage token; DDM backup remains only on data disk"
  fi
}

on_exit() {
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "PROVISIONING RESULT: SUCCESS"
    logger -t sifap-provisioning -p user.notice "SIFAP-PROVISIONING RESULT: SUCCESS" || true
    if [ -f /opt/sifap/PROVISIONED ]; then
      echo "finalize marker present: /opt/sifap/PROVISIONED"
    else
      echo "base phase completed without finalization; DDMs are still pending"
    fi
  else
    echo "PROVISIONING RESULT: FAILED (exit $rc at line $PROV_LINE)"
    logger -t sifap-provisioning -p user.err "SIFAP-PROVISIONING RESULT: FAILED (exit $rc at line $PROV_LINE)" || true
    printf 'failed at %s (exit %s, line %s)\n' "$(date -Is)" "$rc" "$PROV_LINE" \
      > /opt/sifap/PROVISIONING-FAILED
  fi
  /opt/sifap/update-www-status.sh || true
}
PROV_LINE=0
trap 'PROV_LINE=$LINENO' ERR
trap on_exit EXIT

echo "=== SIFAP provisioning started at $(date -Is) ==="
echo "phase: $SIFAP_PHASE"
restore_ddm_backup_if_empty

if [ ! -f "$ENTRYPOINT" ]; then
  echo "ERROR: $ENTRYPOINT is missing."
  echo "ERROR: nothing has loaded Adabas and nothing has compiled Natural."
  echo "ERROR: the corpus itself may still be present - check /opt/sifap/corpus."
  echo "ERROR:"
  echo "ERROR: fix: add the scripts under infra/adabas-natural-lab/provisioning/"
  echo "ERROR:      (run-all.sh, 01-load-adabas.sh, 02-build-natural.sh,"
  echo "ERROR:       03-smoke-test.sh, lib.sh, seed/), re-apply, then on the VM:"
  echo "ERROR:        sudo /opt/sifap/fetch-payload.sh"
  echo "ERROR:        sudo systemctl restart sifap-provisioning"
  exit 3
fi

chmod 0755 "$ENTRYPOINT" 2>/dev/null || true

echo "waiting for the adabas-db container to be running (up to 5 minutes)"
READY=0
for attempt in $(seq 1 60); do
  if [ "$(docker inspect -f '{{.State.Running}}' adabas-db 2>/dev/null || echo false)" = "true" ]; then
    READY=1
    echo "adabas-db is running after $((attempt * 5))s"
    break
  fi
  sleep 5
done
if [ "$READY" -ne 1 ]; then
  echo "ERROR: the adabas-db container is not running, so there is nothing"
  echo "ERROR: to load into. This is a container problem, not a load problem."
  echo "ERROR: check: sudo docker compose -f /opt/sifap/docker-compose.yml logs adabas-db"
  exit 4
fi

export PROVISIONING_DIR=/opt/sifap/provisioning
export SIFAP_CORPUS_DIR=/opt/sifap/corpus
export SIFAP_PROVISIONING_LOG=/var/log/sifap-provisioning.log
export ADABAS_CONTAINER=adabas-db
export NATURAL_CONTAINER=natural-ce
export ADABAS_DBID="12"
export HOST_ADABAS_ENV=/opt/sifap/adabas.env
export SIFAP_PHASE
export SIFAP_STATE_DIR="$STATE_DIR"
export SIFAP_DDMS_READY_MARKER="$STATE_DIR/DDMS-READY"

cd /opt/sifap/provisioning
"$ENTRYPOINT" >&3 2>&3

backup_ddms_if_present

echo "=== SIFAP provisioning finished at $(date -Is) ==="

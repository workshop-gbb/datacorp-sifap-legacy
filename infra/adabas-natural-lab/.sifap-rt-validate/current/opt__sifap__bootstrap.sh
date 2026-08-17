#!/usr/bin/env bash
# Idempotent: safe to re-run over SSH after fixing whatever went wrong.
#   sudo /opt/sifap/bootstrap.sh
set -Eeuo pipefail

LOG=/var/log/sifap-bootstrap.log
# Append, never truncate, so a re-run keeps the earlier evidence. Created
# before the redirect so tee cannot leave it world-readable at 0644.
touch "$LOG"
chown root:adm "$LOG" 2>/dev/null || true
chmod 0640 "$LOG"
exec > >(tee -a "$LOG") 2>&1

rm -f /opt/sifap/READY /opt/sifap/FAILED

# Single, unambiguous success/failure marker for a human over SSH.
# outputs.tf points at $LOG; these markers are the machine-readable half.
#
# The `logger` calls put the same marker on syslog, which the Azure Monitor
# agent ships to Log Analytics. That is what
# azurerm_monitor_scheduled_query_rules_alert_v2.bootstrap_failed queries,
# so a first boot that dies at 02:00 raises an alert instead of waiting for
# someone to SSH in and notice. Keep the string in sync with the KQL in main.tf.
on_exit() {
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "BOOTSTRAP RESULT: SUCCESS"
    logger -t sifap-bootstrap -p user.notice "SIFAP-BOOTSTRAP RESULT: SUCCESS" || true
    date -Is > /opt/sifap/READY
  else
    echo "BOOTSTRAP RESULT: FAILED (exit $rc at line $BOOTSTRAP_LINE)"
    logger -t sifap-bootstrap -p user.err "SIFAP-BOOTSTRAP RESULT: FAILED (exit $rc at line $BOOTSTRAP_LINE)" || true
    echo "Inspect $LOG, fix the cause, then re-run: sudo /opt/sifap/bootstrap.sh"
    printf 'failed at %s (exit %s, line %s)\n' "$(date -Is)" "$rc" "$BOOTSTRAP_LINE" \
      > /opt/sifap/FAILED
  fi
}
BOOTSTRAP_LINE=0
trap 'BOOTSTRAP_LINE=$LINENO' ERR
trap on_exit EXIT

echo "=== SIFAP lab bootstrap started at $(date -Is) ==="

# --- data disk -------------------------------------------------------
# Azure exposes data disks under a stable by-path alias, which avoids the
# /dev/sdc guesswork that breaks whenever device ordering shifts.
# This whole block runs BEFORE Docker starts any container, so nothing can
# write Adabas or Natural FUSER data to the OS disk and then have it
# shadowed by the mount.
DISK=/dev/disk/azure/scsi1/lun0
for _ in $(seq 1 60); do
  [ -e "$DISK" ] && break
  echo "waiting for data disk at $DISK ..."
  sleep 5
done

if [ -e "$DISK" ]; then
  if ! blkid "$DISK" >/dev/null 2>&1; then
    echo "formatting empty data disk"
    mkfs.ext4 -F -L sifapdata "$DISK"
  else
    echo "data disk already carries a filesystem; leaving it alone"
  fi

  mkdir -p /mnt/sifap-data

  # UUID, not LABEL and never /dev/sdX: it is the only identifier that is
  # both stable across reattach and unique across disks.
  DISK_UUID=$(blkid -s UUID -o value "$DISK")
  if [ -z "$DISK_UUID" ]; then
    echo "ERROR: could not read filesystem UUID from $DISK"
    exit 1
  fi

  # nofail keeps a missing disk from wedging boot at the emergency prompt;
  # x-systemd.device-timeout stops systemd waiting 90s for it.
  FSTAB_LINE="UUID=$DISK_UUID /mnt/sifap-data ext4 defaults,nofail,x-systemd.device-timeout=30s 0 2"
  # Literal space, not [[:space:]]: "$DISK_UUID[" reads as an array
  # subscript to both bash and shellcheck, and the obvious repair
  # (${DISK_UUID}) would need Terraform escaping to survive templatefile.
  if ! grep -q "^UUID=$DISK_UUID /mnt/sifap-data " /etc/fstab; then
    # Drop any earlier entry for this mount point (e.g. a LABEL= line from
    # a previous bootstrap) so re-runs cannot stack duplicates.
    sed -i '\| /mnt/adabas-data |d; \| /mnt/sifap-data |d' /etc/fstab
    echo "$FSTAB_LINE" >> /etc/fstab
    echo "added fstab entry: $FSTAB_LINE"
  fi

  # daemon-reload BEFORE mounting so systemd regenerates the .mount unit
  # from the fstab line we just wrote.
  systemctl daemon-reload || true
  mountpoint -q /mnt/sifap-data || mount /mnt/sifap-data

  if ! mountpoint -q /mnt/sifap-data; then
    echo "ERROR: /mnt/sifap-data did not mount"
    exit 1
  fi
  echo "data disk mounted:"
  df -h /mnt/sifap-data
else
  echo "ERROR: data disk never appeared at $DISK."
  echo "ERROR: refusing to fall back to the OS disk because Natural DDMs"
  echo "ERROR: and Adabas data must survive OS disk rebuilds."
  echo "ERROR: check the LUN 0 attachment with:"
  echo "ERROR:   az vm show -d -g <rg> -n <vm> -o json"
  exit 1
fi

mkdir -p /mnt/sifap-data/adabas-data /mnt/sifap-data/natural-fuser /mnt/sifap-data/state /mnt/sifap-data/work/{in,runs,logs,reports} /opt/sifap/corpus /etc/sifap
chown -R 1724:1724 /mnt/sifap-data/adabas-data /mnt/sifap-data/natural-fuser /mnt/sifap-data/work
chmod 0750 /mnt/sifap-data /mnt/sifap-data/adabas-data /mnt/sifap-data/natural-fuser /mnt/sifap-data/work /mnt/sifap-data/work/{in,runs,logs,reports}
chmod 0755 /mnt/sifap-data/state

if [ -d /opt/sifap/state ] && [ ! -L /opt/sifap/state ]; then
  cp -a /opt/sifap/state/. /mnt/sifap-data/state/ 2>/dev/null || true
  rm -rf /opt/sifap/state
fi
ln -sfn /mnt/sifap-data/state /opt/sifap/state

if [ ! -f /mnt/sifap-data/state/provisioning.env ]; then
  if [ -f /etc/sifap/provisioning.env ] && [ ! -L /etc/sifap/provisioning.env ]; then
    cp /etc/sifap/provisioning.env /mnt/sifap-data/state/provisioning.env
  else
    printf 'SIFAP_PHASE=auto\n' > /mnt/sifap-data/state/provisioning.env
  fi
fi
ln -sfn /mnt/sifap-data/state/provisioning.env /etc/sifap/provisioning.env
chown root:root /mnt/sifap-data/state/provisioning.env
chmod 0644 /mnt/sifap-data/state/provisioning.env

mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/10-sifap-data.conf <<'EOF'
[Unit]
RequiresMountsFor=/mnt/sifap-data
After=mnt-sifap\x2ddata.mount
EOF
systemctl daemon-reload || true

# Both images run as the non-root service account sagadmin, uid/gid 1724
# (verified in /etc/passwd of adabas-ce and natural-ce). The Adabas
# entrypoint hard-fails with exit 20 if /data is not writable, so grant
# exactly that account write access instead of chmod 777.
chown -R 1724:1724 /mnt/sifap-data/adabas-data /mnt/sifap-data/natural-fuser /mnt/sifap-data/work
systemd-tmpfiles --create /etc/tmpfiles.d/sifap-work.conf || true
/opt/sifap/update-www-status.sh || true

sysctl --system

# --- key vault helper ------------------------------------------------
# Both secrets this VM needs are fetched the same way: an IMDS token for
# the vault audience, then a GET on the secret. The VM boots before
# Terraform has attached its Key Vault access policy (the policy depends on
# the VM's principal id), so the first attempts legitimately 403 - this
# retries for a few minutes rather than failing on them.
#
# Writes the secret to stdout and NOTHING else; every diagnostic goes to
# stderr, so callers can safely do VALUE=$(read_kv_secret name 30).
read_kv_secret() {
  local name="$1" attempts="$2" token="" value=""
  for attempt in $(seq 1 "$attempts"); do
    # -s keeps the token off stdout; nothing here is ever echoed.
    token=$(curl -s --retry 3 --retry-delay 2 -H "Metadata:true" \
      "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net" \
      | jq -r '.access_token // empty')

    if [ -n "$token" ]; then
      value=$(curl -s -H "Authorization: Bearer $token" \
        "https://sifap-lab-kv.vault.azure.net/secrets/$name?api-version=7.4" | jq -r '.value // empty')
    fi

    if [ -n "$value" ]; then
      echo "key vault: read '$name' on attempt $attempt" >&2
      printf '%s' "$value"
      return 0
    fi
    echo "key vault: '$name' not readable yet (attempt $attempt/$attempts); retrying" >&2
    sleep 10
  done
  return 1
}

# --- adabas admin password from key vault ----------------------------
# Pulled at boot through the VM managed identity so the secret never
# travels through Terraform variables or state inputs.
ADMIN_PWD=$(read_kv_secret "adabas-admin-password" 30 || true)

FALLBACK=0
if [ -z "$ADMIN_PWD" ]; then
  FALLBACK=1
  echo "############################################################"
  echo "WARNING: could not read the Key Vault secret after 30 tries."
  echo "WARNING: generating a LOCAL password so the lab still starts."
  echo "WARNING: the password in Key Vault will NOT work for the"
  echo "WARNING: Adabas REST UI until this is fixed."
  echo "WARNING: local password file: /opt/sifap/.adabas-fallback-password"
  echo "WARNING: fix: confirm the VM identity has Get on the vault, then"
  echo "WARNING: re-run  sudo /opt/sifap/bootstrap.sh"
  echo "############################################################"
  ADMIN_PWD=$(head -c 18 /dev/urandom | base64 | tr -d '/+=')
  ( umask 077; printf '%s\n' "$ADMIN_PWD" > /opt/sifap/.adabas-fallback-password )
else
  rm -f /opt/sifap/.adabas-fallback-password
fi

# The Adabas entrypoint accepts an already-hashed value (it calls
# check_if_valid_hash and reuses a 128-char SHA-512 digest verbatim), so
# the plaintext password never has to reach disk on this VM.
ADMIN_HASH=$(printf '%s' "$ADMIN_PWD" | sha512sum | cut -d' ' -f1)

# Rewritten from scratch on every run: idempotent, unlike sed-ing a
# placeholder that only exists the first time. umask 077 before the
# redirect so the digest is never briefly world-readable.
( umask 077; printf 'ADABAS_ADMIN_PWD=%s\n' "$ADMIN_HASH" > /opt/sifap/adabas.env )
chown root:root /opt/sifap/adabas.env
chmod 0600 /opt/sifap/adabas.env

unset ADMIN_PWD ADMIN_HASH

# --- legacy corpus and provisioning scripts --------------------------
# Terraform staged both into a private blob container; this pulls them
# down as the VM's own identity and checksums every file. Runs BEFORE the
# containers start, because /opt/sifap/corpus is bind-mounted into
# natural-ce and an empty mount is exactly the "the legacy does not
# actually run" failure this module exists to avoid.
#
# Not fatal: a lab that boots without the corpus is still worth having on
# its feet so the operator can fix the role assignment and re-run. It is
# loud about it, and /opt/sifap/PAYLOAD-FAILED is left behind as evidence.
if ! /opt/sifap/fetch-payload.sh; then
  echo "WARNING: payload download failed - see the block above."
  echo "WARNING: the lab will start, but with NO SIFAP data and NO"
  echo "WARNING: provisioning scripts. Re-run once fixed:"
  echo "WARNING:   sudo /opt/sifap/fetch-payload.sh"
  echo "WARNING:   sudo systemctl restart sifap-provisioning"
fi

# --- containers ------------------------------------------------------
# Docker is enabled by install-docker.sh but started only after the data
# disk is mounted and the RequiresMountsFor drop-in is installed. That
# prevents restart policies from ever creating an empty FUSER on the OS
# disk.
systemctl start docker
for attempt in $(seq 1 30); do
  docker info >/dev/null 2>&1 && break
  echo "waiting for the docker daemon (attempt $attempt/30)"
  sleep 5
done
if ! docker info >/dev/null 2>&1; then
  echo "ERROR: docker daemon never became ready"
  exit 1
fi
echo "docker daemon is ready"

cd /opt/sifap

# ~1.7 GB across both images. Retried: a single transient registry error
# would otherwise kill the whole bootstrap under set -e.
echo "pulling images (~1.7 GB, this is the slow step)"
PULLED=0
for attempt in $(seq 1 5); do
  if docker compose pull; then PULLED=1; break; fi
  echo "image pull failed (attempt $attempt/5); retrying in 15s"
  sleep 15
done
if [ "$PULLED" -ne 1 ]; then
  echo "ERROR: could not pull the Adabas/Natural images."
  echo "ERROR: both are public on Docker Hub and need no login; this is"
  echo "ERROR: almost certainly egress or DNS on the VM. Check with:"
  echo "ERROR:   docker pull softwareag/adabas-ce:7.4.0@sha256:2d1eb6df66b188bbb6e024d24262ea5f03f35d4e9e2500694ca127c7747a3b8b"
  exit 1
fi

if ! find /mnt/sifap-data/natural-fuser -mindepth 1 -print -quit | grep -q .; then
  echo "seeding persistent Natural FUSER from the image"
  docker run --rm -v /mnt/sifap-data/natural-fuser:/target "softwareag/natural-ce:9.3.3@sha256:b671669f6625b7d23847e46a5e2f50476778bb1b26550d9248bf6ed49e5597d5" \
    sh -lc 'cp -a /opt/softwareag/Natural/fuser/. /target/'
  chown -R 1724:1724 /mnt/sifap-data/natural-fuser
fi

# --- docker client for the web terminal -------------------------------
# ttyd runs `docker exec` into natural-ce, and its image is Alpine (musl),
# so the host's Ubuntu client cannot simply be bind-mounted - it is glibc
# and would fail to load. The client binary is lifted out of the pinned
# Alpine-based Docker CLI image instead, which is why docker_cli_image
# exists as a variable at all.
#
# This MUST happen before `compose up`: Docker creates a DIRECTORY at a
# bind-mount source that does not exist, and a directory mounted over
# /usr/local/bin/docker makes ttyd fail in a thoroughly confusing way.
mkdir -p /opt/sifap/bin
if [ ! -x /opt/sifap/bin/docker ]; then
  echo "extracting the docker client from docker:29.7.2-cli@sha256:000bb62ff495f986c9f5578eb67cc2cb98b91138eda81d7762d5371eb8a497fe"
  docker pull "docker:29.7.2-cli@sha256:000bb62ff495f986c9f5578eb67cc2cb98b91138eda81d7762d5371eb8a497fe"
  CLI_CID=$(docker create "docker:29.7.2-cli@sha256:000bb62ff495f986c9f5578eb67cc2cb98b91138eda81d7762d5371eb8a497fe")
  docker cp "$CLI_CID:/usr/local/bin/docker" /opt/sifap/bin/docker
  docker rm -v "$CLI_CID" >/dev/null
  chmod 0755 /opt/sifap/bin/docker
  echo "docker client staged: $(/opt/sifap/bin/docker --version 2>/dev/null || echo 'version check failed')"
else
  echo "docker client already staged at /opt/sifap/bin/docker"
fi

# --- basic auth for the public origin ---------------------------------
# Caddy reads the username and the bcrypt hash from this env file, so the
# credential lives in exactly one place on the VM, at mode 0600, and never
# in custom_data, the compose file or the Caddyfile.
#
# Two shapes are supported, decided by Terraform:
#   hash      - the operator supplied their own bcrypt hash; use verbatim.
#   password  - Terraform generated a random password and stored the
#               PLAINTEXT in Key Vault (so a human can be told it); this
#               hashes it here. `caddy hash-password` reads stdin when
#               stdin is not a TTY, which keeps the plaintext out of the
#               process table and out of `docker inspect`.
BASIC_AUTH_SECRET=$(read_kv_secret "demo-basic-auth-password" 30 || true)
# Rendered by Terraform to a literal "password" or "hash". Held in a
# variable rather than compared inline so the branch reads as a decision
# rather than as a constant.
BASIC_AUTH_KIND="password"
BASIC_AUTH_HASH=""

if [ -n "$BASIC_AUTH_SECRET" ]; then
  if [ "$BASIC_AUTH_KIND" = "hash" ]; then
    BASIC_AUTH_HASH="$BASIC_AUTH_SECRET"
  else
    # Piped, never passed as an argument. Trailing newline is required:
    # hash-password reads one line from a non-interactive stdin.
    BASIC_AUTH_HASH=$(printf '%s\n' "$BASIC_AUTH_SECRET" \
      | docker run --rm -i "caddy:2.10.2-alpine@sha256:4c6e91c6ed0e2fa03efd5b44747b625fec79bc9cd06ac5235a779726618e530d" caddy hash-password 2>/dev/null | tr -d '\r\n')
  fi
fi

if [ -z "$BASIC_AUTH_HASH" ]; then
  # FAIL CLOSED. An unreadable credential must never degrade into an open
  # origin, so the site gets a hash of a random string nobody holds: the
  # URL stays up, /healthz still answers, and every other route is simply
  # unenterable until this is fixed.
  echo "############################################################"
  echo "WARNING: could not build the basic-auth hash for the demo URL."
  echo "WARNING: the site is being locked with an UNKNOWN password."
  echo "WARNING: nobody can sign in until this is repaired - which is the"
  echo "WARNING: intended failure mode; an open origin is not."
  echo "WARNING: fix: confirm the VM identity has Get on the vault and"
  echo "WARNING: that the 'demo-basic-auth-password' secret exists, then"
  echo "WARNING: re-run  sudo /opt/sifap/bootstrap.sh"
  echo "############################################################"
  BASIC_AUTH_HASH=$(head -c 32 /dev/urandom | base64 \
    | docker run --rm -i "caddy:2.10.2-alpine@sha256:4c6e91c6ed0e2fa03efd5b44747b625fec79bc9cd06ac5235a779726618e530d" caddy hash-password 2>/dev/null | tr -d '\r\n')
fi

# Written whole on every run, umask first so it is never briefly readable.
# The hash is a verifier, not a password, but it is still bcrypt-crackable
# offline and gets the same 0600 treatment as adabas.env.
( umask 077
  printf 'SIFAP_BASIC_AUTH_USER=%s\n' 'sifap' > /opt/sifap/caddy.env
  printf 'SIFAP_BASIC_AUTH_HASH=%s\n' "$BASIC_AUTH_HASH" >> /opt/sifap/caddy.env )
chown root:root /opt/sifap/caddy.env
chmod 0600 /opt/sifap/caddy.env
echo "basic auth configured for user 'sifap' (hash not logged)"

unset BASIC_AUTH_SECRET BASIC_AUTH_HASH BASIC_AUTH_KIND

docker compose up -d --remove-orphans
/opt/sifap/update-www-status.sh || true

# Bounded readiness probe. Deliberately NOT fatal: Adabas can take several
# minutes to build the demo database and we do not want a slow disk to be
# reported as a broken lab. It only makes the log honest.
echo "waiting for the Adabas nucleus to answer (up to 10 minutes)"
for attempt in $(seq 1 60); do
  state=$(docker inspect -f '{{.State.Health.Status}}' adabas-db 2>/dev/null || echo unknown)
  if [ "$state" = "healthy" ]; then
    echo "adabas-db is healthy after $((attempt * 10))s"
    break
  fi
  sleep 10
done

echo "--- container state ---"
docker compose ps
echo "-----------------------"

# --- provisioning ------------------------------------------------------
# Hand off to systemd rather than running it here. run-all.sh loads Adabas
# and compiles the whole SIFAPPRD library, which takes far longer than
# cloud-init should be kept waiting; --no-block lets bootstrap.sh finish
# and report while the load continues in the background.
systemctl daemon-reload
systemctl enable sifap-provisioning.service >/dev/null 2>&1 || true
if [ -f /opt/sifap/provisioning/run-all.sh ]; then
  echo "starting sifap-provisioning (Adabas load + Natural compile, runs in background)"
else
  echo "WARNING: /opt/sifap/provisioning/run-all.sh is absent; the unit will"
  echo "WARNING: start, fail immediately and say exactly why. That is"
  echo "WARNING: deliberate - a silent no-op is how a demo reaches the room"
  echo "WARNING: with an empty database."
fi
systemctl restart --no-block sifap-provisioning.service || true

# --- demo url --------------------------------------------------------
# Bounded and NOT fatal, same reasoning as the Adabas probe above. With
# Caddy's internal CA the certificate is ready in seconds; with Let's
# Encrypt it waits on an ACME round trip that can take a minute.
echo "checking the demo URL: https://sifap-lab-eastus2.cloudapp.azure.com/healthz"
DEMO_OK=0
for attempt in $(seq 1 20); do
  # -k because the internal-CA certificate is not in the VM's trust store.
  # This only proves the proxy is answering over TLS, not that the chain is
  # publicly trusted - a browser is the judge of that.
  if curl -sSk --max-time 10 -o /dev/null "https://sifap-lab-eastus2.cloudapp.azure.com/healthz"; then
    DEMO_OK=1
    echo "demo URL answered after $((attempt * 10))s"
    break
  fi
  sleep 10
done
if [ "$DEMO_OK" -ne 1 ]; then
  echo "WARNING: https://sifap-lab-eastus2.cloudapp.azure.com/healthz did not answer yet."
  echo "WARNING: check 'docker compose logs caddy'. If it is failing ACME,"
  echo "WARNING: Let's Encrypt cannot reach port 80 from the internet -"
  echo "WARNING: that needs enable_public_acme = true in terraform.tfvars."
fi

if [ "$FALLBACK" -eq 1 ]; then
  echo "NOTE: started with the LOCAL fallback password, not the Key Vault one."
fi
echo ""
echo "  Demo URL      https://sifap-lab-eastus2.cloudapp.azure.com/           landing page"
echo "  Green screen  https://sifap-lab-eastus2.cloudapp.azure.com/terminal/  Natural session"
echo "  Modern app    https://sifap-lab-eastus2.cloudapp.azure.com/app/       placeholder until Stage 3 ships"
echo "  Adabas admin  https://sifap-lab-eastus2.cloudapp.azure.com/admin/     console"
echo "  Readiness     https://sifap-lab-eastus2.cloudapp.azure.com/healthz    no authentication"
echo ""
echo "  Sign in as 'sifap'. The password is in Key Vault -"
echo "  see the basic_auth_password_command output; it is never printed here."
echo ""
echo "  Legacy sources: /opt/sifap/corpus (read-only as /corpus in natural-ce)"
echo "  Provisioning:   systemctl status sifap-provisioning"
echo "                  tail -f /var/log/sifap-provisioning.log"
echo "=== SIFAP lab bootstrap finished at $(date -Is) ==="

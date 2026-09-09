#!/usr/bin/env bash
set -euo pipefail
umask 077
: "${SIFAP_RUNTIME_URL:?Missing protected runtime download URL}"
: "${SIFAP_RUNTIME_SHA:?Missing runtime checksum}"
[[ "$SIFAP_RUNTIME_SHA" =~ ^[a-f0-9]{64}$ ]] ||
  { echo 'Invalid release checksum' >&2; exit 2; }
stage="$(mktemp -d /opt/sifap-viewer-release.XXXXXX)"
trap 'rm -f "$stage/runtime.tar.gz"; rmdir "$stage"' EXIT
printf 'url = "%s"\n' "$SIFAP_RUNTIME_URL" | curl -q --config - --proto '=https' \
  --fail --silent --show-error --connect-timeout 15 --max-time 120 -o "$stage/runtime.tar.gz"
unset SIFAP_RUNTIME_URL
printf '%s  %s\n' "$SIFAP_RUNTIME_SHA" "$stage/runtime.tar.gz" | sha256sum -c -
if [[ ! -d /opt/sifap/www.before-direct-viewer ]]; then cp -a /opt/sifap/www /opt/sifap/www.before-direct-viewer; fi
tar -xzf "$stage/runtime.tar.gz" -C /opt/sifap
docker build --pull=false -t sifap-legacy-viewer:workshop-v2 /opt/sifap/provisioning/viewer-access
bash /opt/sifap/provisioning/viewer-access/seed-accounts.sh
bash /opt/sifap/provisioning/viewer-access/install.sh sifap-lab-438k30.eastus2.cloudapp.azure.com
bash /opt/sifap/provisioning/verify-startup.sh --check-only

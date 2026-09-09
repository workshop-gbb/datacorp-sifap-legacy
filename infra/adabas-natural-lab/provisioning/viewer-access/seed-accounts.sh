#!/usr/bin/env bash
set -euo pipefail
umask 077
directory=/opt/sifap/provisioning/viewer-access
output=/opt/sifap/workshop-accounts.env
node_image='node:24-alpine@sha256:e67514e5d0f6c46656005e1b693b2ec9d52e80b641307de684d4a015ba7a4eaf'

admin_password="$(/opt/sifap/read-secret.sh demo-basic-auth-password)"
viewer_password="$(/opt/sifap/read-secret.sh demo-viewer-password)"
trap 'unset admin_password viewer_password admin_hash viewer_hash' EXIT

admin_hash="$(printf '%s\n' "$admin_password" | docker run --rm -i --network none \
  -v "$directory:/app:ro" -w /app "$node_image" \
  node hash-password.mjs)"
viewer_hash="$(printf '%s\n' "$viewer_password" | docker run --rm -i --network none \
  -v "$directory:/app:ro" -w /app "$node_image" \
  node hash-password.mjs)"

cat > "$output" <<EOF
SIFAP_ADMIN_USERNAME='admin'
SIFAP_ADMIN_PASSWORD_HASH='$admin_hash'
SIFAP_VIEWER_USERNAME='viewer'
SIFAP_VIEWER_PASSWORD_HASH='$viewer_hash'
EOF
chmod 0600 "$output"
chown root:root "$output"
printf 'Workshop account hashes prepared from Key Vault. No password printed.\n'

#!/usr/bin/env bash
set -euo pipefail
umask 077
hostname="${1:?Provide the legacy hostname}"
[[ "$hostname" == sifap-lab-438k30.eastus2.cloudapp.azure.com ]] ||
  { printf 'ERROR: this installer targets only the existing SIFAP legacy lab.\n' >&2; exit 2; }

directory=/opt/sifap/provisioning/viewer-access
accounts=/opt/sifap/workshop-accounts.env
test -r /opt/sifap/caddy.env
test -r /opt/sifap/docker-compose.yml
test -r "$directory/Caddyfile"
if [[ ! -r "$accounts" ]]; then
  bash "$directory/seed-accounts.sh"
fi
[[ "$(stat -c '%a %U' "$accounts")" == "600 root" ]] ||
  { printf 'ERROR: %s must be mode 600 and owned by root.\n' "$accounts" >&2; exit 2; }
docker image inspect sifap-legacy-viewer:workshop-v2 > /dev/null
[[ "$(docker inspect --format '{{.State.Running}}' ttyd-viewer)" == true ]]
[[ "$(docker inspect --format '{{.State.Running}}' ttyd)" == true ]]

project="$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' caddy)"
[[ "$project" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo "ERROR: cannot identify the existing Compose project." >&2; exit 1; }
image="$(docker inspect --format '{{.Config.Image}}' caddy)"

# The restricted Natural session driver must release its buffer-pool slot on
# disconnect; without it a closed browser tab exhausts Natural CE capacity.
install -m 0755 "$directory/viewer-session.sh" /opt/sifap/viewer-session.sh

export SIFAP_HOST="$hostname"
docker run --rm --network none -e SIFAP_HOST \
  -v "$directory/Caddyfile:/etc/caddy/Caddyfile:ro" "$image" caddy validate --config /etc/caddy/Caddyfile

if [[ ! -f /opt/sifap/Caddyfile.before-direct-viewer ]]; then
  cp -p /opt/sifap/Caddyfile /opt/sifap/Caddyfile.before-direct-viewer
fi
compose=(docker compose --project-name "$project" --env-file "$accounts"
  -f /opt/sifap/docker-compose.yml -f "$directory/compose.viewer.yaml")

"${compose[@]}" up -d --no-deps --no-build --force-recreate --wait --wait-timeout 60 viewer-access ttyd-viewer
cp -p /opt/sifap/Caddyfile /opt/sifap/Caddyfile.previous-viewer
install -m 0644 "$directory/Caddyfile" /opt/sifap/Caddyfile
if ! "${compose[@]}" up -d --force-recreate --no-deps --no-build --wait --wait-timeout 90 caddy; then
  cp -p /opt/sifap/Caddyfile.previous-viewer /opt/sifap/Caddyfile
  "${compose[@]}" up -d --force-recreate --no-deps --no-build --wait --wait-timeout 90 caddy
  printf 'ERROR: sign-in gateway activation failed; prior Caddy configuration restored.\n' >&2
  exit 1
fi
printf 'enabled\n' > /opt/sifap/guest-viewer-enabled
printf 'Legacy landing and credential sign-in enabled. Databases and Natural containers were not restarted.\n'

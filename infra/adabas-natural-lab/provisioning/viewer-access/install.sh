#!/usr/bin/env bash
set -euo pipefail
hostname="${1:?Provide the legacy hostname}"
[[ "$hostname" == sifap-lab-438k30.eastus2.cloudapp.azure.com ]] ||
  { printf 'ERROR: this installer targets only the existing SIFAP legacy lab.\n' >&2; exit 2; }
directory=/opt/sifap/provisioning/viewer-access
test -r /opt/sifap/caddy.env
test -r /opt/sifap/docker-compose.yml
test -r "$directory/Caddyfile"
docker image inspect sifap-legacy-viewer:workshop-v1 > /dev/null
[[ "$(docker inspect --format '{{.State.Running}}' ttyd-viewer)" == true ]]
project="$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' caddy)"
[[ "$project" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo "ERROR: cannot identify the existing Compose project." >&2; exit 1; }
image="$(docker inspect --format '{{.Config.Image}}' caddy)"
export SIFAP_HOST="$hostname"
docker run --rm --network none --env-file /opt/sifap/caddy.env -e SIFAP_HOST \
  -v "$directory/Caddyfile:/etc/caddy/Caddyfile:ro" "$image" caddy validate --config /etc/caddy/Caddyfile
if [[ ! -f /opt/sifap/Caddyfile.before-direct-viewer ]]; then
  cp -p /opt/sifap/Caddyfile /opt/sifap/Caddyfile.before-direct-viewer
fi
compose=(docker compose --project-name "$project" -f /opt/sifap/docker-compose.yml -f "$directory/compose.viewer.yaml")
"${compose[@]}" up -d --no-deps --no-build --wait --wait-timeout 60 viewer-access
cp -p /opt/sifap/Caddyfile /opt/sifap/Caddyfile.previous-viewer
install -m 0644 "$directory/Caddyfile" /opt/sifap/Caddyfile
if ! "${compose[@]}" up -d --force-recreate --no-deps --no-build --wait --wait-timeout 90 caddy; then
  cp -p /opt/sifap/Caddyfile.previous-viewer /opt/sifap/Caddyfile
  "${compose[@]}" up -d --force-recreate --no-deps --no-build --wait --wait-timeout 90 caddy
  printf 'ERROR: viewer gateway activation failed; prior Caddy configuration restored.\n' >&2
  exit 1
fi
printf 'enabled\n' > /opt/sifap/guest-viewer-enabled
printf 'Legacy landing and direct viewer enabled. Existing databases and Natural containers were not restarted.\n'

#!/usr/bin/env bash
set -euo pipefail
phase=auto
[ -r /etc/sifap/provisioning.env ] && . /etc/sifap/provisioning.env || true
ddms="pending"; [ -f /opt/sifap/state/DDMS-READY ] && ddms="ready"
final="pending"; [ -f /opt/sifap/PROVISIONED ] && final="complete"
payload="ok"; [ -f /opt/sifap/PAYLOAD-FAILED ] && payload="failed"
cat > /opt/sifap/www/status.html <<EOF
<ul><li>Requested phase: <code>${SIFAP_PHASE:-$phase}</code></li><li>Payload: <code>$payload</code></li><li>DDMs: <code>$ddms</code></li><li>Final provisioning: <code>$final</code></li><li>Terminal: <a href="/terminal/">/terminal/</a></li></ul>
EOF

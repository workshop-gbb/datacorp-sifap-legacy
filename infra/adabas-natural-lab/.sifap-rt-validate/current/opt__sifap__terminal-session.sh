#!/bin/sh
# Alpine container: /bin/sh is busybox ash, not bash. Keep this POSIX.
set -u

CONTAINER=natural-ce

# Quoted heredoc: the operator's command arrives verbatim, so quotes and
# parentheses in a Natural session string cannot break this script.
NATURAL_CMD=$(cat <<'SIFAP_NATURAL_COMMAND'

SIFAP_NATURAL_COMMAND
)

say() { printf '%s\n' "$1"; }

if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
  say "The Natural container ($CONTAINER) is not running."
  say ""
  say "Check it from the VM with:  sudo docker compose -f /opt/sifap/docker-compose.yml ps"
  say "This window will close in 20 seconds."
  sleep 20
  exit 1
fi

say "Opening a Natural session in $CONTAINER ..."

if [ -n "$NATURAL_CMD" ]; then
  exec docker exec -it "$CONTAINER" sh -lc "$NATURAL_CMD"
fi

# `natural` is on the PATH inside a login shell - that is exactly how
# provisioning/lib.sh drives it in batch mode ("natural BATCHMODE ..."),
# so this is the same entry point, minus the batch flags. Probed rather
# than assumed: a moved binary degrades to the shell below instead of an
# exec failure the participant cannot read.
if docker exec "$CONTAINER" sh -lc 'command -v natural' >/dev/null 2>&1; then
  exec docker exec -it "$CONTAINER" sh -lc 'natural'
fi

for candidate in /opt/softwareag/Natural/bin/natural /opt/softwareag/Natural/bin/natrun; do
  if docker exec "$CONTAINER" test -x "$candidate" 2>/dev/null; then
    exec docker exec -it "$CONTAINER" "$candidate"
  fi
done

say ""
say "Could not find the Natural session driver in $CONTAINER."
say "Dropping you into a shell inside the container instead."
say ""
say "  ls /opt/softwareag/Natural/bin      # find the session driver"
say "  ls /corpus                          # the SIFAP sources, read-only"
say ""
say "Set terminal_natural_command in terraform.tfvars once you know the"
say "correct line, or edit /opt/sifap/terminal-session.sh on the VM and run"
say "  sudo docker compose -f /opt/sifap/docker-compose.yml restart ttyd"
say ""
exec docker exec -it "$CONTAINER" /bin/bash -l

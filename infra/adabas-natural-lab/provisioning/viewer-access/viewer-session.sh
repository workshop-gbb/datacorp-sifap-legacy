#!/bin/sh
# Alpine container: /bin/sh is busybox ash, not bash. Keep this POSIX.
#
# Natural CE allows only a few concurrent buffer-pool users. `docker exec` does
# not propagate the client's hang-up into the container, so a closed browser tab
# used to leave the Natural session running and consume that capacity until the
# lab was restarted. This script therefore terminates its own session on exit.
set -u

CONTAINER=natural-ce
MARKER="sifap-viewer-session-$$-$(date +%s)"

VIEWER_CMD=$(cat <<'SIFAP_VIEWER_COMMAND'
natural SM=ON 'STACK=(LOGON SIFAPPRD;VIEWBENF;FIN)'
SIFAP_VIEWER_COMMAND
)

say() { printf '%s\n' "$1"; }

cleanup() {
  docker exec "$CONTAINER" sh -c '
    marker=$1
    wrapper=""
    for p in /proc/[0-9]*; do
      [ -r "$p/cmdline" ] || continue
      case "$(tr "\0" " " < "$p/cmdline" 2>/dev/null)" in
        *"$marker"*) wrapper="${p#/proc/}" ;;
      esac
    done
    [ -n "$wrapper" ] || exit 0
    children=""
    for c in /proc/[0-9]*; do
      [ -r "$c/status" ] || continue
      if [ "$(awk "/^PPid:/{print \$2}" "$c/status" 2>/dev/null)" = "$wrapper" ]; then
        children="$children ${c#/proc/}"
      fi
    done
    # shellcheck disable=SC2086
    kill -TERM $children "$wrapper" 2>/dev/null || true
    sleep 2
    # shellcheck disable=SC2086
    kill -KILL $children "$wrapper" 2>/dev/null || true
  ' _ "$MARKER" >/dev/null 2>&1 || true
}

cleanup_previous() {
  # Only one viewer client is allowed. A browser can terminate ttyd without
  # giving this wrapper a final signal, while Docker leaves the exec process
  # inside natural-ce. Reap only prior VIEWBENF sessions before opening the
  # next one; operator Natural sessions are never matched.
  docker exec "$CONTAINER" sh -c '
    for p in /proc/[0-9]*; do
      [ -r "$p/cmdline" ] || continue
      cmd=$(tr "\0" " " < "$p/cmdline" 2>/dev/null) || continue
      case "$cmd" in
        natural*VIEWBENF*) kill -TERM "${p#/proc/}" 2>/dev/null || true ;;
      esac
    done
    sleep 2
    for p in /proc/[0-9]*; do
      [ -r "$p/cmdline" ] || continue
      cmd=$(tr "\0" " " < "$p/cmdline" 2>/dev/null) || continue
      case "$cmd" in
        natural*VIEWBENF*) kill -KILL "${p#/proc/}" 2>/dev/null || true ;;
      esac
    done
  ' >/dev/null 2>&1 || true
}

stop() {
  say ""
  say "$1"
  say "This window will close in 20 seconds."
  sleep 20
  exit 1
}

trap 'cleanup; exit 0' EXIT HUP INT TERM

if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
  stop "The Natural container ($CONTAINER) is not running."
fi

cleanup_previous

say "SIFAP - read-only session"
say ""
say "This account opens the beneficiary query screen only. It cannot reach"
say "the Natural command line, so the registration and batch programs and"
say "the Adabas console are all out of reach. Leaving the screen with PF3"
say "ends the session."
say ""

docker exec -it "$CONTAINER" sh -c ": $MARKER; exec timeout 3300 $VIEWER_CMD"

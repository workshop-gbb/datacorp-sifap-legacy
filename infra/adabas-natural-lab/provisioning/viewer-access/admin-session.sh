#!/bin/sh
# Releases a previous interactive administrator session before opening the next
# one. It never matches VIEWBENF, the Natural development server or batch jobs.
set -u
CONTAINER=natural-ce

docker exec "$CONTAINER" sh -c '
  for p in /proc/[0-9]*; do
    [ -r "$p/cmdline" ] || continue
    cmd=$(tr "\0" " " < "$p/cmdline" 2>/dev/null) || continue
    case "$cmd" in
      natural*VIEWBENF*) ;;
      natural*) kill -TERM "${p#/proc/}" 2>/dev/null || true ;;
    esac
  done
  sleep 2
  for p in /proc/[0-9]*; do
    [ -r "$p/cmdline" ] || continue
    cmd=$(tr "\0" " " < "$p/cmdline" 2>/dev/null) || continue
    case "$cmd" in
      natural*VIEWBENF*) ;;
      natural*) kill -KILL "${p#/proc/}" 2>/dev/null || true ;;
    esac
  done
' >/dev/null 2>&1 || true

exec timeout 3300 /usr/local/bin/sifap-session

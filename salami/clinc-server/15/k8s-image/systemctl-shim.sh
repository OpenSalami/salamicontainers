#!/usr/bin/env bash
# Minimal systemctl shim for Omnibus/Cinc Server inside Kubernetes.
# It pretends that certain units exist and are active/enabled so
# Chef's Systemd provider is satisfied, but does NOT manage real services.

set -euo pipefail

echo "[systemctl-shim] systemctl $*" >&2

SUBCMD=""
UNIT=""

# Very simple argument parser: first arg = subcommand, first non-flag after that = unit
for arg in "$@"; do
  if [ -z "$SUBCMD" ]; then
    SUBCMD="$arg"
  elif [ -z "$UNIT" ] && [[ "$arg" != -* ]]; then
    UNIT="$arg"
    break
  fi
done

case "$SUBCMD" in
  daemon-reload)
    # No-op
    exit 0
    ;;
  enable|disable|start|stop|restart|reload)
    # Pretend these always work
    exit 0
    ;;
  is-enabled)
    # Pretend everything is enabled
    exit 0
    ;;
  is-active)
    # Pretend everything is active
    exit 0
    ;;
  show)
    # Chef's Systemd provider calls `systemctl show <unit> ...` and expects
    # some properties. We fake a minimal, always-active unit.
    if [ -n "$UNIT" ]; then
      cat <<EOF
Id=$UNIT
Names=$UNIT
LoadState=loaded
ActiveState=active
SubState=running
UnitFileState=enabled
EOF
    fi
    exit 0
    ;;
  *)
    # Default: succeed
    exit 0
    ;;
esac
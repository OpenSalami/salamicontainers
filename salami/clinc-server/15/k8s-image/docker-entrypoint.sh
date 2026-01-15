#!/usr/bin/env bash
set -euo pipefail

# Basic trap to forward signals to cinc-server-ctl for graceful shutdown
_term() {
  echo "[entrypoint] Caught SIGTERM, stopping Cinc Server..." >&2
  cinc-server-ctl stop || true
  exit 0
}

trap _term TERM INT

BOOTSTRAP_FLAG="/etc/opscode/.bootstrapped"

# If config is not bootstrapped yet, run reconfigure (idempotent)
if [ ! -f "$BOOTSTRAP_FLAG" ]; then
  echo "[entrypoint] Running initial cinc-server-ctl reconfigure..." >&2
  cinc-server-ctl reconfigure
  touch "$BOOTSTRAP_FLAG"
fi

# Allow overriding default behavior via args (for debugging, etc.)
if [ "${1:-}" = "bash" ]; then
  exec bash
fi

# Start all services
echo "[entrypoint] Starting Cinc Server services..." >&2
cinc-server-ctl start

# Simple wait loop: tail nginx log so the container stays alive
LOG_FILE="/var/log/opscode/nginx/current"

if [ -f "$LOG_FILE" ]; then
  echo "[entrypoint] Tailing $LOG_FILE" >&2
  exec tail -F "$LOG_FILE"
else
  echo "[entrypoint] Log file $LOG_FILE not found, sleeping..." >&2
  # Fallback: sleep loop
  while true; do
    sleep 3600 &
    wait $!
  done
fi

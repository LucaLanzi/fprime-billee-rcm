#!/usr/bin/env bash
# Runs the LAN F´ GDS forever. Whatever the GDS exits for -- board unplugged,
# missing build, crash, network not up yet -- wait RETRY_SECONDS and start it
# again. Meant to be the command a detached `screen` session runs under the
# billee-lan-gds systemd service (see install-lan-gds-service.sh), but it works
# standalone too: `./gds-run-loop.sh`.
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RETRY_SECONDS="${GDS_RETRY_SECONDS:-10}"

while true; do
  echo "[gds-loop] $(date '+%F %T') starting ./lan_uart_gds.sh"
  if ./lan_uart_gds.sh "$@"; then
    rc=0
  else
    rc=$?
  fi
  echo "[gds-loop] $(date '+%F %T') lan_uart_gds.sh exited (rc=${rc}); retrying in ${RETRY_SECONDS}s"
  sleep "$RETRY_SECONDS"
done

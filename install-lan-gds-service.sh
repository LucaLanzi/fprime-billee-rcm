#!/usr/bin/env bash
# Installs a systemd service that runs ./lan_uart_gds.sh at boot inside a
# detached `screen` session, auto-retrying every 10s if the GDS drops. Installs
# `screen` first if it's missing.
#
#   sudo ./install-lan-gds-service.sh
#
# After: attach with `screen -r billee-lan-gds` (Ctrl-A D to detach),
#        follow logs with `journalctl -u billee-lan-gds -f`.
set -euo pipefail

SERVICE_NAME="billee-lan-gds"
UNIT_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOOP_SCRIPT="${SCRIPT_DIR}/gds-run-loop.sh"
GDS_SCRIPT="${SCRIPT_DIR}/lan_uart_gds.sh"
RETRY_SECONDS="${GDS_RETRY_SECONDS:-10}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run with sudo: sudo ./install-lan-gds-service.sh" >&2
  exit 1
fi

RUN_USER="${SUDO_USER:-}"
if [ -z "$RUN_USER" ] || [ "$RUN_USER" = "root" ]; then
  echo "Run this via 'sudo' from your normal user account (needs \$SUDO_USER)." >&2
  exit 1
fi
RUN_GROUP="$(id -gn "$RUN_USER")"

for f in "$LOOP_SCRIPT" "$GDS_SCRIPT"; do
  [ -f "$f" ] || { echo "Missing $f" >&2; exit 1; }
done

# 1. screen
if ! command -v screen >/dev/null 2>&1; then
  echo "[INFO] Installing screen..."
  apt-get update -qq
  apt-get install -y screen
fi
SCREEN_BIN="$(command -v screen)"

chmod +x "$LOOP_SCRIPT" "$GDS_SCRIPT"

# 2. systemd unit
echo "[INFO] Writing ${UNIT_PATH}"
cat > "$UNIT_PATH" <<EOF
[Unit]
Description=BILLEE LAN F Prime GDS (detached screen, auto-retry)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${RUN_USER}
Group=${RUN_GROUP}
SupplementaryGroups=dialout
WorkingDirectory=${SCRIPT_DIR}
Environment=GDS_RETRY_SECONDS=${RETRY_SECONDS}
# -D -m : run screen detached but WITHOUT forking, so systemd tracks it.
ExecStart=${SCREEN_BIN} -DmS ${SERVICE_NAME} ${LOOP_SCRIPT}
ExecStop=${SCREEN_BIN} -S ${SERVICE_NAME} -X quit
# gds-run-loop.sh already retries every ${RETRY_SECONDS}s; this only matters if
# screen itself dies.
Restart=always
RestartSec=${RETRY_SECONDS}

[Install]
WantedBy=multi-user.target
EOF

# 3. enable + start
systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}.service"

echo
echo "[INFO] ${SERVICE_NAME} enabled and started (runs at every boot)."
echo "  status : systemctl status ${SERVICE_NAME}"
echo "  logs   : journalctl -u ${SERVICE_NAME} -f"
echo "  attach : screen -r ${SERVICE_NAME}    (detach with Ctrl-A then D)"
echo "  stop   : sudo systemctl stop ${SERVICE_NAME}"

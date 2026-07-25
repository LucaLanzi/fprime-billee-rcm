#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UART_DEVICE="${UART_DEVICE:-/dev/ttyACM0}"
DICTIONARY_PATH="${DICTIONARY_PATH:-${PROJECT_ROOT}/build-artifacts/zephyr/fprime-zephyr-deployment/dict/rp2350DeploymentTopologyDictionary.json}"
GDS_BIN="${PROJECT_ROOT}/fprime-venv/bin/fprime-gds"

if [[ ! -x "${GDS_BIN}" ]]; then
    echo "F Prime GDS was not found at ${GDS_BIN}. Run 'make setup' first." >&2
    exit 1
fi

if [[ ! -f "${DICTIONARY_PATH}" ]]; then
    echo "The RP2350 dictionary was not found. Run 'make zephyr-rp2350' first." >&2
    exit 1
fi

if [[ ! -c "${UART_DEVICE}" ]]; then
    echo "Serial device ${UART_DEVICE} is not available." >&2
    echo "On WSL2, attach the runtime USB CDC device with usbipd, then check 'ls -l /dev/ttyACM*'." >&2
    exit 1
fi

exec "${GDS_BIN}" \
  --no-app \
  --dictionary "${DICTIONARY_PATH}" \
  --framing-selection space-packet-space-data-link \
  --communication-selection uart \
  --uart-device "${UART_DEVICE}" \
  --uart-skip-port-check \
  --uart-baud 115200 \
  "$@"

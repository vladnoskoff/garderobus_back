#!/usr/bin/env bash
set -euo pipefail

INSTALL_URL="${INSTALL_URL:-https://raw.githubusercontent.com/vladnoskoff/garderobus_back/main/install_for_server/install.sh}"
TEMP_SCRIPT="$(mktemp -t garderobus-install.XXXXXX)"

cleanup() {
    rm -f "${TEMP_SCRIPT}"
}
trap cleanup EXIT

curl -fsSL "${INSTALL_URL}" -o "${TEMP_SCRIPT}"
chmod +x "${TEMP_SCRIPT}"
exec bash "${TEMP_SCRIPT}"

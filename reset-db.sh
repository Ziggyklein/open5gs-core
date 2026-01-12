#!/usr/bin/env bash
set -euo pipefail

echo "⚠️  This will stop the stack and delete MongoDB data (subscribers, sessions, config cache)."

SUDO=""
if [ "${EUID:-$(id -u)}" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

${SUDO}docker compose down -v

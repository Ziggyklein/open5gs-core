#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# laad .env (export variabelen automatisch)
set -a
[ -f .env ] && source .env
set +a

IFACE="${IFACE:-$(ip route | awk '/default/ {print $5; exit}')}"

if [ -n "$UE_SUBNET" ]; then
  sudo iptables -t nat -A POSTROUTING -s "$UE_SUBNET" -o "$IFACE" -j MASQUERADE 2>/dev/null || true
else
  sudo iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null || true
fi

sudo docker compose pull
sudo docker compose up -d
sudo docker compose ps
sudo docker compose logs --tail=50 amf smf upf || true

